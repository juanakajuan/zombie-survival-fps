class_name PerkMachine
extends Machine

var perk: Perks.Kind
var price: int


func _init(machine_perk: Perks.Kind, perk_price: int) -> void:
	super()
	perk = machine_perk
	price = perk_price


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
