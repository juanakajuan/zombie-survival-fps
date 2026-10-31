class_name DoublePointsItem
extends TimedItem
## Multiplies the points that the player earns, for a time.

@export_range(2, 10) var multiplier: int = 2


func points_multiplier() -> int:
	return multiplier
