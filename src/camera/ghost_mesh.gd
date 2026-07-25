@tool
extends Marker3D

@export_enum("none", "pumpkin", "apple") var must_hold_item_id: String = "none"
@export var position_tolerance: float = 2.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		if has_node("GhostMesh"):
			$GhostMesh.hide()
