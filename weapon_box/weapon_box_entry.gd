class_name WeaponBoxEntry
extends Resource

@export var item: WeaponItem
## The chance of this entry is its weight over the sum of the weights of the entries that the box can give.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
