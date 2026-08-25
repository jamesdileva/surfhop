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

## Sprint P3 — Visual Materials Pass

- **Neon-edge surface treatment** (`assets/shaders/neon_edge.gdshader`): flat white albedo with fresnel rim emission plus faint 128u world-space grid lines — the §16 "white geometry + neon edges" aesthetic in one unshaded shader.
- **Per-difficulty tinting**: `WorldMaterials` (UIManager-owned sibling of VisualEffects) styles every loaded map's StaticBody3D/AnimatableBody3D meshes via `LevelLoader.map_loaded`, tinting from `MapMetadata.vertex_color_tint` or a difficulty palette (cyan→green→amber→orange→magenta). SurfRamp* bodies are skipped — the Sprint-25 interactive glow shader owns those surfaces.
- **Skybox**: one shared `WorldEnvironment` under UIManager covers all scenes incl. dev bootstraps — dark procedural sky tuned so neon emissions pop.
- Flagged extra: `MapMetadata.vertex_color_tint` export added (doc-specified field that didn't exist); existing `.tres` metadata untouched (hand-editing forbidden) — palette fallback covers all shipped maps, per-map overrides can be set programmatically later.
- Deferred: P2 playtest polish pass moved behind P3 by decision (needs human sessions).
- Lesson: `map_loaded` fires after `current_metadata` is set in `_finalize_load` — ordering dependency worth keeping documented.
- 386 checks passing (up from 377).

---

## Sprint E1 — Endless Movement Mode (Phase 7 begins)

- **Endless Skatepark** (`scenes/maps/endless.tscn`): 8000u floor, three surf ramps (45/50/60°), two elevated platforms with walkable approach inclines, a strafe corridor; tagged `"endless"` in metadata. Generated programmatically by `tools/generate_endless_map.gd` (ResourceSaver/PackedScene, per the never-hand-edit-resources rule).
- **Scoring**: session peak + all-time top speed per map. `TopSpeed` tracker (UIManager-owned) activates only on `"endless"`-tagged metadata; improvements persist through `SaveManager.record_top_speed()` into the existing `MapRecord.best_speed` field; `SignalBus.top_speed_beaten` announces with a 25 u/s margin so the HUD flash doesn't spam.
- **HUD**: endless maps hide timer/PB/checkpoint labels and show a persistent TOP readout with a green flash on new records. Race systems stay dormant (no triggers → no race/results/ghost recording); R respawn works via spawn capture.
- Bugs caught: `PackedScene.pack()` silently drops children without `owner` set — first generated park was an empty root (found via all-miss raycasts); regenerating requires actually rerunning the generator after edits; E1's HUD edit accidentally deleted the SteamManager achievement-toast wiring — restored, caught by the Sprint-28 toast test.
- Lesson: `--script` runs can lose the global class cache after new `class_name`s appear — run the editor import pass before tooling scripts that reference project classes.
- 406 checks passing (up from 386).

---

## Sprint INT1 — Sentinel Integration

- **Shim `package.json`**: first manifest in the repo; `start`/`test`/`build` map to the canonical godot CLI lines so Sentinel's extractor works unchanged. `npm run test` / `start` / `build` now work.
- **Self-driving smoke mode** (`-- --smoke`, handled in Game.gd): boots the real menu flow, resolves a map (`--smoke-map=`, default beginner), waits for async load + player spawn, simulates ~8s of auto-bhop input, asserts the player moved >50u, then exits 0/1 with milestones printed to stdout and written to `%TEMP%\velocity_smoke.log`. Stages: MENU_SHOWN → MAP_LOAD_STARTED → PLAYER_SPAWNED → GAMEPLAY_OK. Windowed runs double as screenshot targets for Sentinel's smoke capture.
- **`tools\godot.cmd` locator wrapper** (GODOT_EXE → PATH → winget scan): needed because bare shell lines can't resolve the winget user-PATH godot — integration.md's rule #1 bit us exactly as documented.
- Bugs caught: bare `process_frame` doesn't exist on Node scripts (`get_tree().process_frame`); cmd parse-time `%errorlevel%` expansion inside for-blocks returns stale exit codes (restructured wrapper).
- Verified live via `cmd /c "<string>"` for all three commands: test 406 checks ✅ · start windowed + headless ✅ (audio confirmed by user) · build ✅. Facts block appended to docs/integration.md §9.
- Deferred: packaged-exe layout (`dist/win-unpacked/`) until P6 export.

## INT1 follow-up — Surfhop tester screenshots (2026-08-23)

- Wired a custom Sentinel tester (`backend/app/testers/surfhop.py` in the
  Sentinel repo): full suite → windowed smoke pass, capturing stage
  screenshots gated on app-log markers.
- Integration debugging findings (full write-up in docs/integration.md
  "Lessons from live Sentinel integration"): stale persisted `stack.commands`
  (fixed in default_smoke via live rediscovery), backend restart required
  after tester-module edits, pool_size=2 scheduler starvation with no
  watchdog, trailing-slash API routes, exe-path window matching blind to the
  winget Godot install, PrintWindow blanking on GPU-composited frames.
- Game-side fixes: smoke milestones now print LIVE per stage (+ new
  RUN_STARTED marker); new flags `--smoke-stage-pause=<sec>` (dwell on
  menu/load/spawn so screenshots photograph the actual stage) and
  `--smoke-hold=<sec>` (window survives RESULT for post-pass shots). Shim
  `start` defaults: hold=60, pause=2.5.
- Tester-side fixes: title-based window find (`^Velocity`), gameplay shot
  gated on RUN_STARTED +4s (mid-run motion instead of frozen spawn pose),
  ImageGrab screen-crop fallback for blank PrintWindow frames.
- One self-inflicted parse error during the marker refactor (`result`
  identifier referenced after its declaration was removed) — caught by a
  hanging headless run; fixed and suite re-verified.
- Result: session PASSED; three verified screenshots (real main menu /
  165 u/s mid-run / post-run hold at 56 u/s). Suite still 406 checks green.
  Commits: surfhop eed4cde→0cadf12→4cf6b68; Sentinel edf77ac→9022c94→5434927→2bd1509.

## INT1 follow-up 2 — full menu coverage + music stations (2026-08-23)

- **Music stations (P4)**: user dropped 7 pixabay tracks as MP3 into
  `assets/audio/music/`. Godot 4 imports MP3 natively — added `.mp3` to
  AudioManager's extension list; no external conversion needed.
- **Docs discrepancy flagged & fixed**: AGENTS.md claimed the
  `audio/music_track` dropdown "already ships" — the Audio tab only had
  volume sliders. Implemented the dropdown per docs: scans MUSIC_DIR on
  every settings open (new files appear without restart), persists via
  SaveManager, switches station live. Excluded internal fallback
  `menu_placeholder` from the list.
- **Smoke coverage widened**: new `MAP_SELECT_SHOWN` / `SETTINGS_SHOWN`
  stages dwell in the real Play flow (map select → settings overlay →
  launch).
- **Screenshot architecture rework**: log-gate-then-shoot proved unreliable
  (app-log tail lag made shots photograph the NEXT stage — map_select shots
  caught settings, settings shots caught map load). Definitive fix: the game
  now dumps its own framebuffer per stage to `%TEMP%\velocity_smoke_*.png`
  (`_smoke_capture`, awaited — fire-and-forget captures the next stage,
  first bug found by inspection of the dumps). Tester registers the dumps
  after RESULT; PrintWindow survives only as the hold-window sanity shot.
- Verified: session PASSED with five correct screenshots (menu, map select,
  settings, 165 u/s mid-run, post-run hold). Suite 406 checks green.
  Commits: surfhop e1eb89a, 4290c51, cbe8146, a51f0cb(docs);
  Sentinel 41e7ac6, 9bdee10.

## P2 round 1 — playtest fixes (2026-08-23)

First human playtest feedback (beginner map), four bugs + one design change:

- **Invisible pause menu**: Esc opened pause and closed it in the SAME frame
  — PlayerCamera._input didn't mark the event handled, so UIManager's
  ui_cancel close handler ate it. Fix: set_input_as_handled + Esc works
  without mouse capture + auto-recapture on APPLICATION_FOCUS_IN.
- **Beginner ramp resets**: kill_plane_y defaulted to -1000 while the course
  descended to -1400 — the plane sliced through ramp 3. Now -600, plus a
  GUT sweep (_test_kill_planes) asserting every map's kill plane sits >100u
  below its lowest box corner. Only beginner was broken.
- **Static on ramps**: surf_loop placeholder is literally filtered noise
  (gain 1.6, pitch-scaled with speed). Regenerated at gain 0.35 with a
  deeper lowpass, player rides -8dB; land thud 2.2 → 0.8 gain, impact
  boost capped +6 → +3dB.
- **Music during runs**: removed race_started → stop_music (design change:
  background enjoyment over race silence).
- **Beginner flow rework** (user sketch: `____ \_ ____ \_ ____`): generator
  now supports ascending kickers (`_ramp(..., ascending)` — the kicker bug
  where a kicker rotated as a descender was caught by the traversal test's
  position trace). Course: 4 floors, ~100u drops, 38° entries → 30°
  kickers → 60u gaps. Known quirk (documented in test): a ground-sliding
  player leaves the kicker lip with ~zero vy — the capsule catches the lip
  edge and Godot projects against it; airborne (bhop) players launch
  normally, and the flat hop still clears the gap.
- Suite: 417 checks green (kill-plane sweep added 11). Smoke RESULT=OK.
  User's 7 pixabay MP3s committed. Commit 87b1418.

## P2 round 2 — surf feel + ramp audit (2026-08-23)

Second playtest round: colors blend, surf feel off, air strafe too tight.

- **Surf feel root cause**: round 1's shallow ramps demoted beginner to
  GROUND state (friction 6.0 vs surf 0.25) — the "not sliding gracefully".
  Two rework attempts (38/30 flow ramps; 55/47 short curves) then exposed
  **catch physics**: a player leaving a floor edge re-intersects a ramp
  plane at a distance that grows with speed squared (~280u at 320 u/s,
  ~670u at 500 u/s), so short or shallow ramps shed players into the next
  floor's wall. Original 46-degree/380-deep geometry catches at every
  speed — RESTORED, with the kill-plane fix kept (-1600). Lesson: surf
  catchability demands long ramps; verticality is the price of surf.
- **Ramp tinting**: ramps now carry the map accent color as their shader
  BASE (VisualEffects pulls WorldMaterials.tint_for_metadata) — no more
  white-on-white against floors.
- **air_accel 10 → 14** (snappier strafe gain; user hit 500 u/s but it was
  a grind).
- **Endless Skatepark ramp audit** (user-reported map): SurfRamp1 was 40°
  (below surf threshold — sticky) → 47°; SurfRamp3 sat at exactly 45.0°
  (classification boundary, falls to ground side) → 48°; both re-anchored.
  SurfRamp2 (60° banked) and UpRamps (16/28° kickers) fine.
- **Full map ramp audit**: tutorial 48° ok; intermediate 50/55/60 (60 is a
  bottom-edge catch at 320 u/s — borderline, difficulty 3); advanced
  50-70° and precision 63° narrow are steep by design; all kill planes
  verified safe by the sweep.
- Suite 417 green, smoke RESULT=OK. Commit 4377db4.

## P2 round 3+4 — V-channels + persistence fixes (2026-08-23)

- **Beginner V-channels shipped and validated by playtest** ("way more like
  what we want"). Round 3: `_surf_channel()` — two opposing 56° banked
  walls (512:384 CS ratio) + flat lip; walls can't be hopped over; 600u
  junctions, 250u drops, kill plane -960. Round 4: walls 350→500 tall for
  longer carves.
- **Settings clobbered by test runs**: the settings-menu test saved
  fullscreen=true into the REAL settings.cfg on every suite run. Test
  runner now snapshots user://save before the run and restores at exit.
- **Music loops**: AudioStreamMP3.loop + finished-signal restart fallback
  (tracks were one-shot).
- **Surf momentum**: surf_friction 0.25 → 0.05 (CS surf is frictionless;
  slides were dying in ~2s). Remaining feel lever: wall-entry projection
  losses are inherent — approach low on the face, carve up.
- air_accel stays 14 — verified cap-limited by air_speed_cap; raises are
  no-ops. The channels are the speed source (frictionless faces gain speed
  linearly with time per HL physics).
- Suite 416 green, smoke RESULT=OK. Commits e055f77, caaf9c2.

---

## Deferred / Backlog (see also AGENTS.md "Deferred Polish Items")

- Decide jump-while-surfing policy permanently (currently allowed via coyote window; playtester finds it useful for repositioning).
- Neon edge highlights / per-difficulty tinting (docs §16 aesthetic) — current maps are white-boxed.
- Ramp & air-accel feel tuning after extended sessions; gap-distance validation needs human clears.
- Main menu / results screen flow (dev bootstrap scenes are the current entry point).

*(Entries above reconstructed verbatim from git history `e84efb9..c28e155`; going forward, append a new section after each sprint push.)*
