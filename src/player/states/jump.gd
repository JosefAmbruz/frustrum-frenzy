extends State

@export_category("Next States")
@export var move_state: State

@export_category("Components")
@export var movement_component: MovementComponent

func enter_state() -> void:
	movement_component.movement_type = movement_component.MovementTypes.WALKING
	movement_component.jump()

func physics_update(delta: float) -> void:
	if movement_component.is_grounded():
		switch_state.emit(move_state)
	
	# variable jump height: if player releases jump while still moving upward, cut it
	if Input.is_action_just_released("jump") and movement_component.is_falling():
		movement_component.fall()
