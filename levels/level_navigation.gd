extends NavigationRegion3D
## Bakes the navigation mesh at startup from the nodes in the source group.


func _ready() -> void:
	# CSG shapes build their meshes at the end of the frame, so bake one frame later.
	get_tree().process_frame.connect(_bake, CONNECT_ONE_SHOT)


func _bake() -> void:
	bake_navigation_mesh(false)
