extends StaticBody3D

@export var countdown_time: int = 15
@export var respawn_offset: Vector3 = Vector3(0, 1, 2)

var in_camera: bool = false
var _interact_lock := false
var dot_tween: Tween
var _has_posed := false
var _required_pose_key: String = ""
var _key_labels := {"interact": "[E]", "left_click": "LMB", "jump": "SPACE"}
var _reference_texture: Texture2D
var _captured_texture: Texture2D
var _ghosts_visible := true
var _photo_taken := false

@onready var view_camera = $Camera3D
@onready var countdown_timer = $CountdownTimer
@onready var countdown_label: Label = %CountdownLabel
@onready var camera_overlay: Control = %CameraOverlay
@onready var red_dot: Panel = %RedDot
@onready var photo_result_ui: Control = %PhotoResultUI
@onready var captured_image: TextureRect = %CapturedImage
@onready var toggle_hint: HBoxContainer = %ToggleHint
@onready var score_label: Label = %ScoreLabel
@onready var details_label: Label = %DetailsLabel
@onready var fade_rect: ColorRect = %FadeRect
@onready var interactable: Area3D = %Interactable
@onready var timer_ui: Control = %TimerUI
@onready var pose_timer: Timer = $PoseTimer
@onready var pose_intro_timer: Timer = $PoseIntroTimer
@onready var pose_prompt: Label = %PosePrompt

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable.interact = _on_interact
	if timer_ui:
		timer_ui.visible = false
	camera_overlay.visible = false
	EventBus.pose_performed.connect(_on_pose_performed)
	print("debug: Camera start")

func _on_pose_performed() -> void:
	_has_posed = true

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
	# toggle ghosts on photo result
	if photo_result_ui.visible and event.is_action_pressed("left_click"):
		_toggle_ghost_overlay()
		get_viewport().set_input_as_handled()
		return

	if photo_result_ui.visible and event.is_action_pressed("interact"):
		photo_result_ui.visible = false
		_photo_taken = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		EventBus.player_released.emit.call_deferred()
		EventBus.interaction_text_toggled.emit.call_deferred(true)
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
		
		# play camera countdown music
		SoundManager.play_camera_music()


# Timer ended
func _on_countdown_timer_timeout() -> void:
	EventBus.player_captured.emit() # lock player movement
	timer_ui.visible = false
	EventBus.interaction_text_toggled.emit(false) # turn off text like "Drop [E]"

	view_camera.make_current() # switch to tripod

	# POSING WINDOW - Phase 1: "POSE!" intro
	_has_posed = false

	var keys := ["interact", "left_click", "jump"]
	_required_pose_key = keys[randi() % keys.size()]

	pose_prompt.text = "POSE!"
	pose_prompt.modulate.a = 0.0
	pose_prompt.visible = true

	var intro_tween = create_tween()
	intro_tween.tween_property(pose_prompt, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	intro_tween.tween_interval(0.4)
	intro_tween.tween_property(pose_prompt, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)

	pose_intro_timer.start()


func _on_pose_intro_timer_timeout() -> void:
	pose_prompt.text = _key_labels[_required_pose_key]
	pose_prompt.modulate.a = 0.0
	var key_tween = create_tween().set_ease(Tween.EASE_OUT)
	key_tween.tween_property(pose_prompt, "modulate:a", 1.0, 0.2)

	EventBus.pose_window_started.emit(1.0, _required_pose_key)
	pose_timer.start(1.0)

func _on_pose_timer_timeout() -> void:
	EventBus.pose_window_ended.emit()
	EventBus.interaction_text_toggled.emit(false)
	pose_prompt.visible = false

	# wait for GPU to render frames
	fade_rect.visible = false
	await get_tree().process_frame
	await get_tree().process_frame

	# turn off highlights so they don't appear in the photo
	disable_highlights()

	# --- REFERENCE PHOTO WITH GHOSTS ---
	_ghosts_visible = true
	toggle_hologram(true)
	await get_tree().process_frame
	await get_tree().process_frame

	var ref_img = get_viewport().get_texture().get_image()
	_reference_texture = ImageTexture.create_from_image(ref_img)

	toggle_hologram(false)
	await get_tree().process_frame

	# fade to black (or white)
	var flash_tween = create_tween()
	flash_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.15)
	await flash_tween.finished

	# work in dark
	camera_overlay.visible = false

	# play camera click sound
	SoundManager.play_sound("camera_click_sound")
	
	# restore background music
	SoundManager.restore_background_music()

	# --- FINAL PHOTO WITHOUT GHOSTS ---
	var viewport_img = get_viewport().get_texture().get_image()
	_captured_texture = ImageTexture.create_from_image(viewport_img)
	fade_rect.visible = true

	# show reference photo (with ghosts) first
	captured_image.texture = _reference_texture
	photo_result_ui.visible = true
	_photo_taken = true
	toggle_hint.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.interaction_text_toggled.emit(false)

	# reveal
	var reveal_tween = create_tween()
	reveal_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.2)

	# evaluate
	evaluate_new_objectives()

	view_camera.clear_current()
	interactable.is_interactable = true

	print("debug: Camera shoot")


func _toggle_ghost_overlay() -> void:
	if not _photo_taken:
		return
	_ghosts_visible = not _ghosts_visible
	if _ghosts_visible:
		captured_image.texture = _reference_texture
		toggle_hint.text = "[LMB] Hide ghosts  |  [E] Close"
	else:
		captured_image.texture = _captured_texture
		toggle_hint.text = "[LMB] Show ghosts  |  [E] Close"

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
	var score_result = active_objective.evaluate_photo(player_node, visible_items, _has_posed)
	
	var final_score = score_result["earned"]
	var max_score = score_result["max"]
	var details_array = score_result["details"]
	
	# Calculate percentage just for the colors
	var percentage = 0.0
	if max_score > 0:
		percentage = (final_score / max_score) * 100.0
	
	# Update UI to show format: 2500 / 3500 with grade
	var grade_text = ""
	if percentage >= 90.0:
		grade_text = "STAR PHOTO!"
		score_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	elif percentage >= 80.0:
		grade_text = "Great shot!"
		score_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.6))
	elif percentage >= 50.0:
		grade_text = "Nice try!"
		score_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	else:
		grade_text = "Try again!"
		score_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	score_label.text = "%d / %d\n%s" % [final_score, max_score, grade_text]

	# details with playful prefixes
	if details_label != null:
		var details_text = ""
		for detail in details_array:
			var prefix = "> "
			if "wrong" in detail or "not found" in detail or "too far" in detail or "Clutter" in detail:
				prefix = "x "
			elif "nailed" in detail or "belongs" in detail or "Pose" in detail:
				prefix = "* "
			details_text += prefix + detail + "\n"

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
