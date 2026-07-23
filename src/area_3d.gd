extends Area3D

@export var boost_force := Vector3(0, 50, 0)

func _on_spring_body_entered(body: Node3D) -> void:
	print_debug("Hellnoi")
	if body.has_method("apply_external_impulse"):
		body.apply_external_impulse(boost_force)
