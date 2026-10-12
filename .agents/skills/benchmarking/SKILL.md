---
name: benchmarking
description: How to write accurate and meaningful benchmarks. Use this skill whenever measuring performance, ranking, or comparing implementation alternatives.
---

Creating accurate and meaningful benchmarks requires careful attention to how modern JavaScript engines optimize code. Different ways of writing similar logic can have significant performance differences. This covers essential concepts and best practices to ensure your benchmarks measure actual performance characteristics rather than optimization artifacts.

## General Principles

- Benchmark before optimizing: always measure code performance with real benchmarks first; never optimize without measuring.
- Profile in realistic environments: engine behavior differs (V8, JSC, SpiderMonkey) and devtools instrumentation changes results. Benchmark in the actual environment the code will run in.
- Focus on bottlenecks: optimize the code sections that consume the most runtime, not just any slow-looking code.
- Document optimization rationale: when changing code for performance, include comments explaining the benchmark results and reasoning.
- Doubt your results: if a change "runs 100x faster", verify it in production before trusting the benchmark.

## Setup with mitata

Use [mitata](https://github.com/evanwashere/mitata) for benchmarking tooling. See its README for the full API; If context7 is configured and available, use it to look up any docs too.

```typescript
import { bench, run, do_not_optimize } from "mitata";

bench("fibonacci(30)", () => fibonacci(30));

await run();
```

- Run Node benchmarks with `node --expose-gc` so mitata can control garbage collection (Bun exposes GC by default).
- Use dedicated, quiet hardware and isolate the measurement from other work in the process; install the optional `@mitata/counters` package for IPC (instructions per cycle) and cache statistics.
- Let the JIT warm up — mitata handles warmup internally. Never hand-roll timing loops (e.g., N iterations around `Date.now()`); JIT compilation during the measured region invalidates results.
- Report distributions, not just averages. Mitata shows min/max, p75/p99 and the sample distribution; wrap benchmarks in `summary()`, `boxplot()`, or `lineplot()` for comparisons.
- Use a clean browser profile when measuring in the browser (extensions, especially React devtools, distort results).

## Dead Code Elimination

JIT compilers remove code with no observable effects. If a benchmark's result is unused, the engine can optimize the call away entirely; mitata flags this with a `!` warning.

```typescript
// ❌ Bad: the allocation is unused and can be eliminated by the JIT
bench(() => new Array(0));

// ✅ Good: do_not_optimize() emits code with an observable side effect
bench(() => do_not_optimize(new Array(0)));
```

## Garbage Collection Pressure

For benchmarks with significant allocations, GC pauses can dominate timings. Control GC frequency for consistent results:

```typescript
// ❌ Bad: unpredictable gc pauses (and, as written, this is also DCE-eligible — see above)
bench(() => {
  const bigArray = new Array(1000000);
});

// ✅ Good: gc before each (batch-)iteration
bench(() => {
  const bigArray = new Array(1000000);
}).gc("inner"); // run gc before each batch-iteration
```

GC modes: `false` (never), `"once"` (after warmup; the default), `"inner"` (after warmup and before each batch-iteration).

- Treat GC dominance as a signal: if pauses dominate a benchmark, the code under test likely allocates heavily in production too. Reducing allocations by fusing small objects, flatter data structures, more compact storage formats improves the real workload; `.gc("inner")` only stabilizes the measurement. Consider techniques such as object pooling, lazy loading, pagination, stream processing or memoization.

## Loop Invariant Code Motion

Engines hoist loop-invariant computations out of measurement loops, distorting results. Use computed parameters so fresh values are produced per iteration and the computation cannot be hoisted or constant-folded:

```typescript
bench(function* (ctx) {
  const str = "abc";
  const substr = ctx.get("substr");

  // ❌ Likely distorted: the JIT may hoist or fold this call out of the loop
  yield () => str.includes(substr);

  // ✅ Good: computed parameters prevent JIT hoisting/constant folding
  yield {
    [0]() {
      return str;
    },

    [1]() {
      return substr;
    },

    bench(str, substr) {
      return do_not_optimize(str.includes(substr));
    },
  };
}).args("substr", ["c"]);
```

Whether a particular call gets hoisted or folded varies by engine and version; computed parameters prevent both, making results engine-independent.

## Validity and Worst-Case Inputs

- Verify the workload did what it claims before trusting numbers: check mitata shows no `!` DCE warning, assert postconditions or counters, and confirm the measured path was actually travelled.
- Measure slow/failure arms too, not just the fast path (e.g., cache miss alongside hit, rejection alongside success).
- Judge by worst edit, not quiet average: include adversarial inputs (large retained collections, far-from-view changes, moves, deletions) alongside typical cases.
- Distinguish growth from a large constant: benchmark across sizes and state work in concrete units (rows, bytes, entries, queries) so scaling is visible.

## Browser Benchmarks

When benchmarking DOM code, avoid layout thrashing — interleaved reads and writes invalidate measurements:

```ts
// ❌ Bad: alternating reads and writes (each read forces layout)
for (const el of elements) {
  el.style.height = `${el.offsetHeight * 2}px`;
}

// ✅ Good: batch reads first, then writes
const heights = elements.map((el) => el.offsetHeight);
for (let i = 0; i < elements.length; i++) {
  elements[i].style.height = `${heights[i] * 2}px`;
}
```

- `document.getElementById` is already highly optimized in modern browsers; don't cache DOM references preemptively — measure first.

## CLI / Process Benchmarks

Use [hyperfine](https://github.com/sharkdp/hyperfine) when the unit under test is a process: CLI tools, scripts, compilers, comparing binaries. Do not wrap `execSync`/`spawn` in `mitata` for this — that conflates Node overhead with child time.

```sh
hyperfine --warmup 3 'cmd-a --flag' 'cmd-b --flag'
hyperfine --runs 10 --prepare 'make clean' --export-markdown results.md 'make -j4'
```

- hyperfine handles repeated process spawns, warmup, `--prepare/--setup/--cleanup` per run, outlier detection, and `-P/--parameter-scan` + `-L/--parameter-list` sweeps.
- Report from its statistics/exports, not a single run.

## References

- [mitata](https://github.com/evanwashere/mitata) — the benchmarking library used above
- [hyperfine](https://github.com/sharkdp/hyperfine) — command-line benchmarking for processes/CLIs; use instead of mitata when measuring spawned commands
- [node:bench — Benchmark runner](https://nodejs.org/api/bench.html) — Node built-in runner (experimental since v26.9.0); read Measurement integrity and Comparing benchmark results even when using mitata
- [perf_hooks](https://nodejs.org/api/perf_hooks.html) — stable Performance Measurement APIs for production instrumentation, not for hand-rolled microbenchmark loops
- [V8 blog](https://v8.dev/blog) — updated engine internals explaining JIT behavior
- [How V8 measures real-world performance](https://v8.dev/blog/real-world-performance) — why synthetic microbenchmarks mislead; prefer representative workloads
- [LLVM Benchmarking tips](https://llvm.org/docs/Benchmarking.html) — general micro-benchmark methodology
