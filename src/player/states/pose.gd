extends State

@export_category("Components")
@export var movement_component: MovementComponent
@export var skin: PlayerSkin

func enter_state() -> void:
	movement_component.movement_type = movement_component.MovementTypes.DISABLED
	if not EventBus.pose_performed.is_connected(_on_pose_performed):
		EventBus.pose_performed.connect(_on_pose_performed)

func exit_state() -> void:
	if EventBus.pose_performed.is_connected(_on_pose_performed):
		EventBus.pose_performed.disconnect(_on_pose_performed)
	skin.transition("Moving", true)

func _on_pose_performed() -> void:
	skin.transition("Pose", true)
	if EventBus.pose_performed.is_connected(_on_pose_performed):
		EventBus.pose_performed.disconnect(_on_pose_performed)
