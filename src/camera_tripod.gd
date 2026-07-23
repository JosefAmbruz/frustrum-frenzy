extends StaticBody3D

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
		
		EventBus.player_released.emit()

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
		
		print_debug("Release 2")
		
		EventBus.player_released.emit()
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
	
	print("debug: Camera shoot")

func _on_interact(player : CharacterBody3D):
	if not in_camera:
		# Capture players' movement
		EventBus.player_captured.emit()
		
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

	
