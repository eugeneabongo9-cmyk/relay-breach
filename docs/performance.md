# Performance

## What was measured

Command: `godot --headless --path . -s res://tests/run_tests.gd`  
Godot 4.7.2.stable.official, Compatibility project, logic tick only (no raster).  
Workload: `stress` room, 24 pursuers, 120 ticks at 1/60 s.  
Machine: the container that built this slice. No discrete GPU was available, so there is no 1080p frame capture.

| Metric | Value |
| --- | --- |
| Logic tick median | 173 µs |
| Logic tick p95 | 210 µs |
| Logic tick p99 | 285 µs |
| GPU frame time | UNVERIFIED |
| CPU/GPU split | UNVERIFIED (no profiler capture) |
| Peak memory | UNVERIFIED |
| Load time | UNVERIFIED |

The 16.67 ms / 60 fps desktop target is still a target. These logic numbers only say the AI step is not the thing that would miss it. Remeasured after bodies stepped by the tick delta. The earlier capture on this same machine was median 175 µs, p95 227 µs, p99 348 µs. That gap is sample noise, not an optimization.

No optimization was landed against a before/after capture. Enemies are a handful of bodies, not a pool. The stress room exists so that measurement can be repeated:

1. Debug build, F6, or `start_stress()` as the test does.
2. Sample after the room exists (the test does not drop the first ticks; treat the first moments as warm-up if you extend it).
3. Report median, p95, p99, and the machine. Do not copy the table above onto different hardware.

Restart soak: 10 rebuilds of the shield room stayed within 8 live nodes of the first build in the same run (`tests/run_tests.gd`).
