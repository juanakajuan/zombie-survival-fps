class_name HealthItem
extends BuyItem
## Fills the player's health.


func can_apply(player: Player) -> bool:
	return not player.is_dead() and not player.is_downed() and player.health.current < player.health.max_health


func apply(player: Player) -> void:
	player.health.reset()
