class_name RoundManager
extends Node
## Runs the rounds. Round 1 starts when the level loads. Each round spawns its zombies at the Marker3D children, one
## after the other. When the last zombie of the round dies, the break starts, and the next round starts after it.

signal round_started(round_number: int)
signal round_ended(round_number: int)

enum State { BREAK, ACTIVE }

## The HUD is in the player scene, so it finds the manager of the level by this group.
const GROUP := &"round_manager"

@export var settings: RoundSettings
@export var zombie_scene: PackedScene = preload("res://zombie/zombie.tscn")

## The current round. It is 0 until round 1 starts. During a break, it is the round that just ended.
var round_number: int = 0
var state: State = State.BREAK

var _spawn_points: Array[Marker3D] = []
var _next_spawn_point: int = 0
var _zombies_to_spawn: int = 0
var _zombies_alive: int = 0
var _spawn_cooldown: float = 0.0
var _break_left: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for child: Node in get_children():
		if child is Marker3D:
			_spawn_points.append(child as Marker3D)
	if _spawn_points.is_empty():
		push_error("RoundManager: add Marker3D children as spawn points.")
		return
	# Deferred so that the player is in its group before the first zombie looks for it.
	_start_round.call_deferred(1)


## The zombies of the current round that are alive or not spawned yet.
func zombies_left() -> int:
	return _zombies_alive + _zombies_to_spawn


## The seconds until the next round starts. It is 0 during a round.
func break_time_left() -> float:
	return maxf(_break_left, 0.0) if state == State.BREAK else 0.0


func _physics_process(delta: float) -> void:
	match state:
		State.ACTIVE:
			if _zombies_to_spawn == 0:
				return
			_spawn_cooldown -= delta
			if _spawn_cooldown <= 0.0:
				_spawn_zombie()
		State.BREAK:
			if round_number == 0:
				return
			_break_left -= delta
			if _break_left <= 0.0:
				_start_round(round_number + 1)


func _start_round(number: int) -> void:
	round_number = number
	state = State.ACTIVE
	_zombies_to_spawn = settings.zombie_count(number)
	round_started.emit(number)
	_spawn_zombie()


func _spawn_zombie() -> void:
	var zombie := zombie_scene.instantiate() as Zombie
	zombie.configure(settings.zombie_speed(round_number), settings.zombie_health(round_number))
	Health.find_on(zombie).died.connect(_on_zombie_died)
	zombie.transform = _spawn_points[_next_spawn_point].global_transform
	_next_spawn_point = (_next_spawn_point + 1) % _spawn_points.size()
	_zombies_to_spawn -= 1
	_zombies_alive += 1
	_spawn_cooldown = settings.spawn_interval
	add_child(zombie)


func _on_zombie_died() -> void:
	_zombies_alive -= 1
	if _zombies_alive > 0 or _zombies_to_spawn > 0:
		return
	state = State.BREAK
	_break_left = settings.break_time
	round_ended.emit(round_number)
