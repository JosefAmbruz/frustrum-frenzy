extends State

@export_category("Next States")
@export var move_state: State
@export var climb_state: State

@export_category("Components")
@export var movement_component: MovementComponent
@export var skin: PlayerSkin


func enter_state() -> void:
	SoundManager.play_sound("player_jump_sound")
	skin.transition("Jump", true)
	movement_component.movement_type = movement_component.MovementTypes.WALKING
	movement_component.do_wall_jump()

func physics_update(delta: float) -> void:
	if movement_component.can_climb():
		switch_state.emit(climb_state)
		return

	if movement_component.is_grounded():
		switch_state.emit(move_state)
		return

	if Input.is_action_just_pressed("jump") and movement_component.can_wall_jump():
		movement_component.do_wall_jump()
