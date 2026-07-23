extends Area3D
@export var respawn_point:	Node3D
func _on_body_entered(body:Node3D) -> void:
	if body.has_method("apply_external_impulse"):
		print("Player died")
		body.global_position = respawn_point.global_position # respawn position
		body.velocity = Vector3.ZERO #resets player speed
