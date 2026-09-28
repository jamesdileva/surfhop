# Worklog — audit backlog M3: steep faces retain (2026-09-24)

Experiment over theory; audit.md carries ✅ with correction (M3).

## Finding (reverses the audit claim)
Nobody peels. 70° drop-in AND slow-slide riders retain and accelerate —
anti-stuck push loses to slide-buildup within ticks. ">~65° peels"
comment was wrong; corrected in Surf.gd. Difficulty = steering.

## Shipped
- `_test_steep_peel`: 70° drop-in entry+build, 70° slow-slide retention,
  50° control retention (solo worlds each).
- user_guide surfing: 48°→70° progression, enter with speed, never W in.
- audit.md: M3 ✅ with correction.

## Verify
- `tests/test_runner.gd`: 497 checks, 0 failures, exit 0.
- Smoke beginner RESULT=OK.

Next: M4 (hold-vs-press bhop parity) or as user calls it.
