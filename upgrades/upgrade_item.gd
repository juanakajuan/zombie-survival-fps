class_name UpgradeItem
extends BuyItem
## Sells the upgrades of the weapon in the player's hand. The first swaps it for its WeaponData.upgrade, at `cost`. An
## upgraded weapon has no upgrade, so a weapon with no upgrade and no effect is ready for the second, at `effect_cost`:
## the player selects one of `effects`, and the weapon keeps it. A weapon with an effect has no upgrade left.

@export_range(0, 100000) var effect_cost: int = 0
@export var effects: Array[WeaponEffect] = []


func price(player: Player) -> int:
	return cost if _has_first_upgrade(player) else effect_cost


func label(player: Player) -> String:
	return "%s %s" % [display_name, player.weapon.data.display_name]


func blocked_text(player: Player) -> String:
	return "" if can_apply(player) else "%s CANNOT BE UPGRADED" % player.weapon.data.display_name


func can_apply(player: Player) -> bool:
	return _has_first_upgrade(player) or (player.weapon.effect == null and not effects.is_empty())


func apply(player: Player) -> void:
	if _has_first_upgrade(player):
		player.upgrade_weapon()
	else:
		player.choose_effect(effects)


func _has_first_upgrade(player: Player) -> bool:
	return player.weapon.data.upgrade != null
