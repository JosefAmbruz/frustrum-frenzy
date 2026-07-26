class_name PlayerSkin extends Node3D

@onready var _animation_tree: AnimationTree = %AnimationTree

var playback : AnimationNodeStateMachinePlayback

func _ready() -> void:
	playback = _animation_tree["parameters/playback"]

func transition(state: String, restart: bool = false) -> void:
	if restart:
		playback.start(state)
	else:
		playback.travel(state)

func set_moving_blend_position(value: float) -> void:
	#print_debug(value)
	_animation_tree.set("parameters/Moving/blend_position", value)
