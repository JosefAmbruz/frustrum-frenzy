@tool
extends Marker3D

# Přidali jsme setter - jakmile změníš hodnotu v Inspektoru, zavolá se _update_ghost()
@export_enum("none", "pumpkin", "apple") var must_hold_item_id: String = "none":
	set(value):
		must_hold_item_id = value
		if is_inside_tree():
			_update_ghost()

@export var position_tolerance: float = 2.0

const PLAYER_SKIN_SCENE = preload("res://src/player_skin.tscn")
const HOLOGRAM_MATERIAL = preload("res://src/resources/hologram_blue.tres")

# Cesty k čistým modelům (ne RigidBody itemům, aby to nedělalo v editoru fyzikální chyby)
const ITEM_MODELS = {
	"pumpkin": preload("res://src/items/models/pumpkin.tscn"),
	"apple": preload("res://src/items/apple.tscn")
}

func _ready() -> void:
	_update_ghost()
	
	if not Engine.is_editor_hint():
		if has_node("GhostMesh"):
			$GhostMesh.hide()

func _update_ghost() -> void:
	if not is_node_ready() or not has_node("GhostMesh"):
		return
		
	var ghost_node = $GhostMesh
	
	# 1. Vyčistíme staré modely
	for child in ghost_node.get_children():
		child.queue_free()
		
	if ghost_node is MeshInstance3D:
		ghost_node.mesh = null
		
	# 2. Vytvoříme instanci skinu hráče
	if PLAYER_SKIN_SCENE:
		var skin_instance = PLAYER_SKIN_SCENE.instantiate()
		ghost_node.add_child(skin_instance)
		
		# Obarvíme POUZE hráče na modro (před přidáním itemu)
		_apply_material_recursive(skin_instance, HOLOGRAM_MATERIAL)
		
		# 3. Pokud má něco držet, přidáme to do ruky
		if must_hold_item_id in ITEM_MODELS and ITEM_MODELS[must_hold_item_id] != null:
			var item_instance = ITEM_MODELS[must_hold_item_id].instantiate()

			# Pokusíme se najít HoldPosition uzel (pokud je přímo ve skinu)
			var hold_pos = _find_node_by_name(skin_instance, "HoldPosition")

			if hold_pos:
				hold_pos.add_child(item_instance)
			else:
				# HoldPosition je v player.tscn na PlayerSkin/SpringArm3D/HoldPosition,
				# vytvoříme stejnou strukturu i pro ghosta
				var spring_arm = SpringArm3D.new()
				spring_arm.position = Vector3(0, 0.6783708, -0.69625014)
				spring_arm.spring_length = 1.65
				skin_instance.add_child(spring_arm)

				hold_pos = Marker3D.new()
				hold_pos.name = "HoldPosition"
				spring_arm.add_child(hold_pos)

				hold_pos.add_child(item_instance)

			# Předmět lehce zprůhledníme, aby to pořád vypadalo jako duch (ale zachová si své barvy)
			_make_item_ghostly(item_instance)

# Pomocná funkce pro obarvení všech částí hráče
func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

# Pomocná funkce pro vyhledání uzlu (protože nemůžeme použít %HoldPosition na instanci)
func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, target_name)
		if result:
			return result
	return null

# Zprůhlední předmět, ale zachová jeho originální barvy pro čitelnost
func _make_item_ghostly(node: Node) -> void:
	if node is MeshInstance3D:
		# Vytáhneme stávající materiál a uděláme ho průhledný
		var active_mat = node.mesh.surface_get_material(0) if node.mesh and node.mesh.get_surface_count() > 0 else null
		if active_mat and active_mat is StandardMaterial3D:
			var ghost_mat = active_mat.duplicate()
			ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost_mat.albedo_color.a = 0.65 # Průhlednost
			ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Aby svítil ve tmě
			node.material_override = ghost_mat
			
	for child in node.get_children():
		_make_item_ghostly(child)
