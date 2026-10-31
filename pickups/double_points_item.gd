class_name DoublePointsItem
extends BuyItem
## Multiplies the points that the player earns, for a time.

@export_range(2, 10) var multiplier: int = 2
@export_range(1.0, 120.0, 1.0, "suffix:s") var duration: float = 30.0


func can_apply(player: Player) -> bool:
	return not player.is_dead()


func apply(player: Player) -> void:
	player.wallet.boost(multiplier, duration)
