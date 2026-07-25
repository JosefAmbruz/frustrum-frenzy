class_name MovementQuery extends Node

@export_category("Components")
@export var character_body: CharacterBody3D
@export var coyote_time: CoyoteTime
@export var movement_config: MovementConfig

func is_grounded() -> bool:
	return character_body.is_on_floor()

func can_jump() -> bool:
	if coyote_time:
		return character_body.is_on_floor() or coyote_time.get_time_left()

	return character_body.is_on_floor()

func can_wall_jump() -> bool:
	#TODO
	return false

func can_climb() -> bool:
	#TODO
	return false

func get_gravity() -> float:
	return (2.0 * movement_config.jump_height) / (movement_config.jump_time_to_apex * movement_config.jump_time_to_apex)
