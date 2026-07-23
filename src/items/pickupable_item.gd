extends RigidBody3D


@onready var interactable: Area3D = %Interactable

func _ready() -> void:
	interactable.interact = _on_interact

func _on_interact():
	print_debug("Interacted")
	interactable.is_interactable = false
