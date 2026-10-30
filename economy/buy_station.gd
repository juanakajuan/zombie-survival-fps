class_name BuyStation
extends Interactable
## A crate that sells one BuyItem. The player looks at it and presses the interact action to buy.

signal purchased

@export var item: BuyItem

@onready var _label: Label3D = $Label


func _ready() -> void:
	_label.text = "%s\n%d" % [item.display_name, item.cost]


## Sells the item to the player. Returns false, and takes no points, when the item would do nothing or the
## player cannot pay.
func buy(player: Player) -> bool:
	if not item.can_apply(player) or not player.wallet.spend(item.price(player)):
		return false
	item.apply(player)
	purchased.emit()
	return true


func prompt_text(player: Player) -> String:
	return "E  BUY %s  %d" % [item.label(player), item.price(player)]


func press(player: Player) -> void:
	buy(player)
