class_name LevelNavigation
extends NavigationRegion3D
## Parses the parent node and bakes the navigation mesh at startup, with the settings of the region's `navigation_mesh`.
## Emits `bake_finished` when the mesh is baked.


func _ready() -> void:
	# CSG shapes build their meshes at the end of the frame, so bake one frame later.
	get_tree().process_frame.connect(_bake_after_first_map_sync, CONNECT_ONE_SHOT)


# A mesh that is set before the first sync of the map does not get to the navigation server.
func _bake_after_first_map_sync() -> void:
	if NavigationServer3D.map_get_iteration_id(get_navigation_map()) > 0:
		_bake()
	else:
		NavigationServer3D.map_changed.connect(_on_map_changed)


func _on_map_changed(map: RID) -> void:
	if map == get_navigation_map():
		NavigationServer3D.map_changed.disconnect(_on_map_changed)
		_bake()


func _bake() -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navigation_mesh, source, get_parent())
	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)
	bake_finished.emit()
