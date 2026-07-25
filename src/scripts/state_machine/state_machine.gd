class_name StateMachine extends Node

@export var initial_state : State
@export var debug_mode : bool = false
@export var _debug_label : Label3D

var active_state: State

func _ready() -> void:
	for child_state: State in get_children():
		child_state.switch_state.connect(change_state)
	
	change_state(initial_state)

func _process(delta: float) -> void:
	if active_state:
		active_state.update(delta)

func _physics_process(delta: float) -> void:
	if active_state:
		active_state.physics_update(delta)

func _update_debug_label() -> void:
	if not debug_mode or _debug_label == null:
		_debug_label.visible = false
		return

	_debug_label.visible = true
	_debug_label.text = active_state.name if active_state != null else "None"

func change_state(new_state: State) -> void:
	if new_state == active_state:
		return
	
	if active_state:
		active_state.exit_state()
	
	active_state = new_state
	
	if active_state:
		active_state.enter_state()
	
	_update_debug_label()
