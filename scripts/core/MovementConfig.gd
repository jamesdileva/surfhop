class_name MovementConfig
extends Resource

## All tunable movement parameters (resource-driven per architecture §15.1).
## Values follow Quake/CS conventions; world scale is 1 Godot unit = 1 Quake unit.

# Ground movement
@export var walk_speed: float = 320.0
@export var ground_accel: float = 10.0
@export var ground_friction: float = 6.0
@export var stop_speed: float = 8.0  # Friction base below this speed (clean stops, §1.3)
@export var friction_override_factor: float = 0.1  # Friction multiplier on buffered bhop landing (§2.2)

# Air movement
@export var air_accel: float = 14.0  # playtest P2: raised from 10 for snappier strafe gain
@export var air_speed_cap: float = 30.0
@export var air_cap_multiplier: float = 1.0

# Jumping
@export var jump_impulse: float = 300.0
@export var coyote_time_ms: float = 50.0
@export var jump_buffer_ms: float = 50.0
@export var max_jump_height: float = 56.25  # apex height for jump_impulse 300 / gravity 800
@export var auto_bhop: bool = true          # holding jump re-hops on every landing

# Gravity
@export var gravity: float = 800.0
@export var max_fall_speed: float = 1000.0

# Surfing
@export var surf_angle_min_deg: float = 45.0
@export var surf_speed_multiplier: float = 1.0
@export var surf_preservation: float = 0.95
@export var surf_friction: float = 0.25       # Ramp friction, far lower than ground (§4.3)
@export var surf_min_speed: float = 20.0      # Anti-stuck threshold (§4.6)
@export var surf_push: float = 300.0         # Outward accel (u/s^2) when below surf_min_speed
@export var surf_exit_boost: float = 1.0      # Down-fling scale on ramp exit (§5.3)
@export var floor_max_angle_deg: float = 45.0 # Walkable limit; steeper surfaces are surf ramps (walls)

# Physics
@export var tick_rate: int = 100
@export var max_velocity: Vector3 = Vector3(4000, 1500, 4000)

# Debug
@export var draw_debug: bool = false
@export var enable_console: bool = false
