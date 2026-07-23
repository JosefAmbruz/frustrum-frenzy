extends StaticBody3D

var can_interact: bool = false
var in_camera: bool = false
var dot_tween: Tween

@onready var view_camera = $Camera3D
@onready var interact_label = $Label3D
@onready var countdown_timer = $CountdownTimer
@onready var countdown_label = $CanvasLayer/CountdownLabel
@onready var camera_overlay = $CanvasLayer/CameraOverlay
@onready var red_dot = $CanvasLayer/CameraOverlay/RedDot

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interact_label.visible = false
	countdown_label.visible = false
	camera_overlay.visible = false
	print("debug: Camera start")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not countdown_timer.is_stopped():
		countdown_label.text = str(ceil(int(countdown_timer.time_left)))

# Switch and leave camera view
func _unhandled_input(event: InputEvent) -> void:
	if not can_interact:
		return
	if event.is_action_pressed("interact"):
		if not in_camera:
			# Camera entered
			view_camera.make_current()
			in_camera = true
			interact_label.visible = false # trun off "Press E" label
			camera_overlay.visible = true
			print("debug: Switched to camera view")
			
			# Hande red dot tween
			if dot_tween:
				dot_tween.kill()
			dot_tween = create_tween().set_loops()
			dot_tween.set_trans(Tween.TRANS_SINE)
			dot_tween.tween_property(red_dot, "modulate:a", 0.0, 1.0)
			dot_tween.tween_property(red_dot, "modulate:a", 1.0, 1.0)

		else:
			# Leaving camera
			view_camera.clear_current()
			in_camera = false
			interact_label.visible = true
			camera_overlay.visible = false
			print("debug: Cleared camera view")

			if dot_tween:
				dot_tween.kill()
			red_dot.modulate.a = 1.0

	if event.is_action_pressed("left_click") and can_interact and in_camera:
		view_camera.clear_current()
		in_camera = false
		
		if dot_tween:
			dot_tween.kill()
		red_dot.modulate.a = 1.0
		
		countdown_timer.start(15)
		countdown_label.visible = true
		camera_overlay.visible = false
		print("debug: Start timer")


# Entering camera area
func _on_interaction_component_area_entered(area: Area3D) -> void:
	can_interact = true
	interact_label.visible = true
	print("debug: Entered camera area")

# Exiting camera area
func _on_interaction_component_area_exited(area: Area3D) -> void:
	can_interact = false
	interact_label.visible = false
	print("debug: Exited camera area")

# Timer ended
func _on_countdown_timer_timeout() -> void:
	countdown_label.visible = false
	print("debug: Camera shoot")
