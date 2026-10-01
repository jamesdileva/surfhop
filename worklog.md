# Worklog — Slice 1: bugfixes (2026-09-24)

## Diagnosis
- Crash error was a stale-compiled MovementConfig under a running
  editor (pulled floor_snap_length addition never compiled; error at
  LevelLoader config-apply on map load). Also surfaced a lost edit:
  the minors commit never actually contained the export.
- Mouse capture stuck ON after finish: show_menu's match released the
  mouse for every menu except "results" (invisible cursor until the
  minimize focus dance freed it). Dual capture flags also desynced.

## Shipped (3743c61)
- MovementConfig: floor_snap_length=0.1 export restored + per-axis
  max_velocity note.
- MovementController: snap read via get_indexed (desync-safe), dup
  line removed.
- UIManager: results/credits release mouse; camera flag synced on
  every set_mouse_captured.
- Tests: results free/recapture camera-flag asserts; suite 567/0.

## Your step after pulling
- Close the editor COMPLETELY (file menu), then update, then reopen —
  hot-reload desyncs are the root cause; never pull under a running
  editor.

Next: Slice 2 (advanced feed ramps) / Slice 3 (beginner uphill bot
diagnostic) when you call it.


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
