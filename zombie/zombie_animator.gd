class_name ZombieAnimator
extends Node
## Poses the zombie model in code: a shambling walk that follows the move speed, an idle sway, an arm slam on each hit,
## and a fall onto its back when it dies. A RUN zombie blends the walk into a run: a forward lean, longer strides, and
## arms that reach out and pump.
## It moves the parts of art_source/zombie.blend: LegL, LegR, Torso, and its children Head, ArmL, and ArmR.

@export_group("Walk")
## Full leg cycles for each metre walked.
@export_range(0.1, 3.0, 0.01) var steps_per_metre: float = 0.45
@export_range(0.0, 60.0, 0.5, "suffix:°") var leg_swing: float = 28.0
@export_range(0.0, 0.2, 0.005, "suffix:m") var bob_height: float = 0.04
@export_range(0.0, 20.0, 0.5, "suffix:°") var torso_sway: float = 6.0
@export_range(0.0, 30.0, 0.5, "suffix:°") var arm_swing: float = 10.0
@export_range(0.0, 30.0, 0.5, "suffix:°") var head_wobble: float = 8.0
## Below this speed the zombie stands and sways.
@export_range(0.0, 1.0, 0.01, "suffix:m/s") var walk_threshold: float = 0.1

@export_group("Run")
## Full leg cycles for each metre run. It is below the walk value, because the longer swing covers more ground in a
## cycle. Fit it to RoundSettings.runner_speed so the feet do not slide.
@export_range(0.1, 3.0, 0.01) var run_steps_per_metre: float = 0.35
@export_range(0.0, 80.0, 0.5, "suffix:°") var run_leg_swing: float = 50.0
@export_range(0.0, 0.3, 0.005, "suffix:m") var run_bob_height: float = 0.08
## The torso leans forward this far while it runs.
@export_range(0.0, 60.0, 0.5, "suffix:°") var run_lean: float = 22.0
## The head tips back this far against the lean, so that the zombie looks ahead.
@export_range(0.0, 60.0, 0.5, "suffix:°") var run_head_lift: float = 20.0
## The arms reach forward this far while it runs.
@export_range(0.0, 120.0, 1.0, "suffix:°") var run_arm_reach: float = 50.0
## Around the reach, the arms pump this far, one up and one down.
@export_range(0.0, 60.0, 0.5, "suffix:°") var run_arm_pump: float = 30.0

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

@export_group("Death")
## The zombie falls back this far, from its feet.
@export_range(0.0, 120.0, 1.0, "suffix:°") var fall_angle: float = 88.0
@export_range(0.05, 3.0, 0.01, "suffix:s") var fall_time: float = 0.55
## When it lands, the body bounces up by this angle and settles again.
@export_range(0.0, 30.0, 0.5, "suffix:°") var bounce_angle: float = 7.0
@export_range(0.01, 1.0, 0.01, "suffix:s") var bounce_time: float = 0.25
## The arms fling up toward the head as it falls.
@export_range(0.0, 180.0, 1.0, "suffix:°") var arm_fling: float = 70.0
## The legs kick up as it falls.
@export_range(0.0, 90.0, 1.0, "suffix:°") var leg_kick: float = 25.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var head_loll: float = 30.0
## Time the body lies still before it sinks.
@export_range(0.0, 10.0, 0.05, "suffix:s") var lie_time: float = 1.2
@export_range(0.01, 5.0, 0.01, "suffix:s") var sink_time: float = 0.8
@export_range(0.0, 2.0, 0.01, "suffix:m") var sink_depth: float = 0.5

## How fast the pose blends between walking, standing, and attacking.
@export_range(0.1, 40.0, 0.1) var blend_sharpness: float = 10.0

## The gait to pose. The pose blends toward it. Set it before attach(), which starts the blend at this gait.
var gait: Zombie.Gait = Zombie.Gait.WALK

var _model: Node3D
var _model_rest_y: float
var _death_time: float = 0.0
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
var _run_weight: float = 0.0
var _attack_weight: float = 0.0


## Finds the parts in the model. Call it before the first advance().
func attach(model: Node3D) -> void:
	_model = model
	_model_rest_y = model.position.y
	_leg_l = _part(model, "LegL")
	_leg_r = _part(model, "LegR")
	_torso = _part(model, "Torso")
	_head = _part(model, "Head")
	_arm_l = _part(model, "ArmL")
	_arm_r = _part(model, "ArmR")
	_torso_rest_y = _torso.position.y
	_run_weight = _run_target()


## Moves the pose on by one step. `attack_progress` goes from 0 just after a hit to 1 at the next hit, and is
## negative when the zombie is not attacking.
func advance(delta: float, speed: float, attack_progress: float) -> void:
	_time += delta
	var blend := 1.0 - exp(-blend_sharpness * delta)
	_run_weight = lerpf(_run_weight, _run_target(), blend)
	_phase = fmod(_phase + speed * delta * lerpf(steps_per_metre, run_steps_per_metre, _run_weight) * TAU, TAU)
	_walk_weight = lerpf(_walk_weight, 1.0 if speed > walk_threshold else 0.0, blend)
	_attack_weight = lerpf(_attack_weight, 1.0 if attack_progress >= 0.0 else 0.0, blend)

	var step := sin(_phase)
	var idle := sin(_time * idle_rate * TAU) * (1.0 - _walk_weight)
	_leg_l.rotation.x = deg_to_rad(lerpf(leg_swing, run_leg_swing, _run_weight)) * step * _walk_weight
	_leg_r.rotation.x = -_leg_l.rotation.x
	_torso.position.y = _torso_rest_y + lerpf(bob_height, run_bob_height, _run_weight) * absf(cos(_phase)) * _walk_weight
	_torso.rotation.z = deg_to_rad(torso_sway * step * _walk_weight + idle_sway * idle)
	_head.rotation.z = deg_to_rad(head_wobble * sin(_phase * 0.5) * _walk_weight - idle_sway * idle)

	var run_pose := _run_weight * _walk_weight
	_head.rotation.x = deg_to_rad(run_head_lift) * run_pose
	var swing := deg_to_rad(lerpf(arm_swing, run_arm_pump, _run_weight)) * cos(_phase) * _walk_weight
	var reach := deg_to_rad(run_arm_reach) * run_pose
	var slam := _slam_amount(attack_progress)
	var wind_up := _wind_up_amount(attack_progress)
	var attack_pitch := deg_to_rad(wind_up_angle * wind_up - slam_angle * slam)
	_arm_l.rotation.x = lerpf(reach + swing, attack_pitch, _attack_weight)
	_arm_r.rotation.x = lerpf(reach - swing, attack_pitch, _attack_weight)
	var lunge := deg_to_rad(lunge_angle * (0.3 * wind_up - slam))
	_torso.rotation.x = lerpf(-deg_to_rad(run_lean) * run_pose, lunge, _attack_weight)


## Moves the death pose on by one step. Call it each physics frame after the zombie dies, until death_finished().
func advance_death(delta: float) -> void:
	_death_time += delta
	var blend := 1.0 - exp(-blend_sharpness * delta)
	var fall := clampf(_death_time / fall_time, 0.0, 1.0)
	var bounce := clampf((_death_time - fall_time) / bounce_time, 0.0, 1.0)
	_model.rotation.x = deg_to_rad(fall_angle * fall * fall - bounce_angle * sin(PI * bounce))
	var sink_start := fall_time + bounce_time + lie_time
	var sink := clampf((_death_time - sink_start) / sink_time, 0.0, 1.0)
	_model.position.y = _model_rest_y - sink_depth * sink
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, deg_to_rad(arm_fling), blend)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, deg_to_rad(arm_fling * 0.8), blend)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, deg_to_rad(leg_kick), blend)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, deg_to_rad(leg_kick * 0.5), blend)
	_torso.rotation.x = lerpf(_torso.rotation.x, 0.0, blend)
	_head.rotation.x = lerpf(_head.rotation.x, 0.0, blend)
	_head.rotation.z = lerpf(_head.rotation.z, deg_to_rad(head_loll) * fall, blend)


## Whether the death pose has played to the end, so the zombie can go.
func death_finished() -> bool:
	return _death_time >= death_length()


## The time from death until the zombie goes.
func death_length() -> float:
	return fall_time + bounce_time + lie_time + sink_time


## How far the model has fallen back from standing, in radians.
func fall_tilt() -> float:
	return _model.rotation.x


## The pitch of the left leg in radians. Positive swings it forward.
func leg_pitch() -> float:
	return _leg_l.rotation.x


## The pitch of the left arm in radians. Positive raises it.
func arm_pitch() -> float:
	return _arm_l.rotation.x


## How far the torso leans forward from standing, in radians. Positive leans forward.
func torso_lean() -> float:
	return -_torso.rotation.x


func _run_target() -> float:
	return 1.0 if gait == Zombie.Gait.RUN else 0.0


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
