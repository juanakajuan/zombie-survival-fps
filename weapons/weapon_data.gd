class_name WeaponData
extends Resource

## The name that the HUD shows.
@export var display_name: String = "WEAPON"

@export_range(0.0, 1000.0, 1.0) var damage: float = 25.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var fire_interval: float = 0.15
@export_range(1, 200) var magazine_size: int = 12
## Rounds that the player can hold outside the magazine. The weapon starts with this many.
@export_range(0, 999) var max_reserve: int = 48
@export_range(0.0, 10.0, 0.05, "suffix:s") var reload_time: float = 1.2
@export_range(1.0, 1000.0, 1.0, "suffix:m") var max_range: float = 100.0
@export var automatic: bool = false
## The model the player sees in first person. The Weapon node adds it as a child.
@export var view_model: PackedScene
## The streak that shows each shot fly from the muzzle. It has no effect on the hit. With none, shots show no streak.
@export var tracer: PackedScene
## What the upgrade machine turns this weapon into, or null when it cannot be upgraded. An upgraded weapon has none.
@export var upgrade: WeaponData
## Swaps a material of the view model's gun, by the material's name in the model, for another. The gun that a reload
## throws away gets the same swap. An upgraded weapon uses it to look different.
@export var view_materials: Dictionary[String, Material] = {}
