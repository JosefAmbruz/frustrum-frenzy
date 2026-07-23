extends Area3D

@export var force_mult := 50.0

@onready var trampoline_raycast := %TrampolineDirection

func _on_spring_body_entered(body: Node3D) -> void:
	print_debug("Hellnoi")
	if body.has_method("apply_external_impulse"):
		body.apply_external_impulse(get_aim_direction() * force_mult)

func get_aim_direction() -> Vector3:
	var local_dir = trampoline_raycast.target_position.normalized()
	var global_dir = trampoline_raycast.global_basis * local_dir
	
	return global_dir
