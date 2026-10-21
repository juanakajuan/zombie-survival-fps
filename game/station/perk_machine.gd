@tool
class_name PerkMachine
extends Machine

@export var perk: Perks.Kind = Perks.Kind.MENDER:
	set(kind):
		perk = kind
		_build()
@export_range(0, 10000, 10) var price: int = 0:
	set(cost):
		price = cost
		_build()


func caption() -> String:
	return "%s\n%d" % [Perks.display_name(perk), price]


func glow_color() -> Color:
	return Perks.color(perk)


func _offer(_loadout: Loadout, perks: Perks) -> Station.Offer:
	if perks.has(perk):
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "%s owned" % Perks.display_name(perk))
	return Station.Offer.new(Station.Offer.Kind.PERK, price, "Buy %s" % Perks.display_name(perk))


func accept(chosen: Station.Offer, _weapon: Weapon, perks: Perks) -> void:
	if chosen.kind == Station.Offer.Kind.PERK:
		perks.grant(perk)
