class_name Burn
extends Node3D
## The fire on a target. It is a child of the target, damages the target's Health on a timer, and frees itself when
## the time runs out or the target dies. FireEffect adds it, and a target has at most one.

@onready var _flames: CPUParticles3D = $Flames
@onready var _health: Health = Health.find_on(get_parent())

var _fire: FireEffect
var _source: Weapon
var _time_left: float = 0.0
var _tick_left: float = 0.0


func _ready() -> void:
	_health.died.connect(queue_free)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_tick_left -= delta
	while _tick_left <= 0.0 and not _health.is_dead():
		_tick_left += _fire.tick_interval
		_tick()
	if _time_left <= 0.0:
		queue_free()


## Returns the Burn that is a child of `node`, or null.
static func find_on(node: Node) -> Burn:
	for child: Node in node.get_children():
		if child is Burn:
			return child as Burn
	return null


## Starts the burn, or restarts its time. The tick timer keeps running, so a fast weapon does not hold the first tick
## back. `source` is the weapon that gets the points for the next ticks.
func ignite(fire: FireEffect, source: Weapon) -> void:
	if _fire == null:
		_tick_left = fire.tick_interval
	_fire = fire
	_source = source
	# Both timers drift by float error, so a tick due at the very end of the burn would land on either side of it.
	# Half a physics frame of slack makes that last tick always count.
	_time_left = fire.burn_time + 0.5 * get_physics_process_delta_time()


## The seconds before the fire goes out.
func time_left() -> float:
	return _time_left


func is_emitting() -> bool:
	return _flames.emitting


func _tick() -> void:
	_health.damage(_fire.tick_damage)
	if is_instance_valid(_source):
		_source.effect_damaged.emit(get_parent(), _health.is_dead())
