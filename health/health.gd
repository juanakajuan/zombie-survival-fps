class_name Health
extends Node
## Hit points for any node. Add it as a direct child of the thing that can be hurt.

signal damaged(amount: float)
signal died
## Emitted after `current` changes, from damage, raise_max(), or reset().
signal changed(current: float)

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0

var current: float
## Debug only. While true, damage() does nothing.
var invulnerable: bool = false


func _ready() -> void:
	current = max_health


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
	damaged.emit(amount)
	changed.emit(current)
	if is_dead():
		died.emit()


func is_dead() -> bool:
	return current <= 0.0


## Raises max_health and current by `amount`.
func raise_max(amount: float) -> void:
	if amount == 0.0:
		return
	max_health += amount
	current += amount
	changed.emit(current)


func reset() -> void:
	current = max_health
	changed.emit(current)
