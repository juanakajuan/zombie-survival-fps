class_name MuttAnimator
extends BodyAnimator
## Poses the Mutt model in code: a trot with the diagonal legs together, a wagging tail, a bite on each hit, and a fall
## onto its side when it dies. It ignores the gait: the Mutt always trots.
## It moves the parts of art_source/mutt.blend: Body, and its children Head, Tail, LegFL, LegFR, LegBL, and LegBR.

@export_group("Trot")
## Full leg cycles for each metre trotted. Fit it to RoundSettings.special_speed so the feet do not slide.
@export_range(0.1, 5.0, 0.01) var steps_per_metre: float = 0.9
@export_range(0.0, 80.0, 0.5, "suffix:°") var leg_swing: float = 40.0
## The body bobs this far, two times in each cycle.
@export_range(0.0, 0.2, 0.005, "suffix:m") var bob_height: float = 0.04
## The body rocks nose up and nose down this far.
@export_range(0.0, 20.0, 0.5, "suffix:°") var body_rock: float = 4.0
@export_range(0.0, 30.0, 0.5, "suffix:°") var head_nod: float = 8.0
## Below this speed the Mutt stands.
@export_range(0.0, 1.0, 0.01, "suffix:m/s") var walk_threshold: float = 0.1

@export_group("Tail")
@export_range(0.0, 10.0, 0.1, "suffix:Hz") var wag_rate: float = 3.0
@export_range(0.0, 60.0, 0.5, "suffix:°") var wag_angle: float = 25.0

@export_group("Bite")
## The body rears up this far as the next bite comes.
@export_range(0.0, 45.0, 0.5, "suffix:°") var rear_angle: float = 18.0
## On the bite the body lunges nose down this far, then comes back.
@export_range(0.0, 45.0, 0.5, "suffix:°") var lunge_angle: float = 14.0
@export_range(0.0, 0.5, 0.01, "suffix:m") var lunge_distance: float = 0.15
## The head snaps down this far on the bite.
@export_range(0.0, 60.0, 0.5, "suffix:°") var bite_angle: float = 25.0
## The part of the attack interval before a bite that the rear takes.
@export_range(0.0, 1.0, 0.01) var rear_fraction: float = 0.4
## The part of the attack interval after a bite that the lunge takes.
@export_range(0.0, 1.0, 0.01) var lunge_fraction: float = 0.25

@export_group("Death")
## The Mutt falls onto its side this far.
@export_range(0.0, 120.0, 1.0, "suffix:°") var fall_angle: float = 85.0
@export_range(0.05, 3.0, 0.01, "suffix:s") var fall_time: float = 0.35
## The legs go stiff, front legs forward and back legs back, by this angle.
@export_range(0.0, 90.0, 1.0, "suffix:°") var leg_stiffen: float = 30.0
## Time the body lies still before it sinks.
@export_range(0.0, 10.0, 0.05, "suffix:s") var lie_time: float = 1.0
@export_range(0.01, 5.0, 0.01, "suffix:s") var sink_time: float = 0.8
@export_range(0.0, 2.0, 0.01, "suffix:m") var sink_depth: float = 0.6

## How fast the pose blends between trotting, standing, and biting.
@export_range(0.1, 40.0, 0.1) var blend_sharpness: float = 12.0

var _model: Node3D
var _model_rest_y: float
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _front_left: Node3D
var _front_right: Node3D
var _back_left: Node3D
var _back_right: Node3D
var _body_rest: Vector3
var _head_rest: Vector3
var _phase: float = 0.0
var _time: float = 0.0
var _walk_weight: float = 0.0
var _attack_weight: float = 0.0
var _death_time: float = 0.0


func attach(model: Node3D) -> void:
	_model = model
	_model_rest_y = model.position.y
	_body = _part(model, "Body")
	_head = _part(model, "Head")
	_tail = _part(model, "Tail")
	_front_left = _part(model, "LegFL")
	_front_right = _part(model, "LegFR")
	_back_left = _part(model, "LegBL")
	_back_right = _part(model, "LegBR")
	_body_rest = _body.position
	_head_rest = _head.rotation


func advance(delta: float, speed: float, attack_progress: float) -> void:
	_time += delta
	var blend := 1.0 - exp(-blend_sharpness * delta)
	_phase = fmod(_phase + speed * delta * steps_per_metre * TAU, TAU)
	_walk_weight = lerpf(_walk_weight, 1.0 if speed > walk_threshold else 0.0, blend)
	_attack_weight = lerpf(_attack_weight, 1.0 if attack_progress >= 0.0 else 0.0, blend)

	var swing := deg_to_rad(leg_swing) * sin(_phase) * _walk_weight
	_front_left.rotation.x = swing
	_back_right.rotation.x = swing
	_front_right.rotation.x = -swing
	_back_left.rotation.x = -swing
	_tail.rotation.y = deg_to_rad(wag_angle) * sin(_time * wag_rate * TAU)

	var rear := _ramp_up(attack_progress, rear_fraction)
	var lunge := _ramp_down(attack_progress, lunge_fraction)
	var trot_pitch := deg_to_rad(body_rock) * sin(2.0 * _phase) * _walk_weight
	var bite_pitch := deg_to_rad(rear_angle * rear - lunge_angle * lunge)
	_body.rotation.x = lerpf(trot_pitch, bite_pitch, _attack_weight)
	var bob := bob_height * absf(sin(_phase)) * _walk_weight
	_body.position = _body_rest + Vector3(0.0, bob, -lunge_distance * lunge * _attack_weight)
	var nod := deg_to_rad(head_nod) * cos(2.0 * _phase) * _walk_weight
	_head.rotation.x = _head_rest.x + lerpf(nod, deg_to_rad(rear_angle * rear - bite_angle * lunge), _attack_weight)


func advance_death(delta: float) -> void:
	_death_time += delta
	var blend := 1.0 - exp(-blend_sharpness * delta)
	var fall := clampf(_death_time / fall_time, 0.0, 1.0)
	_model.rotation.z = deg_to_rad(fall_angle) * fall * fall
	var sink := clampf((_death_time - fall_time - lie_time) / sink_time, 0.0, 1.0)
	_model.position.y = _model_rest_y - sink_depth * sink
	var stiff := deg_to_rad(leg_stiffen)
	_front_left.rotation.x = lerpf(_front_left.rotation.x, stiff, blend)
	_front_right.rotation.x = lerpf(_front_right.rotation.x, stiff * 0.8, blend)
	_back_left.rotation.x = lerpf(_back_left.rotation.x, -stiff, blend)
	_back_right.rotation.x = lerpf(_back_right.rotation.x, -stiff * 0.8, blend)
	_body.rotation.x = lerpf(_body.rotation.x, 0.0, blend)
	_head.rotation.x = lerpf(_head.rotation.x, _head_rest.x, blend)
	_tail.rotation.y = lerpf(_tail.rotation.y, 0.0, blend)


func death_finished() -> bool:
	return _death_time >= death_length()


func death_length() -> float:
	return fall_time + lie_time + sink_time


## How far the model has rolled onto its side, in radians.
func side_tilt() -> float:
	return _model.rotation.z


## The pitch of the front left leg in radians. Positive swings it forward.
func front_leg_pitch() -> float:
	return _front_left.rotation.x


## The pitch of the head in radians from its rest pose. Negative snaps it down.
func head_pitch() -> float:
	return _head.rotation.x - _head_rest.x


func _ramp_up(progress: float, fraction: float) -> float:
	if progress < 1.0 - fraction:
		return 0.0
	return smoothstep(1.0 - fraction, 1.0, progress)


func _ramp_down(progress: float, fraction: float) -> float:
	if progress < 0.0 or progress > fraction:
		return 0.0
	return 1.0 - progress / fraction


func _part(model: Node3D, part_name: String) -> Node3D:
	var part := model.find_child(part_name) as Node3D
	if part == null:
		push_error("MuttAnimator: the model has no part named %s." % part_name)
	return part
