# Worklog — audit backlog M10a: new rollercoaster map (2026-09-24)

Biggest slice yet; audit.md carries ✅ for M10a (M10b pending).

## Decisions
- New map (not rework), gravity untouched at 800 (airtime = speed +
  geometry). M10b (inter/advanced relevance pass) later.

## Shipped
- `rollercoaster` (diff 3, surf/flow/air): spawn 600 → 48.7° → pool →
  26.6° kicker → 55° → drop-transfer 60° → pool + carve wall →
  V-channel → 65° finale → pool finish. 5 CPs, kill −2600.
- Tests: discovery/meta/angles/rides/chain/kicker (~26 asserts).
- 3 red runs → 3 lessons: slow-drift drops for steep faces, buried
  kicker starts, input-driven (never overwritten) cruise.

## Verify
- `tests/test_runner.gd`: 547 checks, 0 failures, exit 0.
- Smoke rollercoaster RESULT=OK, 2500u/8s flow.

Next: M10b relevance pass + minors, then user playtest.
