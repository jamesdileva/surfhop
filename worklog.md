# Worklog — quality audit + rollercoaster flow restore (2026-10-02)

## Audit of last commits (per user request)
- 6efbf9c (M10c lips): verified baked scenes match source (advanced
  e1 metas 85/-715/-2114 == generator). Consistent, good.
- 442bce0 (guide): docs-only. No risk.
- Uncommitted work: needed its regen (stale Kicker1 scene would have
  broken the renamed meta lookups); fixed a garbled shader comment.

## Shipped (c75cc77)
- Rollercoaster R2/R4 reverted to M10a anchors (raised prows blocked
  mounts: R2 145u over Pool1, R4 85u over Floor4).
- Kicker1 -> SurfRampKicker1 (dark-base + glow; was invisible white).
- Test bands/drops re-anchored to restored geometry.

## Verify
- Suite 567/0; rollercoaster smoke 2500u/8s (was 83u blocked).

Next: resume M10d scoping (kicker variants, wall curve tops) or
playtest verdict on lips elsewhere.

# Worklog — slice 2 forcing verdicts: M10c reverted, R2 embeds (2026-10-03)

## What slice 2 settled (audit M10)
- M10c blocker lips (+75 e1) REVERTED to M10b geometry (tutorial, inter,
  adv, precision): jump head +128 clears any lip, and the steepening broke
  R4's prow-mount. Regen + churn-revert; tutorial/precision diffs are the
  revert itself.
- Tall prows tried and REVERTED (collinear extensions, same angles): trace
  proved speed flyovers graze the corner and sail (steep face out-descends
  gravity — a rider above it never comes back down), and 150-200u walls
  across full-width corridors softlock walkers. Forcing is routing, not
  walls. All 5 prow-contact tests failed the same way — correct call to
  delete, not tune.
- R2 cap-traps EMBEDDED R4-style: inter R2 e1 -470 -> -535 (51.6 deg,
  R1<R2<R3 holds), adv R2 e1 -790 -> -856 (62.7 deg, band holds). The +10
  nubs' box-end caps (8% oversize + half-thickness rise ~32-35u above e1)
  trapped entries phase-dependently (diag: same spawn +/-40u flips
  mount/stall on hop-phase luck). Corners now 20u+ under slab tops.
- R4 hop-entry sign added (SignR4 on FloorE, reveal-tested).
- Tests: hop-mount + ride-deep per face (R4 pattern), SignR4
  present/worded/reveal. Suite 581/581; smokes intermediate + advanced OK.

## Lessons (load-bearing)
- Multi-entry ride tests MUST settle stale SURF after each teleport:
  identical slab-rest failure coords across geometry changes was the tell
  (stall precedes any ramp contact). Drain on flat slab before mounting.
- Diag scripts run under GM-autoload kill default -1000 (not the map's
  -2600): a mid-face "teleport" was a legit kill-respawn to last ground.
- NEVER write files via PowerShell (Set-Content rewrote test_runner.gd
  as ANSI -> invalid-UTF-8 parse failure). Edit tool only; recovered via
  cp1252->UTF-8 round-trip, zero loss.
- `_ramp` box = 8% oversize + sunk 14u: embed math must clear corner rise
  (margin*sin + 20*cos above e1), not just e1.

Next: embed-all deferred (R1 49-50.5 band vs embed depth; needs band+doc
changes); R4-sign pattern for other hop faces; playtest verdict on feel.

# Worklog — slice 3 hop-entry telegraphs (2026-10-03)

- Same-issue-across-maps fix: hop-mount is suite-proven but
  undiscoverable (riders cruise into nubs and stall). SignR4 pattern
  extended: inter SignR1/R2/R3, adv SignR1/R2 — right side, 40u above
  slab, ~180u before each prow. Uniform text ("SURF RAMP / Hop onto the
  face / and ride it down!").
- Tests: per-map sign loops (present + TutorialSign + hidden + text +
  reveal). user_guide §3 gained the hop-entry doctrine (2 lines).
- Rollercoaster already telegraphed (Drop/Kicker/Wall signs, M10a);
  tutorial has its school signs; precision pool-drops are a different
  technique (out of scope).
- Verify: suite 601/601 (+20 sign checks); smokes inter/adv OK.

Next: test-list for user playtest (one map at a time); then vision
doc/plan/scope for open surf-kicker-catch maps (rollercoaster/endless).
