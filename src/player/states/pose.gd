extends State

@export_category("Components")
@export var movement_component: MovementComponent
@export var skin: PlayerSkin

func enter_state() -> void:
	skin.transition("Pose", true)
	movement_component.movement_type = movement_component.MovementTypes.DISABLED

func exit_state() -> void:
	skin.transition("Moving", true)
