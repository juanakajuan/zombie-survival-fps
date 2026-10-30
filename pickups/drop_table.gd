class_name DropTable
extends Resource
## What a dying zombie may leave on the ground.

## The chance that a death drops a pickup.
@export_range(0.0, 1.0, 0.01) var chance: float = 0.0
@export var items: Array[BuyItem]
## The seconds that a dropped pickup stays on the ground.
@export_range(1.0, 120.0, 1.0, "suffix:s") var lifetime: float = 20.0


## The item to drop: null, or one of `items` at random.
func roll() -> BuyItem:
	if items.is_empty() or randf() >= chance:
		return null
	return items.pick_random()
