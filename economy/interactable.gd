class_name Interactable
extends StaticBody3D
## A body that the player looks at and uses with the interact action. A subclass says what the prompt shows and what
## a press or a hold does.


## The text of the HUD prompt while the player looks at this body. An empty string shows no prompt.
func prompt_text(_player: Player) -> String:
	return ""


## Called once when the interact action is just pressed.
func press(_player: Player) -> void:
	pass


## Called each physics frame while the interact action is held, including the frame of the press.
func hold(_player: Player, _delta: float) -> void:
	pass
