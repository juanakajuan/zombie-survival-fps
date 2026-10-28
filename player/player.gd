class_name Player
extends CharacterBody3D
## First-person controller. The origin is at the feet. Yaw is on this body, pitch is on Head.

## Emitted once when the Health child gets to 0. After it, the player ignores all input.
signal died

@export_group("Movement")
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var walk_speed: float = 4.5
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var sprint_speed: float = 7.0
## Each second on the floor, the player gains up to this many times the target speed.
@export_range(0.0, 50.0, 0.5) var ground_acceleration: float = 10.0
## Each second in the air, the player gains up to this many times the target speed, along the wish direction.
@export_range(0.0, 200.0, 0.5) var air_acceleration: float = 10.0
## Air acceleration stops when speed along the wish direction gets to this value. A low cap is what makes air strafing work.
@export_range(0.0, 10.0, 0.05, "suffix:m/s") var air_speed_cap: float = 1.0
## Each second on the floor, the player loses this many times its speed.
@export_range(0.0, 20.0, 0.1) var friction: float = 6.0
## Below this speed, friction acts as if the player moves at this speed, so the player comes to a full stop quickly.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var stop_speed: float = 2.5
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var jump_velocity: float = 8.0
@export_range(0.0, 60.0, 0.1, "suffix:m/s²") var gravity: float = 25.0

@export_group("Look")
@export_range(0.0001, 0.02, 0.0001, "suffix:rad/px") var mouse_sensitivity: float = 0.0025
@export_range(0.0, 90.0, 0.5, "suffix:°") var max_pitch_degrees: float = 89.0

@onready var _head: Node3D = $Head
@onready var _weapon: Weapon = $Head/Camera3D/Weapon
@onready var _health: Health = $Health


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_health.died.connect(_on_health_died)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		return
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
	# Holding jump hops again on the first floor frame, before friction can slow the player.
	var jumping := on_floor and Input.is_action_pressed("jump") and not is_dead()
	if jumping:
		velocity.y = jump_velocity
	elif on_floor:
		velocity.y = 0.0
		_apply_friction(delta)
	else:
		velocity.y -= gravity * delta

	var move_input := _move_input()
	var wish_dir := (global_basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
	var target_speed := (sprint_speed if is_sprinting() else walk_speed) * move_input.length()
	if on_floor:
		_accelerate(wish_dir, target_speed, target_speed, ground_acceleration, delta)
	else:
		_accelerate(wish_dir, minf(target_speed, air_speed_cap), target_speed, air_acceleration, delta)
	move_and_slide()


## Applies a mouse delta in pixels. Moving the mouse right turns right, and moving it up looks up.
## A dead player does not look.
func look(relative: Vector2) -> void:
	if is_dead():
		return
	rotation.y -= relative.x * mouse_sensitivity
	var max_pitch := deg_to_rad(max_pitch_degrees)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * mouse_sensitivity, -max_pitch, max_pitch)


## True while on the floor with the sprint action held and the move input pointing forward.
func is_sprinting() -> bool:
	return is_on_floor() and Input.is_action_pressed("sprint") and _move_input().y < -0.5


func is_dead() -> bool:
	return _health.is_dead()


func _on_health_died() -> void:
	_weapon.trigger_enabled = false
	died.emit()


func _move_input() -> Vector2:
	if is_dead():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _apply_friction(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	if speed == 0.0:
		return
	var new_speed := maxf(speed - maxf(speed, stop_speed) * friction * delta, 0.0)
	horizontal *= new_speed / speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Adds speed along wish_dir until the speed along it gets to cap_speed. The step size uses target_speed,
## so a low cap in the air still turns velocity fast. This is what lets air strafing gain speed.
func _accelerate(wish_dir: Vector3, cap_speed: float, target_speed: float, acceleration: float, delta: float) -> void:
	var add_speed := cap_speed - velocity.dot(wish_dir)
	if add_speed <= 0.0:
		return
	velocity += wish_dir * minf(acceleration * target_speed * delta, add_speed)
