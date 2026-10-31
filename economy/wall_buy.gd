class_name WallBuy
extends BuyStation
## A BuyStation on a wall that sells a weapon. In place of a crate, it shows a flat silhouette of the weapon on a board.

@export var silhouette_material: Material
## The silhouette is scaled to fit in this length (x) and height (y), and centred on the Silhouette node.
@export var silhouette_size: Vector2 = Vector2(1.25, 0.45)

@onready var _silhouette: Node3D = $Silhouette


func _ready() -> void:
	super()
	var model := (item as WeaponItem).weapon.world_model.instantiate() as Node3D
	_silhouette.add_child(model)
	var bounds := AABB()
	for mesh: GeometryInstance3D in silhouette_meshes():
		mesh.material_override = silhouette_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var box := model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	# The Silhouette node lays the model's -Z (the barrel) along the board.
	var fit := minf(silhouette_size.x / bounds.size.z, silhouette_size.y / bounds.size.y)
	model.transform = Transform3D(Basis.from_scale(Vector3.ONE * fit), -bounds.get_center() * fit)


## The meshes of the silhouette.
func silhouette_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in _silhouette.find_children("*", "GeometryInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
