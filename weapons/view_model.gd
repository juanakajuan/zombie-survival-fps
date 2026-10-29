class_name ViewModel
extends Node3D
## First-person weapon model. Make it the root of a `view_model` scene, with this layout:
## ViewModel > Motion > Model, and an optional Motion > Hand. Motion holds the hand position and follows the player's movement
## (bob, sprint, crouch, jump, landing, look sway). Model plays the one-shot motions
## (raise, recoil, reload, lower on death) relative to Motion. A reload throws the gun away
## over the shoulder as debris and draws an identical new one.

@export var motion: Node3D
@export var model: Node3D
@export var slide: Node3D
## The hand that holds the gun, or null for none. hand_anchor, a child of the model, moves it with the gun.
@export var hand: Node3D
@export var hand_anchor: RemoteTransform3D
## The tip of the barrel, a child of the model. Tracers start here.
@export var muzzle: Node3D

@export_group("Raise")
@export_range(0.0, 2.0, 0.01, "suffix:s") var raise_time: float = 0.45
@export_range(0.0, 0.5, 0.005, "suffix:m") var lower_distance: float = 0.25
## Pitch of the lowered gun, before the raise and after the player dies. Negative points the muzzle down.
@export_range(-90.0, 90.0, 1.0, "suffix:°") var lower_angle: float = -40.0

@export_group("Recoil")
@export_range(0.0, 0.2, 0.005, "suffix:m") var kick_distance: float = 0.05
@export_range(0.0, 45.0, 0.5, "suffix:°") var kick_angle: float = 12.0
@export_range(0.0, 0.1, 0.005, "suffix:m") var slide_travel: float = 0.035
@export_range(0.01, 1.0, 0.01, "suffix:s") var recoil_time: float = 0.14

@export_group("Reload")
## The gun that flies away. With none, the gun only goes out of view and comes back.
@export var thrown_scene: PackedScene
## Where the gun moves before the throw, relative to its rest place.
@export var wind_up_offset: Vector3 = Vector3(0.03, 0.06, 0.08)
@export_range(-90.0, 90.0, 1.0, "suffix:°") var wind_up_angle: float = 35.0
## How far the gun moves in view space during the toss, before it flies free as debris.
@export var toss_offset: Vector3 = Vector3(0.06, 0.5, 0.2)
## Throw velocity in view space: +X is right, +Y is up, +Z is back. The player's own velocity is added.
@export var throw_velocity: Vector3 = Vector3(1.5, 3.5, 4.0)
## Spin in view space, in rad/s. +X flips the muzzle up and back.
@export var throw_spin: Vector3 = Vector3(14.0, 0.0, 3.0)
## Each phase of the reload lasts this fraction of the weapon's reload time. The phases run one after the other.
## Keep their sum at or below 1, so the motion ends before the weapon is ready again.
@export_range(0.0, 1.0, 0.01) var wind_up_fraction: float = 0.1
@export_range(0.0, 1.0, 0.01) var toss_fraction: float = 0.2
## The hands stay empty after the throw for this fraction.
@export_range(0.0, 1.0, 0.01) var empty_hands_fraction: float = 0.1
@export_range(0.0, 1.0, 0.01) var draw_fraction: float = 0.4
@export_range(0.0, 1.0, 0.01) var slide_pull_fraction: float = 0.08
@export_range(0.0, 1.0, 0.01) var slide_release_fraction: float = 0.07

@export_group("Bob")
@export_range(0.0, 2.0, 0.01) var bob_cycles_per_metre: float = 0.32
@export_range(0.0, 0.05, 0.001, "suffix:m") var bob_amount: float = 0.012
## Speed at which the bob is at full bob_amount. It grows past that while sprinting.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var bob_reference_speed: float = 4.5
@export_range(0.0, 0.02, 0.0005, "suffix:m") var idle_sway_amount: float = 0.003

@export_group("Poses")
@export_range(0.0, 90.0, 1.0, "suffix:°") var sprint_pitch: float = 22.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var sprint_yaw: float = 30.0
@export var sprint_offset: Vector3 = Vector3(-0.04, -0.04, 0.03)
@export var crouch_offset: Vector3 = Vector3(-0.02, 0.01, 0.0)
@export_range(0.0, 45.0, 1.0, "suffix:°") var crouch_roll: float = 8.0
## Each second, the pose closes this much of the gap to its target. Higher is snappier.
@export_range(0.1, 40.0, 0.1) var pose_sharpness: float = 10.0

@export_group("Air")
## How far the gun lags per m/s of vertical speed in the air.
@export_range(0.0, 0.02, 0.0005, "suffix:m") var air_lag_per_speed: float = 0.003
@export_range(0.0, 0.1, 0.001, "suffix:m") var max_air_lag: float = 0.04
## How far the gun dips per m/s of fall speed when the player lands.
@export_range(0.0, 0.02, 0.0005, "suffix:m") var land_dip_per_speed: float = 0.004
@export_range(0.0, 0.1, 0.001, "suffix:m") var max_land_dip: float = 0.05

@export_group("Aim")
## The change from the rest position of Motion that puts the rear and front sights on the screen centre.
@export var aim_offset: Vector3 = Vector3(-0.16, 0.067, 0.0)
## While aimed, bob, sway, air lag, the landing dip and the crouch pose shrink to this fraction.
@export_range(0.0, 1.0, 0.01) var aim_motion_scale: float = 0.15
## While aimed, the recoil kick shrinks to this fraction, so the sights stay in view.
@export_range(0.0, 1.0, 0.01) var aim_kick_scale: float = 0.5
## Each second, the aim pose closes this much of the gap to its target. Higher is snappier.
@export_range(0.1, 40.0, 0.1) var aim_sharpness: float = 14.0

@export_group("Punch")
## While the wielder punches, the gun moves by this much and rolls right, out of the hand's path.
@export var punch_dip_offset: Vector3 = Vector3(0.03, -0.08, 0.02)
@export_range(0.0, 45.0, 0.5, "suffix:°") var punch_dip_roll: float = 15.0

@export_group("Look sway")
## How far the gun turns behind the view, per radian the view turns in one frame.
@export_range(0.0, 2.0, 0.01) var look_sway: float = 0.6
@export_range(0.0, 20.0, 0.5, "suffix:°") var max_look_sway: float = 6.0

var _motion_rest: Transform3D
var _model_rest: Transform3D
var _slide_rest: Vector3
var _tween: Tween
var _wind_up: Transform3D
var _toss_time := 0.0
static var _unshadowed_copies: Dictionary[BaseMaterial3D, BaseMaterial3D] = {}
var _player: Player
var _lowered := false

var _bob_phase := 0.0
var _time := 0.0
var _sprint := 0.0
var _crouch := 0.0
var _aim := 0.0
var _air_lag := 0.0
var _land_dip := 0.0
var _was_on_floor := true
var _last_fall_speed := 0.0
var _look_sway := Vector2.ZERO
var _last_view := Vector2.ZERO


func _ready() -> void:
	detach_from_shadows(self)
	_motion_rest = motion.transform
	_model_rest = model.transform
	_slide_rest = slide.position
	_last_view = _view_angles()
	var weapon := get_parent() as Weapon
	if weapon != null:
		_player = weapon.wielder
		weapon.fired.connect(_on_fired)
		weapon.reload_started.connect(_on_reload_started.bind(weapon))
		weapon.reload_finished.connect(_settle)
	if _player != null:
		_player.died.connect(_on_player_died)
	_raise()


func _process(delta: float) -> void:
	_time += delta
	var weight := 1.0 - exp(-pose_sharpness * delta)
	var speed := 0.0
	var on_floor := true
	var vertical := 0.0
	var sprinting := false
	var crouching := false
	var aiming := false
	var punch_dip := 0.0
	if _player != null and not _player.is_dead():
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
		on_floor = _player.is_on_floor()
		vertical = _player.velocity.y
		sprinting = _player.is_sprinting()
		crouching = _player.is_crouching()
		aiming = _player.is_aiming()
	if _player != null:
		var punch := _player.melee.visual_progress()
		if punch >= 0.0:
			punch_dip = sin(PI * clampf(punch, 0.0, 1.0))

	if on_floor:
		_bob_phase = fmod(_bob_phase + speed * delta * bob_cycles_per_metre * TAU, TAU)
	if on_floor and not _was_on_floor:
		_land_dip = minf(_last_fall_speed * land_dip_per_speed, max_land_dip)
	_was_on_floor = on_floor
	_last_fall_speed = maxf(-vertical, 0.0)
	_land_dip = lerpf(_land_dip, 0.0, weight)
	var air_target := 0.0 if on_floor else clampf(-vertical * air_lag_per_speed, -max_air_lag, max_air_lag)
	_air_lag = lerpf(_air_lag, air_target, weight)
	_sprint = lerpf(_sprint, 1.0 if sprinting else 0.0, weight)
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, weight)
	_aim = lerpf(_aim, 1.0 if aiming else 0.0, 1.0 - exp(-aim_sharpness * delta))
	var steady := lerpf(1.0, aim_motion_scale, _aim)

	var view := _view_angles()
	var turn := Vector2(angle_difference(_last_view.x, view.x), angle_difference(_last_view.y, view.y))
	_last_view = view
	var max_sway := deg_to_rad(max_look_sway)
	var sway_target := (-turn * look_sway).clamp(Vector2(-max_sway, -max_sway), Vector2(max_sway, max_sway))
	_look_sway = _look_sway.lerp(sway_target, weight)

	var bob_scale := 0.0 if not on_floor else speed / bob_reference_speed
	var bob := Vector3(sin(_bob_phase), -absf(cos(_bob_phase)), 0.0) * bob_amount * bob_scale
	var idle := Vector3(sin(_time * 1.1), sin(_time * 2.2) * 0.5, 0.0) * idle_sway_amount
	var offset := (bob + idle + crouch_offset * _crouch + Vector3(0.0, _air_lag - _land_dip, 0.0)) * steady \
		+ sprint_offset * _sprint + aim_offset * _aim + punch_dip_offset * punch_dip
	motion.transform = _motion_rest.translated(offset) \
		.rotated_local(Vector3.UP, deg_to_rad(sprint_yaw) * _sprint + _look_sway.x * steady) \
		.rotated_local(Vector3.RIGHT, -deg_to_rad(sprint_pitch) * _sprint + _look_sway.y * steady) \
		.rotated_local(Vector3.FORWARD, -deg_to_rad(crouch_roll) * _crouch * steady + deg_to_rad(punch_dip_roll) * punch_dip)


func _raise() -> void:
	_restart_tween()
	model.transform = _lowered_transform()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(model, "transform", _model_rest, raise_time)


func _on_fired() -> void:
	if _lowered:
		return
	_restart_tween()
	var kick := lerpf(1.0, aim_kick_scale, _aim)
	model.transform = _model_rest.translated_local(Vector3(0.0, 0.0, kick_distance * kick)) \
		.rotated_local(Vector3.RIGHT, deg_to_rad(kick_angle * kick))
	slide.position = _slide_rest + Vector3(0.0, 0.0, slide_travel)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(model, "transform", _model_rest, recoil_time)
	_tween.parallel().tween_property(slide, "position", _slide_rest, recoil_time * 0.6)


func _on_reload_started(weapon: Weapon) -> void:
	if _lowered:
		return
	_restart_tween()
	var time := weapon.data.reload_time
	_wind_up = _model_rest.translated_local(wind_up_offset).rotated_local(Vector3.RIGHT, deg_to_rad(wind_up_angle))
	_toss_time = time * toss_fraction
	slide.position = _slide_rest
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(model, "transform", _wind_up, time * wind_up_fraction)
	_tween.tween_callback(_hold_hand_upright.bind(true))
	_tween.tween_method(_toss_step, 0.0, 1.0, _toss_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_throw)
	_tween.tween_interval(time * empty_hands_fraction)
	_tween.tween_callback(_take_out_new_gun)
	_tween.tween_property(model, "transform", _model_rest, time * draw_fraction).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(slide, "position", _slide_rest + Vector3(0.0, 0.0, slide_travel), time * slide_pull_fraction)
	_tween.tween_property(slide, "position", _slide_rest, time * slide_release_fraction).set_trans(Tween.TRANS_BACK)


func _toss_step(progress: float) -> void:
	model.transform = _wind_up.translated(toss_offset * progress) \
		.rotated_local(Vector3.RIGHT, throw_spin.x * _toss_time * progress)


func _throw() -> void:
	model.hide()
	if thrown_scene == null or _player == null:
		return
	var gun := thrown_scene.instantiate() as RigidBody3D
	_player.get_parent().add_child(gun)
	gun.global_transform = model.global_transform
	gun.add_collision_exception_with(_player)
	gun.linear_velocity = _player.velocity + global_basis * throw_velocity
	gun.angular_velocity = global_basis * throw_spin


func _take_out_new_gun() -> void:
	_hold_hand_upright(false)
	model.transform = _lowered_transform()
	model.show()


## Puts every part at rest, so a reload always ends with the gun ready even if its motion was cut short.
func _settle() -> void:
	if _lowered:
		return
	if _tween != null:
		_tween.kill()
	model.transform = _model_rest
	slide.position = _slide_rest
	model.show()
	_hold_hand_upright(false)


func _on_player_died() -> void:
	_lowered = true
	_restart_tween()
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(model, "transform", _lowered_transform(), raise_time)


func _lowered_transform() -> Transform3D:
	return _model_rest.translated_local(Vector3(0.0, -lower_distance, 0.0)).rotated_local(Vector3.RIGHT, deg_to_rad(lower_angle))


func _hold_hand_upright(upright: bool) -> void:
	if hand_anchor != null:
		hand_anchor.update_rotation = not upright


## A first-person model floats in front of the camera, so its shadow would fall where nothing is, and the player's
## own body shadow would speckle it.
static func detach_from_shadows(root: Node) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material != null:
				mesh.set_surface_override_material(surface, _unshadowed(material))


static func _unshadowed(material: BaseMaterial3D) -> BaseMaterial3D:
	if not _unshadowed_copies.has(material):
		var copy := material.duplicate() as BaseMaterial3D
		copy.disable_receive_shadows = true
		_unshadowed_copies[material] = copy
	return _unshadowed_copies[material]


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()


## Yaw and pitch of this node's view, in radians.
func _view_angles() -> Vector2:
	var forward := -global_basis.z
	return Vector2(atan2(-forward.x, -forward.z), asin(clampf(forward.y, -1.0, 1.0)))
