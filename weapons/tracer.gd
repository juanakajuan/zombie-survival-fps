class_name Tracer
extends MeshInstance3D
## A bright streak that flies from the muzzle to where a shot ended, then frees itself.
## It only shows the shot. The hitscan ray already did the damage.

const GROUP := &"tracer"

@export_range(10.0, 2000.0, 1.0, "suffix:m/s") var speed: float = 120.0
@export_range(0.05, 20.0, 0.05, "suffix:m") var length: float = 3.0

var _from: Vector3
var _direction: Vector3
var _distance: float
var _travelled: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	# The tracer moves every frame on its own, so interpolation between physics ticks would only make it lag.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	hide()


## Starts the flight. Call it after the tracer is in the tree.
func launch(from: Vector3, to: Vector3) -> void:
	_from = from
	_distance = from.distance_to(to)
	_direction = from.direction_to(to)
	_place()


## The point of the streak that is farthest along the shot.
func head() -> Vector3:
	return _from + _direction * _travelled


func _process(delta: float) -> void:
	_travelled = minf(_travelled + speed * delta, _distance)
	if _travelled >= _distance:
		queue_free()
		return
	_place()


func _place() -> void:
	var streak := minf(length, _travelled)
	if streak <= 0.0 or _direction.is_zero_approx():
		hide()
		return
	var up := Vector3.UP if absf(_direction.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var look := Basis.looking_at(_direction, up)
	look.z *= streak
	global_transform = Transform3D(look, head() - _direction * streak * 0.5)
	show()
