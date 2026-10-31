class_name Grenades
extends Node
## The wielder's grenades. This node is the only owner of the count. A throw instances a Grenade that flies from the
## head along the aim. Each new round gives more grenades, up to a maximum.

## Emitted after the count changes.
signal changed(count: int)
signal thrown(grenade: Grenade)
## Relays Grenade.damaged for every grenade that this node throws. It has the shape of Weapon.damaged.
signal damaged(target: Node, killed: bool, headshot: bool)

@export_range(0, 20) var starting_count: int = 2
## The grenades that each new round adds.
@export_range(0, 20) var per_round: int = 2
## The most grenades the player holds. A round never takes the count above it.
@export_range(1, 20) var max_count: int = 4
@export var grenade_scene: PackedScene
@export_group("Throw")
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var throw_speed: float = 14.0
## Speed added upward to the throw, so that it arcs. The wielder's own velocity is added too.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var throw_up_speed: float = 3.0
## How far in front of the head the grenade starts.
@export_range(0.1, 2.0, 0.05, "suffix:m") var throw_offset: float = 0.5
@export_range(0.0, 5.0, 0.05, "suffix:s") var cooldown: float = 0.5

## The player who throws. Player sets it.
var wielder: Player
var count: int

var _cooldown_left: float = 0.0


func _ready() -> void:
	count = starting_count
	changed.emit(count)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


## Throws one grenade along the aim. Returns false with no grenades, during the cooldown, and when the wielder is
## missing, downed, or dead.
func try_throw() -> bool:
	if count <= 0 or _cooldown_left > 0.0 or wielder == null or wielder.is_dead() or wielder.is_downed():
		return false
	var aim := wielder.aim_transform()
	var grenade := grenade_scene.instantiate() as Grenade
	arm(grenade)
	wielder.get_parent().add_child(grenade)
	grenade.global_position = aim.origin - aim.basis.z * throw_offset
	grenade.linear_velocity = -aim.basis.z * throw_speed + Vector3.UP * throw_up_speed + wielder.velocity
	count -= 1
	_cooldown_left = cooldown
	changed.emit(count)
	thrown.emit(grenade)
	return true


## Makes the grenade this wielder's: it does not collide with the wielder, and its damage reports reach `damaged`.
## Call it before the grenade enters the tree. try_throw does it for the grenades that it throws.
func arm(grenade: Grenade) -> void:
	grenade.thrower = wielder
	grenade.damaged.connect(damaged.emit)


## Adds `per_round` grenades, up to `max_count`. The level calls it when a round starts.
func start_round() -> void:
	if count >= max_count:
		return
	count = mini(count + per_round, max_count)
	changed.emit(count)
