extends State

@export_category("Next States")
@export var idle_state: State
@export var jump_state: State
@export var climb_state: State

@export_category("Components")
@export var movement_component: MovementComponent

func enter_state() -> void:
	SoundManager.play_sound("player_running_sound")
	movement_component.movement_type = movement_component.MovementTypes.WALKING

func update(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if raw_input == Vector2.ZERO:
		switch_state.emit(idle_state)
	
	if not movement_component.is_grounded() and movement_component.can_climb():
		switch_state.emit(climb_state)
		return

	if movement_component.can_jump() and Input.is_action_just_pressed("jump"):
		switch_state.emit(jump_state)
