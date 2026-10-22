class_name UpgradeMachine
extends Machine
## Upgrades the weapon in the hands one time. The price is Rules.UPGRADE_PRICE, because one machine exists.

const GLOW: Color = Color(1.0, 0.8, 0.25)


func caption() -> String:
	return "Upgrade\n%d" % Rules.UPGRADE_PRICE


func glow_color() -> Color:
	return GLOW


func _offer(loadout: Loadout, _perks: Perks) -> Station.Offer:
	var def: WeaponDef = loadout.current().def
	if def.tier > 0:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "Already upgraded")
	return Station.Offer.new(Station.Offer.Kind.UPGRADE, Rules.UPGRADE_PRICE, "Upgrade %s" % def.display_name, def)


func accept(chosen: Station.Offer, weapon: Weapon, _perks: Perks) -> void:
	if chosen.kind == Station.Offer.Kind.UPGRADE:
		weapon.upgrade_current()
