extends State

@export_category("Next States")
@export var move_state: State
@export var climb_state: State
@export var wall_jump_state: State

@export_category("Components")
@export var movement_component: MovementComponent

var _can_wall_jump := false

func enter_state() -> void:
	#SoundManager.play_sound("player_jump_sound")
	movement_component.movement_type = movement_component.MovementTypes.WALKING
	movement_component.jump()
	_can_wall_jump = false

func physics_update(delta: float) -> void:
	if _can_wall_jump and Input.is_action_just_pressed("jump") and movement_component.can_wall_jump():
		switch_state.emit(wall_jump_state)
		return

	_can_wall_jump = true

	if movement_component.can_climb():
		switch_state.emit(climb_state)
		return

	if movement_component.is_grounded():
		switch_state.emit(move_state)
	
	# variable jump height: if player releases jump while still moving upward, cut it
	if Input.is_action_just_released("jump") and movement_component.is_falling():
		movement_component.fall()
