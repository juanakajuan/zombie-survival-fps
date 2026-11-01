class_name WeaponEffect
extends Resource
## A bonus that a weapon gets from its second upgrade. The weapon calls on_hit() for each ray that damages a living target.

## The name that the effect menu and the HUD show.
@export var display_name: String = "EFFECT"
## The color of the name on the HUD and the menu.
@export var color: Color = Color.WHITE


## Called after a ray of `weapon` damaged `target` and the target lived through it.
func on_hit(_weapon: Weapon, _target: Node) -> void:
	pass
