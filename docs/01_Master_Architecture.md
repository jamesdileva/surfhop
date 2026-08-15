# Velocity Engine — Master Architecture

> **Version:** 1.0
> **Status:** Draft — Sprint 0 (Pre-MVP)
> **Audience:** Developers, AI coding agents, future contributors
> **Related:** See `docs/02_Gameplay_Systems.md` for movement mathematics and `docs/03_Sprint_Plan.md` for the sprint-by-sprint roadmap.

This document is the **technical reference** for the Velocity Engine and the game *Velocity*. It defines the engine-first architecture, the technology stack, the project layout, the high-level system decomposition, coding standards, the testing strategy, and the development workflow. Every sprint in `docs/03_Sprint_Plan.md` maps back to sections defined here.

---

## Table of Contents

1. Vision
2. Design Philosophy
3. Technical Stack
4. Overall Architecture
5. Folder Structure
6. Scene Hierarchy
7. Core Systems
8. Physics Engine
9. Player Movement Framework
10. Camera System
11. Input System
12. UI Architecture
13. Audio Architecture
14. Save System
15. Configuration
16. Asset Pipeline
17. Coding Standards
18. Testing Strategy
19. Development Workflow
20. Long-Term Extensibility
21. Responsibility Matrix
22. Notes for AI Agents

---

## 1. Vision

### Purpose

Velocity Engine is a reusable, modular movement engine built on Godot 4. The first game to ship on the engine is *Velocity* — a first-person movement game where players build and maintain speed through bunny hopping, air strafing, and ramp surfing to complete time-trial maps as fast as possible.

Think of the relationship as: **Unreal Engine → Fortnite**. The engine powers multiple movement games; each game is a thin layer on top.

### Project Names

| Role | Name |
|---|---|
| Engine | Velocity Engine |
| Game | Velocity |

### North Star

> **Movement is the game.** Every system exists to serve the feeling of speed.

### Design Goals

- Extremely responsive controls (input → visible change in ≤ 1–2 ticks)
- Deterministic movement (identical inputs produce identical results, frame-rate independent)
- Easy map creation (community mappers can build maps in Godot's editor with minimal scripting)
- Easy mechanic additions (new movement mechanics are drop-in modules)
- High FPS (render at display refresh rate; physics at a fixed 100 Hz)
- Low input latency (≤ 10 ms from input event to physics response)
- Community moddable (configs are resource-driven; maps are `.tscn` scenes)

---

## 2. Design Philosophy

### Engine-First, Game-Second

The project is structured as a general-purpose movement engine first. The game *Velocity* is one consumer. This means:

- Movement mechanics live in a **framework** layer (`scripts/movement/`) that has no knowledge of timers, scores, or maps.
- Game-specific systems (timer, checkpoints, finish triggers, PBs) live in the **game** layer and depend downward on the framework, never upward.
- Configuration is **resource-driven**: all tunable parameters (walk speed, acceleration, jump height, surf angle thresholds, etc.) are exposed via `.tres` resources so community mappers and modders can tweak them without touching code.

### One Responsibility Per Module

Each class, script, or component owns exactly one responsibility. The player character is *not* a single 800-line monolith. Instead, the `MovementController` delegates to modular components:

```
MovementController
├── GroundMovement     # Walking, ground acceleration & friction
├── AirMovement        # Air acceleration, wish-strafe logic
├── BunnyHop           # Jump buffering, friction skip on landing
├── Surf               # Ramp detection, plane projection, gravity conversion
├── Jump               # Impulse application, coyote time, jump grace
├── Gravity            # Gravity application & clamping
├── Friction           # Ground & air friction calculations
├── Collision          # Ground detection, slope handling, step-up
└── Velocity           # Speed limiting, vector storage
```

Each module is a self-contained GDScript class that exposes:

```gdscript
class_name BunnyHop extends MovementModule

func init(controller: MovementController) -> void
func process(input_state: InputState, delta: float) -> void
func enabled_in_state(state: MovementState) -> bool
```

### Resource-First Configuration

All tunable values are defined in `.tres` resource files (see [Section 15 — Configuration](#15-configuration)). Code reads from these resources at runtime. This makes the engine moddable and keeps magic numbers out of scripts.

### Determinism by Design

Movement runs on a fixed **100 Hz** physics tick. Rendering runs at the display's native refresh rate with interpolation between tick snapshots. This ensures:

- Identical movement on every machine, regardless of render FPS.
- Frame-rate-independent physics calculations.
- Ghost replays that reproduce frame-for-frame.
- Future multiplayer that can be synchronized via input broadcasting.

---

## 3. Technical Stack

### Stack Summary

| Layer | Technology | Justification |
|---|---|---|
| Engine | Godot 4.x | Lightweight, excellent 3D first-person support, no royalties, small download |
| Language | GDScript (primary) · C# (optional, future) | Easy to learn, tight Godot integration, fast iteration; C# modules available for perf-critical systems |
| Physics | Godot Physics | Adequate for movement games; deterministic when run at fixed tick |
| Rendering | Forward+ (Godot 4 default) | Good balance of performance and visual fidelity |
| Scripting | GDScript 2.0 | Built-in tool, debugger, profiler |
| Version Control | Git | Industry standard |
| Issue Tracking | GitHub Issues (or self-hosted) | Sprint-based development |
| CI/CD | GitHub Actions | Run linter, static analysis, and tests on push/PR |

### Project Settings

Key Godot project settings that must be locked:

| Setting | Value | Rationale |
|---|---|---|
| `physics/common/physics_fps` | `100` | Fixed 100 Hz tick for deterministic movement |
| `physics/3d/default_angular_damp` | `0.0` | We handle angular damping manually |
| `physics/3d/default_linear_damp` | `0.0` | We handle linear damping manually |
| `input/mouse/sensitivity` | Configured per-device | Read from settings at runtime |
| `rendering/quality/driver/driver_name` | `Forward+` | Consistent rendering path |
| `rendering/limits/fps` | `0` (unlimited) | Let rendering run at display refresh rate |
| `application/run/target_fps` | `0` (unlimited) | No render FPS cap |

### Platform Targets

| Priority | Platform | Status |
|---|---|---|
| 1 | Windows (x64) | MVP, fully supported |
| 2 | Linux (x64) | Post-MVP |
| 3 | macOS | Post-MVP |
| 4 | Steam Deck | Post-MVP (Linux target covers this) |

---

## 4. Overall Architecture

### Layered Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          GAME  (Velocity)                          │
│                                                                     │
│  GameManager • Timer • Checkpoints • Finish • Maps •              │
│  GhostRecorder • Leaderboards • Tutorial                          │
├─────────────────────────────────────────────────────────────────────┤
│                     MOVEMENT FRAMEWORK                              │
│                                                                     │
│  MovementController • MovementConfig • MovementModule             │
│  ├── GroundMovement  • AirMovement  • BunnyHop                    │
│  ├── Surf            • Jump         • Gravity                     │
│  ├── Friction        • Collision    • Velocity                     │
│  └── [Future: WallRun, Slide, Grapple, Dash]                        │
├─────────────────────────────────────────────────────────────────────┤
│                        VELOCITY ENGINE CORE                         │
│                                                                     │
│  TickManager • SignalBus • InputManager • CameraSystem            │
│  AudioManager • UIManager • SaveManager • LevelLoader              │
├─────────────────────────────────────────────────────────────────────┤
│                         GODOT 4.x RUNTIME                           │
│                                                                     │
│  Scene Tree • Rendering • Audio Server • Input Server             │
└─────────────────────────────────────────────────────────────────────┘
```

### Dependency Direction

```
  GAME  →  MOVEMENT FRAMEWORK  →  ENGINE CORE  →  GODOT
  (may use)        (depends on)       (depends on)     (runtime)
  ↑                ↑                  ↑
  Timers, maps    Movement modules   Tick, signals,
  use Framework   use Engine Core     input, audio,
  systems         systems            UI, save
```

No downward dependency may depend on an upward one. The Movement Framework never calls into game-specific systems.

---

## 5. Folder Structure

```
velocity/                          # Project root (Git repo)
├── project.godot                  # Godot project file
├── project.godot.lock             # (generated) — DO NOT commit
├── .gitignore                     # Excludes .godot/imports/, *.import, exports/
├── assets/
│   ├── audio/                     # SFX and music (imported to .ogg)
│   ├── fonts/                     # Custom fonts
│   ├── icons/                     # UI icons, app icon
│   ├── materials/                 # StandardMaterial3D / ShaderMaterial resources
│   ├── models/                    # GLB meshes
│   ├── shaders/                   # Custom shader files
│   ├── skyboxes/                  # Cubemaps / panoramas
│   └── textures/                  # PNGs (compressed on import)
├── scenes/
│   ├── player/                    # Player.tscn, camera, debug
│   │   └── MovementController.tscn
│   ├── ui/                        # HUD, menus, overlays
│   ├── world/                     # Environment, triggers, volumes
│   ├── maps/                      # Game maps (.tscn)
│   │   ├── tutorial.tscn
│   │   ├── beginner.tscn
│   │   └── intermediate.tscn
│   ├── menus/                     # Main menu, pause, settings
│   ├── checkpoints/               # Checkpoint trigger template
│   ├── finish/                    # Finish line trigger template
│   └── props/                     # Decorative props
├── scripts/
│   ├── managers/                  # Autoload singletons
│   │   ├── GameManager.gd
│   │   ├── InputManager.gd
│   │   ├── TickManager.gd
│   │   ├── AudioManager.gd
│   │   ├── UIManager.gd
│   │   ├── SaveManager.gd
│   │   ├── LevelLoader.gd
│   │   └── SignalBus.gd
│   ├── core/                      # Core engine utilities
│   │   ├── MovementConfig.gd      # Resource: tunable movement params
│   │   └── MovementState.gd       # Enum / helpers for movement states
│   ├── movement/                  # Movement framework modules
│   │   ├── MovementController.gd
│   │   ├── modules/               # Individual movement modules
│   │   │   ├── GroundMovement.gd
│   │   │   ├── AirMovement.gd
│   │   │   ├── BunnyHop.gd
│   │   │   ├── Surf.gd
│   │   │   ├── Jump.gd
│   │   │   ├── Gravity.gd
│   │   │   ├── Friction.gd
│   │   │   ├── Collision.gd
│   │   │   ├── Velocity.gd
│   │   │   └── MovementModule.gd  # Base class for all modules
│   │   └── InputState.gd          # Struct-like input state
│   ├── player/                    # Player-specific logic
│   │   ├── Player.gd              # CharacterBody3D script
│   │   └── PlayerCamera.gd
│   ├── ui/                        # HUD & menu scripts
│   ├── debug/                     # Debug overlay, velocity debugger
│   ├── save/                      # Save/load logic
│   └── game/                      # Game-specific systems
│       ├── Timer.gd
│       ├── Checkpoint.gd
│       ├── FinishTrigger.gd
│       ├── GhostRecorder.gd
│       └── GameMode.gd
├── resources/                     # .tres / .res resource instances
│   ├── movement/                  # MovementConfig.tres variants
│   ├── maps/                      # MapMetadata.tres per map
│   └── ui/                        # Theme resources, styles
├── configs/
│   ├── input_map.cfg              # Default key bindings
│   ├── settings_default.cfg       # Default game settings
│   └── movement_presets/          # .tres movement configs for maps
├── addons/                        # Godot plugins (community or dev)
├── tests/                         # GUT (Godot Unit Test) test suite
│   ├── unit/
│   └── integration/
├── docs/                          # Architecture documents (this file)
├── exports/                       # Build outputs (gitignored)
└── AGENTS.md                      # Sprint execution rules (like resmaker)
```

### `.gitignore` Targets

```
.godot/          # Godot's import cache and binary cache
*.import         # Imported asset cache files
export.cfg       # Export templates settings
export_preconfigured.cfg
.import/         # Asset import configs
exports/*.exe    # Build outputs
*.godot.import   # Additional cache files
```

---

## 6. Scene Hierarchy

### Main Scene (`scenes/world/main.tscn`)

```
Main (Node3D)
├── GameManager               (AutoLoad singleton)
├── InputManager              (AutoLoad singleton)
├── TickManager               (AutoLoad singleton)
├── SignalBus                 (AutoLoad singleton)
├── SaveManager               (AutoLoad singleton)
├── AudioManager              (AutoLoad singleton)
├── UIManager                 (AutoLoad singleton)
├── LevelLoader               (AutoLoad singleton)
├── CurrentMap                (Node3D — placeholder for loaded map)
│   └── [Map content loaded by LevelLoader]
├── Player (Player.tscn instance)
│   ├── MovementController    (Node3D — owns physics tick)
│   ├── PlayerCamera          (Camera3D)
│   ├── PlayerVisuals         (optional: first-person arms / viewmodel)
│   └── DebugOverlay          (optional: velocity vectors, state display)
├── HUD                       (Control — CanvasLayer)
└── [Dynamic: GhostReplay, DebugTools, Menus as needed]
```

### Player Scene (`scenes/player/Player.tscn`)

```
Player (CharacterBody3D, Player.gd)
├── MovementController (Node3D, MovementController.gd)
├── PlayerCamera (Camera3D, PlayerCamera.gd)
├── PlayerVisuals (Node3D, optional)
│   └── [first-person hands / weapon / viewmodel]
└── DebugOverlay (Node3D, optional)
    ├── VelocityVector (ImmediateMesh)
    ├── StateLabel (Label3D)
    └── CollisionDisplay (ImmediateMesh)
```

### Map Scene (`scenes/maps/tutorial.tscn`)

```
TutorialMap (Node3D, MapMetadata.tres attached)
├── Environment3D
├── DirectionalLight3D
├── SurfRamps (StaticBody3D with surf material)
├── Jumps (StaticBody3D — jump pads)
├── Checkpoints (Checkpoint trigger instances)
├── Finish (FinishTrigger)
├── RespawnPoint (Marker3D)
└── [Props, decorations, skybox]
```

### Key Design Decision: MovementController as Child

The `MovementController` is a child node of `Player` (CharacterBody3D) and owns the `_physics_process` tick. It:

1. Reads input from `InputManager`.
2. Delegates to modular movement components.
3. Writes the resulting `velocity` to `owner.velocity` (where `owner` is the `CharacterBody3D`).
4. Calls `owner.move_and_slide()` to handle collision resolution.

This keeps the `Player.gd` script thin — it mainly exists to hold the physics body and expose properties the `MovementController` needs.

---

## 7. Core Systems

### 7.1 Core Managers (AutoLoad Singletons)

These are project-wide singletons registered in Godot's **AutoLoad** settings. They have no dependency on any scene and are accessible from anywhere via their global name.

| Manager | Global Name | Responsibility | Key API |
|---|---|---|---|
| GameManager | `GameManager` | Game state machine, pause, restart, game over | `start_game()`, `pause()`, `restart()`, `end_game()` |
| InputManager | `InputManager` | Maps raw input events to logical actions; handles rebinding | `is_action_pressed(action)`, `get_movement_vector()`, `get_turn_vector()` |
| TickManager | `TickManager` | Fixed 100 Hz tick accumulator; fires `on_tick` signal | `register_tick_callback(cb)`, `tick` signal |
| SignalBus | `SignalBus` | Global event dispatch (decoupling) | `emit(event, payload)`, `connect(event, cb)` |
| SaveManager | `SaveManager` | Settings persistence, PB storage, ghost files | `save_settings()`, `load_settings()`, `save_pb()`, `load_pbs()` |
| AudioManager | `AudioManager` | Music playback, SFX management, volume control | `play_sfx(name)`, `play_music(track)`, `set_volume(bus, val)` |
| UIManager | `UIManager` | HUD updates, menu navigation, notifications | `show_menu(name)`, `update_hud(data)`, `show_toast(msg)` |
| LevelLoader | `LevelLoader` | Async map loading, unloading, transition effects | `load_map(path)`, `unload_current()`, `current_map` |

### 7.2 SignalBus — Global Event Dispatch

To avoid tight coupling, most cross-system communication goes through the `SignalBus`. Instead of `Player` directly calling `Timer.start()`, the flow is:

```gdscript
# When the player crosses the start trigger:
SignalBus.emit("race_started", {time: 0.0})

# Timer listens for this:
func _ready():
    SignalBus.connect("race_started", Callable(self, "_on_race_started"))

func _on_race_started(data):
    start_time = Time.get_ticks_msec()
```

Common signals emitted by the engine:

| Signal | Emitted By | Payload |
|---|---|---|
| `race_started` | StartTrigger | `{time: 0.0}` |
| `race_finished` | FinishTrigger | `{time: float, pb: bool}` |
| `checkpoint_reached` | Checkpoint | `{checkpoint_id: int, time: float}` |
| `player_landed` | BunnyHop | `{velocity: Vector3, fall_speed: float}` |
| `player_took_off` | Collision | `{velocity: Vector3, is_surfing: bool}` |
| `surf_entered` | Surf | `{plane_normal: Vector3, ramp_angle: float}` |
| `settings_changed` | SettingsMenu | `{key: String, value: Variant}` |
| `game_paused` | GameManager | `{paused: bool}` |

### 7.3 TickManager — Fixed Period System

The `TickManager` is the central heartbeat for physics. It uses an accumulator pattern to decouple the 100 Hz physics tick from the variable render FPS.

```gdscript
# TickManager.gd (simplified)
extends Node

const TICK_RATE := 100
const TICK_TIME := 1.0 / TICK_RATE  # 0.01 seconds

signal tick(delta)

var _accumulator := 0.0

func _physics_process(delta):
    _accumulator += delta
    while _accumulator >= TICK_TIME:
        emit_signal("tick", TICK_TIME)
        _accumulator -= TICK_TIME
```

All movement logic subscribes to the `tick` signal (or the `MovementController._physics_process` runs at physics FPS which is set to 100 in Project Settings). Since Godot's `_physics_process` already runs at the physics FPS, the simplest approach is:

- Set `physics_fps = 100` in Project Settings.
- Run all movement logic in `_physics_process`.
- This makes the TickManager optional for v1 — it becomes relevant when you need sub-tick scheduling or custom tick rates per system.

### 7.4 InputManager

The `InputManager` translates raw Godot input events into a structured `InputState` that the `MovementController` consumes. It handles:

- Keyboard (WASD, Space, Shift)
- Mouse movement (for air strafing and camera)
- Controller input (future)
- Input rebinding (persisted via SaveManager)
- Input buffering (e.g., jump buffer for bunny hopping)

The `InputState` struct (a plain GDScript class):

```gdscript
class_name InputState

var forward: float = 0.0    # -1 to 1 (S to W)
var right: float = 0.0      # -1 to 1 (A to D)
var jump_just_pressed: bool = false
var jump_held: bool = false
var crouch_held: bool = false
var sprint_held: bool = false
var mouse_delta: Vector2 = Vector2.ZERO
```

---

## 8. Physics Engine

### 8.1 Tick Rate & Determinism

| Parameter | Value | Rationale |
|---|---|---|
| Physics tick rate | **100 Hz** | Matches Quake/CS movement conventions; 10 ms per tick is imperceptible |
| Render tick rate | Display native (up to 360 Hz) | Smooth visuals, interpolated between physics snapshots |
| Gravity | 800 units/sec² (configurable) | Standard Quake gravity |
| Max fall speed | 1000 units/sec (configurable) | Terminal velocity clamp |

### 8.2 Physics Pipeline (Per Tick)

The MovementController executes the following pipeline every tick (100 times per second):

```
INPUT FRAME          PHYSICS TICK (100 Hz)
                     ↓
Read Input           InputManager.get_state() → InputState
                     ↓
Update State         GroundDetector → MovementState (GROUND | AIR | SURF)
                     ↓
Run Modules          [see §9.2 for module execution order]
                     ↓
Apply Gravity        Gravity module modifies velocity.y
                     ↓
Collision Move       owner.move_and_slide() → handles wall/slope collisions
                     ↓
Post-Process         BunnyHop: check landing for jump buffer
                     ↓
Emit Signals         player_landed / player_took_off / surf_entered
                     ↓
Update HUD           Speed, state, timers
                     ↓
Record Ghost         Capture input + position for replay
```

### 8.3 Movement Integration Approach

The `Player` node is a `CharacterBody3D`. The `MovementController` (child node) computes `velocity` each tick and calls `owner.move_and_slide()`.

The key insight: `CharacterBody3D.move_and_slide()` in Godot 4 already provides collision resolution, slope handling, and floor detection. We override the *velocity computation* with Quake-style equations while letting Godot handle the *collision response*.

### 8.4 Key Physics Parameters (Resource-Driven)

All values are defined in `MovementConfig.gd` resources (see [Section 15](#15-configuration)):

| Parameter | Default | Description |
|---|---|---|
| `walk_speed` | 320 | Max ground speed (units/sec) |
| `ground_accel` | 10 | Ground acceleration rate |
| `ground_friction` | 6 | Ground friction coefficient |
| `air_accel` | 10 | Air acceleration rate |
| `air_speed_cap` | 30 | Max air strafe speed (Quake cap) |
| `jump_impulse` | 300 | Upward velocity on jump (units/sec) |
| `gravity` | 800 | Downward acceleration (units/sec²) |
| `max_fall_speed` | 1000 | Terminal velocity clamp |
| `surf_angle_min` | 0.707 | Min floor normal dot(UP) to classify as surf (≈ 45°) |
| `bhop_buffer_ms` | 50 | Jump input buffer window for bunny hopping |
| `coyote_time_ms` | 50 | Grace period after leaving ground |
| `tick_rate` | 100 | Physics tick rate (Hz) |

> **Note:** These values match Quake/CS conventions. They live in `resources/movement/default.tres` and can be swapped per-map or per-game-mode.

### 8.5 Surface & Slope Detection

| Method | Purpose |
|---|---|
| `get_floor_normal()` | Returns the normal of the surface the `CharacterBody3D` is standing on |
| `is_on_floor()` | Returns true if the body has a valid floor (within `max_angle`) |
| `get_floor_angle()` | Returns the angle between floor normal and UP |
| `get_slide_collision()` | Per-collision contact info after `move_and_slide()` |

The `Surf` module uses `get_floor_normal()` to determine if the current surface is a surf ramp: if `floor_normal.dot(Vector3.UP) < cos(surf_angle_min)`, the surface is classified as a surf ramp.

---

## 9. Player Movement Framework

### 9.1 Architecture Overview

```
Player (CharacterBody3D)
  └── MovementController (Node3D, owns _physics_process)
        ├── InputState            # read from InputManager each tick
        ├── MovementState         # GROUND | AIR | SURF | JUMP
        ├── Modules[]             # ordered list of MovementModule instances
        ├── MovementConfig        # .tres resource with all parameters
        │
        Modules run in order:
        1. GroundMovement        # if GROUND: accelerate, apply friction
        2. Gravity               # always: apply gravity & clamp fall
        3. AirMovement           # if AIR: air accelerate (strafe logic)
        4. Surf                  # if SURF: project velocity to ramp plane
        5. Jump                  # if jump_buffer: apply impulse
        6. BunnyHop              # post-move: check landing, set up next buffer
        7. Velocity              # clamp speed tiers, limit max
        8. Collision            # floor checks, step-up (via move_and_slide)
```

### 9.2 Module Execution Order (Per Tick)

| Step | Module | Runs When | Modifies |
|---|---|---|---|
| 1 | GroundMovement | State == GROUND | Horizontal velocity (accelerate toward wishdir) |
| 2 | Gravity | Always | Vertical velocity (v.y -= g·dt) |
| 3 | AirMovement | State == AIR | Horizontal velocity (air accelerate / strafe) |
| 4 | Surf | State == SURF | Project velocity onto ramp plane; convert gravity to forward |
| 5 | Jump | `jump_buffer > 0` AND on floor | Upward velocity impulse |
| 6 | BunnyHop | Post-collision (landing detected) | Friction override, jump buffer setup |
| 7 | Velocity | Always (last) | Speed clamp, max velocity cap |

### 9.3 Movement States

```gdscript
enum MovementState {
    GROUND,   # Standing on walkable surface
    AIR,      # In the air (not surfing)
    SURF,     # On a surfable ramp
    JUMP,     # Transient (just took off)
    LAND,     # Transient (just landed)
    FALL      # Falling (fall_speed exceeds threshold)
}
```

State transitions are determined each tick by the `Collision` module:

```
GROUND → AIR     when !is_on_floor()
AIR → GROUND    when is_on_floor() + normal ≈ UP
AIR → SURF      when is_on_floor() + slope > threshold
ANY → JUMP      when jump_buffer fires and on_floor
JUMP → AIR      next tick after jump impulse
```

### 9.4 Movement Module Base Class

```gdscript
class_name MovementModule extends Resource

# Called once when added to the controller
func init(controller: MovementController) -> void

# Called every tick if enabled_in_state returns true
func process(input: InputState, delta: float) -> void

# Returns whether this module should run in the current state
func enabled_in_state(state: MovementState) -> bool:
    return true

# Optional: post-move callback (after move_and_slide)
func on_collision() -> void

# Optional: post-landing callback
func on_land(velocity: Vector3, fall_speed: float) -> void
```

### 9.5 How New Mechanics Are Added

To add wall-running (future):

1. Create `scripts/movement/modules/WallRun.gd` extending `MovementModule`.
2. Add it to the `MovementController.modules` array in `MovementController.tscn`.
3. Set its `enabled_in_state` to return true when `state == AIR && wall_normal_detected`.
4. The `WallRun` module modifies velocity in its `process()` method.
5. No changes needed to `GroundMovement`, `AirMovement`, or any other module.

This is the "engine-first" philosophy in action: the framework doesn't need to know what mechanics exist.

### 9.6 Velocity Storage

The `Velocity` module owns the canonical player velocity. It's a simple wrapper around `owner.velocity` with convenience methods:

```gdscript
class_name VelocityModule extends MovementModule

# Horizontal-only speed (ignoring vertical component)
func horizontal_speed() -> float:
    var h = Vector3(owner.velocity.x, 0, owner.velocity.z)
    return h.length()

# Set velocity with preservation options
func set_velocity(new_vel: Vector3, preserve_vertical: bool = false) -> void:
    if preserve_vertical:
        new_vel.y = owner.velocity.y
    owner.velocity = new_vel
```

---

## 10. Camera System

### 10.1 Architecture

```
PlayerCamera (Camera3D, PlayerCamera.gd)
├── Mouse look (pitch/yaw rotation)
├── Sensitivity settings (per-axis, configurable)
├── FOV settings (base FOV + dynamic FOV bump on speed)
├── Lean / recoil (future: camera shake on landings)
└── Interpolation (for 100Hz physics → smooth render)
```

### 10.2 Mouse Look

- **Yaw** rotates the `Player` (the physics body) around the Y axis.
- **Pitch** rotates the `PlayerCamera` around the X axis (clamped to ±89°).
- Mouse sensitivity is read from `SaveManager` settings at runtime.
- Mouse is captured (hidden + confined) when the game starts.

```gdscript
# PlayerCamera.gd (simplified)
func _input(event):
    if event is InputEventMouseMotion and mouse_captured:
        yaw -= event.relative.x * sensitivity_x
        pitch = clamp(pitch - event.relative.y * sensitivity_y, -89, 89)
        get_parent().rotation.y = yaw        # rotate Player body
        rotation.x = pitch                   # rotate camera
```

### 10.3 Camera Settings

| Setting | Type | Default |
|---|---|---|
| `mouse_sensitivity_x` | float | 1.0 |
| `mouse_sensitivity_y` | float | 1.0 |
| `invert_mouse_y` | bool | false |
| `base_fov` | float (degrees) | 90 |
| `fov_bump_enabled` | bool | true |
| `fov_bump_max_speed` | float | 1000 (units/sec) |
| `fov_bump_strength` | float | 20 (degrees of FOV increase at max speed) |

### 10.4 Dynamic FOV (Future)

When the player is moving fast (> 600 u/s), the FOV increases slightly to accentuate the feeling of speed. This is purely cosmetic.

---

## 11. Input System

### 11.1 Architecture

```
Keyboard/Mouse/Controller Hardware
  ↓
Godot Input Events (_input(event))
  ↓
InputManager (singleton)
  ↓
Action Map (res://configs/input_map.cfg)
  ↓
InputState (struct for MovementController)
  ↓
MovementController → Modules
```

### 11.2 Action Map

Defined in `configs/input_map.cfg` and mirrored in Godot's Project Settings → Input Map. The `InputManager` reads these at startup.

| Action | Default (Keyboard) | Default (Controller) |
|---|---|---|
| `move_forward` | W | Left Stick Up |
| `move_back` | S | Left Stick Down |
| `move_left` | A | Left Stick Left |
| `move_right` | D | Left Stick Right |
| `jump` | Space | South (A / Cross) |
| `duck` | Ctrl | Down (Left Stick click / L3) |
| `sprint` | Shift | Right Stick (L2/R2) |
| `pause` | Esc | Start |
| `restart` | R | Back |
| `next_checkpoint` | F | Right D-pad |
| `toggle_debug` | F1 | D-pad Up |

### 11.3 Input Buffering

The `InputManager` tracks a 50 ms buffer for the `jump` action. If jump is pressed within 50 ms of landing, the `BunnyHop` module consumes the buffered input and fires the jump immediately.

### 11.4 Rebinding

Settings menu writes the new bindings to `SaveManager` and persists them to `user://save/settings.cfg`. On startup, `InputManager._ready()` applies saved bindings over the defaults.

> **Note for AI agents:** Rebinding must update both the Godot InputMap (via `InputMap.action_erase_events` / `InputMap.action_add_event`) and the on-disk config. See `docs/02_Gameplay_Systems.md § Input Rebinding` for the full API.

---

## 12. UI Architecture

### 12.1 Hierarchy

```
UILayer (CanvasLayer, always-on-top)
├── HUD (Container)
│   ├── SpeedLabel        "532 u/s"
│   ├── TimerLabel        "0:00.000"
│   ├── PRLabel           "PB: 0:00.000"
│   ├── CheckpointLabel   "Checkpoint 2/3"
│   ├── FPSLabel          "FPS: 144"
│   └── DebugOverlay      (if debug mode)
├── Menus (Control)
│   ├── MainMenu
│   ├── PauseMenu
│   ├── SettingsMenu
│   ├── ResultsMenu
│   ├── CreditsMenu
│   └── MapSelect
└── Notifications (ToastContainer)
    ├── ToastMessage (transient, fades after 3s)
```

### 12.2 HUD Components

| Component | Updates From | Frequency |
|---|---|---|
| SpeedLabel | `VelocityModule.horizontal_speed()` | Every tick (100 Hz) → throttled to 30 Hz for display |
| TimerLabel | `GameManager.time` | Every tick |
| PRLabel | `SaveManager.load_pb()` | On race start/finish |
| CheckpointLabel | `Checkpoint` signals | On checkpoint reach |
| FPSLabel | `Engine.get_frames_per_second()` | Every second |
| DebugOverlay | `DebugModule` | When debug mode active |

### 12.3 UI Update Flow

```
MovementController (tick)
  → SignalBus.emit("velocity_updated", speed)
  → UIManager._on_velocity_updated(speed)
  → HUD.SpeedLabel.text = "%d u/s" % speed
```

The UIManager subscribes to `SignalBus` signals and dispatches updates to the appropriate HUD element. This keeps the movement framework decoupled from the UI.

---

## 13. Audio Architecture

### 13.1 Buses

Godot's audio bus layout:

| Bus | Purpose |
|---|---|
| Master | All audio output |
| Music | Background tracks |
| SFX | Sound effects (jump, land, surf) |
| UI | Menu clicks, beeps |
| Ambience | Skybox/environment sounds |

### 13.2 AudioManager API

| Method | Description |
|---|---|
| `play_sfx(name, position)` | Play a 3D positional SFX |
| `play_music(track)` | Play/load a music track (crossfade) |
| `set_volume(bus, linear_value)` | Set bus volume (0.0 – 1.0) |
| `set_sfx_pitch(name, pitch)` | Adjust pitch (e.g., surf whoosh scales with speed) |

### 13.3 SFX Inventory (MVP)

| Trigger | SFX |
|---|---|
| Player Jump | `sfx/jump.wav` |
| Player Land | `sfx/land_hard.wav` (volume scales with fall speed) |
| Surf Start | `sfx/surf_enter.wav` |
| Surf Slide | `sfx/surf_loop.wav` (pitch scales with speed) |
| Finish Line | `sfx/finish.wav` |
| Button Click | `sfx/ui_click.wav` |

---

## 14. Save System

### 14.1 Save Locations

| Type | Path | Format |
|---|---|---|
| Settings | `user://save/settings.cfg` | INI (.cfg) |
| PBs | `user://save/records.tres` | Godot Resource (.tres) |
| Ghosts | `user://ghosts/` | Binary (.tres) per replay |
| Unlocks | `user://save/unlocks.tres` | Godot Resource (.tres) |

### 14.2 Settings

Stored as key-value pairs in `settings.cfg`:

```ini
[input]
mouse_sensitivity_x = 1.2
mouse_sensitivity_y = 1.0
invert_mouse_y = false

[audio]
master_volume = 0.8
music_volume = 0.6
sfx_volume = 0.9

[graphics]
fullscreen = true
vsync = true
fps_cap = 0

[movement]
tick_rate = 100
show_debug = false
```

### 14.3 Records (PBs)

Each map records:

```gdscript
class_name MapRecord extends Resource
var map_name: String
var pb_time: float
var pb_date: int  # Unix timestamp
var best_speed: float
var jumps: int     # for stats
var completion_count: int
```

Multiple maps are stored in a single `RecordsResource.tres`:

```gdscript
class_name AllRecords extends Resource
var records: Dictionary  # map_name → MapRecord
```

---

## 15. Configuration

### 15.1 MovementConfig Resource

The most critical resource. Every tunable movement parameter lives here:

```gdscript
# MovementConfig.gd
class_name MovementConfig extends Resource

# Ground movement
@export var walk_speed: float = 320.0
@export var ground_accel: float = 10.0
@export var ground_friction: float = 6.0

# Air movement
@export var air_accel: float = 10.0
@export var air_speed_cap: float = 30.0
@export var air_cap_multiplier: float = 1.0

# Jumping
@export var jump_impulse: float = 300.0
@export var coyote_time_ms: float = 50.0
@export var jump_buffer_ms: float = 50.0

# Gravity
@export var gravity: float = 800.0
@export var max_fall_speed: float = 1000.0

# Surfing
@export var surf_angle_min_deg: float = 45.0
@export var surf_speed_multiplier: float = 1.0
@export var surf_preservation: float = 0.95

# Physics
@export var tick_rate: int = 100
@export var max_velocity: Vector3 = Vector3(4000, 1500, 4000)

# Debug
@export var draw_debug: bool = false
@export var enable_console: bool = false
```

### 15.2 Preset Management

Different game modes or community maps can load different `MovementConfig` instances:

```
resources/movement/
├── default.tres          # Standard Quake-style movement
├── competitive.tres      # Tightened parameters for ranked
├── casual.tres          # More forgiving (higher jump, more bhop leniency)
└── tutorial.tres        # Simplified for learning basics
```

The `LevelLoader` reads `MapMetadata.tres` from each map, which references the movement config preset.

### 15.3 Map Metadata

```gdscript
# MapMetadata.gd
class_name MapMetadata extends Resource

@export var display_name: String
@export var author: String
@export var difficulty: int          # 1-5 stars
@export var recommended_min_time: float
@export var movement_config_path: String = "res://resources/movement/default.tres"
@export var tags: PackedStringArray   # ["bhop", "surf", "air-strafe"]
@export var thumbnail_path: String
```

---

## 16. Asset Pipeline

### 16.1 Models

```
Blender (.blend / .fbx)
   ↓  "Export GLB"
GLB
   ↓  Godot import (import > 3D > glTF)
.glb.scene + .gltf.import
   ↓  Assign materials, add collision (Convex/Concave static body)
Scene in scenes/props/
```

**Guidelines:**
- Use low-poly geometry. The aesthetic is minimal (white geometry + neon edges + skybox).
- Collision should be convex or simplified trimesh for performance.
- No rigs/animation needed — player is first-person only.

### 16.2 Textures

```
PNG (source art)
   ↓  Godot import (import > 2D > texture)
Compressed (VRAM compression — BC/DXT on Windows)
   ↓  .import + .stex
```

### 16.3 Audio

```
WAV/OGG/FLAC (source)
   ↓  Godot import (import > audio)
OGG (compressed)
   ↓  .import
```

### 16.4 Shaders

Custom shaders (`.shader` / `.twc shader`) for:
- Neon edge outlines (world position + normal-based outline)
- Skybox with rotation
- Speed trail particles (shader-based, not CPU particles)
- Water/surf ramp visual feedback (color shift based on speed)

---

## 17. Coding Standards

### 17.1 Core Principles

| Principle | Rule |
|---|---|
| One class, one purpose | Each GDScript file defines one class with a single responsibility |
| Keep classes small | Aim for ≤ 300 lines. If larger, split into sub-modules. |
| Prefer composition over inheritance | Use `extends` only for engine types (Node, Resource). Movement logic is composed via modules. |
| No script monoliths | The Player node must NEVER exceed ~200 lines. All movement logic lives in MovementController and its modules. |

### 17.2 Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Classes | PascalCase + `class_name` | `class_name BunnyHop` |
| Functions | snake_case | `func apply_acceleration()` |
| Variables | snake_case | `var ground_speed` |
| Constants | UPPER_SNAKE | `const MAX_STRAFE_ANGLE = 30.0` |
| Signals | snake_case | `signal on_landed(velocity)` |
| Resources | PascalCase + `.tres` | `MovementConfig.tres` |
| Input actions | snake_case | `jump`, `move_forward` |

### 17.3 GDScript Best Practices

- Always use type hints: `func process(input: InputState, delta: float) -> void`
- Use `class_name` for any script that's referenced by type elsewhere
- Never use `get_node()` with hardcoded paths in production code. Use `@onready var` exports or dependency injection
- Use `export_resource`, `export_node_path`, or `export var` for inspector configurability
- Keep `match` statements instead of long `if/else` chains for state machines
- Use `preload()` for compile-time resource loading, `load()` for runtime
- Signal connections: use `connect()` with `Callable(self, ...)` — never string-based connections in Godot 4

### 17.4 Git Conventions

- `main` branch: production-ready, tagged releases
- `develop` branch: current sprint work (feature branches merge here)
- Feature branches: `feature/movement-bhopt`, `feature/ui-hud`, `feature/map-tutorial`
- Commit messages: `feat(movement): add bunny hop friction skip` / `fix(physics): correct air accel clamping` / `docs: update architecture`

---

## 18. Testing Strategy

### 18.1 Test Framework

- **Framework**: [GUT](https://github.com/bananabreadman/gut) (Godot Unit Test) — the de facto standard for Godot testing.
- **Test command**: `godot --headless --script test_runner.gd`
- **CI**: GitHub Actions runs GUT tests on every PR.

### 18.2 Test Categories

| Category | What's Tested | Tools |
|---|---|---|
| Unit | Individual math functions (accelerate, friction, strafe calc) | GUT, plain asserts |
| Integration | Movement modules interacting with MovementController | GUT, mock InputState |
| Physics | Tick determinism (same input → same output across runs) | Custom comparison assertions |
| UI | HUD updates, menu navigation, settings persistence | GUT + scene instantiation |
| E2E | Full race: spawn → move → bhop → surf → finish → PB saved | Scene-based integration tests |

### 18.3 Key Test Cases

| Test | Description |
|---|---|
| `test_ground_acceleration()` | Verify velocity approaches wish speed over time |
| `test_air_strafe_speed_gain()` | Verify W+A/D + mouse turn gains speed |
| `test_bunny_hop_preserves_momentum()` | Landing + immediate jump retains velocity |
| `test_surf_gravity_conversion()` | Downward gravity converts to forward speed on ramp |
| `test_fixed_tick_determinism()` | Same inputs over 1000 ticks → identical final position |
| `test_jump_buffer_window()` | Jump pressed 30ms before landing still fires |
| `test_coyote_time()` | Jump pressed within 50ms of leaving ground still fires |

### 18.4 Performance Targets

| Metric | Target | Measurement |
|---|---|---|
| Physics tick | 100 Hz stable | TickManager timing |
| Render FPS | ≥ target_fps (default 360) | `Engine.get_frames_per_second()` |
| Physics step | < 2 ms per tick | Godot profiler / `get_physics_process_time()` |
| Input latency | ≤ 20 ms end-to-end | Manual measurement with high-speed footage (future) |

---

## 19. Development Workflow

### 19.1 Sprint Cycle

Each sprint (see `docs/03_Sprint_Plan.md`) follows this flow:

```
Sprint Planning (review section in docs/03_Sprint_Plan.md)
  ↓
Read relevant sections from docs/01 and docs/02
  ↓
Implement (create/modify only files listed in sprint)
  ↓
Write/update tests
  ↓
Run GUT tests + linter
  ↓
Verify acceptance criteria
  ↓
Update docs if architecture changed
  ↓
Commit + merge to develop
```

### 19.2 Local Development

```bash
# 1. Clone
git clone <repo> velocity

# 2. Install Godot 4.x (downloaded to /opt/godot or PATH)
# 3. Open project
godot project.godot

# 4. Run tests (headless)
godot --headless --path velocity --script tests/test_runner.gd

# 5. Or edit in Godot editor with live reload
```

### 19.3 CI Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):

```yaml
# On every push/PR:
- Checkout code
- Setup Godot 4.x
- Run GUT tests (headless)
- Run gdformat linting
- (Future) Run static analysis (godothon/godot-lint)
- (Future) Build for Windows/Linux as artifact
```

---

## 20. Long-Term Extensibility

The architecture is designed from day one to grow. The following systems are **not** in the v1 MVP but have reserved spaces in the architecture:

| System | Reserved Architecture | Document Reference |
|---|---|---|
| **Networking Layer** | `addons/networking/` — authoritative movement, input broadcasting, ghost sync | §20.1 |
| **Replay & Analytics** | `scripts/game/replay/` — deterministic replay files, telemetry collection | §9.5, §20.2 |
| **Plugin System** | `addons/` — custom movement modules register via ResourceGroup | §9.5, §20.3 |
| **Map SDK** | `addons/map_tools/` — editor plugin for map validation, packaging | §15.3, §20.4 |
| **Mod Support** | `resources/movement/` + `configs/` — community can override configs & add maps | §15, §20.5 |
| **AI Framework** | `scripts/ai/` — training ghosts, racing bots, procedural course testing | §20.6 |
| **Steam Features** | `addons/steam/` — Workshop, achievements, cloud saves, leaderboards | §20.7 |

### 20.1 Networking Layer (Future)

```
┌────────────────────────────────────────────┐
│          Client Prediction                 │
│  Local input applied immediately           │
│  Server state received and reconciled      │
└────────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────┐
│          Server Authority                  │
│  Runs 100Hz tick, simulates all players    │
│  Broadcasts state snapshots                │
└────────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────┐
│          Input Broadcasting                │
│  Clients send 1-bit inputs (keys pressed)  │
│  Server replays deterministically          │
└────────────────────────────────────────────┘
```

Movement runs on a fixed 100 Hz tick on both client and server. Clients send *inputs* (not states), and the server replays them deterministically. This makes cheating detection possible (server compares client vs server simulation).

### 20.2 Replay & Analytics

- **Replay format**: `.tres` binary file containing input snapshots (100 per second) + initial state.
- **Telemetry**: `scripts/debug/telemetry/` captures per-tick velocity, state transitions, strafe efficiency for heatmap/analysis.
- **Ghost files**: Replays loaded as invisible `Player` instances that replay inputs.

### 20.3 Plugin System

Movement modules use a `ResourceGroup` named `MovementModules`:

```gdscript
# Any .gd file in scripts/movement/modules/ that extends MovementModule
# is automatically discovered by the MovementController at startup.
```

Community mods can add new movement mechanics by dropping a new `.gd` file into `addons/my_mechanic/modules/` and registering it.

### 20.4 Map SDK

The Map SDK (future addon) provides:
- Editor gizmo for `Checkpoint` and `FinishTrigger` nodes
- Map validator: checks for unreachable areas, overlapping triggers, invalid surf angles
- Packaging tool: exports `.tscn` + assets into a `.zip` for easy sharing

### 20.5 Mod Support

- Maps are `.tscn` scenes — anyone can create them in the Godot editor.
- Movement configs are `.tres` resources — tweakable per-map.
- A `map_manifest.json` in each map folder declares metadata + tags.
- Maps dropped into `user://maps/` are auto-discovered at startup.

### 20.6 AI Framework (Future)

- **Training ghosts**: AI agents that learn optimal routes via reinforcement learning.
- **Racing bots**: Simple bots that follow a predetermined path for multiplayer practice.
- **Course testing**: Automated agents that traverse maps to find impossible jumps or broken paths.

### 20.7 Steam Features (Future)

- Leaderboards synced via Steam Web API
- Workshop integration for community maps
- Cloud saves for PBs and settings
- Achievements (first bhopt, first surf, clean landing, etc.)

---

## 21. Responsibility Matrix

| Module | Owns | Does NOT Own |
|---|---|---|
| **MovementController** | Orchestrating modules, reading InputState, writing velocity, calling move_and_slide | Ground/air accel math (delegated to modules), UI, timers, maps |
| **Movement Modules** (Ground/Air/BHop/Surf/Jump/Gravity/Friction/Velocity) | Their specific physics calculation | Reading raw input, emitting signals, rendering |
| **InputManager** | Translating input events to InputState, rebinding, buffering | Physics simulation, HUD, settings persistence |
| **GameManager** | Game state (menu, playing, paused, results), timer start/stop | Physics equations, input mapping, save file I/O |
| **SaveManager** | Reading/writing settings, PBs, unlocks | UI rendering, physics params, input handling |
| **LevelLoader** | Loading/unloading maps, instantiating CurrentMap | Player physics, HUD, input handling |
| **SignalBus** | Event dispatch & subscription | Any domain logic (only routes, never decides) |
| **TickManager** | Fixed tick timing, tick callbacks | Game state, movement math, audio |
| **UIManager** | HUD rendering, menu navigation | Game logic, physics params, audio mixing |
| **AudioManager** | Playing music/SFX, volume control, spatial audio | Input handling, game state, physics |

---

## 22. Notes for AI Agents

### Operating Contract

These guidelines prevent architectural drift and ensure the modular, engine-first design is preserved.

1. **Read the docs first.** Always read `docs/01_Master_Architecture.md` and the relevant section of `docs/02_Gameplay_Systems.md` before writing any code.

2. **Complete only the current sprint's scope.** Do not add features, refactor, or "improve" code outside the current sprint's acceptance criteria.

3. **Preserve the engine-first boundary.** The Movement Framework (`scripts/movement/`) must never import or depend on game-layer code (`scripts/game/`). If a movement module needs a game concept (e.g., timer), emit a `SignalBus` signal and let the game layer listen.

4. **Movement modules are small.** If a module exceeds 300 lines, split it. If `MovementController.gd` exceeds 400 lines, the module decomposition needs rethinking.

5. **Configuration is always resource-driven.** Never hardcode a number that could be a `MovementConfig` parameter. If you find yourself typing `300.0` for jump height, that's a bug — add it to `MovementConfig.tres`.

6. **Test before merging.** Every feature must have GUT tests. Acceptance criteria must pass.

7. **Keep changes localized.** Modify only the files listed in the current sprint. Touching unrelated files is a red flag — document it in a note if it's a critical dependency.

8. **Follow the coding standards.** PascalCase for classes, snake_case for functions/variables, always type-hint, use `class_name`.

### Sprint Execution Workflow

1. Read the sprint's section in `docs/03_Sprint_Plan.md` (including Inputs/Outputs/Acceptance Criteria).
2. Check `docs/02_Gameplay_Systems.md` for relevant technical details (equations, APIs).
3. Check `docs/01_Master_Architecture.md` for architectural boundaries.
4. Create/modify only the files listed in the sprint.
5. Write or update GUT tests.
6. Run `gut` test suite + gdformat linting.
7. Verify acceptance criteria.
8. Update `docs/` if architecture changed.
9. Commit only the sprint's files + tests + doc updates.

### Prohibited Actions

- Adding Godot plugins/dependencies not specified in the Technology Stack.
- Modifying `MovementConfig.gd` parameters without updating `resources/movement/default.tres`.
- Bypassing the `InputManager` — all input must flow through it.
- Putting game logic (timer, score, checkpoints) inside movement modules.
- Hardcoding magic numbers that should be config parameters.
- Writing movement modules that exceed 300 lines.

---

*This is Document 1 of 3. For movement mathematics and implementation details, see `docs/02_Gameplay_Systems.md`. For the sprint-by-sprint roadmap, see `docs/03_Sprint_Plan.md`.

© 2026 Velocity Engine — Development Architecture