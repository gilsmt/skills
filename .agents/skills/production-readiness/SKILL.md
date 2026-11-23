---
name: production-readiness
description: Use when the user says "ready to ship", "ready for launch", "going live", "ready for prod", "production-ready", "ship it", before opening to real users, or before announcing a launch. Walks the full pre-launch checklist across security, data, reliability, ops, billing, and rollout — and explicitly flags what's missing.
---

# Production Readiness Review

> "Working in dev" and "safe for real users" are different states. This is the pre-launch checklist: have you actually thought about each of these.

## When to use
- Anyone says "we're ready to launch" / "let's ship it" / "going live tomorrow"
- Before a public announcement (Show HN, Product Hunt, press, paid ads)
- Before opening a closed beta to real customers
- Before turning off feature flags for a major feature

## When to skip
- Internal demos to teammates with no real user impact
- Dev environments still in early scaffolding

## How to run this

For each section: ask the question. Ground it in the actual code/config (not "I'll check later"). If something is missing, it's a launch blocker unless explicitly waived with a reason.

This is a **review skill** — pair it with the underlying topic skills (`secrets-and-env`, `auth-and-sessions`, etc.) when you find a gap.

---

## 1. Secrets & configuration

- [ ] No `NEXT_PUBLIC_*_SECRET` / `_KEY` / `_TOKEN` in the bundle (`secrets-and-env`)
- [ ] `.env*` gitignored; no committed secrets in history (`git log -p | grep -E '(_KEY|_SECRET|_TOKEN)='` returns nothing)
- [ ] Production secrets live in the platform secret manager — not in `.env` files
- [ ] Env validated at boot (Zod) — missing config fails loud at start, not at first request
- [ ] Server-only modules guarded with `import 'server-only'`

## 2. Authentication & authorization

- [ ] Tokens in `httpOnly` `secure` `sameSite: 'lax'` cookies — never localStorage (`auth-and-sessions`)
- [ ] Passwords with argon2id (or via managed provider)
- [ ] Auth endpoints rate-limited (login, signup, reset, MFA verify)
- [ ] Same response for unknown email + wrong password
- [ ] **Every** endpoint handling user data scopes by `userId` / `orgId` / `tenantId` (`authorization`)
- [ ] 404 (not 403) for "exists but not yours"
- [ ] Server Actions and RSC data fetching have authz checks
- [ ] CSRF protection in place (Server Actions, or `sameSite: 'lax'` + double-submit token)

## 3. Input handling

- [ ] Every endpoint parses input via Zod/Valibot at the boundary (`input-validation`)
- [ ] Schemas use `.strict()` — no mass assignment
- [ ] Server-controlled fields (`id`, `role`, `userId`) cannot come from request body
- [ ] String/array max lengths set explicitly
- [ ] Webhook receivers verify signatures on the raw body, check timestamp, dedupe by event ID (`webhooks`)

## 4. API hardening

- [ ] Rate limits on every mutating endpoint, per-user and per-IP (`api-route-hardening`)
- [ ] Request body size cap before parsing
- [ ] Idempotency keys on charge / send / irreversible mutations
- [ ] Stable JSON error contract with codes (no leaking internals to users)
- [ ] CORS allowlist, not `*`
- [ ] Response DTOs, not raw DB rows
- [ ] Per-call timeouts on every outbound `fetch` (`reliability-patterns`)

## 5. LLM / cost-bearing endpoints

- [ ] LLM API key server-only; client calls a proxy (`llm-endpoint-safety`)
- [ ] Auth required to hit any LLM endpoint
- [ ] Per-user daily quota (token or $ cap), not just rate limit
- [ ] `maxOutputTokens` set on every call
- [ ] `abortSignal: req.signal` so client disconnect cancels upstream
- [ ] Provider-side billing cap configured (OpenAI / Anthropic dashboard)

## 6. Database

- [ ] All queries parameterized; no string-concat SQL with user input (`database-query-safety`)
- [ ] Indexes on every filter + sort column on hot queries (verified with `EXPLAIN`)
- [ ] Every list endpoint has a max page size
- [ ] No N+1 in hot paths (verified by query-count log)
- [ ] Multi-step writes wrapped in transactions (`transactions-and-consistency`)
- [ ] Money / inventory / counters use atomic ops or `SERIALIZABLE` with retry
- [ ] Connection pooler configured (PgBouncer, platform pooler) — serverless connections won't blow up the DB
- [ ] `statement_timeout` set per role

## 7. Migrations

- [ ] Last migration is additive; no breaking schema change without a deploy plan (`migrations-and-schema`)
- [ ] Migrations linted for unsafe patterns (Squawk or equivalent in CI)
- [ ] `NOT NULL` adds are 3-step (nullable → backfill → enforce)
- [ ] Indexes on big tables created `CONCURRENTLY`
- [ ] Backfills are batched, not single huge `UPDATE`
- [ ] Down migration written (or irreversibility explicit)

## 8. File uploads (if any)

- [ ] Direct-to-storage with presigned URLs; server doesn't proxy bytes (`file-uploads`)
- [ ] Size cap enforced at the bucket
- [ ] MIME sniffed server-side; SVG rejected or sanitized
- [ ] Uploads served from separate domain or as `Content-Disposition: attachment`
- [ ] Image dimension cap (`limitInputPixels`)
- [ ] EXIF stripped
- [ ] Per-user storage quota

## 9. Background jobs (if any)

- [ ] Handlers are idempotent (dedupe by business key) (`jobs-and-queues`)
- [ ] Retries with exponential backoff + jitter; max attempts; DLQ
- [ ] DLQ monitored / alerts fire when growing
- [ ] Visibility timeout > expected job duration
- [ ] Crons run on a single leader; idempotent per period
- [ ] Outbox pattern for "DB write + enqueue"

## 10. Reliability

- [ ] Every outbound call has a timeout (`reliability-patterns`)
- [ ] Retries with backoff + jitter on transient errors only
- [ ] Circuit breaker on chronically flaky upstreams
- [ ] Fallback (or fail-loud) decided per dependency
- [ ] Concurrency limits on outbound parallel calls
- [ ] Health check verifies real dependencies (DB + cache), not just "200 OK"

## 11. Observability

- [ ] Structured logger, no `console.log` in prod (`observability`)
- [ ] `requestId` in every log line and echoed in response header
- [ ] Errors logged with `{ err }` (full Error), not stringified
- [ ] OpenTelemetry instrumented; traces flow across services + jobs
- [ ] RED dashboard per service (rate / errors / latency)
- [ ] **At least one** SLO-based alert wired to a human (PagerDuty, on-call)
- [ ] Sensitive fields redacted at the logger level (passwords, tokens, full PII)

## 12. Errors

- [ ] No silent `catch {}` (`error-handling`)
- [ ] Every async UI surface has loading + error + empty states; user can recover (retry, back)
- [ ] User-facing messages are generic; full detail in logs with `requestId` correlation
- [ ] Auth/permission failures fail closed; auxiliary failures fail open (and surface degradation)
- [ ] Top-level `unhandledRejection` / `uncaughtException` handlers

## 13. Caching

- [ ] Cache keys include every input that varies the result (`caching-and-invalidation`)
- [ ] No per-user data in a globally-keyed cache
- [ ] Tag-based invalidation on entity mutations (`revalidateTag` after Server Actions)
- [ ] Stampede protection on hot keys (SWR, single-flight, jitter)
- [ ] Permission/auth state not cached, or only briefly

## 14. Privacy & compliance

- [ ] Only fields the product needs are collected (`data-privacy`)
- [ ] HTTPS everywhere; HSTS configured
- [ ] High-sensitivity fields encrypted at app level (managed KMS)
- [ ] Card data via tokenization (Stripe Elements / Checkout) — never on your server
- [ ] Real deletion path for "delete my account" — DB + indexes + caches + sub-processors, tested end-to-end
- [ ] Data export available (GDPR / CCPA right of access)
- [ ] Privacy policy lists every sub-processor
- [ ] DPA signed with sub-processors handling EU user data

## 15. Release & rollout

- [ ] Feature flag for the new feature; can disable without redeploy
- [ ] Migration ordering: additive migration → deploy code that handles both shapes → contract migration after the deploy stabilizes
- [ ] Preview env mirrors production config (same DB engine, same auth provider) — caught surprises before prod
- [ ] Canary / staged rollout if supported (10% → 50% → 100%)
- [ ] Rollback plan documented and tested (last green deploy reachable in 1 click)
- [ ] Recent-deploy markers visible on dashboards
- [ ] Pre-launch smoke tests pass against the prod URL (without leaving artifacts)

## 16. Cost & abuse

- [ ] Billing alerts at the platform (Vercel, Cloudflare, AWS) and at every paid API (OpenAI, Anthropic, Resend, Twilio)
- [ ] Hard usage caps where the provider supports them
- [ ] Rate limits and quotas on anything that consumes paid resources
- [ ] One eyes-on monitoring for unusual spend / 5xx / signup-spam patterns post-launch

## 17. Day 1 / 2 ops

- [ ] On-call rotation set; one human paged for the SLO alert
- [ ] Incident response checklist (who, where, how) written down somewhere accessible
- [ ] Runbook for known recurring issues (DB connection blowups, queue backups, deploy rollback)
- [ ] Status page (Statuspage, BetterStack, or a public Vercel/Cloudflare-hosted page)
- [ ] Customer support inbox monitored — `support@`, intercom, etc.

---

## Output format when running this review

Write the result as a punch list, organized by section, with status next to each item:

```
## Auth & authz
✅ Tokens in httpOnly cookies (verified app/lib/session.ts)
❌ Authorization: /api/projects/[id] doesn't scope by userId — IDOR risk
⚠️  CSRF: Server Actions used everywhere except /api/legacy-import — gap
```

Don't say "looks good" without naming the file you checked. If you didn't check, mark it `❓` and ask.

## War story

A startup launched on Product Hunt without going through any pre-launch review. Within 6 hours: (1) `NEXT_PUBLIC_OPENAI_API_KEY` was scraped from the bundle, $9k charged before billing alerts caught it, (2) a missing `.scope by userId` let visitors paginate through every other user's saved chats, (3) a feature flag had been missing the kill switch, so the broken auth flow stayed live during the entire 8-hour incident. Each individual rule in the checklist would have caught one of these. The checklist itself would have caught all three.

## Quick framing for the team

Going through this list takes ~1 hour for a small app. The cost of skipping it is measured in:
- Customer-data-leak posts on HN
- Refund queues
- Founder-eyes-shut-on-the-couch debugging at 2am
- "We just have to launch" turning into "we just had to launch with all the holes"

