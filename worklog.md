# Worklog — audit backlog M2: low surf exits (2026-09-24)

Severity order; audit.md carries ✅ (M2, with correction).

## Research (user request)
CS2-Surf-Mapping guide: linked ramp segments overlap, top vertices
almost touching. Rampbug literature (zer0k-z): end-of-ramp
discontinuities annihilate momentum; surf faces must be single uncut
planes (ours comply — single boxes).

## Shipped
- Inter R1: FloorC +70u north; face meets top ~6u past edge.
- Adv R2b: 5u DOWN-step overlap seam (same 50.0° shape).
- Correction: R2/R3/R4 need NO change (transition-before-burial;
  audit overstated). Documented in audit.md.
- Tests: R1 exit-link + seam no-upstep/overlap asserts.

## Verify
- `tests/test_runner.gd`: 492 checks, 0 failures, exit 0.
- Smokes intermediate + advanced RESULT=OK.

Next: M3/M4 or as user calls it.
