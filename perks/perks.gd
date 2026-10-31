class_name Perks
extends Node
## The perks that the player holds. It is the only owner of the list. A perk stays until the player gets to 0 health.

## Emitted after a perk is added or the perks are lost.
signal changed

@export_range(1, 8) var max_held: int = 4
@export var health: Health

var held: Array[PerkItem] = []

var _times_taken: Dictionary[PerkItem, int] = {}


## Whether the player can take this perk now: it is not held, fewer than max_held are, and it is not sold out.
func can_add(perk: PerkItem) -> bool:
	return not held.has(perk) and held.size() < max_held and not sold_out(perk)


func add(perk: PerkItem) -> void:
	held.append(perk)
	_times_taken[perk] = times_taken(perk) + 1
	health.raise_max(perk.max_health_bonus)
	changed.emit()


## How many times the player took this perk in the run. The scene reload on restart starts the count again.
func times_taken(perk: PerkItem) -> int:
	var count: int = _times_taken.get(perk, 0)
	return count


## Whether the player took this perk max_buys times in the run.
func sold_out(perk: PerkItem) -> bool:
	return perk.max_buys > 0 and times_taken(perk) >= perk.max_buys


## Removes every held perk and its max health bonus.
func lose_all() -> void:
	for perk: PerkItem in held:
		health.lower_max(perk.max_health_bonus)
	held.clear()
	changed.emit()


## The held perk that downs the player at 0 health instead of killing them, or null.
func self_revive() -> PerkItem:
	for perk: PerkItem in held:
		if perk.self_revive_time > 0.0:
			return perk
	return null


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
