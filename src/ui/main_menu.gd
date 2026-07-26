extends Control

@export var game_scene: PackedScene
@export var credits_scene: PackedScene


func _on_start_game_button_pressed() -> void:
<<<<<<< Updated upstream
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	get_tree().change_scene_to_packed(next_scene)


func _on_credits_button_pressed() -> void:
	pass # Replace with function body.


func _on_exit_button_pressed() -> void:
	get_tree().quit()
=======
	get_tree().change_scene_to_packed(game_scene)


func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_packed(credits_scene)
>>>>>>> Stashed changes
