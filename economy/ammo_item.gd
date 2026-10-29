class_name AmmoItem
extends BuyItem
## Fills the reserve of the player's weapon.


func can_apply(player: Player) -> bool:
	return player.weapon.reserve < player.weapon.data.max_reserve


func apply(player: Player) -> void:
	player.weapon.refill_reserve()
