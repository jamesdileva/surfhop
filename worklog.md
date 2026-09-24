# Worklog — wall-climb + two-tone fix (2026-09-24)

Follow-up: jump spam climbed any wall/ramp to the top, ramps wouldn't
glide ( holders hopped straight off), obstacle course still all-white.
Decisions: block ramp jumps entirely (CS2), two-tone by role, LowWall 44,
spacing otherwise untouched.

## Root cause
Last session's surf-jump allowed coyote refresh on every SURF tick, and
auto-bhop counts held jump as intent — held Space re-fired the impulse
forever against any steep contact. Ladders everywhere, no gliding.

## Shipped
- `Jump`: coyote refreshes on REAL floor only; surf/wall contact grants no
  jump. Unified threshold + entry preservation kept.
- Two-tone: generator bakes `surface_role` (floor/obstacle); neon shader
  `dark_base` uniform; `WorldMaterials` styles obstacles dark, floors
  white. `PrecisionRamp*` → `SurfRampP*` (glow coverage).
- LowWall 80 → 44 tall (top y=44 clears under 56.25 apex; old height was
  only passable via the climb exploit).
- Endless corridor walls tagged obstacle.
- Tests: hold-jump 40-tick glide hold, forced-SURF no-fire unit check, OC
  roles/dark_base/LowWall-top asserts, SurfRampP rename check.

## Verify
- `tests/test_runner.gd`: 444 checks, 0 failures, exit 0.
- Smoke: tutorial RESULT=OK, challenge_oc RESULT=OK.
- Manual step for user: eyeball `dev_challenge_oc` — pillars/walls/movers
  should read dark against white floors (headless can't screenshot).

## Deferred
- Intermediate 350u gap, `test_map` in MapSelect, endless dev scene,
  `surf_speed_multiplier` / `surf_exit_boost` inert.

Full detail: `docs/history.md` (latest section).
