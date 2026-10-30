class_name LevelNavigation
extends NavigationRegion3D
## Parses the parent node and bakes the navigation mesh at startup, with the settings of the region's `navigation_mesh`.
## Emits `bake_finished` when the mesh is baked.


func _ready() -> void:
	# With async iterations, the server loses a mesh that changes while the region builds its previous mesh on a worker
	# thread: the map clears the region's sync request, and nothing requests a sync when the build is done.
	NavigationServer3D.region_set_use_async_iterations(get_rid(), false)
	# CSG shapes build their meshes at the end of the frame.
	get_tree().process_frame.connect(bake, CONNECT_ONE_SHOT)


## Parses the geometry again and bakes. Call it after a collider appears or goes away.
func bake() -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navigation_mesh, source, get_parent())
	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)
	bake_finished.emit()
