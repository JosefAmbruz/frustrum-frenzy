class_name MovementComponent extends Node
# Handles player movement
# States change movement_mode: Disabled, Walking, Running

@export_category("Components")
@export var character_body: CharacterBody3D
@export var coyote_time: CoyoteTime
@export var movement_config: MovementConfig

enum MovementTypes {DISABLED, WALKING}
var movement_type: MovementTypes = MovementTypes.DISABLED

var _velocity: Vector3
var _last_movement_direction := Vector3.BACK
var _gravity: float
var _jump_impulse: float


func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	_gravity = (2.0 * movement_config.jump_height) / (movement_config.jump_time_to_apex * movement_config.jump_time_to_apex)
	_jump_impulse = _gravity * movement_config.jump_time_to_apex
	
	# Camera relative movement
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var cam_basis: Basis = character_body.get_camera_global_basis()
	
	var cam_forward := cam_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	
	var cam_right := cam_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	var move_direction := cam_forward * raw_input.y + cam_right * raw_input.x
	if move_direction.length() > 0.001:
		move_direction = move_direction.normalized()
	else:
		move_direction = Vector3.ZERO
	
	var is_sprinting := Input.is_action_pressed("sprint")
	var current_speed : float = movement_config.sprint_speed if is_sprinting else movement_config.move_speed
	
	var y_velocity := character_body.velocity.y
	var horizontal_velocity := Vector3(character_body.velocity.x, 0.0, character_body.velocity.z)
	var target_horizontal := move_direction * current_speed


	var accel := movement_config.ground_acc if is_grounded() else movement_config.air_acc
	var decel := movement_config.ground_dec if is_grounded() else movement_config.air_dec
	
	if move_direction.length() > 0.01:
		horizontal_velocity = horizontal_velocity.move_toward(target_horizontal, accel * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, decel * delta)

	character_body.velocity.x = horizontal_velocity.x
	character_body.velocity.z = horizontal_velocity.z
	character_body.velocity.y = y_velocity
	
	# Vectical handling
	var gravity_multiplier := movement_config.jump_descent_mult if y_velocity < 0.0 else 1.0
	character_body.velocity.y = y_velocity - (_gravity * gravity_multiplier * delta)
	
	character_body.move_and_slide()
	
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	

func is_grounded() -> bool:
	return character_body.is_on_floor()

func can_jump() -> bool:
	if coyote_time:
		return character_body.is_on_floor() or coyote_time.get_time_left()

	return character_body.is_on_floor()

func can_wall_jump() -> bool:
	#TODO
	return false

func can_climb() -> bool:
	#TODO
	return false

func get_gravity() -> float:
	return (2.0 * movement_config.jump_height) / (movement_config.jump_time_to_apex * movement_config.jump_time_to_apex)

func get_last_movement_direction() -> Vector3:
	return _last_movement_direction

func jump() -> void:
	character_body.velocity.y = _jump_impulse
	coyote_time.stop()

func apply_impulse(impulse: Vector3) -> void:
	if impulse.y > 0:
		_velocity.y = impulse.y

	_velocity.x += impulse.x
	_velocity.z += impulse.z

func accelerate_to_velocity(velocity: Vector3) -> void:
	pass

func deccelerate() -> void:
	accelerate_to_velocity(Vector3.ZERO)
