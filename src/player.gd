extends CharacterBody3D

# TODO:
# - item propelling

@export_category("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

@export_category("Movement")
@export var move_speed := 8.0
@export var sprint_speed := 14.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_height := 4.0
@export var jump_time_to_apex := 0.4
@export var jump_descent_mult := 2.0
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier := 0.5
@export_range(0.0, 0.5, 0.01) var coyote_time := 0.12

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _jump_impulse : float
var _gravity : float
var _coyote_time_left := 0.0

@export_category("Movement Tuning")
@export var ground_acceleration := 55.0
@export var ground_deceleration := 70.0
@export var air_acceleration := 14.0
@export var air_deceleration := 6.0

@export_category("Wall Jump")
@export var wall_jump_push := 14
@export var wall_jump_up_factor := 0.78      
@export var wall_jump_lock_time := 0.18      # anti-spam for same wall
@export var same_wall_dot_threshold := 0.82 

var _last_wall_jump_normal := Vector3.ZERO
var _wall_jump_lock_left := 0.0

var is_near_any_wall := false
var any_wall_normal := Vector3.ZERO
var is_captured := false

@export_category("Climbing")
@export var climb_speed_up := 3.5
@export var climb_speed_down := 2.0
@export var climb_slide_idle := 2.5
@export var climb_accel := 18.0
@export var climb_detach_push := 1.2
@export var min_into_wall_dot := 0.08 # how much does the input have to aim into the wall
@export var wall_stick_force := 0.4

var is_climbing := false
var is_wall_jumping := false
var climb_normal := Vector3.ZERO

@onready var _camera_pivot : Node3D = %CameraPivot
@onready var _camera : Camera3D = %Camera3D
@onready var _skin : Node3D = %PlayerSkin
@onready var _particle_trail : GPUParticles3D = %ParticleTrail
@onready var _sound_footsteps = %SoundFootsteps
@onready var _hold_position := %HoldPosition

var held_item: RigidBody3D

func _ready() -> void:
	_coyote_time_left = coyote_time

func _input(event: InputEvent) -> void:
	if is_captured:
		return

	# Capture Mouse
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if is_captured:
		return

	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)

	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity
		
	if event.is_action_pressed("left_click") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if held_item != null and held_item.has_method("throw"):
			var aim_dir = -_camera.global_transform.basis.z.normalized()
			held_item.throw(self, aim_dir)

func check_climbing() -> void:
	is_climbing = false
	climb_normal = Vector3.ZERO

	is_near_any_wall = false
	any_wall_normal = Vector3.ZERO

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var n := collision.get_normal()
		var collider := collision.get_collider()

		# any wall for wall jump
		if abs(n.y) < 0.6:
			is_near_any_wall = true
			any_wall_normal = n

		if collider and collider.is_in_group("climbable"):
			is_climbing = true
			climb_normal = n

func wall_jump() -> void:
	if not is_near_any_wall:
		return

	# lock anti jumping on same wall
	if _wall_jump_lock_left > 0.0 and any_wall_normal.dot(_last_wall_jump_normal) > same_wall_dot_threshold:
		return

	is_climbing = false
	is_wall_jumping = true

	velocity.y = _jump_impulse * wall_jump_up_factor
	velocity += any_wall_normal * wall_jump_push

	_last_wall_jump_normal = any_wall_normal
	_wall_jump_lock_left = wall_jump_lock_time

func set_hand_item(item: RigidBody3D) -> void:
	held_item = item

func _physics_process(delta: float) -> void:
	if is_captured:
		handle_effects(delta)
		_gravity = (2.0 * jump_height) / (jump_time_to_apex * jump_time_to_apex)
		var on_ground := is_on_floor()
		var decel := ground_deceleration if on_ground else air_deceleration
		var h := Vector3(velocity.x, 0.0, velocity.z)
		h = h.move_toward(Vector3.ZERO, decel * delta)
		velocity.x = h.x
		velocity.z = h.z
		velocity.y -= _gravity * delta
		move_and_slide()
		return

	_gravity = (2.0 * jump_height) / (jump_time_to_apex * jump_time_to_apex)
	_jump_impulse = _gravity * jump_time_to_apex
	_wall_jump_lock_left = maxf(_wall_jump_lock_left - delta, 0.0)

	handle_effects(delta)

	# Camera look
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(20.0))
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

	# Camera-relative movement input (ground plane)
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var cam_forward := _camera.global_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()

	var cam_right := _camera.global_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()

	var move_direction := cam_forward * raw_input.y + cam_right * raw_input.x
	if move_direction.length() > 0.001:
		move_direction = move_direction.normalized()
	else:
		move_direction = Vector3.ZERO

	var is_sprinting := Input.is_action_pressed("sprint")
	var current_speed := sprint_speed if is_sprinting else move_speed

	# ITEM SLOW
	if held_item != null and "player_speed_modifier" in held_item:
		current_speed *= held_item.player_speed_modifier

	# Check climbing state from last slide results
	check_climbing()

	# Climbing: player must push into wall (camera-relative), not fixed key
	var into_wall := 0.0
	if is_climbing and move_direction != Vector3.ZERO:
		into_wall = move_direction.dot(-climb_normal)

	var wants_wall_jump := Input.is_action_just_pressed("jump") \
		and is_near_any_wall \
		and not is_on_floor() \
		and _wall_jump_lock_left <= 0.0	
	var can_jump := is_on_floor() or _coyote_time_left > 0.0
	var is_starting_jump := Input.is_action_just_pressed("jump") and can_jump and not is_climbing

	# Horizontal velocity (always smooth)
	var y_velocity := velocity.y
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal := move_direction * current_speed

	var has_input := move_direction.length() > 0.01
	var on_ground := is_on_floor()

	var accel := ground_acceleration if on_ground else air_acceleration
	var decel := ground_deceleration if on_ground else air_deceleration

	if has_input:
		horizontal_velocity = horizontal_velocity.move_toward(target_horizontal, accel * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, decel * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	velocity.y = y_velocity

	# Vertical handling
	if is_climbing and not is_wall_jumping:
		var target_vy := -climb_slide_idle

		# Move up only when moving into wall and pressing forward
		if into_wall > min_into_wall_dot:
			target_vy = climb_speed_up
		elif into_wall < -min_into_wall_dot:
			target_vy = -climb_speed_down
		# else: idle slide down

		velocity.y = move_toward(y_velocity, target_vy, climb_accel * delta)
		# keep slight adhesion to wall
		velocity += -climb_normal * wall_stick_force
	else:
		var gravity_multiplier := jump_descent_mult if y_velocity < 0.0 else 1.0
		velocity.y = y_velocity - (_gravity * gravity_multiplier * delta)

	if is_starting_jump:
		velocity.y = _jump_impulse
		_coyote_time_left = 0.0

	if wants_wall_jump:
		wall_jump()

	move_and_slide()

	# Reset wall-jump lock when grounded or off wall
	if is_wall_jumping and (is_on_floor() or not is_climbing):
		is_wall_jumping = false

	# variable jump height: if player releases jump while still moving upward, cut it
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier

	# Coyote time
	if is_on_floor():
		_coyote_time_left = coyote_time
	else:
		_coyote_time_left = maxf(_coyote_time_left - delta, 0.0)

	# Visual facing
	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)

	# TODO animation state switches
	if is_starting_jump:
		pass
	elif not is_on_floor() and velocity.y < 0:
		pass
	elif is_on_floor():
		var ground_speed := Vector2(velocity.x, velocity.z).length()
		if ground_speed > 0.0:
			pass
		else:
			pass

func handle_effects(_delta: float) -> void:
	var is_sprinting := Input.is_action_pressed("sprint")
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := ground_speed > 0.2

	_particle_trail.emitting = false
	_sound_footsteps.stream_paused = true

	if is_on_floor() and is_sprinting and is_moving:
		_particle_trail.emitting = true

func apply_external_impulse(impulse: Vector3) -> void:
	if impulse.y > 0:
		velocity.y = impulse.y

	velocity.x += impulse.x
	velocity.z += impulse.z
 
func _on_player_captured() -> void:
	print_debug("Player Captured")
	is_captured = true
	_camera_input_direction = Vector2.ZERO
	is_climbing = false
	is_wall_jumping = false

func _on_player_released() -> void:
	print_debug("Player Released")
	is_captured = false

func _on_tree_entered() -> void:
	EventBus.player_captured.connect(_on_player_captured)
	EventBus.player_released.connect(_on_player_released)

func _on_tree_exited() -> void:
	EventBus.player_captured.disconnect(_on_player_captured)
	EventBus.player_released.disconnect(_on_player_released)
