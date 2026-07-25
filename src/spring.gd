extends StaticBody3D

@export var boost_force := 10.0

func _on_body_entered(body) -> void:
	if body.is_in_group("player") and body.has_method("apply_external_impulse"):
		var direction := -global_transform.basis.z.normalized()
		body.apply_external_impulse(direction * boost_force)
		print_debug("SPRING")
