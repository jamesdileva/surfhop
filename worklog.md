# Worklog — audit backlog M5: mixed-contact friction (2026-09-24)

Severity order; audit.md carries ✅ (M5, friction layer only).

## Verification (weighted, not all claims equal)
- 1-tick state lag: real, 10ms, negligible → state machine untouched.
- GROUND-beats-SURF: real; friction its ONLY material effect.
- Preservation off-by-one: real, bounded → untouched.

## Shipped
- Friction: surf rate on steep contact + h > walk_speed; full stop
  otherwise. No hysteresis, no reorder.
- `_test_mixed_contact_friction` (carve/lean/control triple).
- Guide one-liner. audit.md M5 ✅.

## Verify
- `tests/test_runner.gd`: 507 checks, 0 failures, exit 0.
- Smoke beginner RESULT=OK.

Next: M6 (surf steering coverage) or as user calls it.
