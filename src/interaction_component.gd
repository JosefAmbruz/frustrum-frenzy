extends Area3D

@onready var interact_label = %Label3D

func on_interact() -> void:
	interact_label.visible = true
