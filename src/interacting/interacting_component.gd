extends Node3D

@onready var interaction_label: Label3D = %Label3D
var curr_interactions := []
var can_interact := true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_interact:
		if curr_interactions:
			can_interact = false
			interaction_label.hide()
			
			await curr_interactions[0].interact.call()
			
			can_interact = true

func _process(delta: float) -> void:
	if curr_interactions and can_interact:
		curr_interactions.sort_custom(_sort_by_nearest)
		if curr_interactions[0].is_interactable:
			interaction_label.text = curr_interactions[0].interact_name
			interaction_label.show()
	else:
		interaction_label.hide()
	

func _sort_by_nearest(area1, area2):
	var area1_dist = global_position.distance_to(area1.global_position)
	var area2_dist = global_position.distance_to(area2.global_position)
	
	return area1_dist < area2_dist
	

func _on_interact_range_area_entered(area: Area3D) -> void:
	curr_interactions.push_back(area)

func _on_interact_range_area_exited(area: Area3D) -> void:
	curr_interactions.erase(area)
