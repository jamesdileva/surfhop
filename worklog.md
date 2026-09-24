# Worklog — surf-feel + single-skybox pass (2026-09-24)

Request: surfing doesn't feel like CS2; maps white-on-white; spacing review;
thought only 1 map got the fix. Decisions: both tracks parallel, CS2-style
ramp jump allowed, dark-neon look.

## Shipped
- Unified surf threshold on `floor_max_angle_deg` (Collision + Surf + body
  agree; legacy `surf_angle_min_deg` alias must equal it).
- Surf-entry preservation via `surf_preservation` (keeps ≥95% horizontal
  speed through wall-entry; gains never clamped).
- CS2 jump-off-surf: coyote refreshes in SURF; BunnyHop no longer
  auto-ejects on surf touchdowns.
- Single skybox: map-owned WorldEnvironment stripped on load (P3 dark sky
  wins); generator no longer bakes envs; full map regen (7 maps, dev
  scenes, casual.tres 40/40).
- New `_test_surf_polish` GUT coverage (thresholds, boundary, preservation,
  no-eject, env strip).

## Verify
- `tests/test_runner.gd`: 428 checks, 0 failures, exit 0.
- Smoke: tutorial RESULT=OK (661u/5s), beginner RESULT=OK (663u/5s).
- Exit-cleanup "resources still in use" ERROR is pre-existing headless
  shutdown noise (nondeterministic count), not a test failure.

## Deferred (needs human playtest)
- Glow-by-angle (Precision/Up ramps neon-only), intermediate 350u gap,
  challenge_oc 80u wall, test_map in MapSelect, endless dev scene.
- `surf_speed_multiplier` / `surf_exit_boost` still inert by design.

Full detail: `docs/history.md` (latest section).
