class_name Grenades
extends Node
## The wielder's grenades. This node is the only owner of the count. Starting a cook pulls the pin: the count drops
## and the fuse burns. Releasing plays a short swing, and the grenade leaves the hand at its end along the aim with the
## fuse that is left. A grenade held past its fuse explodes in the hand. Each new round gives more grenades, up to a
## maximum.

## Emitted after the count changes.
signal changed(count: int)
## Emitted when a grenade leaves the hand: thrown, or dropped by a player who goes down. Not for one that explodes in the hand.
signal thrown(grenade: Grenade)
## Relays Grenade.damaged for every grenade that this node throws. It has the shape of Weapon.damaged.
signal damaged(target: Node, killed: bool, headshot: bool)

@export_range(0, 20) var starting_count: int = 2
## The grenades that each new round adds.
@export_range(0, 20) var per_round: int = 2
## The most grenades the player holds. A round never takes the count above it.
@export_range(1, 20) var max_count: int = 4
@export var grenade_scene: PackedScene

enum State { READY, COOKING, THROWING }

@export_group("Throw")
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var throw_speed: float = 14.0
## Speed added upward to the throw, so that it arcs. The wielder's own velocity is added too.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var throw_up_speed: float = 3.0
## How far in front of the head the grenade starts.
@export_range(0.1, 2.0, 0.05, "suffix:m") var throw_offset: float = 0.5
## Where the hand holds the grenade, in the view space of the aim (-Z is forward). A grenade that explodes in the hand explodes here.
@export var hand_offset: Vector3 = Vector3(-0.2, -0.2, -0.4)
## How high above the feet a dropped grenade starts.
@export_range(0.0, 1.0, 0.05, "suffix:m") var drop_height: float = 0.2

@export_group("Timing")
## The hand lifts the grenade over this time after the pin is pulled, and then holds it.
@export_range(0.05, 2.0, 0.01, "suffix:s") var cook_raise_time: float = 0.25
## From the release to the moment the grenade leaves the hand. The fuse burns during it.
@export_range(0.01, 1.0, 0.01, "suffix:s") var throw_wind_time: float = 0.12
## From the moment the grenade leaves the hand until the next grenade can be started.
@export_range(0.01, 2.0, 0.01, "suffix:s") var throw_recover_time: float = 0.3

## The player who throws. Player sets it.
var wielder: Player
var count: int

var _state: State = State.READY
## The grenade in the hand. It is not in the tree until it leaves the hand.
var _held: Grenade
var _cook_elapsed: float = 0.0
var _swing_elapsed: float = 0.0
var _raise_at_release: float = 0.0


func _ready() -> void:
	count = starting_count
	changed.emit(count)


func _exit_tree() -> void:
	if _held != null:
		_held.free()
		_held = null


func _physics_process(delta: float) -> void:
	if _state == State.READY:
		return
	if _state == State.COOKING:
		_cook_elapsed += delta
	else:
		_swing_elapsed += delta
	if _held != null:
		_held.fuse_left -= delta
		if _held.fuse_left <= 0.0:
			_burst()
			return
	if _state == State.THROWING:
		if _held != null and _swing_elapsed >= throw_wind_time:
			_throw()
		if _swing_elapsed >= throw_wind_time + throw_recover_time:
			_state = State.READY


## Pulls the pin: takes one grenade and starts its fuse. Returns false with no grenades, during a cook or a throw,
## and when the wielder is missing, downed, or dead.
func start_cook() -> bool:
	if _state != State.READY or count <= 0 or wielder == null or wielder.is_dead() or wielder.is_downed():
		return false
	_held = grenade_scene.instantiate() as Grenade
	arm(_held)
	_held.fuse_left = _held.fuse_time
	_state = State.COOKING
	_cook_elapsed = 0.0
	count -= 1
	changed.emit(count)
	return true


## Starts the throw of the grenade that is cooking. It does nothing at any other time.
func release() -> void:
	if _state != State.COOKING:
		return
	_raise_at_release = minf(_cook_elapsed / cook_raise_time, 1.0)
	_swing_elapsed = 0.0
	_state = State.THROWING


## Lets the grenade in the hand fall at the wielder's feet with the fuse that it has left, and clears the cook or the
## throw. Player calls it when it goes down or dies.
func drop() -> void:
	if _held != null:
		_leave_hand(wielder.global_position + Vector3.UP * drop_height, wielder.velocity)
	_state = State.READY


## True from the pin pull until the throw has ended.
func is_busy() -> bool:
	return _state != State.READY


## True while the pin is out and the player holds the grenade back.
func is_cooking() -> bool:
	return _state == State.COOKING


## True while a grenade is in the hand: from the pin pull until it leaves the hand or explodes.
func has_grenade_in_hand() -> bool:
	return _held != null


## The seconds before the grenade in the hand explodes, or 0 with none in the hand.
func fuse_left() -> float:
	return maxf(_held.fuse_left, 0.0) if _held != null else 0.0


## Where the hand is in the cook and the swing, for a pose. -1 while ready. From 0 to 1 the hand rises, and it stays at
## 1 while the grenade cooks. A release moves it on from where it was to 2 at the moment the grenade leaves the
## hand, and to 3 at the end of the recovery.
func progress() -> float:
	return _progress_at(_cook_elapsed, _swing_elapsed)


## progress() between physics ticks, for a pose drawn every frame. Call it from _process.
func visual_progress() -> float:
	var step := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
	if _state == State.COOKING:
		return _progress_at(_cook_elapsed + step, 0.0)
	return _progress_at(0.0, minf(_swing_elapsed + step, throw_wind_time + throw_recover_time))


## Makes the grenade this wielder's: it does not collide with the wielder, and its damage reports reach `damaged`.
## Call it before the grenade enters the tree. start_cook does it for the grenades that it holds.
func arm(grenade: Grenade) -> void:
	grenade.thrower = wielder
	grenade.damaged.connect(damaged.emit)


## Adds `per_round` grenades, up to `max_count`. The level calls it when a round starts.
func start_round() -> void:
	if count >= max_count:
		return
	count = mini(count + per_round, max_count)
	changed.emit(count)


func _progress_at(cook_elapsed: float, swing_elapsed: float) -> float:
	match _state:
		State.COOKING:
			return minf(cook_elapsed / cook_raise_time, 1.0)
		State.THROWING:
			if swing_elapsed < throw_wind_time:
				return lerpf(_raise_at_release, 2.0, swing_elapsed / throw_wind_time)
			return 2.0 + (swing_elapsed - throw_wind_time) / throw_recover_time
	return -1.0


func _throw() -> void:
	var aim := wielder.aim_transform()
	_leave_hand(aim.origin - aim.basis.z * throw_offset, -aim.basis.z * throw_speed + Vector3.UP * throw_up_speed + wielder.velocity)


## The fuse ran out in the hand.
func _burst() -> void:
	var aim := wielder.aim_transform()
	var grenade := _held
	grenade.freeze = true
	_held = null
	_state = State.READY
	wielder.get_parent().add_child(grenade)
	grenade.global_position = aim.origin + aim.basis * hand_offset


func _leave_hand(at: Vector3, velocity: Vector3) -> void:
	var grenade := _held
	_held = null
	wielder.get_parent().add_child(grenade)
	grenade.global_position = at
	grenade.linear_velocity = velocity
	thrown.emit(grenade)
