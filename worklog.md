# Worklog — adversarial surf audit → audit.md (2026-09-24)

Request: skeptic audit for bugs + ramp spacing/angles against the CS2
rollercoaster standard, written as audit.md. Plan-mode investigation
first (3 parallel audits), then build.

## What the audits found
- Geometry: 3 map blockers (precision P3 unrideable, P1/P2 buried exits,
  endless SR3 on the 45° boundary), 4 flat gaps needing 467–507 u/s, low
  exits everywhere but advanced R1, steep peelers, OC hop-entry.
- CS2: threshold/scale/gravity heritage-correct; flow rules violated.
- Code: endless regen mirrors the park (sign mismatch — do not regen),
  unreachable platforms, stale cross-map respawn latch, hold-vs-press
  bhop friction gap, 1-tick lag, ruler-only seams, test_map shipping.
- History: 2 claims fail verification (wall height 400≠500; endless 48°
  never landed).

## Shipped
- `audit.md`: findings + concrete remedies, blockers-first backlog,
  CS2 reference sheet with sources, 5 unimplemented coverage checks,
  do-not warnings. No code changed.

## Next (decided)
Blockers first; endless repaired; test_map hidden from MapSelect.

Full detail: `audit.md`, `docs/history.md` (latest section).
