class_name MovementState

## Movement state constants shared by the MovementController and its modules.
## Anonymous enum members are exposed as class constants (MovementState.GROUND).

enum {
	GROUND, # Standing on a walkable surface
	AIR,    # In the air, not surfing
	SURF,   # On a surfable ramp
	JUMP,   # Transient: just took off
	LAND,   # Transient: just landed
	FALL,   # Falling fast (fall speed exceeds threshold)
}
