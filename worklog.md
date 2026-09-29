# Worklog — audit backlog M6: surf steering (2026-09-24)

Coverage, not a fix; audit.md carries ✅ (M6).

## Result
A/D + mouse redirects rides (> 15° carve vs drift, speed kept) — green
first try. W-projection-away is correct CS doctrine; wish-clip dropped
for lack of justification. No behavior changed.

## Shipped
- `_test_surf_steering` + `_ride_surf_face` helper (steer vs control).
- audit.md M6 ✅ + backlog list cleanup.

## Verify
- `tests/test_runner.gd`: 511 checks, 0 failures, exit 0.
- Smoke beginner RESULT=OK.

Next: M7 (ridden seam test) or as user calls it.
