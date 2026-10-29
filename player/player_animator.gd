class_name PlayerAnimator
extends Node
## Poses the player's body model in code: a walk that follows the move speed, an idle sway, a pose in the air and
## on a slide, bent knees while crouched, a right arm that holds the gun where the player looks, and both arms up
## while aiming.
## It moves the parts of art_source/player.blend: LegL and LegR, each with a child shin (ShinL, ShinR) that has a
## child foot (FootL, FootR), and Torso with its children Head, ArmL, and ArmR.

@export_group("Walk")
## Full leg cycles for each metre walked.
@export_range(0.1, 3.0, 0.01) var steps_per_metre: float = 0.6
@export_range(0.0, 60.0, 0.5, "suffix:°") var leg_swing: float = 32.0
@export_range(0.0, 0.2, 0.005, "suffix:m") var bob_height: float = 0.03
@export_range(0.0, 30.0, 0.5, "suffix:°") var arm_swing: float = 24.0
## The body leans forward this far at sprint speed.
@export_range(0.0, 30.0, 0.5, "suffix:°") var run_lean: float = 8.0
## The speed at which the lean is full.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var run_speed: float = 7.0
## Below this speed the player stands and sways.
@export_range(0.0, 1.0, 0.01, "suffix:m/s") var walk_threshold: float = 0.1

@export_group("Idle")
@export_range(0.0, 5.0, 0.05, "suffix:Hz") var idle_rate: float = 0.4
@export_range(0.0, 10.0, 0.25, "suffix:°") var idle_sway: float = 2.0

@export_group("Air and slide")
## In the air and on a slide, the front leg goes forward and the back leg goes back by these angles.
@export_range(0.0, 90.0, 1.0, "suffix:°") var front_leg: float = 40.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var back_leg: float = 25.0
## In the air, the free arm lifts out by this angle.
@export_range(0.0, 120.0, 1.0, "suffix:°") var air_arm: float = 50.0

@export_group("Crouch")
## While crouched, each thigh swings forward by this angle and each shin bends back by twice it, so the feet stay
## under the hips and flat. The body drops to keep the feet on the floor.
@export_range(0.0, 85.0, 1.0, "suffix:°") var knee_bend: float = 80.0
@export_range(0.0, 45.0, 1.0, "suffix:°") var crouch_lean: float = 35.0

@export_group("Look")
## The right arm points forward by this angle when the player looks straight ahead.
@export_range(0.0, 120.0, 1.0, "suffix:°") var hold_angle: float = 80.0
## The part of the look pitch that the head follows. The arms that hold the gun follow all of it.
@export_range(0.0, 1.0, 0.01) var head_follow: float = 0.6

@export_group("Slap")
## The left arm lifts to this pitch for the backhand slap, before the look pitch is added.
@export_range(0.0, 120.0, 1.0, "suffix:°") var slap_lift: float = 75.0
## In the wind-up the arm turns this far to the right, across the body.
@export_range(0.0, 90.0, 1.0, "suffix:°") var slap_cross: float = 45.0
## The strike ends with the arm turned this far to the left.
@export_range(0.0, 90.0, 1.0, "suffix:°") var slap_sweep: float = 50.0
## The arm leans across the body by this angle at the top of the wind-up.
@export_range(0.0, 60.0, 1.0, "suffix:°") var slap_roll: float = 20.0
## The part of the slap that the wind-up takes. It matches the melee's wind_up_time over its whole time.
@export_range(0.01, 0.99, 0.01) var slap_wind_share: float = 0.28
## The part of the slap after the wind-up in which the arm sweeps. Then the arm blends back.
@export_range(0.01, 0.99, 0.01) var slap_sweep_share: float = 0.3

## How fast the pose blends between walking, standing, in the air, crouched, and aiming.
@export_range(0.1, 40.0, 0.1) var blend_sharpness: float = 12.0

var _leg_l: Node3D
var _leg_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _foot_l: Node3D
var _foot_r: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _torso_rest_y: float
var _hip_rest_y: float
var _hip_to_ankle: float
var _phase: float = 0.0
var _time: float = 0.0
var _walk_weight: float = 0.0
var _air_weight: float = 0.0
var _aim_weight: float = 0.0
var _crouch_weight: float = 0.0


## Finds the parts in the model. Call it before the first advance().
func attach(model: Node3D) -> void:
	_leg_l = _part(model, "LegL")
	_leg_r = _part(model, "LegR")
	_shin_l = _part(model, "ShinL")
	_shin_r = _part(model, "ShinR")
	_foot_l = _part(model, "FootL")
	_foot_r = _part(model, "FootR")
	_torso = _part(model, "Torso")
	_head = _part(model, "Head")
	_arm_l = _part(model, "ArmL")
	_arm_r = _part(model, "ArmR")
	_torso_rest_y = _torso.position.y
	_hip_rest_y = _leg_l.position.y
	_hip_to_ankle = -_shin_l.position.y - _foot_l.position.y


## Moves the pose on by one step. `look_pitch` is in radians, positive up. `airborne` is true in the air and on a
## slide, when the legs hold a stride instead of walking. `slap_progress` is how far the backhand slap has gone,
## from 0 to 1, or -1 when the player does not slap.
func advance(delta: float, speed: float, airborne: bool, crouching: bool, aiming: bool, look_pitch: float, slap_progress: float) -> void:
	_time += delta
	var blend := 1.0 - exp(-blend_sharpness * delta)
	_air_weight = lerpf(_air_weight, 1.0 if airborne else 0.0, blend)
	var grounded := 1.0 - _air_weight
	_walk_weight = lerpf(_walk_weight, 1.0 if speed > walk_threshold and not airborne else 0.0, blend)
	_aim_weight = lerpf(_aim_weight, 1.0 if aiming else 0.0, blend)
	_crouch_weight = lerpf(_crouch_weight, 1.0 if crouching else 0.0, blend)
	if not airborne:
		_phase = fmod(_phase + speed * delta * steps_per_metre * TAU, TAU)

	var step := sin(_phase)
	var idle := sin(_time * idle_rate * TAU) * (1.0 - _walk_weight) * grounded
	var stride := deg_to_rad(leg_swing) * step * _walk_weight
	var bend := deg_to_rad(knee_bend) * _crouch_weight
	_leg_l.rotation.x = stride + deg_to_rad(front_leg) * _air_weight + bend
	_leg_r.rotation.x = -stride - deg_to_rad(back_leg) * _air_weight + bend
	_shin_l.rotation.x = -2.0 * bend
	_shin_r.rotation.x = -2.0 * bend
	_foot_l.rotation.x = bend
	_foot_r.rotation.x = bend
	var drop := _hip_to_ankle * (1.0 - cos(bend))
	_leg_l.position.y = _hip_rest_y - drop
	_leg_r.position.y = _hip_rest_y - drop
	_torso.position.y = _torso_rest_y - drop + bob_height * absf(cos(_phase)) * _walk_weight
	var lean := run_lean * clampf(speed / run_speed, 0.0, 1.0) * _walk_weight + crouch_lean * _crouch_weight
	_torso.rotation.x = deg_to_rad(-lean)
	_torso.rotation.z = deg_to_rad(idle_sway * idle)
	_head.rotation.x = look_pitch * head_follow + deg_to_rad(lean)

	var hold := deg_to_rad(hold_angle + lean) + look_pitch
	var swing := deg_to_rad(arm_swing) * cos(_phase) * _walk_weight
	_arm_r.rotation.x = hold
	var free_arm := Vector3(
		lerpf(-swing - deg_to_rad(air_arm) * _air_weight, hold, _aim_weight),
		0.0,
		deg_to_rad(-0.5 * air_arm) * _air_weight * (1.0 - _aim_weight),
	)
	_arm_l.rotation = _slap_arm(free_arm, slap_progress, look_pitch)


## The pitch of the left leg in radians. Positive swings it forward.
func leg_pitch() -> float:
	return _leg_l.rotation.x


## The pitch of the right arm, which holds the gun, in radians. Positive raises it.
func gun_arm_pitch() -> float:
	return _arm_r.rotation.x


## The pitch of the left arm in radians. Positive raises it.
func free_arm_pitch() -> float:
	return _arm_l.rotation.x


## The pitch of the left shin against its thigh in radians. Negative bends the knee.
func knee_pitch() -> float:
	return _shin_l.rotation.x


## The pitch of the head in radians. Positive tilts it up.
func head_pitch() -> float:
	return _head.rotation.x


## The left arm rotation for the slap: it lifts and crosses the body, sweeps out to the left, then blends back
## to `free_arm`.
func _slap_arm(free_arm: Vector3, progress: float, look_pitch: float) -> Vector3:
	if progress < 0.0:
		return free_arm
	var sweep_end := slap_wind_share + (1.0 - slap_wind_share) * slap_sweep_share
	var weight := 1.0
	var yaw := deg_to_rad(slap_sweep)
	if progress < slap_wind_share:
		weight = _ease_out(progress / slap_wind_share)
		yaw = deg_to_rad(-slap_cross)
	elif progress < sweep_end:
		yaw = lerpf(deg_to_rad(-slap_cross), yaw, _ease_out((progress - slap_wind_share) / (sweep_end - slap_wind_share)))
	else:
		weight = 1.0 - (progress - sweep_end) / (1.0 - sweep_end)
	var slap := Vector3(deg_to_rad(slap_lift) + look_pitch, yaw, deg_to_rad(slap_roll))
	return free_arm.lerp(slap, weight)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


func _part(model: Node3D, part_name: String) -> Node3D:
	var part := model.find_child(part_name) as Node3D
	if part == null:
		push_error("PlayerAnimator: the model has no part named %s." % part_name)
	return part
