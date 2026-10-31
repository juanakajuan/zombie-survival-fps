class_name RoundManager
extends Node
## Runs the rounds. Round 1 starts when the level loads. Each round spawns its zombies at the SpawnPoint children that are
## active, one after the other. While RoundSettings.max_alive zombies are alive, the next spawn waits. A special round
## spawns Mutts in their place, and its last Mutt leaves `special_reward`. When the last zombie of the round dies, the
## break starts, and the next round starts after it.

signal round_started(round_number: int)
signal round_ended(round_number: int)

enum State { BREAK, ACTIVE }

@export var settings: RoundSettings
# load(), not preload(): zombie.gd reaches this script through Player and Hud, so a preload makes a load cycle that
# fails when mutt.tscn or zombie.gd loads first.
@export var zombie_scene: PackedScene = load("res://zombie/zombie.tscn") as PackedScene
@export var special_scene: PackedScene = load("res://mutt/mutt.tscn") as PackedScene
## The free item on the ground where the last Mutt of a special round dies.
@export var special_reward: BuyItem = preload("res://pickups/max_ammo.tres")
@export var pickup_scene: PackedScene = preload("res://pickups/pickup.tscn")
## The zombies chase this player.
@export var player: Player

## The current round. It is 0 until round 1 starts. During a break, it is the round that just ended.
var round_number: int = 0
var state: State = State.BREAK

var _spawn_points: Array[SpawnPoint] = []
var _next_spawn_point: int = 0
var _zombies_to_spawn: int = 0
var _zombies_alive: int = 0
var _spawn_cooldown: float = 0.0
var _break_left: float = 0.0
var _drops_this_round: int = 0


func _ready() -> void:
	for child: Node in get_children():
		if child is SpawnPoint:
			_spawn_points.append(child as SpawnPoint)
	if _spawn_points.is_empty():
		push_error("RoundManager: add SpawnPoint children.")
		return
	if not _spawn_points.any(func(point: SpawnPoint) -> bool: return point.doors.is_empty()):
		push_error("RoundManager: give one SpawnPoint no doors, so that round 1 has a place to spawn.")
		return
	_start_round(1)


## The zombies of the current round that are alive or not spawned yet.
func zombies_left() -> int:
	return _zombies_alive + _zombies_to_spawn


## Whether the current round, or the round that just ended during a break, is a special round.
func is_special_round() -> bool:
	return settings.is_special_round(round_number)


## The seconds until the next round starts. It is 0 during a round.
func break_time_left() -> float:
	return maxf(_break_left, 0.0) if state == State.BREAK else 0.0


## Ends the current round now: the zombies not spawned yet never come, and the living ones die. They give no points and
## drop nothing.
func kill_all() -> void:
	if state != State.ACTIVE:
		return
	_zombies_to_spawn = 0
	for child: Node in get_children():
		if child is Zombie:
			(child as Zombie).kill_quietly()
	_end_round_if_clear()


## Starts the next round now when a break is running. Does nothing during a round.
func skip_break() -> void:
	if state == State.BREAK and round_number >= 1:
		_start_round(round_number + 1)


func _physics_process(delta: float) -> void:
	match state:
		State.ACTIVE:
			if _zombies_to_spawn == 0:
				return
			_spawn_cooldown -= delta
			if _spawn_cooldown <= 0.0 and _zombies_alive < settings.max_alive:
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
	_zombies_to_spawn = settings.special_count(number) if settings.is_special_round(number) else settings.zombie_count(number)
	_drops_this_round = 0
	round_started.emit(number)
	_spawn_zombie()


func _spawn_zombie() -> void:
	var point := _next_active_spawn_point()
	var zombie: Zombie
	if is_special_round():
		zombie = special_scene.instantiate() as Zombie
		zombie.configure(settings.special_speed, settings.crawl_speed, settings.special_health(round_number), player,
				point.barricade)
	else:
		zombie = zombie_scene.instantiate() as Zombie
		var gait := _next_gait()
		var speed := settings.runner_speed if gait == Zombie.Gait.RUN else settings.zombie_speed(round_number)
		zombie.configure(speed, settings.crawl_speed, settings.zombie_health(round_number), player, point.barricade, gait)
	Health.find_on(zombie).died.connect(_on_zombie_died.bind(zombie))
	zombie.dropped.connect(_on_zombie_dropped)
	if _drops_this_round >= settings.max_drops:
		zombie.drops = null
	zombie.transform = point.global_transform
	_zombies_to_spawn -= 1
	_zombies_alive += 1
	_spawn_cooldown = settings.spawn_interval
	add_child(zombie)


## The gait of the zombie that spawns next. The round's runners are spread evenly over its spawn order: the zombie at
## index i runs when the count floor(i * runners / count) grows at i + 1. The first zombie runs only if all of them do.
func _next_gait() -> Zombie.Gait:
	var count := settings.zombie_count(round_number)
	var runners := settings.runner_count(round_number)
	var index := count - _zombies_to_spawn
	var runs := floori(float(index + 1) * runners / count) > floori(float(index) * runners / count)
	return Zombie.Gait.RUN if runs else Zombie.Gait.WALK


## The next active point after the one that spawned last. `_ready` makes sure that one point has no door, so the
## recursion ends.
func _next_active_spawn_point() -> SpawnPoint:
	var point := _spawn_points[_next_spawn_point]
	_next_spawn_point = (_next_spawn_point + 1) % _spawn_points.size()
	return point if point.is_active() else _next_active_spawn_point()


func _on_zombie_died(zombie: Zombie) -> void:
	_zombies_alive -= 1
	if state == State.ACTIVE and _zombies_alive == 0 and _zombies_to_spawn == 0 and is_special_round():
		var pickup := pickup_scene.instantiate() as Pickup
		pickup.item = special_reward
		pickup.position = zombie.position
		add_child.call_deferred(pickup)
	_end_round_if_clear()


func _end_round_if_clear() -> void:
	if state == State.ACTIVE and _zombies_alive == 0 and _zombies_to_spawn == 0:
		_start_break()


func _on_zombie_dropped() -> void:
	_drops_this_round += 1
	if _drops_this_round < settings.max_drops:
		return
	for child: Node in get_children():
		if child is Zombie:
			(child as Zombie).drops = null


func _start_break() -> void:
	state = State.BREAK
	_break_left = settings.break_time
	round_ended.emit(round_number)
