@tool
extends Marker3D

const ITEM_MODELS = {
	"pumpkin": preload("res://src/items/models/pumpkin.tscn"),
	"apple": preload("res://src/items/apple.tscn")
}

const ITEM_COLORS = {
	"pumpkin": Color(1.0, 0.5, 0.0, 0.7),
	"apple": Color(0.9, 0.1, 0.1, 0.7)
}

@export_enum("none", "pumpkin", "apple") var must_hold_item_id: String = "none":
	set(value):
		must_hold_item_id = value
		if is_inside_tree() or Engine.is_editor_hint():
			_update_item()

@export var position_tolerance: float = 2.0

var _current_item: Node = null
var _hold_position: Node3D = null

func _ready() -> void:
	_hold_position = get_node_or_null("GhostMesh/Hare/Base/Torso/RightArm/HoldPosition")
	if not Engine.is_editor_hint() and has_node("GhostMesh"):
		$GhostMesh.hide()
	_update_item()

func _update_item() -> void:
	if _current_item:
		_current_item.queue_free()
		_current_item = null

	if must_hold_item_id in ITEM_MODELS:
		var item = ITEM_MODELS[must_hold_item_id].instantiate()
		if _hold_position:
			_hold_position.add_child(item)
			if must_hold_item_id in ITEM_COLORS:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = ITEM_COLORS[must_hold_item_id]
				mat.transparency = 1
				mat.shading_mode = 0
				_apply_material_recursive(item, mat)
			_current_item = item

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)
