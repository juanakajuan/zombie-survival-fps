class_name DoorItem
extends BuyItem
## What a door sells. The Door reacts to the station's `purchased` signal, so buying gives the player nothing.


func can_apply(_player: Player) -> bool:
	return true
