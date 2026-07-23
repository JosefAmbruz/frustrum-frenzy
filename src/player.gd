extends CharacterBody3D

# TODO:
# - calculate _jump_impulse and gravity from jump_height and time_to_apex
# - coyote time
# - variable jump height
# - item propelling

@export_category("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

@export_category("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_height := 2.0
@export var jump_time_to_apex := 0.4
@export var jump_descent_mult := 2.0
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier := 0.5
@export_range(0.0, 0.5, 0.01) var coyote_time := 0.12

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _jump_impulse : float
var _gravity : float
var _coyote_time_left := 0.0

@onready var _camera_pivot : Node3D = %CameraPivot
@onready var _camera : Camera3D = %Camera3D
@onready var _skin : Node3D = %PlayerSkin

func _ready() -> void:
	_coyote_time_left = coyote_time

func _input(event: InputEvent) -> void:
	#Capture Mouse
	# -- only in windowed mode?
	
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	

func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity
	
func _physics_process(delta: float) -> void:
	_gravity = (2.0 * jump_height) / (jump_time_to_apex * jump_time_to_apex)
	_jump_impulse = _gravity * jump_time_to_apex
	
	var can_jump := is_on_floor() or _coyote_time_left > 0.0
	var is_starting_jump := Input.is_action_just_pressed("jump") and can_jump

	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(20.0))
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	
	_camera_input_direction = Vector2.ZERO
	
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0 # camera in world is tilted
	move_direction = move_direction.normalized()
	
	var y_velocity := velocity.y
	velocity.y = 0.0 # Ground acceleration calculation will not affect gravity
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = y_velocity - _gravity * delta

	
	if is_starting_jump:
		velocity.y = _jump_impulse
		_coyote_time_left = 0.0
	
	move_and_slide()

	# variable jump height: if the player releases jump while still moving upward,
	# cut the upward velocity so short taps produce smaller jumps (Mario-style)
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier

	if is_on_floor():
		_coyote_time_left = coyote_time
	else:
		_coyote_time_left = maxf(_coyote_time_left - delta, 0.0)
	
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)
	
	if is_starting_jump:
		# TODO: Change skin state to jump
		pass
	elif not is_on_floor() and velocity.y < 0:
		# TODO: Change skin state to falling
		pass
	elif is_on_floor():
	
		var ground_speed := velocity.length()
		if ground_speed > 0.0:
			# TODO: Change skin state to move
			pass
		else:
			# TODO: Change skin state to idle
			pass
