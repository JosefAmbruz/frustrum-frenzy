extends AnimatableBody3D

@export var rotation_speed := 1.5

func roundboud_rotation(delta: float) -> void:
	rotate_y(rotation_speed * delta) 

func _ready() -> void:
	pass

# Move to _physics_process for physics bodies
func _physics_process(delta: float) -> void:
	roundboud_rotation(delta)
