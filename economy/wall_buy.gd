class_name WallBuy
extends BuyStation
## A BuyStation on a wall that sells a weapon. In place of a crate, it shows a flat silhouette of the weapon on a board.

@export var silhouette_material: Material

@onready var _silhouette: Node3D = $Silhouette


func _ready() -> void:
	super()
	var model := (item as WeaponItem).weapon.world_model.instantiate()
	_silhouette.add_child(model)
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		mesh.material_override = silhouette_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The meshes of the silhouette.
func silhouette_meshes() -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	for node: Node in _silhouette.find_children("*", "GeometryInstance3D", true, false):
		meshes.append(node as GeometryInstance3D)
	return meshes
