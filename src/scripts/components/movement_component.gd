class_name MovementComponent extends Node
# Handles player movement
# States change movement_mode: Disabled, Walking, Running

@export_category("Components")
@export var character_body: CharacterBody3D
@export var coyote_time: CoyoteTime
@export var movement_config: MovementConfig

enum MovementTypes {DISABLED, WALKING, CLIMBING}
var movement_type: MovementTypes = MovementTypes.DISABLED

var _velocity: Vector3
var _last_movement_direction := Vector3.BACK
var _gravity: float
var _jump_impulse: float

# Climbing detection (set after move_and_slide)
var is_near_climbable_wall := false
var climb_normal := Vector3.ZERO

# Wall detection (any wall, for wall jumping)
var is_near_any_wall := false
var any_wall_normal := Vector3.ZERO

var _last_wall_jump_normal := Vector3.ZERO
var _wall_jump_lock_left := 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	_gravity = (2.0 * movement_config.jump_height) / (movement_config.jump_time_to_apex * movement_config.jump_time_to_apex)
	_jump_impulse = _gravity * movement_config.jump_time_to_apex
	_wall_jump_lock_left = maxf(_wall_jump_lock_left - delta, 0.0)

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
	
	# --- CLIMBING MODE ---
	if movement_type == MovementTypes.CLIMBING:
		var y_velocity := character_body.velocity.y
		var target_vy := -movement_config.climb_slide_idle
		if move_direction.length() > 0.01:
			var into_wall := move_direction.dot(-climb_normal)
			if into_wall > movement_config.min_into_wall_dot:
				target_vy = movement_config.climb_speed_up
			elif into_wall < -movement_config.min_into_wall_dot:
				target_vy = -movement_config.climb_speed_down
		character_body.velocity.y = move_toward(y_velocity, target_vy, movement_config.climb_accel * delta)

		# Project input onto wall surface for strafing
		var target_horizontal := Vector3.ZERO
		if move_direction.length() > 0.01:
			var along_surface := move_direction - move_direction.dot(climb_normal) * climb_normal
			target_horizontal = along_surface * movement_config.climb_strafe_speed

		var horizontal_vel := Vector3(character_body.velocity.x, 0.0, character_body.velocity.z)
		horizontal_vel = horizontal_vel.move_toward(target_horizontal, movement_config.ground_dec * delta)
		character_body.velocity.x = horizontal_vel.x
		character_body.velocity.z = horizontal_vel.z

		character_body.velocity += -climb_normal * movement_config.wall_stick_force
		character_body.move_and_slide()
		_detect_climbing()
		return

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
	_detect_climbing()

	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	

func is_grounded() -> bool:
	return character_body.is_on_floor()

func is_falling() -> bool:
	return character_body.velocity.y > 0.0

func can_jump() -> bool:
	if coyote_time:
		return character_body.is_on_floor() or coyote_time.get_time_left()

	return character_body.is_on_floor()

func can_wall_jump() -> bool:
	if is_grounded():
		return false
	if not is_near_any_wall:
		return false
	if _wall_jump_lock_left > 0.0 and any_wall_normal.dot(_last_wall_jump_normal) > movement_config.same_wall_dot_threshold:
		return false
	return true

func do_wall_jump() -> void:
	character_body.velocity.y = _jump_impulse * movement_config.wall_jump_up_factor
	character_body.velocity += any_wall_normal * movement_config.wall_jump_push
	_last_wall_jump_normal = any_wall_normal
	_wall_jump_lock_left = movement_config.wall_jump_lock_time
	coyote_time.stop()

func can_climb() -> bool:
	return is_near_climbable_wall

func get_gravity() -> float:
	return (2.0 * movement_config.jump_height) / (movement_config.jump_time_to_apex * movement_config.jump_time_to_apex)

func get_last_movement_direction() -> Vector3:
	return _last_movement_direction

func jump() -> void:
	character_body.velocity.y = _jump_impulse
	coyote_time.stop()

func fall() -> void:
	character_body.velocity.y *= movement_config.jump_cut_multiplier

func set_vertical_velocity(value: float) -> void:
	character_body.velocity.y = value

func apply_impulse(impulse: Vector3) -> void:
	if impulse.y > 0:
		character_body.velocity.y = impulse.y

	character_body.velocity.x += impulse.x
	character_body.velocity.z += impulse.z

func accelerate_to_velocity(velocity: Vector3) -> void:
	pass

func deccelerate() -> void:
	accelerate_to_velocity(Vector3.ZERO)

func _detect_climbing() -> void:
	is_near_climbable_wall = false
	climb_normal = Vector3.ZERO
	is_near_any_wall = false
	any_wall_normal = Vector3.ZERO

	for i in range(character_body.get_slide_collision_count()):
		var collision := character_body.get_slide_collision(i)
		var n := collision.get_normal()
		var collider := collision.get_collider()

		if abs(n.y) < 0.6:
			is_near_any_wall = true
			any_wall_normal = n

			if collider and collider.is_in_group("climbable"):
				is_near_climbable_wall = true
				climb_normal = n
