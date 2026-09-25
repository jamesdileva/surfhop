# Worklog — audit backlog B6+B7: respawn latch + MapSelect filter (2026-09-24)

Two tinies, one slice; audit.md carries ✅ per landed fix (B6/B7).

## Shipped
- B6: `GameManager.reset_spawn()` called on every map load (race-free:
  finalize + emit + positioning atomic in one frame). Old suite
  workaround line removed — fix stands alone.
- B7: MapSelect hides `dev`/`test`-tagged maps; loader still discovers.
- Tests: `_test_spawn_latch_reset` + `test_mapButton` absence assert.

## Verify
- `tests/test_runner.gd`: 484 checks, 0 failures, exit 0.
- Smoke beginner RESULT=OK.

Next: majors (M1 flat gaps first?) when user calls it.
