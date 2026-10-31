class_name Melee
extends Node
## The wielder's punch. A swing winds up, strikes once at the end of the wind-up, then recovers.
## The strike hits every living Health inside a sphere in front of the head, once each.

signal swung
## Emitted when the strike damages a Health that is alive. `killed` is true when it took that Health to 0. `headshot` is always false: a punch has no weak spot. The signal has the shape of Weapon.damaged, so one handler serves both.
signal damaged(target: Node, killed: bool, headshot: bool)

enum State { READY, WIND_UP, RECOVER }

@export_range(1.0, 1000.0, 1.0) var damage: float = 50.0
## How far in front of the head the strike reaches.
@export_range(0.5, 5.0, 0.05, "suffix:m") var reach: float = 1.8
## Radius of the strike sphere. A wider sphere forgives a poor aim.
@export_range(0.1, 2.0, 0.05, "suffix:m") var radius: float = 0.45
@export_range(0.01, 1.0, 0.01, "suffix:s") var wind_up_time: float = 0.1
@export_range(0.01, 2.0, 0.01, "suffix:s") var recover_time: float = 0.22
@export_flags_3d_physics var hit_mask: int = 1

## The player who punches. The strike never hits the wielder. Player sets it.
var wielder: Player

var _state: State = State.READY
var _time_left: float = 0.0


func _physics_process(delta: float) -> void:
	if _state == State.READY:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	if _state == State.WIND_UP:
		_state = State.RECOVER
		_time_left += recover_time
		_strike()
	else:
		_state = State.READY
		_time_left = 0.0


## Starts a swing. Returns false during a swing, and when the wielder is missing, downed, or dead.
func try_swing() -> bool:
	if _state != State.READY or wielder == null or wielder.is_dead() or wielder.is_downed():
		return false
	_state = State.WIND_UP
	_time_left = wind_up_time
	swung.emit()
	return true


func is_swinging() -> bool:
	return _state != State.READY


## How far the swing has gone, from 0 at its start to 1 at its end. -1 while ready.
func progress() -> float:
	var total := wind_up_time + recover_time
	match _state:
		State.WIND_UP:
			return (wind_up_time - _time_left) / total
		State.RECOVER:
			return (total - _time_left) / total
	return -1.0


## progress() between physics ticks, for a pose drawn every frame. Call it from _process.
func visual_progress() -> float:
	if _state == State.READY:
		return -1.0
	var step := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
	return minf(progress() + step / (wind_up_time + recover_time), 1.0)


func _strike() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	var aim := wielder.aim_transform()
	query.transform = Transform3D(Basis.IDENTITY, aim.origin - aim.basis.z * (reach - radius))
	query.collision_mask = hit_mask
	query.exclude = [wielder.get_rid()]
	var struck: Array[Health] = []
	for result: Dictionary in wielder.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider: Node = result["collider"]
		var health := Health.find_on(collider)
		if health == null or health.is_dead() or health in struck:
			continue
		struck.append(health)
		health.damage(damage)
		damaged.emit(collider, health.is_dead(), false)
