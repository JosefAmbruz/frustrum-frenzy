extends StaticBody3D

var can_interact = false
var in_camera = false
@onready var view_camera = $Camera3D
@onready var interact_label = $Label3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interact_label.visible = false
	print("debug: Camera start")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
			print("debug: Switched to camera view")
		else:
			# Leaving camera
			view_camera.clear_current()
			in_camera = false
			interact_label.visible = true
			print("debug: Cleared camera view")

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
