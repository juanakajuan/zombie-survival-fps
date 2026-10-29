class_name BuyItem
extends Resource
## What a BuyStation sells. A subclass says when the item can be bought and what it gives the player.

@export var display_name: String = "ITEM"
@export_range(0, 100000) var cost: int = 0


## Whether buying now would do anything. A station never charges for an item that returns false.
func can_apply(_player: Player) -> bool:
	return false


## Gives the item to the player. The station has already taken the cost.
func apply(_player: Player) -> void:
	pass
