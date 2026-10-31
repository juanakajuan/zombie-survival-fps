class_name Health
extends Node
## Hit points for any node. Add it as a direct child of the thing that can be hurt.

signal damaged(amount: float)
signal died
## Emitted after `current` changes, from damage, heal(), raise_max(), lower_max(), or reset().
signal changed(current: float)
## Emitted by damage_at() after the damage, with the world point that the hit came at.
signal struck_at(amount: float, point: Vector3)

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_group("Regeneration")
## The hit points that come back each second. 0 turns regeneration off.
@export_range(0.0, 1000.0, 1.0, "suffix:hp/s") var regen_rate: float = 0.0
## The seconds with no damage before health starts to come back.
@export_range(0.0, 30.0, 0.1, "suffix:s") var regen_delay: float = 0.0

var current: float
## Debug only. While true, damage() does nothing.
var invulnerable: bool = false

var _since_damage := 0.0


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	if regen_rate <= 0.0 or is_dead() or current >= max_health:
		return
	_since_damage += delta
	if _since_damage >= regen_delay:
		heal(regen_rate * delta)


## Returns the first direct child of `node` that is a Health, or null.
static func find_on(node: Node) -> Health:
	for child: Node in node.get_children():
		if child is Health:
			return child as Health
	return null


func damage(amount: float) -> void:
	if invulnerable or is_dead() or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	_since_damage = 0.0
	damaged.emit(amount)
	changed.emit(current)
	if is_dead():
		died.emit()


## damage() for a hit that comes at `point` in world space, such as a shot or the centre of a blast.
func damage_at(amount: float, point: Vector3) -> void:
	if invulnerable or is_dead() or amount <= 0.0:
		return
	damage(amount)
	struck_at.emit(amount, point)


func is_dead() -> bool:
	return current <= 0.0


## Raises max_health and current by `amount`.
func raise_max(amount: float) -> void:
	if amount == 0.0:
		return
	max_health += amount
	current += amount
	changed.emit(current)


## Lowers max_health by `amount`, and `current` to the new max_health if it is above it.
func lower_max(amount: float) -> void:
	if amount == 0.0:
		return
	max_health -= amount
	current = minf(current, max_health)
	changed.emit(current)


## Raises `current` by `amount`, up to max_health. Does nothing for an amount of 0 or less.
func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	changed.emit(current)


func reset() -> void:
	current = max_health
	changed.emit(current)
