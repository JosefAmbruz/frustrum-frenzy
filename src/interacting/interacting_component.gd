extends Node3D

@export var player: NodePath

@onready var interaction_label: Label3D = %Label
var curr_interactions := []
var can_interact := true
var interaction_blocked := false

func _get_player_node() -> Node:
	if player != NodePath():
		return get_node_or_null(player)
	return get_tree().get_first_node_in_group("player")

func _ready() -> void:
	EventBus.interaction_text_toggled.connect(_on_interaction_text_toggled)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_interact:
		if curr_interactions:
			can_interact = false
			interaction_label.hide()
			
			await curr_interactions[0].interact.call(_get_player_node())
			
			can_interact = true

func _process(delta: float) -> void:
	if curr_interactions and can_interact and not interaction_blocked:
		curr_interactions.sort_custom(_sort_by_nearest)
		if curr_interactions[0].is_interactable:
			interaction_label.text = curr_interactions[0].interact_name
			interaction_label.show()
	else:
		interaction_label.hide()
	

func _on_interaction_text_toggled(visible: bool) -> void:
	interaction_blocked = not visible
	if interaction_blocked:
		interaction_label.hide()

func _sort_by_nearest(area1, area2):
	var area1_dist = global_position.distance_to(area1.global_position)
	var area2_dist = global_position.distance_to(area2.global_position)
	
	return area1_dist < area2_dist
	

func _on_interact_range_area_entered(area: Area3D) -> void:
	curr_interactions.push_back(area)

func _on_interact_range_area_exited(area: Area3D) -> void:
	curr_interactions.erase(area)
