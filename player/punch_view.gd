class_name PunchView
extends Node3D
## First-person left fist for the punch. It is a child of the camera. The fist is hidden while the melee is ready,
## and in a swing it plays three poses from the melee's progress: it comes up and pulls back at the lower left, jabs
## straight out to the screen centre, and drops back out of view.
## Positions are in camera space, where -Z is forward. Angles are pitch, yaw, and roll in degrees. At zero angles
## the knuckles point forward and the back of the hand points up.

@export var hand: Node3D

@export_group("Poses")
@export var start_position: Vector3 = Vector3(-0.14, -0.45, -0.15)
@export var start_angles: Vector3 = Vector3(30.0, 0.0, 0.0)
## The fist pulled back, ready to jab.
@export var cocked_position: Vector3 = Vector3(-0.13, -0.24, -0.18)
@export var cocked_angles: Vector3 = Vector3(10.0, -5.0, -20.0)
## Where the jab ends.
@export var strike_position: Vector3 = Vector3(-0.04, -0.1, -0.5)
@export var strike_angles: Vector3 = Vector3(0.0, -8.0, 0.0)
## Where the fist leaves the view.
@export var exit_position: Vector3 = Vector3(-0.14, -0.45, -0.15)
@export var exit_angles: Vector3 = Vector3(30.0, 0.0, 0.0)
## The fist rises this far in the middle of the jab.
@export var strike_arc: Vector3 = Vector3(0.0, 0.02, 0.0)

@export_group("Timing")
## The jab starts this fraction of the wind-up before the strike, so that the fist is out when the strike lands.
@export_range(0.0, 1.0, 0.01) var jab_lead: float = 0.4
## The jab ends this fraction of the recover time after the strike.
@export_range(0.01, 1.0, 0.01) var strike_fraction: float = 0.3

## The melee that drives the pose. Player sets it.
var melee: Melee


func _ready() -> void:
	ViewModel.detach_from_shadows(self)
	hand.hide()


func _process(_delta: float) -> void:
	if melee == null:
		return
	var progress := melee.progress()
	hand.visible = progress >= 0.0
	if progress < 0.0:
		return
	var total := melee.wind_up_time + melee.recover_time
	var time := progress * total
	var cock_end := melee.wind_up_time * (1.0 - jab_lead)
	var jab_end := melee.wind_up_time + melee.recover_time * strike_fraction
	var place: Vector3
	var angles: Vector3
	if time < cock_end:
		var t := _ease_out(time / maxf(cock_end, 0.0001))
		place = start_position.lerp(cocked_position, t)
		angles = start_angles.lerp(cocked_angles, t)
	elif time < jab_end:
		var s := (time - cock_end) / maxf(jab_end - cock_end, 0.0001)
		var t := _ease_out(s)
		place = cocked_position.lerp(strike_position, t) + strike_arc * sin(PI * s)
		angles = cocked_angles.lerp(strike_angles, t)
	else:
		var r := (time - jab_end) / maxf(total - jab_end, 0.0001)
		var t := r * r
		place = strike_position.lerp(exit_position, t)
		angles = strike_angles.lerp(exit_angles, t)
	hand.transform = Transform3D(Basis.from_euler(angles * (PI / 180.0)), place)


## Whether the hand is drawn: a swing is on and the view is not hidden.
func is_hand_visible() -> bool:
	return hand.is_visible_in_tree()


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
