class_name WeakSpot
extends CollisionShape3D
## A shape on a body that a shot hurts more. Add it as a child of the body, such as a head on a zombie.

@export_range(1.0, 10.0, 0.05) var damage_multiplier: float = 2.0


## Returns the WeakSpot that owns shape `shape_index` of `collider`, or null when that shape is not one.
static func find_hit(collider: Object, shape_index: int) -> WeakSpot:
	var body := collider as CollisionObject3D
	if body == null:
		return null
	var owner_id := body.shape_find_owner(shape_index)
	return body.shape_owner_get_owner(owner_id) as WeakSpot
