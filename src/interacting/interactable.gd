extends Area3D
# Attach this Component to any object that can be interacted with

@export var interact_name := ""
@export var is_interactable := true

# Custom interaction logic
# This function is to be triggered from the interacting component
var interact: Callable = func():
	pass
