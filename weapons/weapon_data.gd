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
## Rays in each shot. Each ray is a separate hit that deals `damage`.
@export_range(1, 32) var pellets: int = 1
## The largest angle between a ray and the aim. The rays spread evenly over the cone.
@export_range(0.0, 45.0, 0.1, "suffix:°") var spread: float = 0.0
@export var automatic: bool = false
## The model the player sees in first person. The Weapon node adds it as a child.
@export var view_model: PackedScene
## The gun alone, for the world. A wall buy draws its silhouette.
@export var world_model: PackedScene
## The streak that shows each shot fly from the muzzle. It has no effect on the hit. With none, shots show no streak.
@export var tracer: PackedScene
