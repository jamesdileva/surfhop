# Worklog — audit backlog item 1: endless repair (2026-09-24)

One fix at a time; audit.md carries ✅ per landed fix.

## Shipped
- SR3 re-anchored 45° → 50° (same facing family; boundary class closed).
- UpRampA/B rebuilt as grade-meeting walkable inclines (8.5°/7.2°);
  platforms reachable with zero jumping.
- `_test_endless_repair`: generator-vs-baked basis lock (5 slabs) +
  reachability asserts. Regen of endless only.
- audit.md: B2/B3 ✅ fixed; B1 withdrawn (see correction).

## Correction (read before touching endless rotations)
Audit B1 (generator/scene sign mismatch) was false: tscn Transform3D
stores basis ROWS, so every hand-read normal was transposed. Proof:
regen round-trip reproduces SR1/SR2 byte-identically; the only mirroring
observed came from acting on the misread (caught by probe test, same
session revert). Rotation literals are standard-math; verify via basis
diagnostics, never file eyeballing.

## Verify
- `tests/test_runner.gd`: 468 checks, 0 failures, exit 0.
- Smoke endless RESULT=OK (675u in 5s).

Next: backlog item 2 (precision exits P1–P3) when user calls it.
