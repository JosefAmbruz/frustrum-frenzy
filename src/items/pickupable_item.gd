extends RigidBody3D

@onready var interactable: Area3D = %Interactable
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# item properties
@export_group("Item Properties")
# @export var throw_force: float = 15.0
@export var boost_jump_power: float = 10.0
@export var player_speed_modifier: float = 1.0 # 1.0 = normal speed
@export var picked_up_label: String = "[E] Drop [LMB] Throw"
@export var item_id: String = "unknown"

var _held := false
var _saved_parent: Node = null
var _saved_transform: Transform3D
var _saved_collision_layer := 0
var _saved_collision_mask := 0
var _saved_linear_velocity := Vector3.ZERO
var _saved_angular_velocity := Vector3.ZERO
var _default_interact_name := ""

func _ready() -> void:
	interactable.interact = _on_interact
	_default_interact_name = interactable.interact_name

func _on_interact(player: CharacterBody3D) -> void:
	if player == null:
		return

	if _held:
		drop(player)
		return

	pickup(player)

func pickup(player: CharacterBody3D) -> void:
	_saved_parent = get_parent()
	_saved_transform = global_transform
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	_saved_linear_velocity = linear_velocity
	_saved_angular_velocity = angular_velocity

	_held = true
	player.set_hand_item(self)
	interactable.interact_name = picked_up_label

	freeze = true
	sleeping = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_shape.disabled = true

	var old_parent := get_parent()
	if old_parent:
		old_parent.remove_child(self)
	player._hold_position.add_child(self)
	global_transform = player._hold_position.global_transform

	collision_layer = 0
	collision_mask = 0

func drop(player: CharacterBody3D) -> void:
	var target_parent: Node = _saved_parent
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent == null:
		return

	var old_parent := get_parent()
	if old_parent:
		old_parent.remove_child(self)
	target_parent.add_child(self)
	global_transform = player._hold_position.global_transform

	show()
	collision_shape.disabled = false
	freeze = false
	sleeping = false
	linear_velocity = _saved_linear_velocity
	angular_velocity = _saved_angular_velocity
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	interactable.interact_name = _default_interact_name
	_held = false
	player.held_item = null
	

func throw(player: CharacterBody3D, aim_direction: Vector3, force: float) -> void:
	drop(player)
	apply_central_impulse(aim_direction * force)
	
