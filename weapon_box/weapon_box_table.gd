class_name WeaponBoxTable
extends Resource
## The weapons that the weapon box gives, with a weight for each.

@export var entries: Array[WeaponBoxEntry]


## The entries that the box can give this player: the weapons that the player does not hold.
func available(player: Player) -> Array[WeaponBoxEntry]:
	return entries.filter(func(entry: WeaponBoxEntry) -> bool: return entry.weight > 0.0 and player.weapon_holding(entry.item.weapon) == null)


## A weighted random item from the available entries, or null when there is none.
func roll(player: Player) -> WeaponItem:
	var candidates := available(player)
	var total := 0.0
	for entry: WeaponBoxEntry in candidates:
		total += entry.weight
	var pick := randf() * total
	for entry: WeaponBoxEntry in candidates:
		pick -= entry.weight
		if pick < 0.0:
			return entry.item
	return null if candidates.is_empty() else candidates.back().item
