class_name FireEffect
extends WeaponEffect
## A hit sets the target on fire. The fire damages it every `tick_interval` seconds for `burn_time` seconds. A new hit
## restarts the burn of that target and does not add a second one.

@export_range(0.5, 30.0, 0.1, "suffix:s") var burn_time: float = 4.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var tick_interval: float = 1.0
@export_range(1.0, 1000.0, 1.0) var tick_damage: float = 15.0
## The flames. It is a child of the burning target.
@export var burn_scene: PackedScene


func on_hit(weapon: Weapon, target: Node) -> void:
	var burn := Burn.find_on(target)
	if burn == null:
		burn = burn_scene.instantiate() as Burn
		target.add_child(burn)
	burn.ignite(self, weapon)
