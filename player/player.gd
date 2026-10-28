class_name Player
extends CharacterBody3D
## First-person controller. The origin is at the feet. Yaw is on this body, pitch is on Head.

@export_group("Movement")
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var walk_speed: float = 4.5
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var sprint_speed: float = 7.0
@export_range(0.0, 200.0, 0.5, "suffix:m/s²") var ground_acceleration: float = 45.0
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var air_acceleration: float = 8.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var jump_velocity: float = 4.8

@export_group("Look")
@export_range(0.0001, 0.02, 0.0001, "suffix:rad/px") var mouse_sensitivity: float = 0.0025
@export_range(0.0, 90.0, 0.5, "suffix:°") var max_pitch_degrees: float = 89.0

@onready var _head: Node3D = $Head
@onready var _weapon: Weapon = $Head/Camera3D/Weapon

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_weapon.trigger_enabled = false
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		# Capture on release, so the click that takes the mouse back never reaches the weapon as a shot.
		if not click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_weapon.trigger_enabled = true


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		velocity.y = jump_velocity if Input.is_action_just_pressed("jump") else 0.0
	else:
		velocity.y -= _gravity * delta

	var move_input := _move_input()
	var wish_dir := global_basis * Vector3(move_input.x, 0.0, move_input.y)
	var target_speed := sprint_speed if is_sprinting() else walk_speed
	var acceleration := ground_acceleration if on_floor else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish_dir * target_speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


## Applies a mouse delta in pixels. Moving the mouse right turns right, and moving it up looks up.
func look(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	var max_pitch := deg_to_rad(max_pitch_degrees)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * mouse_sensitivity, -max_pitch, max_pitch)


## True while on the floor with the sprint action held and the move input pointing forward.
func is_sprinting() -> bool:
	return is_on_floor() and Input.is_action_pressed("sprint") and _move_input().y < -0.5


func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")
