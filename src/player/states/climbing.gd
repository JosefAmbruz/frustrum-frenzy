extends State

@export_category("Next States")
@export var idle_state: State
@export var move_state: State
@export var jump_state: State
@export var wall_jump_state: State

@export_category("Components")
@export var movement_component: MovementComponent
@export var movement_config: MovementConfig

var _was_near_climbable := false

func enter_state() -> void:
	movement_component.movement_type = movement_component.MovementTypes.CLIMBING
	movement_component.set_vertical_velocity(-movement_config.climb_slide_idle)
	_was_near_climbable = true

func exit_state() -> void:
	_was_near_climbable = false

func physics_update(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var has_input := raw_input != Vector2.ZERO

	if movement_component.is_grounded():
		movement_component.movement_type = movement_component.MovementTypes.WALKING
		switch_state.emit(move_state if has_input else idle_state)
		return

	if not movement_component.is_near_climbable_wall:
		var lost_at_top = _was_near_climbable
		_was_near_climbable = false
		movement_component.movement_type = movement_component.MovementTypes.WALKING
		if lost_at_top:
			var body = movement_component.character_body
			body.velocity = movement_component.last_climb_normal * movement_config.climb_detach_push
			body.velocity.y = movement_config.climb_top_pop_velocity
			movement_component.prevent_climb_for(0.3)
		switch_state.emit(move_state if has_input else idle_state)
		return

	_was_near_climbable = true

	if Input.is_action_just_pressed("jump"):
		switch_state.emit(wall_jump_state)
		return
