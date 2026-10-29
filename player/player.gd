class_name Player
extends CharacterBody3D
## First-person controller. The origin is at the feet. Yaw is on this body, pitch is on Head.

## Emitted once when the Health child gets to 0. After it, the player ignores all input.
signal died

## The group that player.tscn puts the player in. Other features find the player with it.
const GROUP := &"player"

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
## Walk speed while the aim action is held.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var aim_speed: float = 3.0

@export_group("Crouch")
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var crouch_speed: float = 2.5
## Collision height while crouched. Standing height comes from the capsule in the scene.
@export_range(0.7, 1.8, 0.05, "suffix:m") var crouch_height: float = 1.0
## How fast the camera moves down and up when the player crouches and stands.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var crouch_camera_speed: float = 6.0

@export_group("Look")
@export_range(0.0001, 0.02, 0.0001, "suffix:rad/px") var mouse_sensitivity: float = 0.0025
@export_range(0.0, 90.0, 0.5, "suffix:°") var max_pitch_degrees: float = 89.0

@export_group("Aim")
## The field of view while fully aimed, as a fraction of the field of view in the settings.
@export_range(0.3, 1.0, 0.01) var aim_fov_scale: float = 0.8
## Each second, the zoom closes this much of the gap to its target. Higher is snappier.
@export_range(0.1, 40.0, 0.1) var aim_sharpness: float = 14.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hud: Hud = $Hud
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var body: MeshInstance3D = $CollisionShape3D/Body
@onready var _health: Health = $Health
@onready var _collision: CollisionShape3D = $CollisionShape3D

var weapon: Weapon
var settings: GameSettings

var _crouched := false
var _aim_blend := 0.0
var _shape: CapsuleShape3D
var _body_mesh: CapsuleMesh
var _stand_height: float
var _stand_head_height: float


func _enter_tree() -> void:
	# The weapon and its view model read the wielder in their _ready, which runs before this node's _ready.
	weapon = $Head/Camera3D/Weapon
	weapon.wielder = self


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_health.died.connect(_on_health_died)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.settings_changed.connect(_apply_settings)
	settings = GameSettings.load_saved()
	_apply_settings()
	# Every Player instance shares the scene's capsule, so crouching must resize a copy.
	_shape = _collision.shape.duplicate() as CapsuleShape3D
	_collision.shape = _shape
	_body_mesh = body.mesh.duplicate() as CapsuleMesh
	body.mesh = _body_mesh
	_stand_height = _shape.height
	_stand_head_height = head.position.y
	# Physics moves the body 60 times a second. On a faster screen the camera would hold still for some frames
	# and then jump, which looks like blur. So the camera follows the interpolated head, but it takes the look
	# angles as they are, because interpolating them would make the mouse lag by one physics tick.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_place_camera(head.global_position)


func _process(delta: float) -> void:
	_aim_blend = lerpf(_aim_blend, 1.0 if is_aiming() else 0.0, 1.0 - exp(-aim_sharpness * delta))
	_apply_field_of_view()
	_place_camera(head.get_global_transform_interpolated().origin)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu.open(settings)


func _physics_process(delta: float) -> void:
	_update_crouch(delta)
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
	var target_speed := (crouch_speed if _crouched else aim_speed if is_aiming() else sprint_speed if is_sprinting() else walk_speed) * move_input.length()
	if on_floor:
		_accelerate(wish_dir, target_speed, target_speed, ground_acceleration, delta)
	else:
		_accelerate(wish_dir, minf(target_speed, air_speed_cap), target_speed, air_acceleration, delta)
	move_and_slide()
	# The weapon is a child of the camera and fires in its own _physics_process, after this one.
	# This puts the shot at the true head position, not the one drawn on screen.
	_place_camera(head.global_position)


## Applies a mouse delta in pixels. Moving the mouse right turns right, and moving it up looks up.
## A dead player does not look.
func look(relative: Vector2) -> void:
	if is_dead():
		return
	var sensitivity := mouse_sensitivity * settings.mouse_sensitivity_scale
	rotation.y -= relative.x * sensitivity
	var max_pitch := deg_to_rad(max_pitch_degrees)
	head.rotation.x = clampf(head.rotation.x - relative.y * sensitivity, -max_pitch, max_pitch)
	camera.global_basis = _look_basis()


## True while the aim action is held. A dead player does not aim.
func is_aiming() -> bool:
	return Input.is_action_pressed("aim") and not is_dead()


## True while on the floor, not crouched, not aiming, with the sprint action held and the move input pointing forward.
func is_sprinting() -> bool:
	return is_on_floor() and not _crouched and not is_aiming() and Input.is_action_pressed("sprint") and _move_input().y < -0.5


## True while the player is crouched. The player stays crouched after the crouch action is released
## until there is room to stand.
func is_crouching() -> bool:
	return _crouched


func is_dead() -> bool:
	return _health.is_dead()


func _on_health_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	weapon.trigger_enabled = false
	died.emit()


func _resume() -> void:
	pause_menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_settings() -> void:
	_apply_field_of_view()
	settings.apply_to_engine()


func _apply_field_of_view() -> void:
	camera.fov = settings.field_of_view * lerpf(1.0, aim_fov_scale, _aim_blend)


func _place_camera(origin: Vector3) -> void:
	camera.global_transform = Transform3D(_look_basis(), origin)


func _look_basis() -> Basis:
	return Basis.from_euler(Vector3(head.rotation.x, rotation.y, 0.0))


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


func _update_crouch(delta: float) -> void:
	if Input.is_action_pressed("crouch") and not is_dead():
		_set_crouched(true)
	elif _crouched and _has_room_to_stand():
		_set_crouched(false)
	var head_height := _stand_head_height - (_stand_height - crouch_height if _crouched else 0.0)
	head.position.y = move_toward(head.position.y, head_height, crouch_camera_speed * delta)


func _set_crouched(crouched: bool) -> void:
	_crouched = crouched
	_shape.height = crouch_height if crouched else _stand_height
	_body_mesh.height = _shape.height
	_collision.position.y = _shape.height / 2.0


func _has_room_to_stand() -> bool:
	var standing := CapsuleShape3D.new()
	standing.radius = _shape.radius
	standing.height = _stand_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	# Lifted a little, so that the floor under the feet does not count.
	query.transform = global_transform.translated(Vector3.UP * (_stand_height / 2.0 + 0.05))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
