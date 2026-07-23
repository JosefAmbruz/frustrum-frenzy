extends Area3D

@export var boost_force := 30.0

func _on_body_entered(body):
	if body.is_in_group("player"):
		var direction = -global_transform.basis.z.normalized()

		body.velocity = direction * boost_force
