class_name BuyItem
extends Resource
## What a BuyStation sells. A subclass says when the item can be bought and what it gives the player.

@export var display_name: String = "ITEM"
@export_range(0, 100000) var cost: int = 0


## What the station charges this player now. A subclass can change it with what the player holds.
func price(_player: Player) -> int:
	return cost


## What the station shows for this player now.
func label(_player: Player) -> String:
	return display_name


## Whether the player can never buy the item again in this run. The station then shows SOLD OUT.
func sold_out(_player: Player) -> bool:
	return false


## The prompt that says why the player cannot buy the item now, or "" for the usual buy prompt.
func blocked_text(_player: Player) -> String:
	return ""


## Whether buying now would do anything. A station never charges for an item that returns false.
func can_apply(_player: Player) -> bool:
	return false


## Gives the item to the player. The station has already taken the cost.
func apply(_player: Player) -> void:
	pass
