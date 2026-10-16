# Benchmark methodology

The Lab tab compares two ways of scanning the same list of independent source strings.

## Sequential path

`SequentialBatchScanner` uses a normal loop to scan each input one after another. Each input uses a fresh `ScannerEngine` value, and each work item carries its selected language dialect.

## Concurrent path

`ConcurrentBatchScanner` uses a bounded Swift structured-concurrency `TaskGroup` worker pool. Each worker scans a strided set of independent source inputs rather than creating a child task for every document. Results carry their input index and are placed back into matching slots, so completion order does not change the comparison order. `ScannerEngine` remains the shared switch-case DFA core.

## Measurement

- The app builds 32 independent benchmark jobs from the four sample programs. Each job contains 24 newline-separated copies of its sample, creating a larger CPU-bound workload without changing scanner semantics.
- Timed runs disable trace-event and per-character state-path recording to benchmark lexical analysis instead of visualization instrumentation. The interactive scanner still uses both features.
- A warm-up is run before measurements, for both strategies.
- Each round measures the sequential and bounded task-group worker-pool workload, alternating which strategy runs first.
- The concurrent worker count is capped by the active processor count, eight workers, and the number of jobs. Each worker processes a strided partition of the workload.
- The median duration is reported to reduce the impact of a single noisy run.
- Speedup is `sequential median / concurrent median`.
- A result below `1.0×` means the concurrent strategy was slower for that run; task creation and coordination have overhead.

## Correctness verification

The benchmark compares ordered token outputs, including lexeme, token type, half-open source range, and character count. Trace events and state paths are intentionally disabled in the timed mode; correctness tests separately verify that this optimized mode emits the same lexical tokens as the interactive trace mode. Random token UUIDs and per-run timings are not compared. The selected language dialect is applied identically to both paths.

## Important caveats

- `TaskGroup` expresses concurrency; it does not promise that each task runs on its own thread or that tasks execute in parallel at the same instant.
- This benchmark compares scheduling strategies, not two different scanning algorithms.
- Simulator and Debug-build timings are not reliable substitutes for optimized measurements on a physical device. Larger workloads can make parallelism visible, but no specific speedup is guaranteed.
- Results depend on CPU load, device model, operating system, workload size, compiler optimization, and task overhead. Treat the displayed figures as an educational experiment, not a universal performance claim.
- The timing currently includes task-group creation and result collection for the concurrent path. This is intentional because it reflects the end-to-end cost of using that strategy.
