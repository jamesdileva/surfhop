# AGENTS.md — Velocity Engine

> Operating rules for AI coding agents working on this repository.
> Authoritative sources: `docs/01_Master_Architecture.md` (architecture),
> `docs/02_Gameplay_Systems.md` (movement math & systems), `docs/03_Sprint_Plan.md` (roadmap).
> If code and docs disagree, the docs win — flag the discrepancy instead of silently "fixing" the doc.

## Documentation Map

- `README.md` — repo overview, quick-start commands, doc index
- `docs/user_guide.md` — player-facing guide (controls, movement school, settings)
- `docs/changelog.md` — feature-level changelog by phase
- `docs/history.md` — engineering session log; append an entry after every sprint push
- `docs/performance_profile.md` — performance baseline, benchmark harness usage, manual validation checklist

## Project Identity

- **Engine:** Velocity Engine (Godot 4.x, GDScript, Forward+, Godot Physics)
- **Game:** *Velocity* — first-person bhop / air-strafe / surf time trials
- **Physics tick:** fixed 100 Hz (`physics/common/physics_fps=100`). Never change without a doc update.

## Operating Contract

1. **Read the docs first.** Read the relevant sections of `docs/01_Master_Architecture.md` and `docs/02_Gameplay_Systems.md`, plus the current sprint in `docs/03_Sprint_Plan.md`, before writing any code.

2. **Complete only the current sprint's scope.** Do not add features, refactor, or "improve" code outside the current sprint's acceptance criteria. Do not start the next sprint unless asked.

3. **Preserve the engine-first boundary.** The Movement Framework (`scripts/movement/`) must never depend on game-layer code (`scripts/game/`). If a movement module needs a game concept (e.g., timer), emit a `SignalBus` signal and let the game layer listen. Dependency direction is strictly: GAME → FRAMEWORK → ENGINE CORE → GODOT.

4. **Movement modules are small.** Split any module exceeding ~300 lines. If `MovementController.gd` exceeds ~400 lines, the module decomposition needs rethinking. `Player.gd` stays thin (~200 lines max).

5. **Configuration is resource-driven.** Never hardcode a number that belongs in a `MovementConfig` `.tres` parameter (walk speed, jump impulse, gravity, surf angles, buffer windows...). Magic numbers in movement math are bugs.

6. **One class, one purpose.** Each GDScript file defines one class with a single responsibility. Always use type hints. Use `class_name` for anything referenced by type elsewhere.

7. **Keep changes localized.** Modify only files listed in the current sprint. If you must touch an extra file (e.g., adding a parameter to `MovementConfig`), keep the change minimal and note it.

8. **Test before done.** Every sprint's acceptance criteria MUST pass before the sprint is marked complete. Sprint manual testing steps are not optional. Write GUT tests where the sprint calls for them; do not stub out acceptance criteria for speed.

9. **Resources are never hand-edited.** Create `.tres` files by instantiating the script via `Resource.new()` + `ResourceSaver.save()` or in the editor — never by hand-writing `.tres` text.

## Sprint Workflow

1. Confirm the current sprint from `docs/03_Sprint_Plan.md`.
2. Read its Inputs sections in docs 01/02.
3. Implement: create/modify only the sprint's file list.
4. Verify every acceptance criterion; run manual tests where possible.
5. Commit using conventional-commit style: `feat(movement): ...`, `fix(physics): ...`, `docs: ...`.
6. Update `docs/history.md` with the session's entry (what shipped, decisions, notable bugs) after every commit+push.

### Sprint Order & Parallelization

- Sprints within a phase are sequential (each builds on the previous).
- Sprints 19–23 (maps) can be partially parallelized.
- Sprint 28 (Steam) can run parallel to sprints 24–27.
- Sprint 29 (docs) runs after everything else.

### Key Dependency Chain

```
1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12
                              └─────────────→ 13 → 14 → 15 → 16 → 17 → 18
                                                                    └→ 19 → 20 → 21 → 22 → 23
                                                                                             └→ 24 → 25 → 26 → 27 → 28 → 29 → 30
```

Notable cross-dependencies: Sprint 16 (HUD) needs 17 (Save) for PB display; Sprint 18 (Ghost) needs 17 for storage; Sprint 26 (Settings) needs 24 (Audio).

## Environment

- Godot binary: installed via winget (`godot` alias; actual exe under `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\`).
- Git conventions: `main` = production-ready/tagged releases; feature branches merge to `develop`; commit style per above.

## Commands (canonical — do not vary)

There is no package manifest (plain Godot project), so these fixed commands are the single source of truth for agents and CI/external tooling:

```sh
# Validate / import check (no main scene needed)
godot --headless --path . --editor --quit

# Run all tests (from Sprint 2 onward; GUT via tests/test_runner.gd)
godot --headless --path . --script res://tests/test_runner.gd

# Launch the game (once a main scene exists, Sprint 4+)
godot --path .
```

### Manual Playtesting (dev bootstrap scenes)

No main menu exists yet; use the dev bootstrap scenes to play maps directly:

```sh
godot --path . scenes/world/dev_tutorial.tscn
godot --path . scenes/world/dev_beginner.tscn
godot --path . scenes/world/dev_intermediate.tscn
godot --path . scenes/world/dev_advanced.tscn   # added Sprint 22
godot --path . scenes/world/dev_challenge_oc.tscn          # Sprint 23
godot --path . scenes/world/dev_challenge_precision.tscn   # Sprint 23
godot --path . scenes/world/dev_challenge_speedrun.tscn    # Sprint 23
```

Controls: WASD move, Space jump, mouse look, R restart-from-checkpoint,
F1 debug overlay (speed/state/vectors), Esc opens the pause menu (tree
pauses; Settings lives inside pause; Esc again resumes). `godot --path .`
boots to the main menu; dev bootstrap scenes still bypass it. HUD shows live
timer/PB/checkpoints; PB ghosts appear after a first record per map.

## Deferred Polish Items (Phase 6 backlog)

- **P2 Playtest polish pass** (deferred behind P3 by decision): ramp feel
  tuning (air_accel (10), surf friction, gravity-conversion strength),
  gap-jump distance validation, jump-while-surfing keep-or-gate decision —
  all need human play sessions.
- ~~**P3 Visual materials pass**~~ — DONE (Sprint P3): neon-edge shader,
  per-difficulty tinting via `WorldMaterials`, procedural skybox.
- **P4 Music stations**: drop royalty-free tracks into `assets/audio/music/<station>.ogg/.wav`
  — the `audio/music_track` dropdown already ships in the settings menu
  (Audio tab lists stations once files exist; placeholder until then).
- **P5 Performance certification**: headless profile is in
  `docs/performance_profile.md`; the manual checklist there (real-hardware
  profiler pass <1.5ms physics, 144+ FPS, 10-min memory soak) still needs a
  human run before release.
- **P6 v1.0 release** (original Sprint 30 spec): export, clean-machine test,
  version alignment, tag. Steam activation follows P6: buy AppID ($100),
  install the GodotSteam GDExtension, add `steam_appid.txt`, then fill in
  `_try_connect_steam()` / `_activate_on_steam()` / `submit_time()` — no
  call-site changes needed.

Notes:
- All test suites must be reachable through `tests/test_runner.gd`. Never use ad-hoc `-s <script>` invocations for testing.
- Exit code 0 + no `ERROR` lines in stdout = success. Godot prints errors to stdout/stderr, so crash-signature scanning applies.

