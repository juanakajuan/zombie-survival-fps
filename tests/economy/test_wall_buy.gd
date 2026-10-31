extends TestCase

const WALL_BUY_SCENE: PackedScene = preload("res://economy/wall_buy.tscn")


func test_the_player_looks_at_the_wall_buy_and_buys_the_shotgun() -> void:
	var player := await spawn_player()
	var wall_buy := WALL_BUY_SCENE.instantiate() as WallBuy
	wall_buy.position = Vector3(0.0, 0.0, -1.5)
	add_child(wall_buy)
	var item := wall_buy.item as WeaponItem
	player.wallet.add(item.cost)
	look_at_point(player, Vector3(0.0, 1.4, -1.45))
	await physics_frames(2)
	assert_eq(player.hud.readout().prompt_text, "E  BUY SHOTGUN  %d" % item.cost, "prompt")
	Input.action_press("interact")
	await physics_frames(2)
	assert_eq(player.weapon.data.display_name, "SHOTGUN", "the shotgun is in hand")
	assert_eq(player.wallet.points, 0, "the cost was spent")


func test_the_wall_buy_shows_a_flat_silhouette_of_its_weapon() -> void:
	var wall_buy := WALL_BUY_SCENE.instantiate() as WallBuy
	add_child(wall_buy)
	var meshes := wall_buy.silhouette_meshes()
	assert_true(not meshes.is_empty(), "the silhouette has meshes")
	var bounds := AABB()
	for mesh: GeometryInstance3D in meshes:
		assert_true(mesh.material_override == wall_buy.silhouette_material, "%s is drawn in the silhouette material" % mesh.name)
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	assert_true(bounds.size.x > 0.8, "the silhouette is wide, got %s" % bounds.size)
	assert_true(bounds.size.z < 0.02, "the silhouette is flat on the wall, got %s" % bounds.size)
