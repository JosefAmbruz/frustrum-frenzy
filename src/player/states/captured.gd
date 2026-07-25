extends State

@export_category("Components")
@export var movement_component: MovementComponent

func enter_state() -> void:
	movement_component.movement_type = movement_component.MovementTypes.DISABLED
