# Velocity Engine — Gameplay Systems

> **Version:** 1.0
> **Status:** Draft - Sprint 0 (Pre-MVP)
> **Audience:** Developers, AI coding agents, movement designers
> **Related:** See `docs/01_Master_Architecture.md` for architecture overview and `docs/03_Sprint_Plan.md` for the sprint-by-sprint roadmap.

This document is the **implementation reference** for Velocity Engine's movement mechanics and all gameplay systems. It provides complete movement mathematics, concrete GDScript implementations, data schemas, API contracts, and serialization formats. Every sprint in `docs/03_Sprint_Plan.md` references the sections and code defined here.

---

## Table of Contents

1. Movement Mathematics
2. Bunny Hop Implementation
3. Air Acceleration & Strafing
4. Surfing
5. Ramp Calculations
6. Checkpoint System
7. Ghost Replay Architecture
8. Time Trial Logic
9. Leaderboards
10. Map Metadata
11. Scoring (Future)
12. Replay Serialization
13. Speedometer Calculations
14. Settings Architecture
15. Input Rebinding
16. Camera Effects
17. Audio Triggers

---

## 1. Movement Mathematics

### 1.1. Conventions & Units

| Symbol | Meaning | Unit |
|---|---|---|
| v | Velocity vector | units/sec |
| v_mag | Speed (velocity magnitude) | units/sec |
| v_h | Horizontal velocity (XZ plane) | units/sec |
| v_y | Vertical velocity (Y axis) | units/sec |
| a | Acceleration rate | units/sec^2 |
| f | Friction coefficient | unitless |
| g | Gravity | units/sec^2 |
| dt | Tick delta | seconds |
| w | Wish speed | units/sec |
| w_dir | Wish direction (normalized) | unitless |
| theta | Angle between two vectors | degrees |

All math is in 3D Vector3 space. Y is up. The tick rate is 100 Hz (dt = 0.01s).

### 1.2. Ground Acceleration

Implements the classic Quake PM_Accelerate function. Accelerates the player toward wish_dir up to wish_speed, with a clamped acceleration rate.

**Equation:**

```
current_speed = dot(v, w_dir)
add_speed     = w_speed - current_speed
if add_speed <= 0: return
accel_speed   = min(a * dt * w_speed, add_speed)
v += w_dir * accel_speed
```

**GDScript (GroundMovement.gd):**

```gdscript
func apply_ground_acceleration(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
    var current_speed = velocity.dot(wish_dir)
    var add_speed = wish_speed - current_speed
    if add_speed <= 0.0:
        return
    var accel_speed = min(config.ground_accel * delta * wish_speed, add_speed)
    velocity += wish_dir * accel_speed
```

**Parameters:**
- wish_speed = config.walk_speed (default: 320)
- a = config.ground_accel (default: 10)
- w_dir = player input direction projected to horizontal plane, normalized

### 1.3. Ground Friction

Implements the classic Quake PM_Friction function. Linearly decays velocity, with a "stop speed" below which friction is stronger (clean stops at low speed).

**Equation (Quake source):**

```
spd = |v_h|                          # horizontal speed
if spd < 0.001: return              # stopped, nothing to do

friction = config.ground_friction   # e.g., 6.0
control  = max(spd, config.stop_speed)  # stop_speed e.g. 8
drop = control * friction * dt

if drop > spd: drop = spd

v_h = v_h * (spd - drop) / spd
```

The `control = max(spd, stop_speed)` is the key: when moving slowly, friction uses stop_speed as the base, so it decays linearly to zero (clean stops). When moving fast, friction is proportional to speed (gradual decay).

For bhopping, stop_speed can be set very low to make friction weaker, giving that "slippery" movement feel.

**GDScript (Friction.gd):**

```gdscript
func apply_friction(delta: float, override: float = 1.0) -> void:
    var speed = Vector3(velocity.x, 0, velocity.z).length()
    if speed < 0.001:
        velocity.x = 0.0
        velocity.z = 0.0
        return

    var friction = config.ground_friction * override
    var control = max(speed, config.stop_speed)
    var drop = control * friction * delta

    if drop > speed:
        drop = speed

    var new_speed = max(0.0, speed - drop)
    velocity.x *= new_speed / speed
    velocity.z *= new_speed / speed
```

The `override` parameter is used by the BunnyHop module to reduce friction on buffered landing jumps (e.g., override = 0.1 for 10% friction).

### 1.4. Air Acceleration

Same formula as ground acceleration but with a cap on wish speed. In Quake, the air speed cap is 30 units/sec. This means air strafing has diminishing returns and requires precise timing.

**Equation:**

```
current_speed = dot(v, w_dir)
add_speed     = air_speed_cap - current_speed    # capped at air_speed_cap!
if add_speed <= 0: return
accel_speed   = min(a * dt * air_speed_cap, add_speed)
v += w_dir * accel_speed
```

**GDScript (AirMovement.gd):**

```gdscript
func apply_air_acceleration(wish_dir: Vector3, delta: float) -> void:
    var wish_spd = config.air_speed_cap   # 30.0
    var current = velocity.dot(wish_dir)
    var add_speed = wish_spd - current
    if add_speed <= 0.0:
        return
    var accel_speed = min(config.air_accel * delta * wish_spd, add_speed)
    velocity += wish_dir * accel_speed
```

### 1.5. Gravity

Constant downward acceleration, clamped to terminal velocity.

**Equation:**

```
v_y -= g * dt
v_y = max(v_y, -max_fall_speed)
```

**GDScript (Gravity.gd):**

```gdscript
func apply_gravity(delta: float) -> void:
    velocity.y -= config.gravity * delta
    velocity.y = max(velocity.y, -config.max_fall_speed)
```

### 1.6. Wish Direction

The "wish direction" is the direction the player wants to move, computed from input + camera orientation.

**GDScript:**

```gdscript
# InputState.gd - helper for ground movement
func compute_wish_dir(camera: Camera3D, input: InputState) -> Vector3:
    var forward = -camera.basis.z
    var right = camera.basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()
    var wish_dir = forward * input.forward + right * input.right
    if wish_dir.length() < 0.01:
        return Vector3.ZERO
    return wish_dir.normalized()
```

For air strafing, the wish direction combines WASD input with the mouse-turned camera orientation:

```gdscript
# AirMovement.gd - air strafe wish direction
func compute_air_wish_dir(camera: Camera3D, input: InputState) -> Vector3:
    var forward = -camera.basis.z
    var right = camera.basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()
    var wish_dir = forward * input.forward + right * input.right
    if wish_dir.length() < 0.01:
        return Vector3.ZERO
    return wish_dir.normalized()
```

---

## 2. Bunny Hop Implementation

### 2.1. Overview

Bunny hopping preserves momentum by jumping immediately upon landing. This works because:

1. On the ground, friction reduces speed.
2. If you jump immediately upon landing, friction is skipped (or reduced), preserving velocity.
3. Combined with air strafing, this creates a positive feedback loop: faster -> more strafe gain -> faster.

### 2.2. Jump Buffering

The jump buffer is a timer that starts when jump is pressed and counts down. If the player lands within the buffer window, the jump fires automatically.

**Parameters:**
- config.jump_buffer_ms = 50 (configurable, typical range: 20-100ms)

**GDScript (BunnyHop.gd):**

```gdscript
class BunnyHop extends MovementModule:

var jump_buffer_timer: float = 0.0
var total_jumps: int = 0

func process(input: InputState, delta: float) -> void:
    if input.jump_just_pressed:
        jump_buffer_timer = config.jump_buffer_ms / 1000.0

    # Tick down the buffer
    jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

func on_landing(controller: MovementController, fall_speed: float) -> void:
    if jump_buffer_timer > 0.0 and controller.is_on_floor():
        # Reduce friction on this landing tick (preserve momentum)
        controller.friction_override = 0.1
        # Fire the buffered jump
        controller.apply_jump_impulse()
        jump_buffer_timer = 0.0
        total_jumps += 1
```

### 2.3. Coyote Time

The Jump module also implements coyote time - a grace period after leaving the ground during which jump still works.

**Parameters:**
- config.coyote_time_ms = 50

**GDScript (Jump.gd):**

```gdscript
class Jump extends MovementModule:

var coyote_timer: float = 0.0

func process(input: InputState, delta: float) -> void:
    if controller.is_on_floor():
        coyote_timer = config.coyote_time_ms / 1000.0
    else:
        coyote_timer = max(0.0, coyote_timer - delta)

    if input.jump_just_pressed and coyote_timer > 0.0:
        controller.apply_jump_impulse()
        coyote_timer = 0.0
        controller.bunnhop.total_jumps += 1
```

### 2.4. Jump Impulse

The jump impulse is a one-frame upward velocity applied when jumping:

**Equation:**

```
v_y = jump_impulse
```

This is an instantaneous velocity change, not a sustained force. The gravity module then acts on it normally.

**GDScript:**

```gdscript
func apply_jump_impulse() -> void:
    velocity.y = config.jump_impulse
    was_on_floor_last_tick = false
    SignalBus.emit("player_jumped", {velocity: velocity})
```

### 2.5. Bunny Hop Flow

```
Player presses JUMP in air
  -> jump_buffer_timer = 0.05s starts counting down

Player lands (move_and_slide sets is_on_floor = true)
  -> on_landing() check: jump_buffer_timer > 0
  -> If yes: friction_override = 0.1, apply jump impulse, buffer = 0
  -> If no: full friction applies

Jump impulse fires -> player leaves ground
  -> coyote_timer resets to 0 (already in air)
  -> Player is now airborne with preserved horizontal velocity

In air:
  -> Air strafing can gain speed (no friction to counteract it)
  -> When landing, repeat the cycle
```

### 2.6. Bunny Hop Mechanics Summary

| Situation | What Happens |
|---|---|
| Land + jump buffer active | Friction override (0.1x), immediate jump, buffer reset |
| Land + jump buffer inactive | Full friction applies, must wait for next input |
| Airborne + jump pressed | Coyote time check, then impulse |
| Ground + jump pressed | Normal jump impulse |
| Fall too fast | Landing damage (future feature) |

---

## 3. Air Acceleration & Strafing

### 3.1. Air Strafe Theory

Air strafing allows gaining speed while airborne by turning the mouse and holding W+A or W+D. The mechanism:

1. In air, friction is ~0 (no speed decay).
2. Air acceleration has a cap on wish speed (30), but if you accelerate perpendicular to velocity, the dot product is near 0, so add_speed is near max.
3. The velocity vector magnitude increases even though the acceleration was perpendicular.

### 3.2. The Air Speed Cap

In Quake/Source, the air acceleration function caps the wish speed at config.air_speed_cap (default: 30). This creates two regimes:

- Below the cap (v_mag < 30): The player can accelerate in any direction up to the cap. Speed gain is large.
- Above the cap (v_mag > 30): The cap limits acceleration. Only acceleration perpendicular to velocity can increase speed (since dot(v, w_dir) reduces the effective add_speed).

### 3.3. Optimal Strafe Angle

When the player's speed is above the air speed cap, there is an optimal angle to strafe at to gain maximum speed.

**Optimal angle alpha (angle from velocity direction to wish direction):**

```
sin(alpha) = air_speed_cap / v_mag
alpha = arcsin(air_speed_cap / v_mag)
```

This means: the faster you go, the closer your strafe must be to 90 degrees relative to your velocity direction.

**Example:**
- v_mag = 60, air_speed_cap = 30
- alpha = arcsin(30/60) = 30 degrees
- Turn mouse ~30 degrees off your forward direction to gain max speed

### 3.4. Maximum Speed Gain Per Tick

```
dv_max = air_accel * air_speed_cap * dt
```

With defaults (air_accel=10, air_speed_cap=30, dt=0.01):
```
dv_max = 10 * 30 * 0.01 = 3.0 units/tick
```

### 3.5. Theoretical Max Speed

With perfect strafing and no landings, the maximum speed grows as:

```
v(t) = sqrt(v_0^2 + (dv_max * t)^2)
```

In practice, speed is limited by:
- Mouse precision (can't maintain perfect angle indefinitely)
- Air time (must land and re-bhop to maintain/increase speed)
- Map design (constrained paths, obstacles)

### 3.6. Strafe Input Mapping

| Key Combination | Mouse Movement | Effect |
|---|---|---|
| W + A | Mouse left | Strafe left, gain speed |
| W + D | Mouse right | Strafe right, gain speed |
| A only | Mouse left | Tight left turn, maintain speed |
| D only | Mouse right | Tight right turn, maintain speed |
| W only | Any | Minimal air acceleration |

**Key insight:** Pure forward (W) in air produces near-zero acceleration because dot(v, w_dir) is already near maximum in the velocity direction. Speed gain comes from accelerating perpendicular to velocity.

### 3.7. Air Strafe Implementation

The air strafe is implemented by computing the wish direction from WASD + mouse orientation, then applying air acceleration:

```gdscript
# AirMovement.gd
func process_air_movement(input: InputState, delta: float) -> void:
    var wish_dir = compute_air_wish_dir(camera, input)
    if wish_dir != Vector3.ZERO:
        apply_air_acceleration(wish_dir, delta)
```

The mouse turn affects the camera's basis vectors (forward, right), which in turn affects the wish direction. This is why turning your mouse while holding W+A changes your acceleration direction - it's the fundamental mechanism of speed gaining.


## 4. Surfing

### 4.1. Overview

Surfing is the core mechanic where the player slides on steep ramps, converting downward gravity into forward momentum. This is the famous Source engine surfing mechanic.

### 4.2. Surf Detection

A surface is classified as a "surf ramp" when its angle from horizontal exceeds config.surf_angle_min_deg (default 45 degrees).

Using the floor normal (from CharacterBody3D.get_floor_normal()):

```
UP dot floor_normal gives the cosine of the angle from horizontal.
- Flat ground: normal = (0, 1, 0), dot = 1.0, angle = 0 degrees
- 45 degree slope: normal dot UP = cos(45) = 0.707
- Vertical wall: normal dot UP = 0, angle = 90 degrees

if normal.dot(UP) < cos(surf_angle_min):
    -> it is a surf ramp
```

**GDScript (Surf.gd):**

```gdscript
func is_surf_normal(normal: Vector3) -> bool:
    return normal.dot(Vector3.UP) < cos(deg2rad(config.surf_angle_min_deg))
```

### 4.3. Surf Physics

When on a surf ramp:

1. Velocity is projected onto the ramp plane (removing the component pushing into the surface).
2. Gravity pulls the player along the ramp surface, converting vertical fall into horizontal motion.
3. Momentum is preserved (modulo ramp-specific friction).

**Plane projection equation:**

```
v_projected = v - (dot(v, n) * n)
where n = ramp surface normal
```

This removes the velocity component normal to the ramp, keeping only the tangential (sliding) component.

**GDScript:**

```gdscript
func process_surf(velocity_in: Vector3, normal: Vector3, delta: float) -> Vector3:
    # Project velocity onto the ramp plane
    var proj_speed = velocity_in.dot(normal)
    var velocity_out = velocity_in - normal * proj_speed

    # Apply surf-specific friction (lower than ground friction)
    var h_speed = Vector3(velocity_out.x, 0, velocity_out.z).length()
    if h_speed > 0.001:
        var drop = h_speed * config.surf_friction * delta
        if drop > h_speed:
            drop = h_speed
        velocity_out.x *= (1.0 - drop / h_speed)
        velocity_out.z *= (1.0 - drop / h_speed)

    return velocity_out
```

### 4.4. Gravity Conversion on Ramps

When surfing, gravity does not simply pull the player straight down - it pulls along the ramp surface. This is handled naturally by Godot's move_and_slide() with the ramp's collision normal.

The key is:
1. Vertical velocity is preserved (gravity still applies vertically).
2. move_and_slide() slides the player along the ramp surface.
3. The horizontal component of the slide motion increases speed.

No special code is needed for this - the physics engine handles it. The Surf module mainly needs to:
- Detect ramp surfaces
- Apply ramp-specific friction (usually lower)
- Handle ramp-to-ramp transitions

### 4.5. Momentum Preservation Through Transitions

**Ramp to air (leaving a ramp):**
- move_and_slide() detects no more floor contact.
- State changes from SURF to AIR.
- Velocity is preserved (both horizontal and vertical).
- Gravity takes over for the descent.

**Air to ramp (landing on a ramp):**
- move_and_slide() detects the ramp surface.
- get_floor_normal() returns the ramp normal.
- Surf module projects velocity onto the new ramp plane.
- Player enters SURF state.

### 4.6. Anti-Stuck Measures

When surfing, players can get "stuck" to a ramp if velocity is too low. To prevent this:

- If projected horizontal speed falls below a threshold, apply a small outward push along the ramp normal.

```gdscript
func anti_stuck(velocity: Vector3, normal: Vector3) -> Vector3:
    var h_speed = Vector3(velocity.x, 0, velocity.z).length()
    if h_speed < config.surf_min_speed:
        velocity += normal * config.surf_push
    return velocity
```

### 4.7. Surf Angle Reference

| Surf Angle | Feel | Typical Use |
|---|---|---|
| 45-50 degrees | Gentle, forgiving | Tutorial, beginner maps |
| 50-60 degrees | Steeper, faster | Intermediate maps |
| 60-80 degrees | Very steep, hard to control | Advanced/challenge maps |
| > 80 degrees | Near-vertical | Wall-running transition (future) |

---

## 5. Ramp Calculations

### 5.1. Velocity Projection

The core operation in surfing is projecting velocity onto a plane defined by the ramp's surface normal:

```
v_projected = v - dot(v, n) * n
```

This is identical to the operation described in Section 4.3. It removes the component of velocity that would push the player into the ramp, keeping only the component parallel to the ramp surface.

### 5.2. Momentum Conservation on Ramps

When the player lands on a new ramp surface:

1. The horizontal velocity component is preserved.
2. The vertical velocity component is absorbed/modified by the ramp collision.
3. move_and_slide() redistributes the velocity based on the new surface normal.

The Surf module ensures speed is not lost in this transition by skipping friction on the landing tick (similar to bunny hop friction override).

### 5.3. Edge Handling

When the player reaches the edge of a ramp:

1. move_and_slide() clears is_on_floor().
2. The Collision module detects the transition (floor normal becomes invalid).
3. State changes from SURF to AIR.
4. Velocity is preserved; gravity takes over.

To prevent edge sticking (clinging to the edge), a small velocity in the ramp's "down-fling" direction is applied when transitioning:

```gdscript
func on_ramp_exit(velocity: Vector3, ramp_normal: Vector3) -> Vector3:
    var ramp_down = Vector3(0, -1, 0) - ramp_normal
    velocity += ramp_down * config.surf_exit_boost
    return velocity
```

### 5.4. Multi-Ramp Sequences

Some maps have sequences of ramps where the player must transition quickly. The Surf module tracks consecutive ramp contacts for:
- Speed preservation (skip friction on ramp-to-ramp landings)
- Chain scoring (future trick scoring: "3-ramp combo")

---

## 6. Checkpoint System

### 6.1. Overview

Checkpoints are Area3D trigger volumes placed throughout a map. When the player touches one, their respawn position is updated. In time-trial mode, checkpoints also segment the timer into splits.

### 6.2. Checkpoint Node

**GDScript (Checkpoint.gd):**

```gdscript
class_name Checkpoint extends Area3D:

@export var checkpoint_id: int = 0
@export var next_checkpoint: NodePath

func _ready():
    connect("body_entered", self._on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        SignalBus.emit("checkpoint_reached", {
            "checkpoint_id": checkpoint_id,
            "position": global_transform.origin,
            "basis": global_transform.basis,
            "time": GameManager.current_race_time
        })
```

### 6.3. Checkpoint Storage

The GameManager tracks the active checkpoint:

```gdscript
# GameManager.gd
var active_checkpoint_id: int = -1
var checkpoint_transform: Transform3D
var checkpoint_splits: Array[float] = []

func _on_checkpoint_reached(data: Dictionary) -> void:
    active_checkpoint_id = data.checkpoint_id
    checkpoint_transform = Transform3D(data.basis, data.position)
    checkpoint_splits.append(data.time)
    UIManager.update_checkpoint(active_checkpoint_id, checkpoint_splits.size())
```

### 6.4. Respawn Logic

When the player falls off the map or restarts:

```gdscript
func respawn() -> void:
    if active_checkpoint_id >= 0:
        player.global_transform = checkpoint_transform
    else:
        player.global_transform = current_map.respawn_point.global_transform
    player.velocity = Vector3.ZERO
```

### 6.5. Splits Comparison

When a ghost replay is loaded, its checkpoint times are compared:

```gdscript
func compare_checkpoint(cp_id: int, current_time: float) -> Dictionary:
    var ghost_time = ghost_replay.splits[cp_id]
    return {
        "ahead": current_time < ghost_time,
        "gap": abs(current_time - ghost_time),
        "gap_percent": abs(current_time - ghost_time) / ghost_time * 100
    }
```

---

## 7. Ghost Replay Architecture

### 7.1. Overview

Ghost replays record the player's position, velocity, and input state at 100 Hz, serialize them to a file, and play them back as a translucent player model. In MVP, ghosts are local-only (PB ghost).

### 7.2. Replay Data Structure

```gdscript
# ReplayFrame.gd
class_name ReplayFrame extends Resource:

@export var tick: int
@export var position: Vector3
@export var velocity: Vector3
@export var rotation: Vector3
@export var input_state: InputStateResource
@export var movement_state: int
```

### 7.3. Recording

```gdscript
# GhostRecorder.gd
var is_recording: bool = false
var frames: Array[ReplayFrame] = []

func start_recording() -> void:
    is_recording = true
    frames.clear()

func record_frame(tick: int, player: Player) -> void:
    if not is_recording:
        return
    frames.append(ReplayFrame.new().init(
        tick, player.global_transform.origin,
        player.velocity, player.rotation,
        InputManager.get_state(),
        MovementController.current_state
    ))

func stop_recording() -> void:
    is_recording = false
    save_to_file()
```

### 7.4. Playback

```gdscript
# GhostPlayer.gd
class_name GhostPlayer extends Node3D:

var replay_data: Dictionary
var frame_index: int = 0

func load_replay(path: String) -> void:
    replay_data = ResourceLoader.load(path) as Dictionary
    mesh_instance = create_ghost_model()

func _physics_process(delta: float) -> void:
    if frame_index >= replay_data.frames.size():
        return
    var frame = replay_data.frames[frame_index]
    global_transform.origin = frame.position
    global_transform.basis = Basis.from_euler(frame.rotation)
    frame_index += 1
```

### 7.5. Ghost Data File Format

Stored as a Godot .tres resource with compression:

```json
{
    "version": 1,
    "map": "tutorial",
    "player_name": "Player1",
    "finish_time": 42.350,
    "config": {
        "walk_speed": 320,
        "jump_impulse": 300
    },
    "frames": [
        {
            "tick": 100,
            "position": [0, 5, 0],
            "velocity": [100, -200, 50],
            "rotation": [0, 1.5, 0],
            "input": {"forward": 1, "right": 0, "jump": true}
        }
    ]
}
```

### 7.6. Storage Locations

| Ghost Type | Path |
|---|---|
| PB Ghost | user://ghosts/{map_name}_pb.tres |
| Downloaded Ghosts | user://ghosts/leaderboard/{player}_{map}.tres |
| Challenge Ghosts | user://ghosts/challenges/{map}_{challenge}.tres |

---

## 8. Time Trial Logic

### 8.1. State Machine

```
IDLE -> RUNNING -> FINISHED
  ^       |          |
  |  (restart)      (restart)
  +------ + ---------+
```

### 8.2. Timer Implementation

```gdscript
# Integrated into GameManager.gd
enum RaceState { IDLE, RUNNING, FINISHED, PAUSED }

var race_state: RaceState = RaceState.IDLE
var start_time: int = 0
var finish_time: int = 0
var checkpoint_splits: Array[float] = []

func start_race() -> void:
    race_state = RaceState.RUNNING
    start_time = Time.get_ticks_usec()
    SignalBus.emit("race_started")

func finish_race() -> void:
    finish_time = Time.get_ticks_usec()
    race_state = RaceState.FINISHED
    var total_time = (finish_time - start_time) / 1000000.0
    var is_pb = check_pb(total_time)

    if is_pb:
        SaveManager.save_ghost(current_map, total_time)

    SignalBus.emit("race_finished", {
        "time": total_time,
        "is_pb": is_pb,
        "splits": checkpoint_splits
    })

func check_pb(time: float) -> bool:
    var pb = SaveManager.get_pb(current_map_name)
    if pb == 0.0 or time < pb:
        SaveManager.save_pb(current_map_name, time)
        return true
    return false

func restart() -> void:
    race_state = RaceState.IDLE
    start_time = 0
    finish_time = 0
    checkpoint_splits.clear()
    player.respawn_to_start()
```

### 8.3. Finish Trigger

```gdscript
# FinishTrigger.gd
class_name FinishTrigger extends Area3D:

func _ready():
    connect("body_entered", self._on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player") and GameManager.race_state == RaceState.RUNNING:
        GameManager.finish_race()
```

### 8.4. Start Trigger

The race starts when the player leaves the spawn platform:

```gdscript
# StartTrigger.gd
func _on_body_exited(body: Node3D) -> void:
    if body.is_in_group("player") and GameManager.race_state == RaceState.IDLE:
        GameManager.start_race()
```

### 8.5. Results Display

On finish, ResultsMenu shows:

| Field | Source |
|---|---|
| Finish time | finish_time - start_time |
| PB status | is_pb flag |
| PB time | SaveManager.get_pb() |
| Speed at finish | player.horizontal_speed |
| Jumps count | BunnyHop.total_jumps |
| Split times | checkpoint_splits array |

---

## 9. Leaderboards

### 9.1. Local Leaderboards

Stored in user://save/leaderboards.tres:

```gdscript
class_name LeaderboardEntry extends Resource:
var player_name: String
var time: float
var date: int
var replay_path: String
var rank: int
```

### 9.2. Leaderboard API

```gdscript
func submit_score(map: String, time: float, replay_path: String) -> void:
    var entry = LeaderboardEntry.new()
    entry.player_name = Settings.player_name
    entry.time = time
    entry.date = Time.get_unix_from_system()
    entry.replay_path = replay_path
    SaveManager.add_leaderboard_entry(map, entry)

func get_top_times(map: String, count: int = 10) -> Array[LeaderboardEntry]:
    return SaveManager.get_leaderboard_entries(map, count)
```

### 9.3. Steam Leaderboards (Future)

When Steam integration is added:

```gdscript
# SteamLeaderboard.gd (future)
func submit_to_steam(map: String, time: float) -> void:
    SteamService.set_leaderboard(map + "_time", time)

func download_steam_leaderboard(map: String) -> void:
    SteamService.find_leaderboard(map + "_time")
```

---

## 10. Map Metadata

### 10.1. Format

Each map has a MapMetadata resource attached as a node metadata or custom resource:

```gdscript
# MapMetadata.gd
class_name MapMetadata extends Resource:

@export var map_id: String
@export var display_name: String
@export var author: String
@export var difficulty: int  # 1-5
@export var tags: PackedStringArray
@export var movement_config_path: String  # path to MovementConfig.tres
@export var thumbnail: Texture2D
@export var description: String
@export var estimated_time: float
@export var required_techniques: PackedStringArray
@export var vertex_color_tint: Color
```

### 10.2. Discovery

```gdscript
func discover_maps() -> Array[MapInfo]:
    var maps: Array[MapInfo] = []
    var dir = DirAccess.open("res://scenes/maps/")
    if dir:
        for file in dir.get_files():
            if file.ends_with(".tscn"):
                var scene = load("res://scenes/maps/" + file)
                var instance = scene.instantiate()
                var metadata = instance.get_meta("map_metadata") as MapMetadata
                if metadata:
                    maps.append(MapInfo.new(file, metadata))
    return maps
```

### 10.3. Map Validation (Map SDK - Future)

A future Map SDK addon will validate maps for:
- No unreachable areas
- Checkpoints ordered correctly
- Finish trigger reachable
- Surf ramps within valid angle range
- No degenerate geometry

---

## 11. Scoring (Future)

### 11.1. Score Components (Planned)

| Component | Formula | Max |
|---|---|---|
| Time Score | base_time / actual_time | Scaled |
| Speed Bonus | max(0, v_max - v_threshold) / v_max | 0.5 |
| Airtime Bonus | total_airtime / total_time | 0.3 |
| Clean Landing | Count of perfect landings (bhop success) | 0.2 |
| Style Multiplier | Combo of consecutive air strafes | x1.5 |

### 11.2. Trick Scoring (Planned)

| Trick | Points |
|---|---|
| Perfect bunny hop (within 1 tick) | 50 |
| Max speed air strafe | 100 |
| Ramp-to-ramp transition without touching ground | 200 |
| Speed maintained through landing | 75 |

---

## 12. Replay Serialization

### 12.1. Format Versioning

All replay files include a version number. When the format changes:

```gdscript
func load_replay(path: String) -> Dictionary:
    var file = FileAccess.open(path, FileAccess.READ)
    var data = file.get_var()
    match data["version"]:
        1:
            return parse_v1(data)
        2:
            return parse_v2(data)  # new field added
        _:
            push_error("Unsupported replay version: %d" % data["version"])
            return {}
```

### 12.2. Compression

Large replays (30s at 100Hz = 3000 frames) are compressed:

```gdscript
func save_compressed(frames: Array, path: String) -> void:
    var bytes = FileAccess.get_var(frames)
    var compressed = bytes.compress(FileAccess.COMPRESSION_FAST)
    var file = FileAccess.open(path, FileAccess.WRITE)
    file.store_buffer(compressed)
```

### 12.3. Delta Encoding (Future)

To reduce file size, future versions will store only changes between frames:

```
Frame 0: {pos: [0, 5, 0], vel: [0, 0, 0], input: {}}
Frame 1: {delta_pos: [1, 0.5, 0], input: jump=true}
Frame 2: {delta_pos: [1, 0.3, 0]}
```

---

## 13. Speedometer Calculations

### 13.1. Horizontal Speed

The speedometer displays the horizontal speed (magnitude of velocity in the XZ plane):

```
v_h = sqrt(v.x^2 + v.z^2)
```

**GDScript:**

```gdscript
func horizontal_speed() -> float:
    return Vector3(velocity.x, 0, velocity.z).length()
```

### 13.2. HUD Display

The speed is displayed in the HUD as "XXX u/s" (units per second).

Update frequency: throttled to 30 FPS (no need to update the label 100 times per second):

```gdscript
var last_speed_update: float = 0.0
const SPEED_UPDATE_INTERVAL = 1.0 / 30.0

func _process(delta: float) -> void:
    last_speed_update += delta
    if last_speed_update >= SPEED_UPDATE_INTERVAL:
        UIManager.update_speed(horizontal_speed())
        last_speed_update = 0.0
```

### 13.3. Speed Tiers (Visual Feedback)

| Speed Range | HUD Color | Feedback |
|---|---|---|
| 0-200 u/s | Gray | Slow |
| 200-400 u/s | White | Normal |
| 400-600 u/s | Yellow | Fast |
| 600-800 u/s | Orange | Very fast |
| 800+ u/s | Red | Maximum |

---

## 14. Settings Architecture

### 14.1. Categories

| Category | Settings | Persistence |
|---|---|---|
| Input | Mouse sensitivity (X/Y), invert Y, key bindings | settings.cfg |
| Audio | Master/SFX/Music volume | settings.cfg |
| Graphics | Fullscreen, VSync, FPS cap, resolution | settings.cfg |
| Gameplay | Tick rate, debug mode, auto-save ghosts | settings.cfg |
| Movement | All MovementConfig parameters (advanced) | Per-map .tres |

### 14.2. Settings Storage

Stored as an .ini-style config file at user://save/settings.cfg:

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

[gameplay]
tick_rate = 100
show_debug = false
auto_save_ghost = true
```

### 14.3. Runtime Application

Settings are loaded at startup and applied immediately when changed in the Settings menu:

```gdscript
# SettingsMenu.gd
func on_setting_changed(key: String, value: Variant) -> void:
    Settings.set(key, value)
    Settings.save()
    match key:
        "mouse_sensitivity_x", "mouse_sensitivity_y", "invert_mouse_y":
            PlayerCamera.apply_settings()
        "master_volume", "music_volume", "sfx_volume":
            AudioManager.update_volumes()
        "fullscreen", "vsync":
            DisplayServer.window_set_mode(...)
        "tick_rate":
            TickManager.set_tick_rate(value)
        _:
            pass
```

---

## 15. Input Rebinding

### 15.1. Architecture

The InputManager reads bindings from the Godot InputMap at startup and writes changes back to the InputMap + persists them via SaveManager.

### 15.2. Action-to-Key Mapping

| Action | Default (Keyboard) | Default (Controller) |
|---|---|---|
| jump | Space | South button |
| move_forward | W | Left stick up |
| move_back | S | Left stick down |
| move_left | A | Left stick left |
| move_right | D | Left stick right |
| duck | Ctrl | Down direction |
| sprint | Shift | L2/R2 |
| pause | Esc | Start |
| restart | R | Back |
| toggle_debug | F1 | D-pad up |

### 15.3. Rebinding Flow

```
Settings Menu -> User clicks action -> waits for keypress -> validates no conflict
  -> InputMap.action_erase_events() for old binding
  -> InputMap.action_add_event() for new binding
  -> SaveManager.persist_bindings() writes to settings.cfg
  -> SignalBus.emit("keybindings_changed")
  -> InputManager.reload_from_input_map()
```

**GDScript:**

```gdscript
func rebind_action(action: String, new_event: InputEventKey) -> bool:
    # Check for conflicts
    for existing_action in InputMap.get_actions():
        var events = InputMap.action_get_events(existing_action)
        for event in events:
            if event is InputEventKey and event.keycode == new_event.keycode:
                if existing_action != action:
                    return false  # conflict detected

    # Apply new binding
    InputMap.action_erase_events(action)
    InputMap.action_add_event(action, new_event)
    SaveManager.save_binding(action, new_event)
    SignalBus.emit("keybindings_changed")
    return true
```

---

## 16. Camera Effects

### 16.1. Dynamic FOV

When the player is moving fast, the camera FOV increases slightly to accentuate the feeling of speed.

```
if horizontal_speed > fov_bump_threshold:
    t = min(horizontal_speed / fov_bump_max_speed, 1.0)
    fov = lerp(base_fov, base_fov + fov_bump_strength, t)
```

**GDScript (PlayerCamera.gd):**

```gdscript
func update_fov(speed: float) -> void:
    if not config.fov_bump_enabled:
        return
    var clamped_speed = min(speed, config.fov_bump_max_speed)
    var t = clamped_speed / config.fov_bump_max_speed
    var fov = lerp(config.base_fov, config.base_fov + config.fov_bump_strength, t)
    fov = clamp(fov, config.base_fov, config.base_fov + config.fov_bump_strength)
    camera.fov = fov
```

### 16.2. Landing Impact (Future)

On hard landings (fall_speed > threshold), a brief camera shake and downward kick:

```gdscript
func on_hard_landing(fall_speed: float) -> void:
    var intensity = min(fall_speed / 1000.0, 1.0)
    camera.offset = Vector3(0, -intensity * 5, 0)
    # Spring back over 0.3 seconds
```

### 16.3. Viewmodel Bob (Future)

Subtle camera bob synchronized to footsteps (future feature, not in MVP).

---

## 17. Audio Triggers

### 17.1. Footstep Sounds

Surface-type footstep sounds are triggered when the player is on the ground and moving above a speed threshold.

```gdscript
# AudioManager.gd
func play_footstep(surface_type: String, speed: float) -> void:
    if speed < footstep_min_speed:
        return
    match surface_type:
        "concrete":
            play_sfx("sfx/footsteps/concrete", 1.0 - speed_variance)
        "metal":
            play_sfx("sfx/footsteps/metal")
        "wood":
            play_sfx("sfx/footsteps/wood")
```

Surface type is determined by the material or a metadata property on the floor mesh.

### 17.2. Speed-Based Layering

The surf slide sound's pitch and volume scale with horizontal speed:

```gdscript
func update_surf_audio(speed: float) -> void:
    var t = clamp(speed / 800.0, 0.0, 1.0)
    surf_stream.pitch_scale = lerp(0.8, 1.2, t)
    surf_stream.volume_db = lerp(-20, -5, t)
```

### 17.3. Event Triggers

| Event | SFX |
|---|---|
| Player Jump | sfx/jump.wav |
| Hard Landing | sfx/land_hard.wav (volume scales with fall speed) |
| Light Landing | sfx/land_light.wav |
| Surf Enter | sfx/surf_enter.wav |
| Surf Loop | sfx/surf_loop.wav (pitch scales with speed) |
| Finish Line | sfx/finish.wav |
| Button Click | sfx/ui_click.wav |
| Checkpoint | sfx/checkpoint.wav |
| PB Beat | sfx/new_pb.wav |

---

*This is Document 2 of 3. For high-level architecture, see `docs/01_Master_Architecture.md`. For the sprint-by-sprint roadmap, see `docs/03_Sprint_Plan.md`.

(c) 2026 Velocity Engine - Development Architecture
