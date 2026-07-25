extends Area3D

func _on_body_entered(body:Node3D) -> void:
	# PLAYER RESPAWN
	if body.is_in_group("player"):
		print("debug: Player fell out of bounds")
		
		# check if the player has our new checkpoint variable
		if "current_checkpoint" in body:
			body.global_position = body.current_checkpoint
		else:
			body.global_position = Vector3.ZERO
			body.global_position.y = 3
		
		# stop falling momentum
		if "velocity" in body:
			body.velocity = Vector3.ZERO

	# ITEM RESPAWN
	elif body.is_in_group("pickupable"):
		print("debug: Item fell out of bounds: ", body.name)
		call_deferred("_respawn_item", body)
		
# Helper function to safely reset physics item at the end of the frame
func _respawn_item(item: RigidBody3D) -> void:
	# read the saved origin point from the item script
	if "origin_position" in item:
		item.global_position = item.origin_position
	if "origin_rotation" in item:
		item.global_rotation = item.origin_rotation
		
	# stop momentum and spin so it doesnt fly away after respawn
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
