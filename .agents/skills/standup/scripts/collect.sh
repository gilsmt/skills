#!/usr/bin/env bash
#
# collect.sh — read-only standup data collector for the `standup` skill.
#
# Emits a stable, tab-separated, uncolored block format so an agent can parse it.
# This script NEVER mutates the repository. Read-only git plumbing only:
#   log, status, stash list, branch, show, rev-list, for-each-ref, config --get,
#   rev-parse, diff.
#
# Usage:
#   collect.sh [--author NAME|all] [--days N] [--since DATE] [--until DATE]
#              [--scope auto|current|dir] [--root DIR] [--max-depth N]
#              [--week MON-FRI] [--branch B] [--no-state]
#
# Defaults: author = git config user.name, scope = auto, max-depth = 2,
#           week = MON-FRI, state sections included.

set -uo pipefail

AUTHOR=""
SCOPE="auto"
ROOT=""
MAXDEPTH=2
WEEK="MON-FRI"
ONLY_BRANCH=""
WANT_STATE=1
SINCE_OVERRIDE=""
UNTIL_OVERRIDE=""
FLOOR_SLACK_SECONDS=$((180 * 24 * 3600))

die() { echo "collect.sh: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --author)    AUTHOR="${2-}"; shift 2 || die "--author needs a value" ;;
    --days)      SINCE_OVERRIDE="days:${2-}"; shift 2 || die "--days needs a value" ;;
    --since)     SINCE_OVERRIDE="date:${2-}"; shift 2 || die "--since needs a value" ;;
    --until)     UNTIL_OVERRIDE="${2-}"; shift 2 || die "--until needs a value" ;;
    --scope)     SCOPE="${2-}"; shift 2 || die "--scope needs a value" ;;
    --root)      ROOT="${2-}"; shift 2 || die "--root needs a value" ;;
    --max-depth) MAXDEPTH="${2-}"; shift 2 || die "--max-depth needs a value" ;;
    --week)      WEEK="${2-}"; shift 2 || die "--week needs a value" ;;
    --branch)    ONLY_BRANCH="${2-}"; shift 2 || die "--branch needs a value" ;;
    --no-state)  WANT_STATE=0; shift ;;
    -h|--help)   awk 'NR>1 && /^#/ { sub(/^# ?/,""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *)           die "unknown argument: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git not found on PATH"

# ---------------------------------------------------------------- date helpers

# Portable "N days ago" across BSD (macOS) and GNU date.
date_ago() { # $1 = integer days
  local n="$1"
  if date -v-"${n}"d +%Y-%m-%d >/dev/null 2>&1; then
    date -v-"${n}"d +%Y-%m-%d
  else
    date -d "-${n} days" +%Y-%m-%d
  fi
}

dow_num() { # ISO day of week, 1=Mon .. 7=Sun
  local d
  d=$(date -j -f "%Y-%m-%d" "$1" +%u 2>/dev/null) && { echo "$d"; return; }
  date -d "$1" +%u
}

# Map MON/TUE/... -> ISO number.
dow_name_to_num() {
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    MON) echo 1 ;; TUE) echo 2 ;; WED) echo 3 ;; THU) echo 4 ;;
    FRI) echo 5 ;; SAT) echo 6 ;; SUN) echo 7 ;; *) echo "" ;;
  esac
}

# ------------------------------------------------------------ window resolver
#
# Reproduces git-standup's weekday logic, plus one fix: running on a non-working
# day steps back to the last working day instead of reporting "no activity".
#
#   working day, not first of week -> since midnight yesterday
#   first working day of the week  -> since midnight of the previous week-end day
#   non-working day                -> since midnight of the last working day

resolve_window() {
  local week_start week_end today_dow offset since_day

  week_start=$(dow_name_to_num "${WEEK%%-*}")
  week_end=$(dow_name_to_num "${WEEK#*-}")
  [[ -z "$week_start" ]] && die "bad --week start in '$WEEK' (use MON-FRI)"
  [[ -z "$week_end" ]] && die "bad --week end in '$WEEK' (use MON-FRI)"

  today_dow=$(dow_num "$(date +%Y-%m-%d)")
  span=$(( (week_end - week_start + 7) % 7 ))

  # Offset-based so wrap-around weeks (SUN-THU) work; a plain >= / <= comparison
  # treats SUN-THU as an empty range and never finds a working day.
  in_week() { [[ $(( ($1 - week_start + 7) % 7 )) -le "$span" ]]; }

  if in_week "$today_dow"; then
    if [[ "$today_dow" -eq "$week_start" ]]; then
      # First working day of the week: cover the whole previous working day.
      offset=$(( (week_start - week_end + 7) % 7 ))
      [[ "$offset" -eq 0 ]] && offset=7
      since_day=$(date_ago "$offset")
    else
      since_day=$(date_ago 1)
    fi
  else
    offset=1
    while :; do
      if in_week "$(dow_num "$(date_ago "$offset")")"; then
        since_day=$(date_ago "$offset")
        break
      fi
      offset=$((offset + 1))
      [[ "$offset" -gt 14 ]] && die "could not resolve last working day from --week $WEEK"
    done
  fi

  SINCE="${since_day} 00:00:00"
  UNTIL="${UNTIL_OVERRIDE:-now}"
  WINDOW_KIND="weekday"
}

if [[ "$SINCE_OVERRIDE" == days:* ]]; then
  SINCE="$(date_ago "${SINCE_OVERRIDE#days:}") 00:00:00"
  UNTIL="${UNTIL_OVERRIDE:-now}"
  WINDOW_KIND="days"
elif [[ "$SINCE_OVERRIDE" == date:* ]]; then
  SINCE="${SINCE_OVERRIDE#date:}"
  UNTIL="${UNTIL_OVERRIDE:-now}"
  WINDOW_KIND="date"
else
  resolve_window
fi

# Epoch bounds, computed once. Used for exact post-filtering.
# Accepts a bare date as well as a full timestamp, on either date implementation.
to_epoch() { # $1 = date string; empty output on failure
  local v="$1" out
  [[ "$v" == "now" ]] && { date +%s; return; }
  # Already epoch seconds?
  [[ "$v" =~ ^-?[0-9]+$ ]] && { echo "$v"; return; }
  # Try each format in a scratch var; a failed parse must not clobber the input.
  for fmt in "%Y-%m-%d %H:%M:%S" "%Y-%m-%dT%H:%M:%S" "%Y-%m-%d"; do
    out=$(date -j -f "$fmt" "$v" +%s 2>/dev/null)
    [[ -n "$out" ]] && { echo "$out"; return; }
  done
  date -d "$v" +%s 2>/dev/null
}

SINCE_EPOCH=$(to_epoch "$SINCE")
[[ -z "$SINCE_EPOCH" ]] && die "could not parse --since '$SINCE' (use YYYY-MM-DD or 'YYYY-MM-DD HH:MM:SS')"

UNTIL_EPOCH=$(to_epoch "${UNTIL_OVERRIDE:-now}")
[[ -z "$UNTIL_EPOCH" ]] && die "could not parse --until '$UNTIL_OVERRIDE'"

# `git log --since` prunes whole subtrees the moment it meets a commit older
# than the cutoff, so a single non-monotonic date (rebase, amend, cherry-pick,
# imported history) hides newer commits behind it. Reach back further than the
# window and filter exactly afterwards.
SINCE_FLOOR=$((SINCE_EPOCH - FLOOR_SLACK_SECONDS))

# --------------------------------------------------------------- repo discovery

if [[ -z "$ROOT" ]]; then
  if [[ "$SCOPE" == "auto" || "$SCOPE" == "dir" ]]; then ROOT="$(pwd)"; else ROOT="$(pwd)"; fi
fi
[[ -d "$ROOT" ]] || die "--root '$ROOT' is not a directory"

discover_repos() {
  local base="$1"

  # Honour git-standup's whitelist file when present.
  local search="."
  [[ -f "$base/.git-standup-whitelist" ]] && search="$(cat "$base/.git-standup-whitelist")"

  # Absolute paths: the collection loop cd's into each repo, so relative paths
  # would resolve against the previously-visited repo and silently skip the rest.
  # A working tree / submodule has .git as a FILE, not a directory; the upstream
  # tool drops those, but keeping them here covers linked worktrees.
  find "$base/$search" -maxdepth "$MAXDEPTH" -name .git 2>/dev/null | while read -r g; do
    (cd "$(dirname "$g")" 2>/dev/null && pwd -P)
  done | sort -u
}

REPOS=()
if [[ "$SCOPE" == "current" ]]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository (--scope current)"
  REPOS=("$top")
else
  # auto: a repo at ROOT means "just this repo", matching git-standup.
  if [[ "$SCOPE" == "auto" && -e "$ROOT/.git" ]]; then
    REPOS=("$ROOT")
  else
    # bash 3.2 has no mapfile.
    while IFS= read -r line; do
      [[ -n "$line" ]] && REPOS+=("$line")
    done < <(discover_repos "$ROOT")
  fi
fi

[[ ${#REPOS[@]} -eq 0 ]] && die "no git repositories found under $ROOT (try --scope dir --max-depth 3)"

# ------------------------------------------------------------------- emission

TAB=$'\t'
AUTHOR_ARG=()
if [[ -n "$AUTHOR" && "$AUTHOR" != "all" ]]; then
  AUTHOR_ARG=(--author="$AUTHOR")
fi

BRANCH_ARG=()
[[ -n "$ONLY_BRANCH" ]] && BRANCH_ARG=(--first-parent "$ONLY_BRANCH")

# Explicit --author wins; otherwise resolve per repo inside the loop, since a
# per-repo user.email is a common way to keep work and personal commits apart.
AUTHOR_EXPLICIT="$AUTHOR"
AUTHOR_ALL=0
[[ "$AUTHOR" == "all" ]] && AUTHOR_ALL=1

if [[ ${#BRANCH_ARG[@]} -eq 0 ]]; then BRANCH_SAFE=(); else BRANCH_SAFE=("${BRANCH_ARG[@]}"); fi

echo "### standup-collect v1"
echo "### root${TAB}$ROOT"
echo "### scope${TAB}$SCOPE${TAB}max-depth=$MAXDEPTH"
echo "### window${TAB}$SINCE${TAB}until=$UNTIL${TAB}kind=$WINDOW_KIND${TAB}week=$WEEK"
echo "### author${TAB}${AUTHOR_EXPLICIT:-<per-repo git config user.name>}"
echo "### collected_at${TAB}$(date +%Y-%m-%dT%H:%M:%S%z)"
echo

for repo in "${REPOS[@]}"; do
  cd "$repo" 2>/dev/null || continue
  git rev-parse --git-dir >/dev/null 2>&1 || continue

  # Resolve the author for THIS repo, then freeze the git arg array.
  AUTHOR_ARG=()
  if [[ "$AUTHOR_ALL" == 1 ]]; then
    AUTHOR_LABEL="all"
  elif [[ -n "$AUTHOR_EXPLICIT" ]]; then
    AUTHOR_LABEL="$AUTHOR_EXPLICIT"
    AUTHOR_ARG=(--author="$AUTHOR_EXPLICIT")
  else
    AUTHOR_LABEL="$(git config user.name 2>/dev/null)"
    if [[ -z "$AUTHOR_LABEL" ]]; then
      AUTHOR_LABEL="<unset: pass --author>"
    else
      AUTHOR_ARG=(--author="$AUTHOR_LABEL")
    fi
  fi
  if [[ ${#AUTHOR_ARG[@]} -eq 0 ]]; then AUTHOR_SAFE=(); else AUTHOR_SAFE=("${AUTHOR_ARG[@]}"); fi

  # Committer date, matching git-standup's default (-R switches it to author date).
  # Leading %ct column: sorts numerically and drives the exact window filter.
  log_commits_raw() {
    git --no-pager log --branches --remotes --no-merges \
      --since="@$SINCE_FLOOR" \
      ${AUTHOR_SAFE[@]+"${AUTHOR_SAFE[@]}"} ${BRANCH_SAFE[@]+"${BRANCH_SAFE[@]}"} \
      --date=iso-strict \
      --pretty=format:'%ct%x09%H%x09%ad%x09%an%x09%ae%x09%s' 2>/dev/null \
    | awk -F'\t' -v s="$SINCE_EPOCH" -v u="$UNTIL_EPOCH" \
        '$1 >= s && $1 <= u { print }' \
    | sort -r
  }

  # Public shape: sha, date, author name, author email, subject.
  log_commits() { log_commits_raw | cut -f2-; }

  name=$(basename "$repo")
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ -z "$branch" ]] && branch="(detached)"
  cfg_name=$(git config user.name 2>/dev/null)
  cfg_email=$(git config user.email 2>/dev/null)

  # upstream + ahead/behind
  upstream=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)
  ahead=""; behind=""
  if [[ -n "$upstream" ]]; then
    counts=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null)
    behind="${counts%%$TAB*}"; ahead="${counts##*$TAB}"
  fi

  dirty_count=0
  if [[ "$WANT_STATE" == 1 ]]; then
    dirty_count=$(git status --porcelain 2>/dev/null | grep -c . )
  fi

  echo "=== REPO${TAB}$repo"
  echo "--- meta"
  echo "name${TAB}$name"
  echo "branch${TAB}$branch"
  echo "upstream${TAB}${upstream:-none}"
  echo "ahead${TAB}${ahead:-?}"
  echo "behind${TAB}${behind:-?}"
  echo "cfg_name${TAB}${cfg_name:-unset}"
  echo "cfg_email${TAB}${cfg_email:-unset}"
  echo "dirty_files${TAB}$dirty_count"
  echo "head${TAB}$(git rev-parse --short HEAD 2>/dev/null)"

  echo "--- commits"
  log_commits | sort -r

  ncommits=$(log_commits | grep -c .)
  echo
  echo "--- author_used${TAB}$AUTHOR_LABEL"
  echo "--- commits_count${TAB}${ncommits:-0}"

  if [[ "$WANT_STATE" == 1 ]]; then
    echo "--- uncommitted"
    git status --porcelain 2>/dev/null

    echo "--- uncommitted_diffstat"
    git diff --stat 2>/dev/null
    git diff --cached --stat 2>/dev/null

    echo "--- stashes"
    # Relative dates: "3 days ago" is what a standup needs; an ISO stamp makes
    # the reader do arithmetic to work out whether a stash is stale.
    git stash list --date=relative 2>/dev/null
    nstashes=$(git stash list 2>/dev/null | grep -c .)
    echo "--- stashes_count${TAB}${nstashes:-0}"

    echo "--- unpushed"
    if [[ -n "$upstream" && "${ahead:-0}" != "0" ]]; then
      git --no-pager log --date=iso-strict \
        --pretty=format:'%h%x09%ad%x09%s' "@{u}..HEAD" 2>/dev/null
    fi

    echo
    echo "--- branches_recent"
    git for-each-ref --sort=-committerdate --count=8 \
      --format='%(refname:short)%09%(committerdate:iso-strict)%09%(upstream:short)%09%(subject)' \
      refs/heads/ 2>/dev/null

    echo "--- whitespace_only_commits"
    # A commit whose diff vanishes under --ignore-all-space changed only
    # whitespace, so it is pure standup noise. `--stat` alone is not enough:
    # its summary line survives even when every hunk is ignored, so compare
    # per-file added/deleted counts instead.
    for sha in $(log_commits_raw | cut -f2); do
      nums=$(git show --ignore-all-space --format='' --numstat "$sha" 2>/dev/null \
             | awk -F'\t' '$1 != "-" && ($1 != 0 || $2 != 0) { n++ } END { print n+0 }')
      [[ "$nums" == "0" ]] && echo "$sha${TAB}$(git log -1 --format=%s "$sha")"
    done
  fi

  echo "=== END"
  echo
done