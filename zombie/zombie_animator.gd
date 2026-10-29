class_name ZombieAnimator
extends Node
## Poses the zombie model in code: a shambling walk that follows the move speed, an idle sway, and an arm slam on each hit.
## It moves the parts that art_source/zombie.py makes: LegL, LegR, Torso, and its children Head, ArmL, and ArmR.

@export_group("Walk")
## Full leg cycles for each metre walked.
@export_range(0.1, 3.0, 0.01) var steps_per_metre: float = 0.9
@export_range(0.0, 60.0, 0.5, "suffix:°") var leg_swing: float = 28.0
@export_range(0.0, 0.2, 0.005, "suffix:m") var bob_height: float = 0.04
@export_range(0.0, 20.0, 0.5, "suffix:°") var torso_sway: float = 6.0
@export_range(0.0, 30.0, 0.5, "suffix:°") var arm_swing: float = 10.0
@export_range(0.0, 30.0, 0.5, "suffix:°") var head_wobble: float = 8.0
## Below this speed the zombie stands and sways.
@export_range(0.0, 1.0, 0.01, "suffix:m/s") var walk_threshold: float = 0.1

@export_group("Idle")
@export_range(0.0, 5.0, 0.05, "suffix:Hz") var idle_rate: float = 0.6
@export_range(0.0, 20.0, 0.5, "suffix:°") var idle_sway: float = 3.0

@export_group("Attack")
## The arms lift this far as the next hit comes.
@export_range(0.0, 120.0, 1.0, "suffix:°") var wind_up_angle: float = 55.0
## On the hit the arms slam down this far below rest, then come back.
@export_range(0.0, 90.0, 1.0, "suffix:°") var slam_angle: float = 35.0
## The part of the attack interval before a hit that the wind-up takes.
@export_range(0.0, 1.0, 0.01) var wind_up_fraction: float = 0.4
## The part of the attack interval after a hit that the slam takes.
@export_range(0.0, 1.0, 0.01) var slam_fraction: float = 0.2
@export_range(0.0, 30.0, 0.5, "suffix:°") var lunge_angle: float = 12.0

## How fast the pose blends between walking, standing, and attacking.
@export_range(0.1, 40.0, 0.1) var blend_sharpness: float = 10.0

var _leg_l: Node3D
var _leg_r: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _torso_rest_y: float
var _phase: float = 0.0
var _time: float = 0.0
var _walk_weight: float = 0.0
var _attack_weight: float = 0.0


## Finds the parts in the model. Call it before the first advance().
func attach(model: Node3D) -> void:
	_leg_l = _part(model, "LegL")
	_leg_r = _part(model, "LegR")
	_torso = _part(model, "Torso")
	_head = _part(model, "Head")
	_arm_l = _part(model, "ArmL")
	_arm_r = _part(model, "ArmR")
	_torso_rest_y = _torso.position.y


## Moves the pose on by one step. `attack_progress` goes from 0 just after a hit to 1 at the next hit, and is
## negative when the zombie is not attacking.
func advance(delta: float, speed: float, attack_progress: float) -> void:
	_time += delta
	_phase = fmod(_phase + speed * delta * steps_per_metre * TAU, TAU)
	var blend := 1.0 - exp(-blend_sharpness * delta)
	_walk_weight = lerpf(_walk_weight, 1.0 if speed > walk_threshold else 0.0, blend)
	_attack_weight = lerpf(_attack_weight, 1.0 if attack_progress >= 0.0 else 0.0, blend)

	var step := sin(_phase)
	var idle := sin(_time * idle_rate * TAU) * (1.0 - _walk_weight)
	_leg_l.rotation.x = deg_to_rad(leg_swing) * step * _walk_weight
	_leg_r.rotation.x = -_leg_l.rotation.x
	_torso.position.y = _torso_rest_y + bob_height * absf(cos(_phase)) * _walk_weight
	_torso.rotation.z = deg_to_rad(torso_sway * step * _walk_weight + idle_sway * idle)
	_head.rotation.z = deg_to_rad(head_wobble * sin(_phase * 0.5) * _walk_weight - idle_sway * idle)

	var swing := deg_to_rad(arm_swing) * cos(_phase) * _walk_weight
	var slam := _slam_amount(attack_progress)
	var wind_up := _wind_up_amount(attack_progress)
	var attack_pitch := deg_to_rad(wind_up_angle * wind_up - slam_angle * slam)
	_arm_l.rotation.x = lerpf(swing, attack_pitch, _attack_weight)
	_arm_r.rotation.x = lerpf(-swing, attack_pitch, _attack_weight)
	_torso.rotation.x = deg_to_rad(lunge_angle * (0.3 * wind_up - slam)) * _attack_weight


## The pitch of the left leg in radians. Positive swings it forward.
func leg_pitch() -> float:
	return _leg_l.rotation.x


## The pitch of the left arm in radians. Positive raises it.
func arm_pitch() -> float:
	return _arm_l.rotation.x


func _wind_up_amount(progress: float) -> float:
	if progress < 1.0 - wind_up_fraction:
		return 0.0
	return smoothstep(1.0 - wind_up_fraction, 1.0, progress)


func _slam_amount(progress: float) -> float:
	if progress < 0.0 or progress > slam_fraction:
		return 0.0
	return 1.0 - progress / slam_fraction


func _part(model: Node3D, part_name: String) -> Node3D:
	var part := model.find_child(part_name) as Node3D
	if part == null:
		push_error("ZombieAnimator: the model has no part named %s." % part_name)
	return part
