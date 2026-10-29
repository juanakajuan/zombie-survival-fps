class_name LevelNavigation
extends NavigationRegion3D
## Parses the parent node and bakes the navigation mesh at startup, with the settings of the region's `navigation_mesh`.
## Emits `bake_finished` when the mesh is baked.


# A mesh that is set before the map's first sync with this region does not get to the navigation server, even when
# an earlier level already synced the map. So wait for that sync, from before it can happen.
func _ready() -> void:
	NavigationServer3D.map_changed.connect(_on_map_changed)


func _on_map_changed(map: RID) -> void:
	if map == get_navigation_map():
		NavigationServer3D.map_changed.disconnect(_on_map_changed)
		# CSG shapes build their meshes at the end of the frame.
		get_tree().process_frame.connect(_bake, CONNECT_ONE_SHOT)


func _bake() -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navigation_mesh, source, get_parent())
	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)
	bake_finished.emit()
