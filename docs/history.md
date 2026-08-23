# Velocity Engine — Development History

> A running log of what was built, decided, and broken along the way.
> **Maintenance rule:** after every sprint commit+push, add or amend the
> session's entry here (what shipped, decisions made, bugs worth remembering).

---

## Phase 0 — Ideation

- Concept settled: first-person bhop / air-strafe / surf time-trial game ("Velocity") built on a reusable engine ("Velocity Engine"), Godot 4.x + GDScript, engine-first architecture (docs 01–03 authored before any code).

## Sprint 1 — Project Setup (`6972e39`)

- Project scaffolded; folder structure per architecture §5; `.gitignore`; `AGENTS.md`.
- Godot 4.7.2 installed via winget. Decision: project name "Velocity", repo dir stays `surfhop`.

## Sprint 2 — Core Managers (`861c2e3`)

- 8 manager autoloads + SignalBus (6 event signals). All registered and validated.
- Established the canonical headless test contract: everything reachable through `tests/test_runner.gd`; success = exit 0 + zero ERROR lines.

## Sprint 3 — Input System (`b9fe23f`)

- `InputState` struct + full `InputManager` (rebinding w/ conflict detection, persistence to `user://save/bindings.cfg`).
- Lesson: input actions were written into `project.godot` programmatically so Godot serialized them; manually corrected `"device":16` → `-1` afterwards.

## Sprint 4 — First-Person Camera (`e5390e5`)

- `PlayerCamera`: yaw-on-body/pitch-on-camera, ±89° clamp, SaveManager-driven sensitivity, capture/release.
- Pattern adopted: **autoload names are not compile-time globals under `-s` scripts** — gameplay code resolves managers via `get_node("/root/<Name>")`.

## Sprint 5 — Basic Movement (`a3853b9`)

- `Player` + `MovementController` + module pipeline (`GroundMovement`, `Gravity`); `MovementConfig`/`MovementState` added as flagged extras.
- Decision: **Quake unit scale** (1 Godot unit = 1 Quake unit; capsule 72u) so documented numbers work verbatim.
- **Doc bug flagged:** `physics/common/physics_fps` doesn't exist in Godot 4 — real setting is `physics_ticks_per_second`. Our 100 Hz was silently not applied until fixed.

## Sprint 6 — Ground Physics (`c738947`)

- `Friction` (PM_Friction + `stop_speed`, override param for later bhop use) + `Velocity` clamp module. Module order now friction-before-accelerate (Quake style).

## Sprint 7 — Jumping (`944ea2a`)

- `Jump` (impulse + coyote time) and `Collision` ground-detection wrapper; controller state machine driven through it.

## Sprint 8 — Bunny Hopping (`1a56a72`)

- `BunnyHop` buffer + landing dispatch + friction override. Ordering bug (override reset wiping a just-set value) caught during self-review.

## Sprint 9 — Air Strafing (`d1ed4fb`)

- `AirMovement` + generic `on_takeoff`/`on_land` hooks on the module base class.
- Learning: strafe gain at high speed is physically tiny (Δv ≈ a²/2v) — authentic Quake behavior, kept as-is at this point.

## Sprint 10 — Surfing (`8121da7`) — *the big one*

- Final design: ramps steeper than `floor_max_angle` are treated as **walls** by grounded `move_and_slide`, which preserves tangential velocity; gravity pressing into the wall maintains contact. `Surf` module projects velocity onto the plane, applies low friction, anti-stuck (acceleration-based), exit boost.
- Dead ends documented: raising `floor_max_angle` to 80° made grounded mode flatten v.y every tick (speed pinned); `MOTION_MODE_FLOATING` slides motion but never rewrites velocity or sets floor flags.
- Lesson: an out-of-scope `delta` reference cascaded into a wall of Nil errors — always check the FIRST script error, not the flood.

## Sprint 11 — Physics Tuning (`797a2dd`)

- Measurement suite (walk/jump/strafe/surf rates) + **fixed-tick determinism test** (bitwise-identical runs).
- Decision (user): keep documented Quake values; acceptance-target contradictions flagged for docs instead of retuning.

## Sprint 12 — Debug Tools (`048b23c`)

- F1-toggled overlay drawing velocity/surface-normal arrows + state label; visibility persisted via settings; overlays self-register with UIManager.

## Sprint 13 — Timer System (`5b57b9a`)

- `TimerSystem` wires scriptless trigger scenes by group; GameManager gained wall-clock race timing, PB checks, pause compensation.
- Gotchas locked into team memory: `PackedScene.pack()` drops children without `owner`; `add_to_group` needs the persistent flag.

## Sprint 14 — Checkpoints (`d459ccb`)

- Forward-only checkpoint progression, splits into finish payload, kill-plane respawn (timer keeps running), R = reset + respawn.

## Sprint 15 — Map Loading (`563e18b`)

- Threaded async `LevelLoader`, discovery via node-metadata `map_metadata`, per-map MovementConfig applied to the player; `GameManager.map_name` set from metadata.

## Sprint 16 — HUD (`88abf55`)

- Speed (30 Hz throttled, §13.3 color tiers), live timer, PB, checkpoint progress, FPS, debug line. Flow: controller emits `SignalBus.velocity_updated` each tick.

## Sprint 17 — Save System (`eb6a278`)

- Full persistence: settings.cfg, records.tres (PBs + stats), ghosts under `user://ghosts/`. First-run defaults written automatically.
- Lesson: inner classes don't resolve as cross-script static types — `MapRecord` promoted to its own file; defensive loading drops malformed legacy entries.

## Sprint 18 — Ghosts (`d2c15af`)

- `ReplayFrame`/`GhostReplay`, signal-driven recorder (saves only on PB), translucent `GhostPlayer` playing one frame per tick in lockstep with races.

## Sprint 19 — Tutorial Map (`887e259`)

- First content map: bhop runway → strafe field → 45° ramp → pool → finish, with proximity-revealed instruction signs and the forgiving `casual.tres` preset. Dev bootstrap scenes introduced for playtesting.

## Sprint 20 — Beginner Map (`fdd8342`)

- ~8600u course, three surf ramps of increasing angle, three checkpoints.
- Integration fix: `LevelLoader` now resets race/checkpoint state when a map loads (state used to leak across maps).

## Playtest Round 1 — The Invisible World

- User reported a uniform gray screen. Root causes (both real): **no lights/environment anywhere**, and **no visual meshes at all** — maps were pure collision geometry.
- Fix: sky + directional sun on every map; white BoxMesh visuals mirroring every collision box. All four generators consolidated into the permanent `tools/generate_maps.gd` (`efba8ea`). Empty-shell dev scenes regenerated (`8779928`).

## Playtest Round 2 — Movement Feel

- `a96eb7a` — wish direction now uses the camera's **global** basis (W follows look direction; prerequisite for real surfing).
- `5d1ce38` — air acceleration switched from the Quake-1 variant to the **Half-Life/CS variant** (cap limits only the projection check; acceleration scales with move speed). This is what makes classic pure-A circle-strafing possible. Doc §1.4 divergence flagged.
- `4353a2f` + `aa3343e` — tutorial ramp surf fixes: casual config lowers `floor_max_angle_deg` to 40°, and body physics are re-applied whenever a map swaps configs (player used to spawn before the map and keep stale body settings).
- `923cddf` — CS 1.6 surf model finalized: A/D against the ramp + mouse steering (air-accel active while pressed into walls), no jumping off ramps, sign text updated.
- `53a3704` — tutorial ramp steepened to 48° (exact-45.0° sat on the walkable-classification boundary); debug line always-on in dev scenes showing STATE / speed / slope-limit.

## Sprint 22 — Advanced Map (`a30b454`)

- ~26,000u course: four ramps up to 70°, a seamless ramp-to-ramp transition (endpoint metadata asserts adjacency), two void gaps, six checkpoints.

## Sprint 23 — Challenge Maps (`c28e155`)

- **Obstacle Course** (pillar slaloms, bhop-over walls, oscillating `MovingPlatform` walls, narrow bridge over void).
- **Precision Surf** (three ~63° ramps, 150u-wide surfaces over pools).
- **Speed Run** (single 6,500u flat line; no checkpoints — pure momentum test).
- `MovingPlatform.gd` (AnimatableBody3D sinusoidal mover) added to the framework.

## Sprint 24 — Audio (`735e4c7`)

- Full `AudioManager`: runtime Music/SFX/UI buses, SFX voice pool, volume API backed by saved settings, menu click sounds.
- Event-driven sound: jump/land (fall-speed-scaled), footsteps (stride-distance based, two variants), surf loop with speed-scaled pitch, finish jingle; music stops on race start and resumes after the jingle.
- Placeholder sounds + music loop are **synthesized** by `tools/generate_sfx.gd` — no licensing concerns; swap files under `assets/audio/` to replace.
- Music stations designed for user-supplied royalty-free tracks: drop `assets/audio/music/<station>.ogg/.wav`, set `audio/music_track`; settings dropdown arrives in Sprint 26.
- New SignalBus signals: `footstep`, `surf_entered`, `surf_exited`.
- Lessons: `get_setting(key)` takes one arg (no inline default) — a bad call crashed `_ready` mid-setup and silently disconnected every later signal connection; prefer `ResourceLoader.exists()` before `load()` to keep stdout clean.

---

## Sprint 25 — Visual Effects

- Event-driven `VisualEffects` coordinator (owned by UIManager, AudioManager listener pattern): landing dust puffs scaled by fall speed, takeoff puffs on **any** ground exit (jump, bhop, ledge walk-off), world-space speed trail above 600 u/s, surf-ramp glow.
- Surf glow: `surf_ramp.gdshader` with a per-instance `glow` uniform is applied at runtime to every `SurfRamp*` StaticBody's meshes via the `node_added` signal — zero map-file edits, covers LevelLoader loads and dev scenes. Glow brightness scales with surf speed and decays after exit; the touched ramp is resolved by raycasting backwards along the surf contact normal.
- Speed trail: `SpeedTrail.tscn` + additive `speed_trail.gdshader`; particles spawn with zero velocity so they linger as a streak behind the player.
- Signal payload extensions: `player_landed` / `player_jumped` / `surf_entered` now carry world `position`; new `player_takeoff(data)` signal emitted by MovementController's post-move contact transition.
- Settings: new `video/vfx_enabled` default (true); UIManager.set_vfx_enabled() persists it. UI toggle lands in Sprint 26.
- Bugs caught by tests: telemetry counters incremented even while VFX was disabled (gate before counting); a `queue_free()`d dropper player kept emitting `velocity_updated(0)` for one more frame and zeroed synthetic trail speeds — flush a process frame after freeing before asserting on event-driven state.
- 318 checks passing (up from 300).

---

## Sprint 26 — Settings Menu

- `SettingsMenu` overlay (CanvasLayer + programmatic UI): Graphics (fullscreen, vsync, fps cap, windowed 16:9 resolution presets), Audio (Master/Music/SFX sliders with live bus preview + click blip), Input (per-action click-to-rebind with conflict feedback), Gameplay (debug toggle, auto-save ghost toggle, tick rate shown display-only).
- All changes persist immediately (`settings.cfg` / `bindings.cfg`); engine-impacting ones apply live through new `SaveManager.apply_settings_to_engine()` (+`apply_windowed_resolution()`, `reset_settings_to_defaults()`). Reset-to-Defaults restores factory settings and re-applies bus volumes; Back/Esc returns to gameplay and recaptures the mouse.
- Menu access decision: **Esc opens/closes settings** (replaces the old release-mouse-only behavior; click-to-recapture suppressed while a menu is open).
- Tick-rate row kept display-only ("engine-fixed") per the docs' untouchable-100Hz rule.
- New settings keys: `gameplay/auto_save_ghost` (off = PBs still record, replays not written — gated in `GhostRecorder.should_autosave_ghost()`), `video/resolution`.
- Lessons: get_node paths must include intermediate container rows (`Graphics/ResolutionRow/ResolutionOption`) — two stale paths threw SCRIPT ERRORs after checks passed; remember the contract is exit 0 + **zero** ERROR lines, not just green checks.
- 338 checks passing (up from 318).

---

## Sprint 27 — Optimization

- **Interpolation**: enabled Godot's built-in 3D physics interpolation (`physics/common/physics_interpolation=true`) instead of hand-rolling a lerp — the doc's custom-Interpolator idea predated the engine feature. `scripts/core/Interpolator.gd` survives as the teleport guard: any per-tick position jump >100u (checkpoint respawns, test teleports) calls `reset_physics_interpolation()` so the view snaps instead of gliding across the map. Node lives in Player.tscn per the sprint file contract.
- **Hot-path opts, strictly non-semantic**: cached `cos(surf_angle_min_deg)` in Surf (recomputed only on config swap); cached player ref in VisualEffects trail update. Determinism suite passes bit-identical.
- **Profiling**: new permanent hook `MovementController.last_script_step_us` + repeatable headless harness `tools/benchmark.gd` (env switches: BENCH_EMPTY / BENCH_NO_MOVE / BENCH_NO_VFX / BENCH_NO_INTERP). Results in docs/performance_profile.md: movement script cost ~0.10ms/tick p50; scene physics baseline ~1.9ms monitor reading is constant and environment-noisy (empty-world floor 0.37ms, jittery tail) — full-step <1.5ms certification deferred to the documented manual profiler pass. Memory flat (+0.3MB/60s).
- Lesson: `Performance.TIME_PHYSICS_PROCESS` is smoothed and includes catch-up — measure your own code with `Time.get_ticks_usec()` before trusting it.
- 343 checks passing (up from 338).

---

## Sprint 28 — Steam Integration (local mode)

- **Decision**: real Steam activation deferred to release (needs GodotSteam GDExtension + paid AppID + running client). Everything else ships now behind a facade: `SteamManager` runs in LOCAL mode (`available == false`) with three documented seams to fill later (`_try_connect_steam`, `_activate_on_steam`, `submit_time`) — no call-site changes needed at flip time.
- Six achievements per spec: First Jump / First BHop / First Surf / First PB / Beat 300 u/s / Beat 600 u/s. All driven from existing SignalBus events; the bhop detection uses a landing→jump timing heuristic (~120ms window) so the movement layer stays untouched.
- Unlocks are once-only, persisted to `user://save/achievements.cfg` (survive restarts), play a synthesized two-note chime (added to `tools/generate_sfx.gd`), and toast on the HUD ("ACHIEVEMENT UNLOCKED — …").
- Cloud-save hook: `SaveManager.queue_cloud_sync()` called from `save_settings()`/`persist_records()`; counted no-op locally.
- SteamManager registered as 9th autoload (deviation from the doc's 8-manager list — flagged).
- Lesson: RNG-based generated WAVs churn byte-wise on every regeneration — restore untouched ones before committing; also, wall-clock heuristics in tests need explicit timestamp isolation or earlier suites' events leak in.
- 358 checks passing (up from 343).

---

## Sprint 29 — Documentation

- New: `docs/user_guide.md` (player-facing controls/movement school/maps/settings/achievements), `docs/changelog.md` (feature changelog by phase), and `README.md` (engine-first framing — flagged extra; acceptance required it but it wasn't in the sprint file list).
- All three architecture docs bumped to **1.1** with revision-history sections reconciling them to the shipped implementation (HL-variant air accel, wall-contact surf model, 9th autoload, built-in interpolation).
- AGENTS.md finalized with a Documentation Map section; backlog already current from prior sprints.
- Decision: docs go 1.0 → 1.1 now; Sprint 30 aligns doc + project version at the v1.0 game release.
- 358 checks passing (docs-only change, suite rerun for completeness).

---

## Sprint P1 — Main Menu & Game Flow (Phase 6 begins)

- **Roadmap change**: v1.0 release deferred — the roadmap never included a main menu, so shipping would have frozen a console-launched game. `docs/03_Sprint_Plan.md` gains a **Phase 6 (P1–P6)** section: main menu → playtest polish → visual materials → music completion → performance certification → v1.0 release; Steam activation follows.
- **Game.tscn** is now the project main_scene: boot shows the main menu; picking a map wires HUD/timer/ghost systems (same assembly as DevMain), loads via LevelLoader and spawns the player. Dev bootstrap scenes unchanged.
- Four new menus in the SettingsMenu programmatic style: MainMenu (Play/Settings/Quit), MapSelect (grid from discover_maps with difficulty stars), PauseMenu (resume/restart/settings/quit-to-menu/desktop), ResultsScreen (time, PB callout, splits; Retry/Map Select/Menu).
- UIManager reworked to a **menu stack**: all menus instantiated eagerly and hidden (ResultsScreen must exist to open itself on race_finished); pause = real tree pause (timer freezes; UIManager runs in ALWAYS mode so menus work while paused); Esc during gameplay toggles pause instead of opening settings directly.
- Lessons: don't generate .tscn files via PowerShell string interpolation (quote escaping silently ate closing quotes); eager instantiation requires every menu layer to self-hide in `_ready`; node paths in tests must match each scene's actual layout (ResultsScreen has no Panel wrapper).
- 377 checks passing (up from 358).

---

## Deferred / Backlog (see also AGENTS.md "Deferred Polish Items")

- Decide jump-while-surfing policy permanently (currently allowed via coyote window; playtester finds it useful for repositioning).
- Neon edge highlights / per-difficulty tinting (docs §16 aesthetic) — current maps are white-boxed.
- Ramp & air-accel feel tuning after extended sessions; gap-distance validation needs human clears.
- Main menu / results screen flow (dev bootstrap scenes are the current entry point).

*(Entries above reconstructed verbatim from git history `e84efb9..c28e155`; going forward, append a new section after each sprint push.)*
