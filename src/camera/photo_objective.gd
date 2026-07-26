extends Node3D

# --- SCORING SETTINGS ---
const POINTS_PLAYER_POSITION = 1000.0
const POINTS_PLAYER_ROTATION = 300.0
const POINTS_PLAYER_HOLD = 500.0
const POINTS_PER_ITEM = 1000.0
const PENALTY_EXTRA_ITEM = 200.0

const PERFECT_RADIUS = 1.0
const POSE_BONUS_POINTS = 200
const ROTATION_PERFECT_DOT = 0.99
# ------------------------

# Helper function to calculate quadratic falloff score
func calculate_distance_score(max_points: float, distance: float, max_tolerance: float) -> int:
	# inside the perfect circle = 100% points
	if distance <= PERFECT_RADIUS:
		return int(max_points)
	
	# outside the maximum tolerance = 0 points
	elif distance >= max_tolerance:
		return 0
		
	else:
		var ratio = (distance - PERFECT_RADIUS) / (max_tolerance - PERFECT_RADIUS)
		var multiplier = 1.0 - pow(ratio, 2)
		return int(max_points * multiplier)

func calculate_rotation_score(max_points: float, dot_product: float) -> int:
	if dot_product >= ROTATION_PERFECT_DOT:
		return int(max_points)
	# perfect dot = 0.95 (-18°), below zero means looking opposite direction
	elif dot_product <= 0.0:
		return 0
	else:
		var ratio = dot_product / ROTATION_PERFECT_DOT
		return int(max_points * ratio * ratio * ratio)

func reset_required_items() -> void:
	for child in get_children():
		if "linked_item" in child and child.linked_item:
			var item = child.get_node_or_null(child.linked_item)
			if item and item is PickupableItem:
				if item.has_method("force_drop"):
					item.force_drop()
				item.global_position = item.origin_position
				item.global_rotation = item.origin_rotation
				item.linear_velocity = Vector3.ZERO
				item.angular_velocity = Vector3.ZERO

func evaluate_photo(actual_player: CharacterBody3D, items_in_camera_view: Array, posed: bool = false) -> Dictionary:
	var total_score = 0.0
	var max_possible_score = 0
	var used_items = []
	var details = []
	
	# 1. FIND TARGETS
	var player_target = null
	var item_targets = []
	
	for child in get_children():
		if "must_hold_item_id" in child:
			player_target = child
		elif "required_item_id" in child:
			item_targets.append(child)
			
# 2. PLAYER EVALUATION
	if player_target:
		max_possible_score += POINTS_PLAYER_POSITION
		
		var dist_to_player = actual_player.global_position.distance_to(player_target.global_position)
		
		var pos_score = calculate_distance_score(POINTS_PLAYER_POSITION, dist_to_player, player_target.position_tolerance)
		total_score += pos_score
		
		if pos_score == int(POINTS_PLAYER_POSITION):
			details.append("Player nailed the spot! [+%d]" % pos_score)
		elif pos_score > 0:
			details.append("Player close enough [+%d]" % pos_score)
		else:
			details.append("Player way off!")
		
		# 2a. ROTATION SCORING
		max_possible_score += POINTS_PLAYER_ROTATION
		var player_forward = actual_player.skin.global_transform.basis.z.normalized()
		var target_forward = player_target.global_transform.basis.z.normalized()
		var dot = player_forward.dot(target_forward)
		var rot_score = calculate_rotation_score(POINTS_PLAYER_ROTATION, dot)
		total_score += rot_score
		
		if rot_score == int(POINTS_PLAYER_ROTATION):
			details.append("Perfect rotation! [+%d]" % rot_score)
		elif rot_score > 0:
			details.append("Rotation close enough [+%d]" % rot_score)
		else:
			details.append("Wrong rotation!")

		if player_target.must_hold_item_id != "none" and player_target.must_hold_item_id != "":
			max_possible_score += POINTS_PLAYER_HOLD
			var hold_id = ""
			if actual_player.held_item and "item_id" in actual_player.held_item:
				hold_id = actual_player.held_item.item_id
				
			if hold_id == player_target.must_hold_item_id:
				total_score += POINTS_PLAYER_HOLD
				details.append("Holding %s [+%d]" % [hold_id, POINTS_PLAYER_HOLD])
				if actual_player.held_item not in used_items:
					used_items.append(actual_player.held_item)
			else:
				details.append("Wrong item in hand!")
				
	# 3. ITEMS EVALUATION
	for target in item_targets:
		max_possible_score += POINTS_PER_ITEM

		var linked_item = null
		if target.linked_item:
			linked_item = target.get_node_or_null(target.linked_item)

		if linked_item and linked_item in items_in_camera_view and not linked_item in used_items:
			var dist = linked_item.global_position.distance_to(target.global_position)
			if dist < target.position_tolerance:
				var item_score = calculate_distance_score(POINTS_PER_ITEM, dist, target.position_tolerance)
				total_score += item_score
				used_items.append(linked_item)

				if item_score == int(POINTS_PER_ITEM):
					details.append("%s right where it belongs! [+%d]" % [target.required_item_id, item_score])
				else:
					details.append("%s almost there [+%d]" % [target.required_item_id, item_score])
			else:
				details.append("%s too far away!" % target.required_item_id)
		else:
			details.append("%s not found!" % target.required_item_id)
			
	# 4. PENALTY FOR EXTRA ITEMS IN VIEW
	var extra_items_count = items_in_camera_view.size() - used_items.size()
	if extra_items_count > 0:
		var penalty = extra_items_count * PENALTY_EXTRA_ITEM
		total_score -= penalty
		details.append("Clutter penalty x%d: -%d" % [extra_items_count, penalty])

	total_score = max(0.0, total_score)

	# 5. POSE BONUS (not part of max, cannot exceed max)
	if posed and total_score < max_possible_score:
		var bonus = min(POSE_BONUS_POINTS, max_possible_score - total_score)
		total_score += bonus
		details.append("Strike a pose! [+%d]" % bonus)
	
	return {
		"earned": total_score,
		"max": max_possible_score,
		"details": details
	}
