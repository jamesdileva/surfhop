# Worklog — audit backlog item 2: precision exits (2026-09-24)

One fix at a time; audit.md carries ✅ per landed fix (B4/B5).

## Shipped
- P1/P2 shortened along-line (55°/60° unchanged), exits daylight 37u /
  ~15u above pools; launch-off-the-end drops into pools.
- P3 re-angled 63° → 60° (63° cannot daylight over Pool3 — line crosses
  pool-top past the edge), entry (0,−790,−2840), exit +22u over Pool3.
  Honest angle comments (were all "~63°").
- Entries intentionally demanding (slow catches, fast safely bypasses);
  exits never into solid.
- Tests: per-ramp daylight + angle asserts, live P1 ride (SURF,
  no-clip, ends in Pool1).

## Notes
- Full-map regen churns node unique_ids everywhere: reverted all id-only
  diffs, shipped only challenge_precision. Do the same on future regens.
- audit.md: B4/B5 ✅ fixed (old finding bodies removed, tables updated).

## Verify
- `tests/test_runner.gd`: 477 checks, 0 failures, exit 0.
- Smoke challenge_precision RESULT=OK.

Next: backlog item 3 (B6 respawn latch) when user calls it.
