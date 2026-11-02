extends TestCase

const REMOTE_PEER := 2


func test_only_local_player_reads_device() -> void:
	var local := await spawn_player()
	var remote := _spawn_remote(Vector3(3.0, 0.0, 0.0))
	await physics_frames(2)
	var remote_start := remote.global_position
	Input.action_press("move_forward")
	Input.action_press("aim")
	await physics_frames(20)
	assert_true(local.is_local() and not remote.is_local(), "only the first player is local")
	assert_true(local.global_position.z < -0.5, "the local player walks forward")
	assert_true(local.is_aiming(), "the local player aims")
	assert_almost_eq(remote.global_position.distance_to(remote_start), 0.0, 0.01, "the remote player stays where it is")
	assert_true(not remote.is_aiming(), "the remote player does not aim")


func test_remote_player_shows_body() -> void:
	var local := await spawn_player()
	var remote := _spawn_remote(Vector3(3.0, 0.0, 0.0))
	await physics_frames(2)
	assert_eq(_shadow_casting(local), [GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY] as Array[GeometryInstance3D.ShadowCastingSetting], "the local body draws only its shadow")
	assert_eq(_shadow_casting(remote), [GeometryInstance3D.SHADOW_CASTING_SETTING_ON] as Array[GeometryInstance3D.ShadowCastingSetting], "the remote body draws in full")
	assert_true(local.weapon.view_model.is_visible_in_tree(), "the local player sees its view model")
	assert_true(not remote.weapon.view_model.is_visible_in_tree(), "the remote player has no view model")


func test_remote_player_camera_not_current() -> void:
	var local := await spawn_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var remote := _spawn_remote(Vector3(3.0, 0.0, 0.0))
	await physics_frames(2)
	assert_true(local.camera.current, "the local camera is current")
	assert_true(not remote.camera.current, "the remote camera is not current")
	assert_true(local.hud.visible and not remote.hud.visible, "only the local HUD shows")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "the remote player does not take the mouse")


func test_remote_player_does_not_fire() -> void:
	var local := await spawn_player()
	var remote := _spawn_remote(Vector3(3.0, 0.0, 0.0))
	await physics_frames(2)
	Input.action_press("fire")
	await physics_frames(3)
	assert_eq(local.weapon.ammo, local.weapon.data.magazine_size - 1, "the local player fires")
	assert_eq(remote.weapon.ammo, remote.weapon.data.magazine_size, "the remote player does not fire")
	Input.action_release("fire")
	await press_action(&"reload")
	assert_true(local.weapon.is_reloading(), "the local player reloads")
	assert_true(not remote.weapon.is_reloading(), "the remote player does not reload")


func _spawn_remote(at: Vector3) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = at
	player.set_multiplayer_authority(REMOTE_PEER)
	add_child(player)
	return player


func _shadow_casting(player: Player) -> Array[GeometryInstance3D.ShadowCastingSetting]:
	var found: Array[GeometryInstance3D.ShadowCastingSetting] = []
	for mesh: MeshInstance3D in player.body.find_children("*", "MeshInstance3D", true, false):
		if not found.has(mesh.cast_shadow):
			found.append(mesh.cast_shadow)
	return found
