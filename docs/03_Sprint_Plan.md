# Velocity Engine — Development Roadmap

> **Version:** 1.1
> **Status:** Draft - Sprint 0 (Pre-MVP)
> **Audience:** Developers, AI coding agents, project managers
> **Related:** See `docs/01_Master_Architecture.md` for architecture and `docs/02_Gameplay_Systems.md` for implementation details.

This document is the **execution plan** for Velocity Engine. It defines 30 sprints across 5 phases, each with objectives, inputs, outputs, file lists, acceptance criteria, manual testing steps, and estimated effort. Sprints are ordered so that each builds on the previous one. Dependencies are called out explicitly.

---

## Table of Contents

- Phase 1: Foundation (Sprints 1-5)
- Phase 2: Movement Engine (Sprints 6-12)
- Phase 3: Gameplay (Sprints 13-18)
- Phase 4: Content (Sprints 19-23)
- Phase 5: Polish & Release (Sprints 24-30)
- Sprint Summary Table
- Notes for AI Agents

---

## Phase 1: Foundation (Sprints 1-5)

The foundation phase establishes the Godot project, core architecture, input system, camera, and basic movement.

### Sprint 1 - Project Setup & Repository

**Objective:** Create the Godot 4 project with the correct folder structure, .gitignore, and AGENTS.md.

**Files Created:**
- `project.godot` (Godot project file with physics_fps=100)
- `.gitignore` (excludes .godot/, *.import, exports/)
- `AGENTS.md` (project rules for AI agents)
- `docs/01_Master_Architecture.md` (already created)
- `docs/02_Gameplay_Systems.md` (already created)
- `docs/03_Sprint_Plan.md` (this file)

**Acceptance Criteria:**
- `project.godot` opens in Godot 4.x with physics_fps set to 100
- `.gitignore` excludes `.godot/`, `*.import`, `exports/*`
- Folder structure matches the architecture document
- AGENTS.md contains operating principles for AI agents

**Definition of Done:** Project opens in Godot, folder structure is correct, AGENTS.md is present. No code yet.

**Estimated Time:** 30 minutes

**Dependencies:** None

---

### Sprint 2 - Core Architecture & Managers

**Objective:** Implement the autoload singleton managers and the SignalBus.

**Inputs:** Master Architecture doc §7 (Core Systems).

**Outputs:** All 8 manager singletons functional; SignalBus ready for event emission.

**Files Created:**
- `scripts/managers/SignalBus.gd`
- `scripts/managers/GameManager.gd`
- `scripts/managers/InputManager.gd`
- `scripts/managers/TickManager.gd`
- `scripts/managers/UIManager.gd`
- `scripts/managers/SaveManager.gd`
- `scripts/managers/AudioManager.gd`
- `scripts/managers/LevelLoader.gd`

**Files Modified:**
- `project.godot` (register 8 autoloads under [autoload] section)

**Backend Changes:**
- SignalBus: extends Node, has `signal` declarations for all events (race_started, checkpoint_reached, player_landed, etc.)
- GameManager: RaceState enum, race_state property, start_race(), finish_race(), restart() stubs
- InputManager: get_movement_input() returns Vector2, is_action_pressed() delegates to Godot Input singleton
- TickManager: sets up 100Hz via project settings, emits tick signal
- UIManager: show_menu(), update_hud() stubs
- SaveManager: load_settings(), save_settings(), get_pb(), save_pb() stubs
- AudioManager: play_sfx(), play_music() stubs
- LevelLoader: load_map() stub, current_map property

**Acceptance Criteria:**
- All 8 managers register as autoloads successfully
- SignalBus has signals: race_started, race_finished, checkpoint_reached, player_landed, player_jumped, settings_changed
- GameManager has RaceState enum with IDLE, RUNNING, FINISHED, PAUSED
- InputManager.get_movement_input() returns Vector2(0, 0) when no keys pressed
- SaveManager.load_settings() returns default values on first run
- UIManager.show_menu("main") does not error

**Manual Testing:**
1. Run the project in Godot editor
2. Verify no errors on startup
3. Check Project Settings -> AutoLoad shows all 8 managers

**Definition of Done:** All managers registered and functional (stubs OK), SignalBus has all event signals, no startup errors.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 1

---

### Sprint 3 - Input System

**Objective:** Implement the InputManager with full action mapping, InputState struct, and input buffering.

**Inputs:** Master Architecture §11, Gameplay Systems §15.

**Outputs:** InputManager reads WASD/mouse/controller; produces InputState structs; jump buffer works.

**Files Created:**
- `scripts/movement/InputState.gd` (struct class)
- `configs/input_map.cfg` (default bindings)

**Files Modified:**
- `scripts/managers/InputManager.gd` (replace stub with full implementation)
- `project.godot` (add input actions to [input] section)

**Backend Changes:**
- InputState.gd: class_name InputState, properties forward, right, jump_just_pressed, jump_held, mouse_delta
- InputManager: 
  - _input(event) reads raw events, updates internal state
  - get_state() returns current InputState
  - rebind_action(action, event) with conflict detection
  - load_bindings() / save_bindings() for config persistence
- input_map.cfg: defines move_forward, move_back, move_left, move_right, jump, duck, sprint

**API Endpoints:** None (internal to Godot input system)

**Acceptance Criteria:**
- InputState correctly reports WASD input as forward/right values (-1 to 1)
- Jump input sets jump_just_pressed=true for exactly one frame
- Mouse delta is captured when cursor is hidden
- rebind_action() detects conflicts and rejects duplicate bindings
- Settings persistence: restarting the game preserves custom key bindings

**Manual Testing:**
1. Run the game, press WASD - verify movement vector
2. Press Jump - verify just_pressed flag
3. Move mouse - verify delta captured
4. Change a key binding in Settings (stub menu), restart - verify binding persists

**Definition of Done:** InputManager produces correct InputStates, rebinding works, bindings persist.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 2

---

### Sprint 4 - First-Person Camera

**Objective:** Implement the PlayerCamera with mouse look, sensitivity settings, and FOV.

**Inputs:** Master Architecture §10.

**Outputs:** Smooth mouse-look camera with configurable sensitivity, proper pitch clamping.

**Files Created:**
- `scenes/player/PlayerCamera.tscn` (Camera3D with script)
- `scripts/player/PlayerCamera.gd`

**Files Modified:** None

**Backend Changes:**
- PlayerCamera.gd:
  - Yaw rotation on parent (Player body), pitch on camera itself
  - Sensitivity read from SaveManager at startup
  - Mouse capture on game start, release on pause/Esc
  - Pitch clamped to +/- 89 degrees
  - apply_settings() method for runtime sensitivity changes

**Acceptance Criteria:**
- Mouse look works in both X and Y axes
- Pitch is clamped to +/- 89 degrees (no flipping)
- Sensitivity settings are read from SaveManager
- Mouse is captured (hidden + confined) when game starts
- Mouse is released when paused or window loses focus

**Manual Testing:**
1. Run the game, move mouse - camera should rotate smoothly
2. Look straight up/down - should stop at 89 degrees
3. Change sensitivity in SaveManager - reload, verify new sensitivity
4. Press Esc - mouse should be released

**Definition of Done:** Camera works correctly with all features, no gimbal lock, sensitivity is configurable.

**Estimated Time:** 60 minutes

**Dependencies:** Sprint 1, Sprint 3

---

### Sprint 5 - Basic Movement

**Objective:** Implement the Player (CharacterBody3D), MovementController, and a basic ground movement module (walk + gravity).

**Inputs:** Master Architecture §9, Gameplay Systems §1.2, §1.5.

**Outputs:** Player can walk around a flat plane with WASD, jump, and fall under gravity.

**Files Created:**
- `scenes/player/Player.tscn` (CharacterBody3D)
- `scripts/player/Player.gd`
- `scripts/movement/MovementController.gd`
- `scripts/movement/modules/MovementModule.gd` (base class)
- `scripts/movement/modules/GroundMovement.gd`
- `scripts/movement/modules/Gravity.gd`

**Files Modified:**
- `scripts/managers/TickManager.gd` (ensure 100Hz, or verify project settings)
- `project.godot` (verify physics_fps=100)

**Backend Changes:**
- Player.gd: CharacterBody3D with _ready() setup; references MovementController child
- MovementController.gd:
  - Owns _physics_process(delta)
  - Reads InputState from InputManager
  - Calls GroundMovement and Gravity modules
  - Calls owner.move_and_slide() at end
  - MovementConfig resource reference (@export)
- GroundMovement.gd: apply_ground_acceleration() using Equation 1.2 from Gameplay Systems
- Gravity.gd: apply_gravity() using Equation 1.5
- MovementModule.gd: base class with init(), process(), enabled_in_state()

**Resources Created:**
- `resources/movement/default.tres` (MovementConfig with default values)

**Acceptance Criteria:**
- Player moves in WASD direction relative to camera
- Player falls under gravity when walking off a ledge
- Player velocity is capped at walk_speed (320)
- Movement is frame-rate independent (test at 60 vs 360 FPS)
- Physics runs at 100Hz consistently

**Manual Testing:**
1. Create a simple flat plane + walls in a test map
2. Walk around - verify WASD moves correctly
3. Walk off a ledge - verify fall under gravity
4. Check `Engine.get_physics_frames_per_second()` = 100 in output

**Definition of Done:** Player walks, jumps (stub impulse), falls, and lands. Physics runs at 100Hz. No crashes.

**Estimated Time:** 120 minutes

**Dependencies:** Sprint 2, Sprint 3, Sprint 4

---

## Phase 2: Movement Engine (Sprints 6-12)

The movement engine phase implements all core physics: ground movement, jumping, bunny hopping, air strafing, and surfing.

### Sprint 6 - Ground Physics

**Objective:** Implement full ground physics: acceleration, friction, and max speed clamping.

**Inputs:** Gameplay Systems §1.2 (Ground Acceleration), §1.3 (Ground Friction).

**Outputs:** Player accelerates toward walk speed, decelerates with friction, and stops cleanly.

**Files Created:**
- `scripts/movement/modules/Friction.gd`
- `scripts/movement/modules/Velocity.gd`

**Files Modified:**
- `scripts/movement/MovementController.gd` (wire up Friction + Velocity modules)
- `scripts/movement/modules/GroundMovement.gd` (refine ground acceleration using friction module)

**Acceptance Criteria:**
- Player accelerates smoothly to walk_speed (320 u/s) when holding W
- Player decelerates to a stop within 0.1-0.2s when input is released
- Ground friction applies with stop_speed behavior (clean stop at low speed)
- Player cannot exceed walk_speed through ground movement alone

**Manual Testing:**
1. Hold W - use debug speed display to verify acceleration curve (should reach 320 in ~0.5s)
2. Release W - verify clean stop in ~0.2s
3. Strafe (A/D) on ground - verify no speed gain

**Definition of Done:** Ground movement feels solid, friction is correct, speed clamp works.

**Estimated Time:** 60 minutes

**Dependencies:** Sprint 5

---

### Sprint 7 - Jumping

**Objective:** Implement the Jump module with impulse, coyote time, and ground detection.

**Inputs:** Gameplay Systems §2.3 (Coyote Time), §2.4 (Jump Impulse).

**Outputs:** Player can jump, has coyote time, and cannot double-jump (MVP).

**Files Created:**
- `scripts/movement/modules/Jump.gd`
- `scripts/movement/modules/Collision.gd` (ground detection)

**Files Modified:**
- `scripts/movement/MovementController.gd` (set movement state based on Collision module)
- `scripts/movement/modules/GroundMovement.gd` (check is_on_floor via Collision module)
- `resources/movement/default.tres` (add jump_impulse, coyote_time_ms, max_jump_height)

**Backend Changes:**
- Jump.gd: coyote_timer, apply_jump_impulse(), check jump conditions
- Collision.gd: is_on_floor() wrapper, get_floor_normal(), slope angle calculation
- MovementController: sets MovementState based on Collision module output

**Acceptance Criteria:**
- Player can jump when on ground (v_y = jump_impulse = 300)
- Coyote time: jump works for 50ms after leaving the ground
- No double jump (second jump in air does nothing)
- Landing resets coyote timer

**Manual Testing:**
1. Walk and press jump - should go up ~37 units (300/800 * gravity)
2. Walk off ledge, press jump within 50ms - should still jump
3. Try to double-jump in air - should not work

**Definition of Done:** Jumping with coyote time works, no double jump, feels responsive.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 5, Sprint 6

---

### Sprint 8 - Bunny Hopping

**Objective:** Implement the BunnyHop module with jump buffering, friction skip on landing, and momentum preservation.

**Inputs:** Gameplay Systems §2 (Bunny Hop Implementation).

**Outputs:** Player can preserve and build speed through bunny hopping.

**Files Created:**
- `scripts/movement/modules/BunnyHop.gd`

**Files Modified:**
- `scripts/movement/MovementController.gd` (wire up BunnyHop, add friction_override)
- `scripts/movement/modules/Friction.gd` (respect friction_override)
- `resources/movement/default.tres` (add jump_buffer_ms, friction_override_factor)

**Backend Changes:**
- BunnyHop.gd:
  - jump_buffer_timer counting down from jump_buffer_ms
  - on_landing() callback: check buffer, apply friction override, fire jump
  - total_jumps counter for stats
- MovementController: friction_override property (default 1.0, set by BunnyHop to 0.1 on buffered land)
- Friction.gd: multiply friction by friction_override

**Acceptance Criteria:**
- Player can maintain speed through consecutive bhopped landings
- Landing + immediate jump preserves ~95%+ of horizontal velocity
- If jump is pressed within 50ms of landing, buffered jump fires automatically
- If landing without buffer, full friction applies (speed drops)

**Manual Testing:**
1. Run forward, jump, land, jump immediately - verify speed maintained
2. Time a jump slightly late (60ms after landing) - verify speed drops (friction applies)
3. Spam jump while running - verify you don't lose speed

**Definition of Done:** Bhopping preserves momentum, jump buffer works, friction skip feels right.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 7

---

### Sprint 9 - Air Strafing

**Objective:** Implement the AirMovement module with air acceleration and strafe-based speed gain.

**Inputs:** Gameplay Systems §3 (Air Acceleration & Strafing).

**Outputs:** Player can gain speed in air by strafing with W+A/D + mouse turn.

**Files Created:**
- `scripts/movement/modules/AirMovement.gd`

**Files Modified:**
- `scripts/movement/MovementController.gd` (set AIR state, call AirMovement)
- `scripts/movement/modules/MovementModule.gd` (add on_takeoff(), on_landing() callbacks)
- `resources/movement/default.tres` (add air_accel, air_speed_cap)

**Backend Changes:**
- AirMovement.gd:
  - compute_air_wish_dir() combining WASD + camera basis vectors
  - apply_air_acceleration() using Equation 1.4 (with air_speed_cap)
  - Only runs when MovementState == AIR
- MovementController: detects AIR state (not on floor AND not surf), calls AirMovement

**Acceptance Criteria:**
- In air, holding W+A and turning mouse left gains speed
- In air, holding W+D and turning mouse right gains speed
- Pure W in air does not gain significant speed
- Speed is capped by air_speed_cap mechanics (harder to gain above 30 u/s)
- Air strafing works at 100Hz tick rate

**Manual Testing:**
1. Jump in air, hold W+A, turn mouse left - watch speed increase (debug display)
2. Try W+D + mouse right - should gain speed in opposite direction
3. Try pure W in air - speed should not increase significantly

**Definition of Done:** Air strafing gains speed, optimal angles work, no speed gain from pure forward.

**Estimated Time:** 120 minutes

**Dependencies:** Sprint 7, Sprint 8

---

### Sprint 10 - Surfing

**Objective:** Implement the Surf module with ramp detection, plane projection, and gravity conversion.

**Inputs:** Gameplay Systems §4 (Surfing), §5 (Ramp Calculations).

**Outputs:** Player can surf on ramp geometry, building speed.

**Files Created:**
- `scripts/movement/modules/Surf.gd`

**Files Modified:**
- `scripts/movement/MovementController.gd` (set SURF state, wire up Surf module)
- `resources/movement/default.tres` (add surf_angle_min_deg, surf_friction, surf_push, surf_exit_boost)

**Backend Changes:**
- Surf.gd:
  - is_surf_normal(normal): checks floor_normal.dot(UP) < cos(surf_angle_min_deg)
  - process_surf(velocity, normal, delta): projects velocity to ramp plane, applies surf friction
  - anti_stuck(velocity, normal): pushes player off ramp if speed too low
  - on_ramp_exit(velocity, normal): small downward push for clean exit
- MovementController: when on_floor and is_surf_normal(floor_normal) → state = SURF
- Friction.gd: reduced friction when in SURF state

**Acceptance Criteria:**
- Player slides on ramps steeper than 45 degrees
- Velocity is projected onto the ramp plane (no sticking into ramp)
- Gravity pulls player along ramp (speed gain from steeper angles)
- Smooth transition from ramp to air (no velocity loss)
- Smooth transition from air to ramp (velocity projected to new plane)
- Anti-stuck prevents low-speed cling

**Manual Testing:**
1. Create a 45+ degree ramp in test map
2. Run onto ramp - verify sliding (no sticking)
3. Observe speed increase from gravity conversion
4. Jump off ramp - verify smooth transition to air
5. Land on ramp at speed - verify smooth transition to surf

**Definition of Done:** Surfing feels like Source/CS, ramps are slideable, transitions are smooth.

**Estimated Time:** 120 minutes

**Dependencies:** Sprint 9

---

### Sprint 11 - Physics Tuning

**Objective:** Fine-tune all movement parameters for good "feel" and verify 100Hz determinism.

**Inputs:** Gameplay Systems §1 (all equations), Master Architecture §8 (Physics Engine).

**Outputs:** Movement parameters in `resources/movement/default.tres` are balanced. 100Hz tick is stable.

**Files Modified:**
- `resources/movement/default.tres` (tune values)
- `scripts/movement/MovementController.gd` (adjust state transitions)
- `scripts/movement/modules/*.gd` (minor adjustments based on feel)

**Acceptance Criteria:**
- Walk speed reaches 320 u/s in ~0.5s (not too slow, not too twitchy)
- Jump feels like ~0.45s air time (300 impulse, 800 gravity)
- Bhopping maintains speed with 50ms buffer window
- Air strafing gains ~100-150 u/s over 1s of optimal strafing
- Surf ramp at 50 degrees builds speed consistently
- 100Hz tick verified (get_physics_frames_per_second() = 100)
- Frame-rate independent (movement identical at 60Hz vs 360Hz render)

**Manual Testing:**
1. Walk forward - verify acceleration curve looks right
2. Jump and count ~45 ticks in air (450ms)
3. Bhop across flat ground - verify speed holds
4. Air strafe in a circle - verify speed gain
5. Surf a ramp - verify speed builds

**Definition of Done:** Movement feels great, parameters are balanced, 100Hz is stable.

**Estimated Time:** 90 minutes

**Dependencies:** Sprints 6-10

---

### Sprint 12 - Movement Debug Tools

**Objective:** Implement debug overlay showing velocity vectors, movement state, and key metrics.

**Inputs:** Master Architecture §7.4 (DebugOverlay), Gameplay Systems §13 (Speedometer).

**Outputs:** Toggleable debug overlay with live movement data.

**Files Created:**
- `scripts/debug/MovementDebugger.gd`
- `scenes/player/DebugOverlay.tscn`
- `scenes/player/VelocityVector.tscn` (ImmediateMesh for vectors)

**Files Modified:**
- `scripts/managers/InputManager.gd` (add toggle_debug action)
- `scripts/managers/UIManager.gd` (forward debug toggle to player)

**Backend Changes:**
- MovementDebugger.gd: draws velocity vector, floor normal, state label
- DebugOverlay.tscn: contains ImmediateMesh nodes + Label3D
- InputManager: F1 toggles debug mode

**Acceptance Criteria:**
- F1 toggles debug overlay on/off
- Overlay shows: current speed (u/s), movement state (GROUND/AIR/SURF), velocity vector (arrow), floor normal
- Debug mode is saved in settings and persists
- Drawing updates at 100Hz (real-time)

**Manual Testing:**
1. Press F1 - debug overlay appears
2. Move around - verify all metrics update live
3. Press F1 again - overlay disappears
4. Restart game - verify debug state persists

**Definition of Done:** Debug overlay shows all key metrics, toggles work, persists across sessions.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 5, Sprint 11

---

## Phase 3: Gameplay (Sprints 13-18)

Gameplay systems are layered on top of the movement engine: timer, checkpoints, map loading, HUD, save system, and ghost recording.

### Sprint 13 - Timer System

**Objective:** Implement the race timer with start/finish logic, PB tracking, and state machine.

**Inputs:** Gameplay Systems §8 (Time Trial Logic).

**Outputs:** Timer starts on movement, stops on finish, tracks PBs.

**Files Created:**
- `scripts/game/TimerSystem.gd`
- `scenes/world/StartTrigger.tscn`
- `scenes/world/FinishTrigger.tscn`

**Files Modified:**
- `scripts/managers/GameManager.gd` (add RaceState, timer integration)

**Acceptance Criteria:**
- Timer starts when player leaves the start platform (body_exited on StartTrigger)
- Timer stops when player crosses finish line (body_entered on FinishTrigger)
- First completion sets the initial PB
- Subsequent completions update PB if faster
- Timer displays in 0:00.000 format
- Pause menu stops the timer (does not increment during pause)

**Manual Testing:**
1. Start on platform, walk off - timer starts
2. Run to finish - timer stops, PB recorded
3. Restart, beat the time - PB updates
4. Pause mid-race - timer freezes

**Definition of Done:** Timer starts/stops correctly, PBs tracked, display format correct.

**Estimated Time:** 60 minutes

**Dependencies:** Sprint 2, Sprint 5

---

### Sprint 14 - Checkpoints

**Objective:** Implement checkpoint trigger volumes with respawn logic and split timing.

**Inputs:** Gameplay Systems §6 (Checkpoint System).

**Outputs:** Checkpoints placed in maps, respawn at last checkpoint, splits recorded.

**Files Created:**
- `scripts/game/Checkpoint.gd`
- `scenes/checkpoints/Checkpoint.tscn`
- `scenes/checkpoints/RespawnPoint.tscn`

**Files Modified:**
- `scripts/managers/GameManager.gd` (add checkpoint tracking, respawn logic)
- `scripts/managers/UIManager.gd` (update checkpoint display)

**Acceptance Criteria:**
- Checkpoint triggers update respawn position
- Pressing Restart (R) respawns at the last checkpoint
- Checkpoint splits are recorded (time at each checkpoint)
- UIManager shows "Checkpoint N/M" on reach
- Falling below the map triggers respawn at last checkpoint (kill plane)

**Manual Testing:**
1. Place 2 checkpoints in test map
2. Reach checkpoint 1 - verify respawn point updates
3. Fall off map - verify respawns at checkpoint 1
4. Reach finish - verify splits are recorded

**Definition of Done:** Checkpoints work, respawn works, splits recorded, kill plane works.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 13

---

### Sprint 15 - Map Loading

**Objective:** Implement the LevelLoader with async map loading, map discovery, and MapMetadata support.

**Inputs:** Master Architecture §7.8 (LevelLoader), Gameplay Systems §10 (Map Metadata).

**Outputs:** LevelLoader can discover and load maps from scenes/maps/.

**Files Created:**
- `scripts/core/MapMetadata.gd` (resource class)
- `resources/maps/tutorial_metadata.tres`

**Files Modified:**
- `scripts/managers/LevelLoader.gd` (replace stub with full implementation)

**Backend Changes:**
- MapMetadata.gd: map_id, display_name, author, difficulty, tags, movement_config_path, thumbnail
- LevelLoader.gd:
  - discover_maps(): scans scenes/maps/ for .tscn with MapMetadata
  - load_map(path): async load, add to CurrentMap node, unload previous
  - unload_current(): queue_free previous map
  - current_map reference

**Acceptance Criteria:**
- LevelLoader.discover_maps() finds all .tscn files in scenes/maps/
- Each map's MapMetadata is loaded and accessible
- load_map() works async (no frame hitch)
- Previous map is properly freed (no memory leak)
- MovementConfig from map metadata is applied to MovementController

**Manual Testing:**
1. Create a simple "test_map.tscn" with some geometry
2. Attach MapMetadata as node metadata
3. Run LevelLoader.discover_maps() - verify map appears in list
4. load_map("test_map.tscn") - verify it loads without error

**Definition of Done:** Maps are discovered, loaded async, metadata is accessible, old maps freed.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 1, Sprint 6

---

### Sprint 16 - HUD

**Objective:** Implement the full HUD: speed, timer, PB, checkpoint counter, FPS, and debug overlay.

**Inputs:** Master Architecture §12 (UI Architecture), Gameplay Systems §13 (Speedometer).

**Files Created:**
- `scenes/ui/HUD.tscn`
- `scripts/ui/HUDController.gd`

**Files Modified:**
- `scripts/managers/UIManager.gd` (add HUD update methods)
- `scripts/managers/GameManager.gd` (emit signals for HUD updates)

**Backend Changes:**
- HUDController.gd: subscribes to SignalBus for speed, timer, checkpoint, race state
- HUD.tscn: CanvasLayer with SpeedLabel, TimerLabel, PRLabel, CheckpointLabel, FPSLabel
- Speed throttled to 30 FPS update (not 100Hz) to avoid UI jank
- Speed tiers with color coding (gray/white/yellow/orange/red)

**Acceptance Criteria:**
- Speed displays in "XXX u/s" with color-coded tiers
- Timer displays in 0:00.000 format, starts/stops with race
- PB time shows in HUD (loaded from SaveManager)
- Checkpoint counter shows "Checkpoint N/M"
- FPS counter shows real-time frames per second
- Debug overlay (speed/tier) appears when debug mode is on

**Manual Testing:**
1. Run a map - verify all 5 HUD elements are visible
2. Move around - verify speed updates with color tiers
3. Start/finish a race - verify timer and PB update
4. Check FPS counter - verify it's a real-time reading

**Definition of Done:** All HUD elements functional, update correctly via signals, color tiers work.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 13, Sprint 14, Sprint 17

---

### Sprint 17 - Save System

**Objective:** Implement persistence for settings, personal bests, and unlocks using .cfg and .tres files.

**Inputs:** Master Architecture §14 (Save System), Gameplay Systems §14 (Settings), §8.2 (PB tracking).

**Files Created:**
- `scripts/save/SaveManager.gd` (full implementation)
- `scripts/save/SettingsResource.gd`
- `scripts/save/RecordsResource.gd`
- `scripts/save/LeaderboardEntry.gd`

**Files Modified:**
- `scripts/managers/SaveManager.gd` (replace stub)
- `resources/movement/default.tres` (ensure loadable by SaveManager for ghost replay)

**Backend Changes:**
- SaveManager:
  - load_settings() / save_settings(): reads/writes user://save/settings.cfg
  - get_pb(map_name) / save_pb(map_name, time): manages RecordsResource.tres
  - load_ghost(map_name) / save_ghost(map_name, replay): manages .tres replay files
  - get_setting(key) / set_setting(key, value): typed accessors
- SettingsResource.gd: typed wrapper for settings.cfg with defaults
- RecordsResource.gd: Dictionary of map_name -> MapRecord
- First-run detection: create default settings on fresh install

**Acceptance Criteria:**
- Settings persist across game restarts
- PBs persist across restarts
- First run creates default settings
- Settings can be loaded before any user modification
- Ghost files are saved to and loaded from user://ghosts/

**Manual Testing:**
1. Change mouse sensitivity in settings
2. Close and restart the game - verify sensitivity persists
3. Run a map, get a PB
4. Restart, re-run the map - verify PB is displayed in HUD
5. Check user://save/ directory exists with settings.cfg

**Definition of Done:** Settings and PBs persist, first-run defaults work, ghost save/load functional.

**Estimated Time:** 90 minutes

**Dependencies:** Sprint 2, Sprint 13

---

### Sprint 18 - Ghost Recording

**Objective:** Implement ghost replay recording (PB ghost) with input+state capture, serialization, and playback.

**Inputs:** Gameplay Systems §7 (Ghost Replay Architecture), §12 (Replay Serialization).

**Files Created:**
- `scripts/game/GhostRecorder.gd`
- `scripts/game/GhostPlayer.gd`
- `scripts/movement/ReplayFrame.gd`
- `scenes/props/GhostModel.tscn`

**Files Modified:**
- `scripts/managers/GameManager.gd` (start/stop ghost recording on race start/finish)

**Backend Changes:**
- ReplayFrame.gd: Resource with tick, position, velocity, rotation, input_state, movement_state
- GhostRecorder.gd:
  - start_recording(): clears frames, sets is_recording=true
  - record_frame(tick, player): captures Player state into ReplayFrame
  - stop_recording(): calls SaveManager.save_ghost()
  - Called from MovementController each tick (or GameManager)
- GhostPlayer.gd:
  - load_replay(path): loads .tres replay file
  - _physics_process: sets ghost position/rotation from frame data
  - Visual: translucent StandardMaterial3D with color tint
- GhostModel.tscn: simple capsule/shape with translucent material

**Acceptance Criteria:**
- Ghost starts recording when race starts
- Ghost records position + velocity + rotation each tick (100Hz)
- Ghost saves to user://ghosts/{map}_pb.tres when PB is achieved
- Ghost loads and plays back from saved file on next race
- Ghost is visually distinct (translucent, colored)
- Ghost playback is in sync with live player

**Manual Testing:**
1. Start a race - ghost recording begins
2. Finish with a time - ghost saves
3. Restart - ghost loads and plays back
4. Beat the ghost time - new ghost saves
5. Verify ghost is translucent and colored differently

**Definition of Done:** Ghosts record, save, load, and play back correctly with visual distinction.

**Estimated Time:** 120 minutes

**Dependencies:** Sprint 13, Sprint 15, Sprint 17

---


## Phase 4: Content (Sprints 19-23)

The content phase builds the actual gameplay maps that use the movement engine.

### Sprint 19 - Tutorial Map

**Objective:** Create a tutorial map that introduces bunny hopping, air strafing, and surfing step by step.

**Inputs:** Gameplay Systems §4 (Surfing), §2 (Bunny Hop), §3 (Air Strafing).

**Outputs:** `scenes/maps/tutorial.tscn` with teaching geometry, signposting, and simple challenges.

**Files Created:**
- `scenes/maps/tutorial.tscn`
- `resources/maps/tutorial_metadata.tres`
- `scripts/game/TutorialSign.gd` (interactive signs with instructions)

**Acceptance Criteria:**
- Map teaches bhop: flat section with "jump on landing" instruction
- Map teaches air strafe: simple air section with "W+A + turn left" instruction
- Map teaches surf: 45 degree ramp with "hold forward, strafe to steer"
- Map ends with finish line
- Tutorial signs appear when player approaches
- Movement config is set to casual (more forgiving bhop window)

**Manual Testing:**
1. Play through the tutorial from start to finish
2. Verify each mechanic is introduced in order
3. Verify tutorial signs trigger on proximity
4. Verify finish line works

**Definition of Done:** New player can learn all 3 core mechanics from the tutorial.

**Estimated Time:** 120 minutes

**Dependencies:** Sprints 5-10, Sprint 15

---

### Sprint 20 - Beginner Map

**Objective:** Create a beginner-level time-trial map that combines basic bunny hopping and simple surf ramps.

**Inputs:** ideas.md "Game Modes: Time Trial".

**Outputs:** `scenes/maps/beginner.tscn` with a ~30s completion time.

**Files Created:**
- `scenes/maps/beginner.tscn`
- `resources/maps/beginner_metadata.tres`

**Acceptance Criteria:**
- Map requires bhop to maintain speed on flat sections
- Map includes 2-3 surf ramps of increasing angle (45-50 degrees)
- Map has 2-3 checkpoints
- Completion time is ~20-40 seconds for a skilled player
- No "cheap" routes or exploits

**Manual Testing:**
1. Complete the map with bhop only - verify it's possible
2. Complete with surf - verify speed builds on ramps
3. Fall off and respawn - verify checkpoint works
4. Time the completion - verify it's in the expected range

**Definition of Done:** Map is completable, fun, and appropriately challenging for beginners.

**Estimated Time:** 150 minutes

**Dependencies:** Sprint 19

---

### Sprint 21 - Intermediate Map

**Objective:** Create an intermediate map with complex bhop lines, mixed surf/bhop sequences, and tighter timings.

**Outputs:** `scenes/maps/intermediate.tscn` with ~60s completion time.

**Files Created:**
- `scenes/maps/intermediate.tscn`
- `resources/maps/intermediate_metadata.tres`

**Acceptance Criteria:**
- Map requires precise bhop chains (5+ consecutive hops)
- Map includes 45-60 degree surf ramps with speed building
- Map includes air strafe sections (gaining speed in air)
- Map has 4-5 checkpoints
- Completion time is ~45-75 seconds for a skilled player
- Optimal route requires both bhop and surf mastery

**Manual Testing:**
1. Complete the map - verify all sections are navigable
2. Time the optimal route - verify it's in range
3. Verify bhop chains are challenging but fair
4. Verify surf speed carries through transitions

**Definition of Done:** Map is challenging but fair, requires mixed technique mastery.

**Estimated Time:** 180 minutes

**Dependencies:** Sprint 20

---

### Sprint 22 - Advanced Map

**Objective:** Create an advanced map with high-speed surf sections, complex bhop lines, and tight execution requirements.

**Outputs:** `scenes/maps/advanced.tscn` with ~90s completion time.

**Files Created:**
- `scenes/maps/advanced.tscn`
- `resources/maps/advanced_metadata.tres`

**Acceptance Criteria:**
- Map includes 50-70 degree surf ramps (high speed)
- Map requires perfect bhop chains (10+ hops)
- Map includes ramp-to-ramp transitions (no ground contact)
- Map has 5-6 checkpoints
- Completion time is ~60-100 seconds for a skilled player
- Map pushes the movement engine to its limits

**Manual Testing:**
1. Complete the map with expert movement
2. Verify all speed is maintained through tight transitions
3. Time the optimal route
4. Verify no geometry exploits exist

**Definition of Done:** Map is extremely challenging, requires expert-level movement.

**Estimated Time:** 210 minutes

**Dependencies:** Sprint 21

---

### Sprint 23 - Challenge Maps

**Objective:** Create 2-3 small challenge maps that test specific movement skills (obstacle course, precision surf, speed run).

**Outputs:** `scenes/maps/challenge_*.tscn` (3 maps) with metadata.

**Files Created:**
- `scenes/maps/challenge_obstaclecourse.tscn`
- `scenes/maps/challenge_precision.tscn`
- `scenes/maps/challenge_speedrun.tscn`
- `resources/maps/challenge_*_metadata.tres` (3 files)

**Acceptance Criteria:**
- Obstacle course: moving walls, spinning platforms, jump puzzles
- Precision surf: tiny ramps, need perfect landing angles
- Speed run: single continuous bhop+surf line, as fast as possible
- Each map has unique movement_config if needed
- Each map is completable but very difficult

**Manual Testing:**
1. Complete each challenge map
2. Verify each tests a specific skill
3. Verify difficulty is appropriate for the label

**Definition of Done:** 3 challenge maps, each focused on a specific movement skill.

**Estimated Time:** 180 minutes

**Dependencies:** Sprint 22

---

## Phase 5: Polish & Release (Sprints 24-30)

The polish phase adds audio, visual effects, settings, optimization, Steam integration, and prepares for release.

### Sprint 24 - Audio

**Objective:** Implement audio system with footsteps, jump sounds, surf audio, music, and event triggers.

**Inputs:** Master Architecture §13 (Audio Architecture), Gameplay Systems §17 (Audio Triggers).

**Files Created:**
- `assets/audio/sfx/` (footsteps, jumps, surf, UI)
- `scripts/audio/AudioManager.gd` (full implementation)
- `configs/audio_presets.cfg`

**Files Modified:**
- `scripts/managers/AudioManager.gd` (replace stub)
- `scripts/managers/GameManager.gd` (connect race_finished to music change)

**Acceptance Criteria:**
- Footstep sounds play based on surface type and speed
- Jump/land sounds play with appropriate pitch volume scaling
- Surf loop plays with pitch scaling to speed
- Finish line sound plays on race complete
- Menu/UI sounds play on button interactions
- Background music plays in menus, stops during race
- Volume sliders in settings affect audio buses

**Manual Testing:**
1. Walk/run - verify footstep sounds
2. Jump and land hard - verify landing sound with volume scaling
3. Surf a ramp - verify surf loop with pitch change
4. Finish a race - verify finish sound + music change
5. Adjust volume in settings - verify audio responds

**Definition of Done:** Audio system fully functional, all events trigger appropriate sounds, volume controls work.

**Estimated Time:** 120 minutes

**Dependencies:** Sprint 17, Sprint 2

---

### Sprint 25 - Visual Effects

**Objective:** Implement visual effects: landing particles, speed trails, takeoff effects, and surf ramp feedback.

**Inputs:** Master Architecture §16 (Asset Pipeline), Gameplay Systems §17 (Audio Triggers - parallel concept for VFX).

**Files Created:**
- `assets/shaders/surf_ramp.gdshader` (color shift on surf)
- `assets/shaders/speed_trail.gdshader`
- `scenes/props/LandingEffect.tscn` (CPUParticles3D)
- `scenes/props/SpeedTrail.tscn`
- `scripts/debug/VisualEffects.gd`

**Files Modified:**
- `scripts/managers/UIManager.gd` (trigger VFX on events)
- `scripts/movement/modules/BunnyHop.gd` (emit on landing)
- `scripts/movement/modules/Surf.gd` (emit on surf enter/exit)

**Acceptance Criteria:**
- Particle effect on hard landing (scales with fall speed)
- Speed trail particles when horizontal speed > 600 u/s
- Surf ramp glows/shifts color when player is on it
- Takeoff effect (small puff) when player leaves ground
- All effects can be disabled via settings (performance option)

**Manual Testing:**
1. Land hard - verify particle effect
2. Build speed above 600 u/s - verify speed trail
3. Enter surf ramp - verify ramp feedback
4. Jump - verify takeoff effect
5. Disable VFX in settings - verify they don't appear

**Definition of Done:** All 4 VFX systems implemented, performance-togglable, look good.

**Estimated Time:** 150 minutes

**Dependencies:** Sprint 24, Sprint 12

---

### Sprint 26 - Settings Menu

**Objective:** Implement full settings menu with graphics, audio, input, and gameplay tabs.

**Inputs:** Master Architecture §15 (Configuration), Gameplay Systems §14 (Settings).

**Files Created:**
- `scenes/menus/SettingsMenu.tscn`
- `scripts/ui/SettingsMenu.gd`

**Files Modified:**
- `scripts/managers/SaveManager.gd` (add apply_settings_to_engine())
- `scripts/managers/UIManager.gd` (add show_menu("settings"))

**Acceptance Criteria:**
- Settings menu has 4 tabs: Graphics, Audio, Input, Gameplay
- Graphics tab: fullscreen, vsync, fps cap, resolution dropdown
- Audio tab: master/music/sfx volume sliders with live preview
- Input tab: shows current key bindings, rebinding via click
- Gameplay tab: tick rate, debug mode toggle, auto-save ghost toggle
- All changes are saved immediately to settings.cfg
- "Reset to Defaults" button restores factory settings
- "Back" button returns to previous menu

**Manual Testing:**
1. Open settings from pause menu
2. Change all settings across all 4 tabs
3. Verify changes take effect immediately (volume, fullscreen)
4. Close and restart - verify all settings persist
5. Click "Reset to Defaults" - verify all reset

**Definition of Done:** Full settings menu with all 4 tabs, live preview, persistence.

**Estimated Time:** 150 minutes

**Dependencies:** Sprint 17, Sprint 15, Sprint 24

---

### Sprint 27 - Optimization

**Objective:** Profile the game, identify bottlenecks, and optimize for 100Hz physics + high FPS rendering.

**Inputs:** Master Architecture §18 (Testing Strategy), §3 (Technical Stack).

**Outputs:** Frame timing analysis, optimized modules, interpolation for smooth rendering.

**Files Created:**
- `docs/performance_profile.md` (profiling results)
- `scripts/core/Interpolator.gd` (render interpolation between physics ticks)

**Files Modified:**
- `scripts/movement/MovementController.gd` (add interpolation)
- `scripts/movement/modules/*.gd` (optimize hot paths)
- `scenes/player/Player.tscn` (add Interpolator node)

**Acceptance Criteria:**
- Physics step (100Hz) consistently uses < 1.5ms
- Render FPS sustained at display refresh rate (144+ FPS on mid-range hardware)
- Interpolator provides smooth visual movement between 100Hz ticks
- Memory usage stable (no growth over 10 minutes of play)
- GUT tests still pass after optimization

**Manual Testing:**
1. Run profiler during intense surf session
2. Verify physics process time < 1.5ms
3. Verify render FPS at or above display refresh
4. Run for 10 minutes - verify no memory growth
5. Verify movement still looks smooth (interpolation working)

**Definition of Done:** Performance targets met, profiler data documented, no regressions.

**Estimated Time:** 120 minutes

**Dependencies:** Sprint 12, Sprint 11

---

### Sprint 28 - Steam Integration

**Objective:** Integrate SteamAPI for achievements, cloud saves, and leaderboards.

**Inputs:** Master Architecture §20.7 (Steam Features).

**Files Created:**
- `addons/steam/` (Steam integration addon)
- `scripts/managers/SteamManager.gd`
- `assets/audio/sfx/steam/` (achievement sounds)

**Files Modified:**
- `scripts/managers/SaveManager.gd` (add cloud sync hooks)
- `scripts/managers/GameManager.gd` (emit achievement events)

**Acceptance Criteria:**
- Steam client detected on startup (Windows)
- Achievements unlock for: First Jump, First BHop, First Surf, First PB, Beat 300 u/s, Beat 600 u/s
- Cloud saves sync settings and PBs on launch/exit
- Steam leaderboard submission on PB
- Steam leaderboard display in results menu
- Graceful degradation when Steam is not running

**Manual Testing:**
1. Launch with Steam running
2. Complete tutorial - verify "First Jump" achievement unlocks
3. Get a PB - verify cloud save + leaderboard upload
4. Close and restart - verify cloud sync restores PBs
5. Launch without Steam - verify game still works (degraded mode)

**Definition of Done:** Steam integration works, achievements/cloud/leaderboards functional, graceful fallback.

**Estimated Time:** 120 minutes

**Dependencies:** Sprint 17, Sprint 26

---

### Sprint 29 - Documentation & AGENTS.md

**Objective:** Write user-facing documentation, update AGENTS.md, and ensure all three docs are current.

**Inputs:** Existing docs/ folder.

**Files Created:**
- `docs/user_guide.md` (player-facing guide)
- `docs/changelog.md`

**Files Modified:**
- `AGENTS.md` (finalize for handoff)
- `docs/01_Master_Architecture.md` (version bump, changelog entry)
- `docs/02_Gameplay_Systems.md` (version bump, changelog entry)
- `docs/03_Sprint_Plan.md` (version bump, changelog entry)

**Acceptance Criteria:**
- User guide explains: installation, controls, movement basics, map navigation, settings
- AGENTS.md contains final sprint execution rules for AI agents
- All 3 architecture docs have consistent version numbers
- Changelog documents all completed features
- README.md links to the docs

**Manual Testing:**
1. Read through user guide as a new player - verify clarity
2. Read AGENTS.md - verify it would guide an AI agent correctly
3. Cross-reference sprint outputs with doc references - verify consistency

**Definition of Done:** All documentation complete and accurate, consistent across docs.

**Estimated Time:** 90 minutes

**Dependencies:** All previous sprints

---

### Sprint 30 - Version 1.0 Release

**Objective:** Final packaging, build, testing, and release preparation.

**Inputs:** Master Architecture §19 (Development Workflow).

**Files Created:**
- `exports/Velocity-1.0-win64.zip`
- `CHANGELOG.md`
- `docs/release_notes.md`

**Files Modified:**
- `project.godot` (version bump to 1.0)

**Acceptance Criteria:**
- `godot --headless --export-release "Windows Desktop" exports/Velocity-1.0-win64.exe` succeeds
- Exported build runs on a clean Windows machine (no Godot installed)
- All 5 maps are playable and completable
- Settings/PBs persist in the exported build
- No console errors on startup or gameplay
- Build size is reasonable (< 100MB)

**Manual Testing:**
1. Export the Windows build
2. Run on a machine without Godot installed
3. Complete the tutorial map start-to-finish
4. Verify PBs save/load correctly
5. Verify settings persist
6. Verify no errors in output log

**Definition of Done:** v1.0 build exported and tested, ready for distribution.

**Estimated Time:** 90 minutes

**Dependencies:** All previous sprints

---

## Sprint Summary Table

| Sprint | Phase | Objective | Est. Time |
|---|---|---|---|
| 1 | Foundation | Project setup & repository | 30 min |
| 2 | Foundation | Core architecture & managers | 90 min |
| 3 | Foundation | Input system | 90 min |
| 4 | Foundation | First-person camera | 60 min |
| 5 | Foundation | Basic movement | 120 min |
| 6 | Movement | Ground physics | 60 min |
| 7 | Movement | Jumping | 90 min |
| 8 | Movement | Bunny hopping | 90 min |
| 9 | Movement | Air strafing | 120 min |
| 10 | Movement | Surfing | 120 min |
| 11 | Movement | Physics tuning | 90 min |
| 12 | Movement | Movement debug tools | 90 min |
| 13 | Gameplay | Timer system | 60 min |
| 14 | Gameplay | Checkpoints | 90 min |
| 15 | Gameplay | Map loading | 90 min |
| 16 | Gameplay | HUD | 90 min |
| 17 | Gameplay | Save system | 90 min |
| 18 | Gameplay | Ghost recording | 120 min |
| 19 | Content | Tutorial map | 120 min |
| 20 | Content | Beginner map | 150 min |
| 21 | Content | Intermediate map | 180 min |
| 22 | Content | Advanced map | 210 min |
| 23 | Content | Challenge maps | 180 min |
| 24 | Polish | Audio | 120 min |
| 25 | Polish | Visual effects | 150 min |
| 26 | Polish | Settings menu | 150 min |
| 27 | Polish | Optimization | 120 min |
| 28 | Polish | Steam integration | 120 min |
| 29 | Polish | Documentation | 90 min |
| 30 | Release | Version 1.0 release | 90 min |
| | | **Total: 30 sprints** | **~56 hours** |

---

## Notes for AI Agents

### Sprint Order & Parallelization

- Sprints within the same phase cannot be parallelized (each builds on the previous).
- Sprints 19-23 (Content) can be partially parallelized since they share the same infrastructure — different maps can be built simultaneously by different agents.
- Sprint 28 (Steam integration) can be done in parallel with Sprints 24-27 (Polish) since it does not block them.
- Sprint 29 (Documentation) should be done after all other sprints are complete.

### Key Dependencies

```
Sprint 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12
                                          |
                                          +----------------> 13 -> 14 -> 15 -> 16 -> 17 -> 18
                                                                                    |
                                                                                    +-> 19 -> 20 -> 21 -> 22 -> 23
                                                                                              |
                                                                                              +-> 24 -> 25 -> 26 -> 27 -> 28 -> 29 -> 30
```

- Sprint 16 (HUD) depends on Sprint 17 (Save System) for PB display.
- Sprint 18 (Ghost) depends on Sprint 17 for ghost file storage.
- Sprint 26 (Settings) depends on Sprint 24 (Audio) and Sprint 28 (Steam).

### Acceptance Criteria

- Every sprint's acceptance criteria MUST pass before marking the sprint done.
- Manual testing steps are not optional — run them every time.
- Do not skip or "stub out" acceptance criteria for velocity. Stub only non-critical future features explicitly marked as "future."

### File Discipline

- Modify ONLY files listed in the sprint. If you must touch an extra file (e.g., adding a parameter to MovementConfig), add a note and keep the change minimal.
- Always create resources (.tres) by instantiating the .gd script in the editor or via `Resource.new()` + `ResourceSaver.save()`, never by hand-editing the .tres text.

*This is Document 3 of 3. For architecture, see `docs/01_Master_Architecture.md`. For implementation details, see `docs/02_Gameplay_Systems.md`.

(c) 2026 Velocity Engine - Development Architecture

---

## Revision History

- **1.1 (Sprint 29):** Sprints 1-28 executed; notable deviations: Sprint 25 VFX coordinator lives in scripts/debug/, Sprint 27 uses Godot built-in physics interpolation instead of a hand-rolled interpolator (Interpolator.gd is the teleport guard), Sprint 28 ships Steam integration in local mode behind manager seams (activation deferred to release). Sprint 29 documentation pass; Sprint 30 release build remains.
- **1.0:** Initial authored version.
