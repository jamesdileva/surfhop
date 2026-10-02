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
