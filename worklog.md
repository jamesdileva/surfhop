# Worklog — surf-glow base + OC surf wall (2026-09-24)

Follow-up: beginner surf felt good but still white-on-white; OC colors
better, yet its "ramp" never surfed. No decision questions this round —
both causes were code bugs / missing geometry.

## Root causes
- Beginner: `surf_ramp.gdshader` declared `base_color`/`glow_color` as
  plain `uniform` while VisualEffects sets them per-instance — silently
  ignored, so every ramp rendered near-white defaults. Real bug, likely
  THE white-on-white on surf maps.
- OC: the map has no surfable geometry at all (flat tops + vertical
  faces). The "ramp" was never a ramp — nothing to fix in physics.

## Shipped
- Shader: both colors `instance uniform` + comment guard. Beginner walls
  now dark-green base + green glow.
- VisualEffects: `map_loaded` re-tag sweep for SurfRamp* (ordering-race
  insurance, idempotent).
- OC: optional banked surf wall `SurfRampB1` (proven 56° face math, right
  side of FloorC, main bhop line untouched); finish -4500 → -5450 so the
  surf section counts.
- Tests: wall exists/tilt, live SURF ride + wall carve; suite 448/0.

## Verify
- `tests/test_runner.gd`: 448 checks, 0 failures, exit 0.
- Smoke: beginner + challenge_oc RESULT=OK.
- Manual step for user: confirm dark-green walls in `dev_beginner`, and
  try the OC wall (veer right on FloorC, press D into the face).

Full detail: `docs/history.md` (latest section).
