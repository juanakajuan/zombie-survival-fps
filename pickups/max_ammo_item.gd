class_name MaxAmmoItem
extends BuyItem
## Fills the reserve of every weapon the player holds.


func can_apply(player: Player) -> bool:
	return player.weapons.any(func(held: Weapon) -> bool: return held.reserve < held.data.max_reserve)


func apply(player: Player) -> void:
	for held: Weapon in player.weapons:
		held.refill_reserve()
