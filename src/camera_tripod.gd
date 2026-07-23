extends StaticBody3D

# TODO: this is temporary for testing - one camera = one scene
@export var player_target_marker: Marker3D

var in_camera: bool = false
var _interact_lock := false
var dot_tween: Tween

@onready var view_camera = $Camera3D
@onready var countdown_timer = $CountdownTimer
@onready var countdown_label = $CanvasLayer/CountdownLabel
@onready var camera_overlay = $CanvasLayer/CameraOverlay
@onready var red_dot = $CanvasLayer/CameraOverlay/RedDot
@onready var photo_result_ui = $CanvasLayer/PhotoResultUI
@onready var captured_image = $CanvasLayer/PhotoResultUI/CapturedImage
@onready var fade_rect = $CanvasLayer/FadeRect
@onready var interactable: Area3D = %Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable.interact = _on_interact
	countdown_label.visible = false
	camera_overlay.visible = false
	print("debug: Camera start")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not countdown_timer.is_stopped():
		countdown_label.text = str(ceil(int(countdown_timer.time_left)))

# Switch and leave camera view
func _unhandled_input(event: InputEvent) -> void:
	# throw away photo
	if photo_result_ui.visible and event.is_action_pressed("left_click"):
		photo_result_ui.visible = false
		# TODO: back to player interaction
		return

	if event.is_action_released("interact"):
		_interact_lock = false
		return
	
	# If we click E in camera
	if event.is_action_pressed("interact") and in_camera and not _interact_lock:
		# Leaving camera
		view_camera.clear_current()
		in_camera = false
		camera_overlay.visible = false
		interactable.is_interactable = true
		print("debug: Cleared camera view")
		_interact_lock = true

		if dot_tween:
			dot_tween.kill()
		red_dot.modulate.a = 1.0
		
	# If we click LMB in camera
	if event.is_action_pressed("left_click") and in_camera:
		view_camera.clear_current()
		in_camera = false
		
		if dot_tween:
			dot_tween.kill()
		red_dot.modulate.a = 1.0
		
		countdown_timer.start(10)
		countdown_label.visible = true
		camera_overlay.visible = false
		print("debug: Start timer")


# Timer ended
func _on_countdown_timer_timeout() -> void:
	countdown_label.visible = false
	
	# TODO: lock player movement
	
	# grace period - leave one second to finish movement
	await get_tree().create_timer(1.0).timeout
	
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
	
	# make a picture and create texture
	var viewport_img = get_viewport().get_texture().get_image()
	var final_texture = ImageTexture.create_from_image(viewport_img)
	fade_rect.visible = true
	
	# show picture
	captured_image.texture = final_texture
	photo_result_ui.visible = true
	
	# show picture
	var reveal_tween = create_tween()
	reveal_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.2)
	
	view_camera.clear_current()
	
	interactable.is_interactable = true

	evaluate_photo_scene()

	print("debug: Camera shoot")

func _on_interact():
	if not in_camera:
		_interact_lock = true
		# Turn off in-world interaactions
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

func evaluate_photo_scene() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	
	if player_node and player_target_marker:
		var final_score = calculate_object_score(player_node, player_target_marker)
		print("Player captured to ", round(final_score), " %")
	else:
		print("Error: No player found or Marker3D is missing")
	
func calculate_object_score(object_node: Node3D, target_marker: Marker3D) -> float:
	# if object is in front of objective
	if view_camera.is_position_behind(object_node.global_position):
		return 0.0
	
	# Evaluation of 2D coordinates (X, Y on photo)
	var actual_2d_pos = view_camera.unproject_position(object_node.global_position) # player
	var ideal_2d_pos = view_camera.unproject_position(target_marker.global_position) # marker
	
	var pixel_distance = actual_2d_pos.distance_to(ideal_2d_pos)
	var max_pixel_tolerance = 300.0 # tolerance in pixels on screen
	var composition_score = 100.0 * (1.0 - (pixel_distance / max_pixel_tolerance))
	composition_score = clamp(composition_score, 0.0, 100.0)
	
	# Evaluation of size/depth (distance)
	var actual_dist_to_cam = object_node.global_position.distance_to(view_camera.global_position)
	var ideal_dist_to_cam = target_marker.global_position.distance_to(view_camera.global_position)
	
	var depth_difference = abs(actual_dist_to_cam - ideal_dist_to_cam)
	var max_depth_tolerance = 4.0 # toleration in meters (if more than 4.0, no points for size)
	var size_score = 100.0 * (1.0 - (depth_difference / max_depth_tolerance))
	size_score = clamp(size_score, 0.0, 100.0)
	
	return (composition_score + size_score) / 2.0
	
