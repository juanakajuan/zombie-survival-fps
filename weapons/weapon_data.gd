class_name WeaponData
extends Resource

@export var display_name: String = "WEAPON"

@export_range(0.0, 1000.0, 1.0) var damage: float = 25.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var fire_interval: float = 0.15
@export_range(1, 200) var magazine_size: int = 12
## Rounds that the player can hold outside the magazine. The weapon starts with this many.
@export_range(0, 999) var max_reserve: int = 48
@export_range(0.0, 10.0, 0.05, "suffix:s") var reload_time: float = 1.2
@export_range(1.0, 1000.0, 1.0, "suffix:m") var max_range: float = 100.0
## Rays in each shot. Each ray is a separate hit that deals `damage`.
@export_range(1, 32) var pellets: int = 1
## The largest angle between a ray and the aim. The rays spread evenly over the cone.
@export_range(0.0, 45.0, 0.1, "suffix:°") var spread: float = 0.0
@export var automatic: bool = false

@export_group("Chain")
## After a ray damages a living target, an arc jumps to this many more, one after the other. Each jump goes to the
## nearest living target that the last one can see within `chain_range`, and that the shot did not hit yet.
@export_range(0, 16) var chain_targets: int = 0
@export_range(0.5, 30.0, 0.5, "suffix:m") var chain_range: float = 6.0
## Each jump deals the damage of the one before it times this.
@export_range(0.0, 1.0, 0.01) var chain_damage_scale: float = 0.75
## The arc aims this far above a target's origin, at the chest of a zombie.
@export_range(0.0, 3.0, 0.05, "suffix:m") var chain_aim_height: float = 1.1
@export_group("")

## The model the player sees in first person. The Weapon node adds it as a child.
@export var view_model: PackedScene
## The gun alone, for the world. A wall buy draws its silhouette.
@export var world_model: PackedScene
## The streak that shows each shot fly from the muzzle. It has no effect on the hit. With none, shots show no streak.
@export var tracer: PackedScene
## What the upgrade machine turns this weapon into, or null when it cannot be upgraded. An upgraded weapon has none.
@export var upgrade: WeaponData
## Swaps a material of the view model's gun, by the material's name in the model, for another. The gun that a reload
## throws away gets the same swap. An upgraded weapon uses it to look different.
@export var view_materials: Dictionary[String, Material] = {}
