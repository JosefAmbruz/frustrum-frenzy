class_name MovementConfig extends Resource

@export var move_speed := 8.0
@export var sprint_speed := 14.0
@export var ground_acc := 55.0
@export var ground_dec := 70.0
@export var air_acc := 14.0
@export var air_dec := 6.0


@export var jump_height: float
@export var jump_time_to_apex: float
@export var jump_descent_mult: float
@export_range(0.0, 1.0, 0.01) var jump_cut_multiplier := 0.5

@export_category("Climbing")
@export var climb_speed_up := 3.5
@export var climb_speed_down := 2.0
@export var climb_slide_idle := 2.5
@export var climb_accel := 18.0
@export var climb_detach_push := 1.2
@export var min_into_wall_dot := 0.08
@export var wall_stick_force := 0.4
@export var climb_strafe_speed := 2.5
