class_name GrenadeView
extends Node3D
## First-person left hand that holds a grenade. It is a child of the camera. The hand is hidden while the grenades are
## ready. The pin pull raises it from the lower left to a cocked pose at the left of the view, where it trembles a
## little while the grenade cooks. The throw swings it forward and up across the view centre, the grenade leaves it
## there, and the hand drops out of view.
## Positions are in camera space, where -Z is forward. Angles are pitch, yaw, and roll in degrees. At zero angles
## the knuckles point forward and the back of the hand points up.

@export var hand: Node3D
## The grenade in the hand. A child of the hand.
@export var grenade: Node3D

@export_group("Poses")
## Where the hand starts to rise and where it ends up out of view.
@export var low_position: Vector3 = Vector3(-0.2, -0.5, -0.1)
@export var low_angles: Vector3 = Vector3(30.0, 0.0, 0.0)
## The hand held back, with the pin out.
@export var cocked_position: Vector3 = Vector3(-0.18, -0.04, -0.34)
@export var cocked_angles: Vector3 = Vector3(35.0, -20.0, -25.0)
## Where the throw ends, as the grenade leaves the hand.
@export var throw_position: Vector3 = Vector3(0.0, -0.08, -0.5)
@export var throw_angles: Vector3 = Vector3(30.0, -10.0, 0.0)
## The hand rises this far in the middle of the throw.
@export var throw_arc: Vector3 = Vector3(0.0, 0.05, 0.0)

@export_group("Tremble")
@export_range(0.0, 0.02, 0.0005, "suffix:m") var tremble_amount: float = 0.003
@export_range(1.0, 100.0, 1.0, "suffix:rad/s") var tremble_speed: float = 45.0

## The grenades that drive the pose.
@export var grenades: Grenades


func _ready() -> void:
	ViewModel.detach_from_shadows(self)
	hand.hide()


func _process(_delta: float) -> void:
	if grenades == null:
		return
	var state := grenades.state()
	hand.visible = state != Grenades.State.READY
	grenade.visible = grenades.has_grenade_in_hand()
	var fraction := grenades.visual_fraction()
	var place: Vector3
	var angles: Vector3
	match state:
		Grenades.State.COOKING:
			var t := _ease_out(fraction)
			place = low_position.lerp(cocked_position, t)
			angles = low_angles.lerp(cocked_angles, t)
			var time := Time.get_ticks_msec() / 1000.0
			place += Vector3(sin(time * tremble_speed), cos(time * tremble_speed * 1.3), 0.0) * tremble_amount * fraction
		Grenades.State.WINDING:
			var r := _ease_out(grenades.raise_at_release())
			var t := fraction * fraction
			place = low_position.lerp(cocked_position, r).lerp(throw_position, t) + throw_arc * sin(PI * fraction)
			angles = low_angles.lerp(cocked_angles, r).lerp(throw_angles, t)
		Grenades.State.RECOVERING:
			var t := smoothstep(0.0, 1.0, fraction)
			place = throw_position.lerp(low_position, t)
			angles = throw_angles.lerp(low_angles, t)
		_:
			return
	hand.transform = Transform3D(Basis.from_euler(angles * (PI / 180.0)), place)


## Whether the hand is drawn: a cook or a throw is on and the view is not hidden.
func is_hand_visible() -> bool:
	return hand.is_visible_in_tree()


func is_grenade_visible() -> bool:
	return grenade.is_visible_in_tree()


func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
