# Worklog — audit minors batch (2026-09-24)

Closes the minors; audit.md carries ✅ throughout (blockers + majors +
minors all done; M10 follow-ups + playtest polish are future work).

## Shipped
- M9 channel comments corrected (600+ flyover accepted).
- floor_snap_length owned via MovementConfig (0.1) + applied + default
  assert; max_velocity per-axis note in-code.
- Removed dead exports air_cap_multiplier/surf_speed_multiplier (zero
  code refs; docs/01 still lists them — flagged divergence).
- OC obstacles + all channel lips embedded 2u (coplanar flicker gone).
- Neon grid fwidth fade; surf-glow releases on raycast miss (+asserts).
- Kill sweep: spheres read, trigger volumes skipped, dev/test skipped
  with shipped count, vacuous-INF impossible (+synthetic unit).

## Verify
- `tests/test_runner.gd`: 552 checks, 0 failures, exit 0.
- Smokes beginner/OC/rollercoaster RESULT=OK.
- Suite-structure check: 52 test funcs, 39 awaited async + 13 sync —
  all wired, no duplicates, no dead tests.

Next: user playtest round, then polish off playtest info.
