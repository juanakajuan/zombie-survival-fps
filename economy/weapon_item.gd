class_name WeaponItem
extends BuyItem
## Sells a weapon. Once the player holds it, the item sells that weapon's ammo instead.

@export var weapon: WeaponData
@export_range(0, 100000) var ammo_cost: int = 0


func price(player: Player) -> int:
	return cost if player.weapon_holding(weapon) == null else ammo_cost


func label(player: Player) -> String:
	return display_name if player.weapon_holding(weapon) == null else "%s AMMO" % weapon.display_name


func can_apply(player: Player) -> bool:
	var held := player.weapon_holding(weapon)
	return held == null or held.reserve < weapon.max_reserve


func apply(player: Player) -> void:
	var held := player.weapon_holding(weapon)
	if held == null:
		player.give_weapon(weapon)
	else:
		held.refill_reserve()
