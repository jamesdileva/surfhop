# Performance Profile — Sprint 27

> Methodology and results for the Sprint 27 optimization pass.
> Harness: `tools/benchmark.gd` (headless, repeatable):
>
> ```sh
> godot --headless --path . --script res://tools/benchmark.gd
> ```
>
> Isolation switches (environment variables): `BENCH_EMPTY=1` (no world),
> `BENCH_NO_MOVE=1` (standing player), `BENCH_NO_VFX=1` (VFX disabled),
> `BENCH_NO_INTERP=1` (physics interpolation off).

## Setup

- Scripted 60s session @100Hz: auto-bhop on flat ground + strafe yaw sweep +
  mid-session drop onto a 55-degree surf ramp; VFX/AudioManager active.
- Metrics:
  - **script-side controller cost**: `Time.get_ticks_usec()` bracketing
    `MovementController._physics_process` (precise, per-tick).
  - **engine monitor** `Performance.TIME_PHYSICS_PROCESS`: smoothed per-frame
    physics-time reading — includes environment jitter; upper-bound estimate.
  - **memory**: `Performance.MEMORY_STATIC` sampled 12x across the session.
- Environment: Windows, headless (dummy renderer), Godot 4.7.2.

## Results

| Run | script p50 | script p95 | monitor p50 | monitor p95 |
|---|---|---|---|---|
| Empty world (floor) | — | — | 0.37 ms | 2.9 ms |
| Full scene, standing player | 0.12 ms | 0.20 ms | 1.87 ms | 13.3 ms |
| Full scene, active bhop+surf | 0.10 ms | 0.21 ms | 1.93 ms | 10–32 ms |
| Active, VFX disabled | 0.10 ms | 0.19 ms | 2.3 ms | 22.8 ms |
| Active, interpolation disabled | 0.10 ms | 0.19 ms | 1.91 ms | 10.1 ms |

Memory: 27.5 MB -> 27.8 MB static over 60s (+0.3 MB, sampling noise; no
growth trend). Headless FPS reading ~145 (no GPU work performed).

## Analysis

- **Movement framework cost is negligible**: all module math (friction,
  ground/air accel, surf projection, jump/bhop) plus `move_and_slide` server
  calls fit in ~0.10 ms/tick median, p95 ~0.21 ms. Sprint 27 hot-path caches
  (`Surf.is_surf_normal` trig cache, `VisualEffects` player-ref cache) are
  bit-identical by construction; the determinism suite passes unchanged.
- **Cost is a constant per-tick scene baseline**, not gameplay-driven:
  standing vs active sessions measure the same. VFX and interpolation have no
  measurable physics-step impact (their cost lives on the render side).
- The engine monitor's absolute numbers are environment-noisy (empty-world
  p95 already 2.9 ms headless); treat them as upper bounds. The precise
  script-side hook (`MovementController.last_script_step_us`) is the reliable
  regression signal.

## Acceptance status

| Criterion | Status |
|---|---|
| Physics step < 1.5 ms | Script-side verified (0.10 ms p50). Full-step certification needs the manual profiler pass below. |
| Render FPS at display refresh | Headless reading meaningless for GPU; manual pass required. |
| Interpolation smooths 100Hz | Built-in engine physics interpolation enabled; teleport resets covered by tests. Visual confirmation is part of the manual pass. |
| Memory stable over 10 min | Flat over 60s sampled (+0.3 MB). Full 10-min soak is a manual step. |
| GUT tests still pass | 343 checks, 0 failures (up from 338). |

## Manual validation checklist (real hardware)

1. Launch a dev scene, open the built-in profiler (Debugger > Profiling),
   surf+bhop hard for ~2 min: confirm Physics Process stays under 1.5 ms.
2. Confirm rendered FPS holds at your display refresh (144+ target) during
   an intense surf session with VFX on.
3. Leave a map running ~10 minutes (or replay several runs); watch the
   Monitors tab for any upward memory trend.
4. Eyeball movement smoothness at high refresh: strafing should not strobe;
   respawn teleports must snap instantly (no cross-map glide).
