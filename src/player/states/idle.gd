extends State

@export_category("Next States")
@export var move_state: State
@export var jump_state: State

@export_category("Components")
@export var movement_component: MovementComponent
@export var movement_config: MovementConfig

func enter_state() -> void:
	movement_component.movement_type = movement_component.MovementTypes.DISABLED

func update(delta: float) -> void:	
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if raw_input != Vector2.ZERO:
		switch_state.emit(move_state)
