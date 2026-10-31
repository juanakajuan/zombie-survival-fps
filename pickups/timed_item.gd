class_name TimedItem
extends BuyItem
## A pickup effect that runs for a time. `Powerups` on the player owns the running effects and asks each one what it does.

@export_range(1.0, 120.0, 1.0, "suffix:s") var duration: float = 30.0


## What earned points are multiplied by while the effect runs.
func points_multiplier() -> int:
	return 1


## Whether each hit on a zombie kills it while the effect runs.
func kills_on_hit() -> bool:
	return false


func can_apply(player: Player) -> bool:
	return not player.is_dead()


func apply(player: Player) -> void:
	player.powerups.start(self)
