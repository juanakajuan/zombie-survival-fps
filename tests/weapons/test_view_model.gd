extends TestCase

const SETTLE_FRAMES := 60
const SMG: WeaponData = preload("res://weapons/smg.tres")


func test_gun_rises_into_view_after_spawn() -> void:
	var player := await spawn_player()
	var start := _pose_in_camera(player).origin
	await physics_frames(SETTLE_FRAMES)
	assert_true(_pose_in_camera(player).origin.y > start.y + 0.05, "the gun moves up into view")


func test_shot_kicks_the_gun_back_and_it_returns() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var rest := _pose_in_camera(player)
	Input.action_press("fire")
	await physics_frames(2)
	var kicked := _pose_in_camera(player)
	assert_true(kicked.origin.z > rest.origin.z + 0.01, "the gun moves back toward the camera")
	assert_true(_muzzle_pitch(kicked) > _muzzle_pitch(rest) + 0.05, "the muzzle points up")
	Input.action_release("fire")
	await physics_frames(SETTLE_FRAMES)
	assert_true(_pose_in_camera(player).origin.distance_to(rest.origin) < 0.005, "the gun is back at rest")


func test_reload_throws_the_gun_behind_the_player_and_draws_a_new_one() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	var model := weapon.view_model.model
	var rest := _pose_in_camera(player)
	weapon.try_fire()
	await physics_frames(SETTLE_FRAMES)
	weapon.start_reload()
	var hands_were_empty := false
	var frames := ceili(weapon.data.reload_time * Engine.physics_ticks_per_second) + 10
	for i in frames:
		await physics_frames(1)
		if not model.is_visible_in_tree():
			hands_were_empty = true
	assert_true(hands_were_empty, "the gun leaves the hand during the reload")
	var thrown := get_tree().get_nodes_in_group("thrown_gun")
	assert_eq(thrown.size(), 1, "one gun was thrown")
	var gun := thrown[0] as Node3D
	assert_true(gun.global_position.z > player.global_position.z + 0.5, "the thrown gun is behind the player")
	assert_true(not weapon.is_reloading(), "the reload is over")
	assert_true(model.is_visible_in_tree(), "a new gun is in the hand")
	assert_true(_pose_in_camera(player).origin.distance_to(rest.origin) < 0.005, "the new gun is at rest")


func test_a_reload_cut_short_by_a_switch_leaves_the_gun_ready_when_drawn_again() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var pistol := player.weapon
	var model := pistol.view_model.model
	var rest := _pose_in_camera(player)
	pistol.try_fire()
	await physics_frames(SETTLE_FRAMES)
	pistol.start_reload()
	var frames := 0
	while model.is_visible_in_tree() and frames < 300:
		await physics_frames(1)
		frames += 1
	assert_true(not model.is_visible_in_tree(), "the reload threw the gun")
	player.give_weapon(SMG)
	press_action(&"weapon_1")
	await physics_frames(SETTLE_FRAMES)
	assert_true(model.is_visible_in_tree(), "the pistol is back in the hand")
	assert_true(_pose_in_camera(player).origin.distance_to(rest.origin) < 0.005, "the pistol is at rest")


func test_reload_phases_longer_than_the_reload_still_end_in_time() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	var view := weapon.view_model
	var rest := _pose_in_camera(player)
	for phase: StringName in [&"wind_up_fraction", &"toss_fraction", &"empty_hands_fraction", &"draw_fraction",
			&"slide_pull_fraction", &"slide_release_fraction"]:
		view.set(phase, 0.4)
	weapon.try_fire()
	await physics_frames(SETTLE_FRAMES)
	weapon.start_reload()
	await physics_frames(floori(weapon.data.reload_time * Engine.physics_ticks_per_second) - 2)
	assert_true(weapon.is_reloading(), "the reload is not over yet")
	assert_true(view.model.is_visible_in_tree(), "a new gun is in the hand")
	assert_true(_pose_in_camera(player).origin.distance_to(rest.origin) < 0.005, "the new gun is at rest before the reload ends")


func test_the_pistol_reload_motion_lasts_until_the_reload_ends() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	await _assert_reload_motion_lasts_until_the_reload_ends(player.weapon)


func test_the_smg_reload_motion_lasts_until_the_reload_ends() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var smg := player.give_weapon(preload("res://weapons/smg.tres"))
	await physics_frames(SETTLE_FRAMES)
	await _assert_reload_motion_lasts_until_the_reload_ends(smg)


func test_sprinting_points_the_gun_away_from_the_crosshair() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var rest := _pose_in_camera(player)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await physics_frames(SETTLE_FRAMES)
	assert_true(player.is_sprinting(), "the player sprints")
	var forward := -_pose_in_camera(player).basis.z
	assert_true(forward.angle_to(-rest.basis.z) > deg_to_rad(15.0), "the gun turns away from the crosshair")


func test_walking_bobs_the_gun() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("move_forward")
	var lowest := INF
	var highest := -INF
	for i in SETTLE_FRAMES:
		await physics_frames(1)
		var y := _pose_in_camera(player).origin.y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	assert_true(highest - lowest > 0.005, "the gun moves up and down while walking")


func test_gun_goes_down_when_the_player_dies() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var rest := _pose_in_camera(player)
	Health.find_on(player).damage(10000.0)
	await physics_frames(SETTLE_FRAMES)
	assert_true(_pose_in_camera(player).origin.y < rest.origin.y - 0.1, "the gun drops out of view")


func _pose_in_camera(player: Player) -> Transform3D:
	return player.camera.global_transform.affine_inverse() * player.weapon.view_model.model.global_transform


func _muzzle_pitch(pose: Transform3D) -> float:
	return asin(clampf(-pose.basis.z.y, -1.0, 1.0))


func test_aiming_moves_the_gun_to_the_aim_pose_and_releasing_returns_it() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var view_model := player.weapon.view_model
	var rest := view_model.motion.position
	Input.action_press("aim")
	await run_seconds(1.0)
	assert_true(view_model.motion.position.distance_to(rest + view_model.aim_offset) < 0.01, "the gun is at the aim pose")
	Input.action_release("aim")
	await run_seconds(1.0)
	assert_true(view_model.motion.position.distance_to(rest) < 0.01, "the gun is back at rest")


func test_aiming_keeps_the_sights_still_while_walking() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var view_model := player.weapon.view_model
	Input.action_press("move_forward")
	Input.action_press("aim")
	await run_seconds(1.0)
	var lowest := INF
	var highest := -INF
	for i in SETTLE_FRAMES:
		await physics_frames(1)
		var y := view_model.motion.position.y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	assert_true(highest - lowest < 0.005, "the gun hardly bobs while aiming")


func test_a_shot_while_aiming_still_kicks_the_gun() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	Input.action_press("aim")
	await run_seconds(1.0)
	var rest := _pose_in_camera(player)
	player.weapon.try_fire()
	await physics_frames(2)
	assert_true(_pose_in_camera(player).origin.z > rest.origin.z + 0.005, "the gun kicks back while aiming")


func test_hand_holds_the_gun_through_a_shot() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var view := player.weapon.view_model
	assert_true(view.hand != null and view.hand.is_visible_in_tree(), "the first-person hand shows")
	Input.action_press("fire")
	await physics_frames(2)
	assert_true(view.hand.global_transform.is_equal_approx(view.model.global_transform), "the hand kicks back with the gun")


func test_hand_does_not_spin_with_the_thrown_gun() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	var view := weapon.view_model
	var rest_up := view.hand.global_basis.y
	weapon.try_fire()
	await physics_frames(SETTLE_FRAMES)
	weapon.start_reload()
	var lowest_dot := 1.0
	for i in ceili(weapon.data.reload_time * Engine.physics_ticks_per_second):
		await physics_frames(1)
		lowest_dot = minf(lowest_dot, view.hand.global_basis.y.dot(rest_up))
	assert_true(lowest_dot > 0.3, "the hand stays upright while the gun spins, lowest dot %s" % lowest_dot)
	await physics_frames(SETTLE_FRAMES)
	assert_true(view.hand.global_transform.is_equal_approx(view.model.global_transform), "the hand holds the new gun")


func test_first_person_gun_and_hand_neither_cast_nor_receive_shadows() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var meshes := player.weapon.view_model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 1, "the view model has meshes")
	for mesh: MeshInstance3D in meshes:
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % mesh.name)
		for surface: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			assert_true(material.disable_receive_shadows, "%s surface %d receives no shadow" % [mesh.name, surface])


## The last phase of a reload pulls the slide back and lets it go. A player can fire as soon as the reload ends, so that
## motion must still run just before the end, or the player waits with a gun that looks ready.
func _assert_reload_motion_lasts_until_the_reload_ends(weapon: Weapon) -> void:
	var slide := weapon.view_model.slide
	var slide_rest := slide.position
	weapon.try_fire()
	await physics_frames(SETTLE_FRAMES)
	weapon.start_reload()
	await run_seconds(weapon.data.reload_time * 0.97)
	assert_true(weapon.is_reloading(), "%s is still reloading" % weapon.data.display_name)
	assert_true(slide.position.distance_to(slide_rest) > 0.001, "the %s slide still moves just before the reload ends" % weapon.data.display_name)
	await run_seconds(weapon.data.reload_time * 0.03 + 2.0 / Engine.physics_ticks_per_second)
	assert_true(not weapon.is_reloading(), "%s finished the reload" % weapon.data.display_name)
	assert_true(slide.position.distance_to(slide_rest) < 0.001, "the %s slide is at rest when the reload ends" % weapon.data.display_name)
