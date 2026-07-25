extends State

@export_category("Next States")
@export var idle_state: State
@export var move_state: State
@export var jump_state: State
@export var wall_jump_state: State

@export_category("Components")
@export var movement_component: MovementComponent
@export var movement_config: MovementConfig

func enter_state() -> void:
	movement_component.movement_type = movement_component.MovementTypes.CLIMBING
	# Reset vertical velocity to prevent jump-warping up the wall
	movement_component.set_vertical_velocity(-movement_config.climb_slide_idle)

func physics_update(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var has_input := raw_input != Vector2.ZERO

	if movement_component.is_grounded():
		movement_component.movement_type = movement_component.MovementTypes.WALKING
		switch_state.emit(move_state if has_input else idle_state)
		return

	if not movement_component.is_near_climbable_wall:
		movement_component.movement_type = movement_component.MovementTypes.WALKING
		switch_state.emit(move_state if has_input else idle_state)
		return

	if Input.is_action_just_pressed("jump"):
		switch_state.emit(wall_jump_state)
		return
