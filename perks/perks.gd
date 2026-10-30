class_name Perks
extends Node
## The perks that the player holds. It is the only owner of the list. A perk stays until the player dies.

## Emitted after a perk is added.
signal changed

@export_range(1, 8) var max_held: int = 4
@export var health: Health

var held: Array[PerkItem] = []


## Whether the player can take this perk now: it is not held, and fewer than max_held are.
func can_add(perk: PerkItem) -> bool:
	return not held.has(perk) and held.size() < max_held


func add(perk: PerkItem) -> void:
	held.append(perk)
	health.raise_max(perk.max_health_bonus)
	changed.emit()


func reload_time_scale() -> float:
	var scale := 1.0
	for perk: PerkItem in held:
		scale *= perk.reload_time_scale
	return scale


func fire_interval_scale() -> float:
	var scale := 1.0
	for perk: PerkItem in held:
		scale *= perk.fire_interval_scale
	return scale
