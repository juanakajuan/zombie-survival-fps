class_name UpgradeItem
extends BuyItem
## Upgrades the weapon in the player's hand to its WeaponData.upgrade. Each weapon has one upgrade, so an upgraded
## weapon cannot be upgraded again.


func label(player: Player) -> String:
	return "%s %s" % [display_name, player.weapon.data.display_name]


func blocked_text(player: Player) -> String:
	return "" if can_apply(player) else "%s CANNOT BE UPGRADED" % player.weapon.data.display_name


func can_apply(player: Player) -> bool:
	return player.weapon.data.upgrade != null


func apply(player: Player) -> void:
	player.upgrade_weapon()
