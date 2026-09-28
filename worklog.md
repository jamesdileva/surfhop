# Worklog — audit backlog M4: hold-bhop parity (2026-09-24)

Severity order; audit.md carries ✅ (M4).

## Research
CS2 `sv_autobunnyhopping 1` = hold jump, server times hops perfectly —
hold MUST equal perfect presses. Our hold path paid ~19 u/s/landing.

## Shipped
- BunnyHop samples `jump_held`; same 0.1× skip on held-hop floor
  landings (surf excluded). Hop still fires from Jump next tick.
- `_test_bhop_hold_parity` (W off, two landings compound): 95/93 bars.
- Negative control: 320→301→283 red without fix, all else green.
- Guide: zero-penalty hold note. audit.md M4 ✅.

## Verify
- `tests/test_runner.gd`: 504 checks, 0 failures, exit 0.
- Smoke beginner RESULT=OK (743u vs 661u before — bot holds jump).

Next: M5 (mixed-contact prefers SURF) or as user calls it.
