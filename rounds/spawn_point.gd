class_name SpawnPoint
extends Marker3D
## Where a RoundManager spawns zombies. A point that lists doors spawns only while one of them is open.

## The doors of this point's area. With none, the point is always active.
@export var doors: Array[Door]


func is_active() -> bool:
	return doors.is_empty() or doors.any(func(door: Door) -> bool: return door.is_open())
