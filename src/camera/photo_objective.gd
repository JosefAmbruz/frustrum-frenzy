extends Node3D

func evaluate_photo(actual_player: CharacterBody3D, items_in_camera_view: Array) -> float:
	var total_score = 0.0
	var used_items = []
	
	# 1. FIND TARGETS DYNAMICALLY (immune to renaming in editor)
	var player_target = null
	var item_targets = []
	
	for child in get_children():
		if "must_hold_item_id" in child:
			player_target = child
		elif "required_item_id" in child:
			item_targets.append(child)
			
	print("debug: Evaluating photo. Found ", item_targets.size(), " item targets.")
	print("debug: Real items in camera view: ", items_in_camera_view.size())
	
	# 2. PLAYER EVALUATION
	if player_target:
		var dist_to_player = actual_player.global_position.distance_to(player_target.global_position)
		
		if dist_to_player <= player_target.position_tolerance:
			total_score += 30.0 # Base position score
			
			# Check if player is holding the required item
			if player_target.must_hold_item_id != "none" and player_target.must_hold_item_id != "":
				var hold_id = ""
				if actual_player.held_item and "item_id" in actual_player.held_item:
					hold_id = actual_player.held_item.item_id
					
				if hold_id == player_target.must_hold_item_id:
					total_score += 20.0
					
					# FIX: Mark the held item as "used" so we don't penalize it as extra trash!
					if actual_player.held_item not in used_items:
						used_items.append(actual_player.held_item)
			else:
				# Give free 20 points if player was not required to hold anything
				total_score += 20.0 
	
	# 3. ITEMS EVALUATION
	var score_per_item = 0.0
	if item_targets.size() > 0:
		score_per_item = 50.0 / float(item_targets.size())
		
	for target in item_targets:
		var best_match = null
		var best_dist = 999.0
		
		for actual_item in items_in_camera_view:
			if "item_id" in actual_item and actual_item.item_id == target.required_item_id and not actual_item in used_items:
				var dist = actual_item.global_position.distance_to(target.global_position)
				if dist < best_dist:
					best_dist = dist
					best_match = actual_item
		
		# Did we find a close enough match?
		if best_match and best_dist <= target.position_tolerance:
			total_score += score_per_item
			used_items.append(best_match)
			print("debug: Matched item target (", target.required_item_id, ") with real item.")
		else:
			print("debug: Failed to find matching item for target (", target.required_item_id, ") in range.")
			
	# 4. PENALTY FOR EXTRA ITEMS IN VIEW
	var extra_items_count = items_in_camera_view.size() - used_items.size()
	if extra_items_count > 0:
		print("debug: Penalty applied for ", extra_items_count, " extra items.")
		total_score -= (extra_items_count * 15.0)
		
	return max(0.0, total_score)
