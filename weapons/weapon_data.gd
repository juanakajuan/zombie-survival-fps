class_name WeaponData
extends Resource

@export_range(0.0, 1000.0, 1.0) var damage: float = 25.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var fire_interval: float = 0.15
@export_range(1, 200) var magazine_size: int = 12
@export_range(0.0, 10.0, 0.05, "suffix:s") var reload_time: float = 1.2
@export_range(1.0, 1000.0, 1.0, "suffix:m") var max_range: float = 100.0
@export var automatic: bool = false
## The model the player sees in first person. The Weapon node adds it as a child.
@export var view_model: PackedScene
