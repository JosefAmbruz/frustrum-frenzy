extends StaticBody3D

@export var target_photo: Texture2D
@export var countdown_time: int = 15
@export var respawn_offset: Vector3 = Vector3(0, 1, 2)

var in_camera: bool = false
var _interact_lock := false
var dot_tween: Tween

@onready var view_camera = $Camera3D
@onready var countdown_timer = $CountdownTimer
@onready var countdown_label = $CanvasLayer/TimerUI/CountdownLabel
@onready var camera_overlay = $CanvasLayer/CameraOverlay
@onready var red_dot = $CanvasLayer/CameraOverlay/RedDot
@onready var photo_result_ui = $CanvasLayer/PhotoResultUI
@onready var captured_image = $CanvasLayer/PhotoResultUI/ResultContainer/PhotoContainer/CapturedFrame/CapturedImage
@onready var reference_image = $CanvasLayer/PhotoResultUI/ResultContainer/PhotoContainer/ReferenceFrame/ReferenceImage
@onready var score_label = $CanvasLayer/PhotoResultUI/ResultContainer/ScoreContainer/ScoreLabel
@onready var details_label = $CanvasLayer/PhotoResultUI/ResultContainer/ScoreContainer/DetailsLabel
@onready var fade_rect = $CanvasLayer/FadeRect
@onready var interactable: Area3D = %Interactable
@onready var timer_ui = $CanvasLayer/TimerUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable.interact = _on_interact
	if timer_ui:
		timer_ui.visible = false
	camera_overlay.visible = false
	print("debug: Camera start")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not countdown_timer.is_stopped():
		var time_left = countdown_timer.time_left
		
		countdown_label.text = "%.1f s" % time_left
		
		if time_left <= 5.0:
			countdown_label.add_theme_color_override("font_color", Color.RED)
		else:
			countdown_label.add_theme_color_override("font_color", Color.WHITE)

# Switch and leave camera view
func _unhandled_input(event: InputEvent) -> void:
	# throw away photo
	if photo_result_ui.visible and event.is_action_pressed("left_click"):
		photo_result_ui.visible = false
		get_viewport().set_input_as_handled() # consume the input so the player doesnt throw the item
		EventBus.player_released.emit() # back to player interaction
		return

	if event.is_action_released("interact"):
		_interact_lock = false
		return
	
	# If we click E in camera
	if event.is_action_pressed("interact") and in_camera and not _interact_lock:
		# Leaving camera
		view_camera.clear_current()
		in_camera = false
		toggle_hologram(false)
		disable_highlights()
		camera_overlay.visible = false
		interactable.is_interactable = true
		print("debug: Cleared camera view")
		_interact_lock = true
		
		EventBus.player_released.emit()

		if dot_tween:
			dot_tween.kill()
		red_dot.modulate.a = 1.0
		
	# If we click LMB in camera - start countdown
	if event.is_action_pressed("left_click") and in_camera:
		view_camera.clear_current()
		in_camera = false
		toggle_hologram(false)
		
		if dot_tween:
			dot_tween.kill()
		red_dot.modulate.a = 1.0
		
		reset_objective_items()
		countdown_timer.start(countdown_time)
		timer_ui.visible = true
		camera_overlay.visible = false
		
		print_debug("Release 2")
		
		EventBus.player_released.emit()
		print("debug: Start timer")


# Timer ended
func _on_countdown_timer_timeout() -> void:    
	EventBus.player_captured.emit() # lock player movement
	timer_ui.visible = false
	EventBus.interaction_text_toggled.emit(false) # turn off text like "Drop [E]"

	# fade to black (or white)
	var flash_tween = create_tween()
	flash_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.15)
	await flash_tween.finished # wait for tweet to finish
	
	# work in dark
	camera_overlay.visible = false
	view_camera.make_current() # switch to tripod
	
	# wait for GPU to render frames
	fade_rect.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	
	# turn off highlights so they don't appear in the photo
	disable_highlights()
	
	# play camera click sound
	SoundManager.play_sound("camera_click_sound")

	# make a picture and create texture
	var viewport_img = get_viewport().get_texture().get_image()
	var final_texture = ImageTexture.create_from_image(viewport_img)
	fade_rect.visible = true
	
	# show picture
	captured_image.texture = final_texture
	photo_result_ui.visible = true
	EventBus.interaction_text_toggled.emit(true) # turn on text like "Drop [E]"

	# show picture
	var reveal_tween = create_tween()
	reveal_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.2)

	# Call the new evaluation system
	evaluate_new_objectives()

	view_camera.clear_current()
	interactable.is_interactable = true
	
	print("debug: Camera shoot")

func _on_interact(player : CharacterBody3D):
	if not in_camera:
		player.current_checkpoint = global_position + global_transform.basis * respawn_offset

		# Capture players' movement
		EventBus.player_captured.emit()
		
		_interact_lock = true
		# Turn off in-world interactions
		interactable.is_interactable = false
		# Camera entered
		view_camera.make_current()
		camera_overlay.visible = true
		print("debug: Switched to camera view")
		
		# Hande red dot tween
		if dot_tween:
			dot_tween.kill()
		dot_tween = create_tween().set_loops()
		dot_tween.set_trans(Tween.TRANS_SINE)
		dot_tween.tween_property(red_dot, "modulate:a", 0.0, 1.0)
		dot_tween.tween_property(red_dot, "modulate:a", 1.0, 1.0)
		
		in_camera = true
		toggle_hologram(true)
		enable_highlights()

# --- NEW EVALUATION SYSTEM INTEGRATION ---
func evaluate_new_objectives() -> void:
	if target_photo != null:
		reference_image.texture = target_photo
	else:
		print("ERROR: Missing target photo in inspector!")
		
	var player_node = get_tree().get_first_node_in_group("player")
	
	# Find the Objectives folder
	if not has_node("Objectives"):
		score_label.text = "Score: N/A"
		return
		
	var objectives_folder = $Objectives
	var active_objective = null
	
	# Find the first valid PhotoObjective in the folder
	for child in objectives_folder.get_children():
		if child.has_method("evaluate_photo"):
			active_objective = child
			break
			
	if active_objective == null:
		score_label.text = "Score: N/A"
		return
		
	# Get all items currently visible to this camera
	var visible_items = get_items_in_camera_view()
	
# Evaluate! returns a Dictionary now
	var score_result = active_objective.evaluate_photo(player_node, visible_items)
	
	var final_score = score_result["earned"]
	var max_score = score_result["max"]
	var details_array = score_result["details"]
	
	# Calculate percentage just for the colors
	var percentage = 0.0
	if max_score > 0:
		percentage = (final_score / max_score) * 100.0
	
	# Update UI to show format: 2500 / 3500
	score_label.text = "Score: %d / %d\n" % [final_score, max_score]
	
	if percentage >= 80.0:
		score_label.add_theme_color_override("font_color", Color.GREEN)
	elif percentage >= 50.0:
		score_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		score_label.add_theme_color_override("font_color", Color.RED)
	
	# details
	if details_label != null:
		var details_text = ""
		for detail in details_array:
			details_text += detail + "\n"
			
		details_label.text = details_text

# Helper function to find all items the camera can see
func get_items_in_camera_view() -> Array:
	var visible_items = []
	# Assumes all items are in a group called "pickupable_item"
	# Make sure to add your items to this group in their scene!
	var all_items = get_tree().get_nodes_in_group("pickupable")
	
	for item in all_items:
		# Check if item is in front of camera
		if not view_camera.is_position_behind(item.global_position):
			# Check if item is inside the camera's viewport frustum
			var unprojected = view_camera.unproject_position(item.global_position)
			var viewport_rect = get_viewport().get_visible_rect()
			
			if viewport_rect.has_point(unprojected):
				visible_items.append(item)
				
	return visible_items


func toggle_hologram(show_hologram: bool) -> void:
	if not has_node("Objectives"):
		return
		
	var objectives_folder = $Objectives
	
	# loop through all objectives
	for objective in objectives_folder.get_children():
		# loop through all targets inside the objective (TargetPlayer, TargetItem)
		for target in objective.get_children():
			# if the target has a GhostMesh, change its visibility
			if target.has_node("GhostMesh"):
				target.get_node("GhostMesh").visible = show_hologram

func reset_objective_items() -> void:
	if not has_node("Objectives"):
		return
	for objective in $Objectives.get_children():
		if objective.has_method("reset_required_items"):
			objective.reset_required_items()

func enable_highlights() -> void:
	if not has_node("Objectives"):
		return
	for objective in $Objectives.get_children():
		for target in objective.get_children():
			if target.has_method("set_highlight"):
				target.set_highlight(true)

func disable_highlights() -> void:
	if not has_node("Objectives"):
		return
	for objective in $Objectives.get_children():
		for target in objective.get_children():
			if target.has_method("set_highlight"):
				target.set_highlight(false)
