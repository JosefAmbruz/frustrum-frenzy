@tool
extends Marker3D

const MESH_DICT = {
	"pumpkin": preload("res://assets/models/items/pumpkin.glb"), 
	"apple": preload("res://assets/models/items/apple.glb")
}

@export_enum("pumpkin", "apple") var required_item_id: String = "pumpkin":
	set(value):
		required_item_id = value
		_update_ghost()

# INCREASED TOLERANCE: 2.0 meters gives the player a fair chance to place the item
@export var position_tolerance: float = 2.0 

func _ready() -> void:
	# 1. ALWAYS load the correct 3D model (both in editor and in game)
	_update_ghost()
	
	# 2. If we are playing the game, hide it immediately
	# (The camera tripod will make it visible later)
	if not Engine.is_editor_hint():
		if has_node("GhostMesh"):
			$GhostMesh.hide()

func _update_ghost() -> void:
	if not is_node_ready() or not has_node("GhostMesh"):
		return
		
	var ghost_node = $GhostMesh
	
	# 1. Clear previous instantiated .glb scenes if they exist
	for child in ghost_node.get_children():
		child.queue_free()
		
	if required_item_id in MESH_DICT:
		var resource = MESH_DICT[required_item_id]
		
		# If the resource is a direct Mesh (.res, .obj)
		if resource is Mesh:
			ghost_node.mesh = resource
			
		# If the resource is a full Scene (.glb, .tscn)
		elif resource is PackedScene:
			ghost_node.mesh = null # Clear base mesh
			var instance = resource.instantiate()
			ghost_node.add_child(instance)
			
			# Recursively apply our blue hologram material to the .glb parts
			if ghost_node.material_override != null:
				_apply_material_recursive(instance, ghost_node.material_override)
	else:
		ghost_node.mesh = null

# Helper function to tint the entire .glb model blue
func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)
