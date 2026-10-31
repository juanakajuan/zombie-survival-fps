class_name BuyStation
extends Interactable
## A crate that sells one BuyItem. The player looks at it and presses the interact action to buy.

signal purchased

@export var item: BuyItem
## With a switch, the station sells only while the switch is on. Without one, it always sells.
@export var power: PowerSwitch

var _price_text: String

@onready var _label: Label3D = $Label


func _ready() -> void:
	_price_text = str(item.cost)
	if power != null:
		power.turned_on.connect(_update_label)
	_update_label()


func has_power() -> bool:
	return power == null or power.is_on()


## Sells the item to the player. Returns false, and takes no points, when the station has no power, the item would do
## nothing, or the player cannot pay.
func buy(player: Player) -> bool:
	if not has_power() or not item.can_apply(player) or not player.wallet.spend(item.price(player)):
		return false
	item.apply(player)
	_price_text = "SOLD OUT" if item.sold_out(player) else str(item.price(player))
	_update_label()
	purchased.emit()
	return true


func prompt_text(player: Player) -> String:
	if not has_power():
		return "NEEDS POWER"
	if item.sold_out(player):
		return "SOLD OUT"
	var blocked := item.blocked_text(player)
	if blocked != "":
		return blocked
	return "E  BUY %s  %d" % [item.label(player), item.price(player)]


func press(player: Player) -> void:
	buy(player)


func label_text() -> String:
	return _label.text


func _update_label() -> void:
	_label.text = "%s\n%s" % [item.display_name, _price_text if has_power() else "NO POWER"]
