extends CharacterBody3D

@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var rotation_speed := 12.0
@export var camera_normal_length: float = 8.0
@export var camera_sprint_length: float = 10.0
@export var camera_zoom_speed: float = 6.0

@onready var state_machine: StateMachine = %StateMachine
@onready var movement_component: MovementComponent = %MovementComponent
@onready var camera_pivot: Marker3D = %CameraPivot
@onready var camera : Camera3D = %Camera3D
@onready var camera_spring_arm: SpringArm3D = %CameraPivot.get_node("SpringArm3D")
@onready var particle_trail: GPUParticles3D = %ParticleTrail
@onready var skin: PlayerSkin = %PlayerSkin
@onready var hold_position: Marker3D = %HoldPosition

@onready var _idle_state: State = %StateMachine.get_node("Idle")
@onready var _captured_state: State = %StateMachine.get_node("Captured")
@onready var _pose_state: State = %StateMachine.get_node("Pose")

@onready var footstep_player: AudioStreamPlayer3D = %FootstepPlayer

#Camera
var _camera_input_direction := Vector2.ZERO

#Pickupable items
var held_item: PickupableItem

#Respawn / Checkpoint
var current_checkpoint: Vector3

#Sprint camera zoom
var _is_sprinting: bool = false
var _target_camera_length: float = 8.0

#Pose
var _required_pose_key: String = ""
var _has_attempted_pose := false

func play_footstep() -> void:
	if not footstep_player.playing:
		footstep_player.play()

func _ready() -> void:
	current_checkpoint = global_position

func _input(event: InputEvent) -> void:
	if state_machine.active_state.name == "Captured":
		return
	
	# Capture Mouse
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	# Pose input during camera pose window
	if state_machine.active_state == _pose_state:
		if not _has_attempted_pose:
			var input_actions := ["interact", "left_click", "jump"]
			var pressed_action := ""
			for action in input_actions:
				if event.is_action_pressed(action):
					pressed_action = action
					break
			if pressed_action != "":
				_has_attempted_pose = true
				if pressed_action == _required_pose_key:
					EventBus.pose_performed.emit()
		return

	if state_machine.active_state.name == "Captured":
		return
	
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)

	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity
	
	# Throwing
	if held_item != null and held_item.has_method("throw"):
		if event.is_action_pressed("left_click") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var is_air_boost_throw := (not is_on_floor()) and Input.is_action_pressed("jump")
			var aim_dir: Vector3
			var force : float
			assert(held_item.boost_jump_power)
			print_debug(held_item.boost_jump_power)
			
			var boost_jump_power : float = 25.0 # Default
			if held_item.boost_jump_power:
				boost_jump_power = held_item.boost_jump_power
			if is_air_boost_throw:
				aim_dir = Vector3.DOWN
			else:
				aim_dir = movement_component.get_last_movement_direction().normalized()
				aim_dir.y = 0.6 # add upward arc
			force = movement_component.get_last_movement_direction().length() * 1.0 + 6.0
			
			held_item.throw(self, aim_dir, force)

			if is_air_boost_throw:
				SoundManager.play_sound("throw_sound")
				skin.transition("Jump", true)
				movement_component.apply_impulse(Vector3(0, boost_jump_power, 0))

func _physics_process(delta: float) -> void:
	handle_effects(delta)

	var sprinting := Input.is_action_pressed("sprint") and Vector2(velocity.x, velocity.z).length() > 0.2

	if sprinting != _is_sprinting:
		_is_sprinting = sprinting
		_target_camera_length = camera_sprint_length if sprinting else camera_normal_length

	camera_spring_arm.spring_length = lerp(camera_spring_arm.spring_length, _target_camera_length, camera_zoom_speed * delta)

	# Camera handling
	camera_pivot.rotation.x += _camera_input_direction.y * delta
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(20.0))
	camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO
	
	var target_angle := Vector3.BACK.signed_angle_to(movement_component.get_last_movement_direction(), Vector3.UP)
	skin.global_rotation.y = lerp_angle(skin.rotation.y, target_angle, rotation_speed * delta)

	# Update blend position based on normalized velocity (standing vs walking vs running)
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var blend_position :float = clamp(ground_speed / movement_component.movement_config.sprint_speed, 0.0, 1.0)
	skin.set_moving_blend_position(blend_position)

func handle_effects(_delta: float) -> void:
	var is_sprinting := Input.is_action_pressed("sprint")
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := ground_speed > 0.2

	particle_trail.emitting = false

	if is_on_floor() and is_sprinting and is_moving:
		particle_trail.emitting = true

func get_camera_global_basis() -> Basis:
	return camera.global_basis

func set_hand_item(item: RigidBody3D) -> void:
	held_item = item

func apply_external_impulse(impulse: Vector3) -> void:
	
	movement_component.apply_impulse(impulse)

func _on_tree_entered() -> void:
	EventBus.player_captured.connect(_on_player_captured)
	EventBus.player_released.connect(_on_player_released)
	EventBus.pose_window_started.connect(_on_pose_window_started)

func _on_tree_exited() -> void:
	EventBus.player_captured.disconnect(_on_player_captured)
	EventBus.player_released.disconnect(_on_player_released)
	EventBus.pose_window_started.disconnect(_on_pose_window_started)

func _on_player_captured() -> void:
	_camera_input_direction = Vector2.ZERO
	state_machine.change_state(_captured_state)

func _on_player_released() -> void:
	state_machine.change_state(_idle_state)

func _on_pose_window_started(duration: float, required_key: String) -> void:
	_required_pose_key = required_key
	_has_attempted_pose = false
	state_machine.change_state(_pose_state)
