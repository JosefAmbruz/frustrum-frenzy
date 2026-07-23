extends StaticBody3D

@export var boost_force: = 10.0

func _on_body_entered(body)->void:
	if body.is_in_group("player"):
		var direction = -global_transform.basis.z.normalized()
		body.velocity = direction * boost_force
		print_debug("SPRING")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
