extends Node3D

# --- SCORING SETTINGS ---
const POINTS_PLAYER_POSITION = 1000.0
const POINTS_PLAYER_HOLD = 500.0
const POINTS_PER_ITEM = 1000.0
const PENALTY_EXTRA_ITEM = 200.0
# ------------------------

func evaluate_photo(actual_player: CharacterBody3D, items_in_camera_view: Array) -> Dictionary:
	var total_score = 0.0
	var max_possible_score = 0.0 # FIX: We calculate this automatically!
	var used_items = []
	
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
		if dist_to_player <= player_target.position_tolerance:
			total_score += POINTS_PLAYER_POSITION
			
			# Check holding
			if player_target.must_hold_item_id != "none" and player_target.must_hold_item_id != "":
				max_possible_score += POINTS_PLAYER_HOLD
				var hold_id = ""
				if actual_player.held_item and "item_id" in actual_player.held_item:
					hold_id = actual_player.held_item.item_id
					
				if hold_id == player_target.must_hold_item_id:
					total_score += POINTS_PLAYER_HOLD
					if actual_player.held_item not in used_items:
						used_items.append(actual_player.held_item)
			else:
				# If no item is required, we don't add to max_possible_score
				pass 
				
	# 3. ITEMS EVALUATION
	for target in item_targets:
		max_possible_score += POINTS_PER_ITEM # Each required item adds to the max potential
		
		var best_match = null
		var best_dist = 999.0
		
		for actual_item in items_in_camera_view:
			if "item_id" in actual_item and actual_item.item_id == target.required_item_id and not actual_item in used_items:
				var dist = actual_item.global_position.distance_to(target.global_position)
				if dist < best_dist:
					best_dist = dist
					best_match = actual_item
		
		if best_match and best_dist <= target.position_tolerance:
			total_score += POINTS_PER_ITEM
			used_items.append(best_match)
			
	# 4. PENALTY FOR EXTRA ITEMS IN VIEW
	var extra_items_count = items_in_camera_view.size() - used_items.size()
	if extra_items_count > 0:
		total_score -= (extra_items_count * PENALTY_EXTRA_ITEM)
		
	total_score = max(0.0, total_score) # No negative scores
	
	# Return both the earned score and the maximum possible score
	return {
		"earned": total_score,
		"max": max_possible_score
	}
