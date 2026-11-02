extends TestCase

const WEAPON_SCENE: PackedScene = preload("res://weapons/weapon.tscn")
const THROWN_GUN_SCENE: PackedScene = preload("res://weapons/pistol_thrown.tscn")
const PISTOL: WeaponData = preload("res://weapons/pistol.tres")
const TARGET_DISTANCE := 5.0
const FRAME_MARGIN := 2


func test_shot_at_dummy_in_front_damages_it_by_weapon_damage() -> void:
	var data := _data()
	var weapon := _spawn_weapon(data)
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	var health := Health.find_on(dummy)
	assert_true(weapon.try_fire(), "shot fires")
	assert_almost_eq(health.current, health.max_health - data.damage, 0.001, "dummy lost data.damage")


func test_hit_signal_reports_collider_and_point() -> void:
	var weapon := _spawn_weapon(_data())
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	var hits: Array[Object] = []
	var points: Array[Vector3] = []
	weapon.hit.connect(func(collider: Object, point: Vector3) -> void:
		hits.append(collider)
		points.append(point))
	weapon.try_fire()
	assert_eq(hits.size(), 1, "hit emitted once")
	assert_true(hits.size() == 1 and hits[0] == dummy, "collider is the dummy")
	assert_true(points.size() == 1 and absf(points[0].z + TARGET_DISTANCE - 0.2) < 0.05, "point is on the dummy front face")


func test_miss_changes_nothing() -> void:
	var weapon := _spawn_weapon(_data())
	var dummy := await spawn_dummy(Vector3(4.0, 0.0, -TARGET_DISTANCE))
	var health := Health.find_on(dummy)
	var hit_count := [0]
	weapon.hit.connect(func(_collider: Object, _point: Vector3) -> void: hit_count[0] += 1)
	assert_true(weapon.try_fire(), "shot still fires")
	assert_almost_eq(health.current, health.max_health, 0.001, "dummy health unchanged")
	assert_eq(hit_count[0], 0, "no hit signal")


func test_target_beyond_max_range_is_not_hit() -> void:
	var data := _data()
	data.max_range = TARGET_DISTANCE - 1.0
	var weapon := _spawn_weapon(data)
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	weapon.try_fire()
	var health := Health.find_on(dummy)
	assert_almost_eq(health.current, health.max_health, 0.001, "out of range target is unharmed")


func test_firing_uses_one_ammo() -> void:
	var data := _data()
	var weapon := _spawn_weapon(data)
	assert_eq(weapon.ammo, data.magazine_size, "starts full")
	weapon.try_fire()
	assert_eq(weapon.ammo, data.magazine_size - 1, "one ammo used")


func test_cannot_fire_faster_than_fire_interval() -> void:
	var data := _data()
	data.fire_interval = 0.5
	var weapon := _spawn_weapon(data)
	assert_true(weapon.try_fire(), "first shot fires")
	assert_true(not weapon.try_fire(), "immediate second shot is refused")
	await run_seconds(data.fire_interval / 2.0)
	assert_true(not weapon.try_fire(), "half an interval later is still refused")
	await run_seconds(data.fire_interval / 2.0 + FRAME_MARGIN / float(Engine.physics_ticks_per_second))
	assert_true(weapon.try_fire(), "fires again after the interval")
	assert_eq(weapon.ammo, data.magazine_size - 2, "refused shots used no ammo")


func test_empty_magazine_does_not_fire_and_starts_reload() -> void:
	var data := _data()
	var weapon := _spawn_weapon(data)
	for _i: int in data.magazine_size:
		assert_true(weapon.try_fire(), "magazine shot fires")
	assert_eq(weapon.ammo, 0, "magazine empty")
	var fired_count := [0]
	weapon.fired.connect(func() -> void: fired_count[0] += 1)
	assert_true(not weapon.try_fire(), "empty weapon does not fire")
	assert_eq(fired_count[0], 0, "fired not emitted")
	assert_true(weapon.is_reloading(), "empty fire starts a reload")


func test_reload_refills_after_reload_time_and_not_before() -> void:
	var data := _data()
	var weapon := _spawn_weapon(data)
	weapon.try_fire()
	weapon.start_reload()
	assert_true(weapon.is_reloading(), "reloading")
	assert_true(not weapon.try_fire(), "cannot fire while reloading")
	await run_seconds(data.reload_time * 0.5)
	assert_true(weapon.is_reloading(), "still reloading halfway")
	assert_eq(weapon.ammo, data.magazine_size - 1, "ammo not refilled early")
	await run_seconds(data.reload_time * 0.5 + FRAME_MARGIN / float(Engine.physics_ticks_per_second))
	assert_true(not weapon.is_reloading(), "reload finished")
	assert_eq(weapon.ammo, data.magazine_size, "ammo refilled")
	assert_true(weapon.try_fire(), "fires again after reload")


func test_reload_when_full_or_reloading_is_a_no_op() -> void:
	var weapon := _spawn_weapon(_data())
	var started := [0]
	weapon.reload_started.connect(func() -> void: started[0] += 1)
	weapon.start_reload()
	assert_true(not weapon.is_reloading(), "full magazine does not reload")
	weapon.try_fire()
	weapon.start_reload()
	weapon.start_reload()
	assert_eq(started[0], 1, "reload_started emitted once")


func test_reload_takes_rounds_from_the_reserve() -> void:
	var data := _data()
	data.max_reserve = 10
	var weapon := _spawn_weapon(data)
	assert_eq(weapon.reserve, 10, "starts with a full reserve")
	weapon.try_fire()
	weapon.try_fire()
	weapon.start_reload()
	await run_seconds(data.reload_time + FRAME_MARGIN / float(Engine.physics_ticks_per_second))
	assert_eq(weapon.ammo, data.magazine_size, "magazine refilled")
	assert_eq(weapon.reserve, 8, "two rounds left the reserve")


func test_reload_with_a_small_reserve_fills_only_what_it_has() -> void:
	var data := _data()
	data.max_reserve = 1
	var weapon := _spawn_weapon(data)
	for _i: int in 3:
		weapon.try_fire()
	weapon.start_reload()
	await run_seconds(data.reload_time + FRAME_MARGIN / float(Engine.physics_ticks_per_second))
	assert_eq(weapon.ammo, 2, "one round added to the one left")
	assert_eq(weapon.reserve, 0, "reserve empty")


func test_no_reserve_means_no_reload() -> void:
	var data := _data()
	data.max_reserve = 0
	var weapon := _spawn_weapon(data)
	for _i: int in data.magazine_size:
		weapon.try_fire()
	weapon.start_reload()
	assert_true(not weapon.is_reloading(), "reload refused")
	assert_true(not weapon.try_fire(), "empty magazine does not fire")
	assert_true(not weapon.is_reloading(), "firing empty does not reload either")
	assert_eq(weapon.ammo, 0, "magazine still empty")


func test_refill_reserve_fills_it_and_reports_whether_it_changed() -> void:
	var data := _data()
	data.max_reserve = 10
	var weapon := _spawn_weapon(data)
	assert_true(not weapon.refill_reserve(), "a full reserve is not refilled")
	weapon.reserve = 3
	assert_true(weapon.refill_reserve(), "a partial reserve is refilled")
	assert_eq(weapon.reserve, 10, "reserve full")


func test_ammo_changed_follows_shots_and_reloads() -> void:
	var data := _data()
	var weapon := _spawn_weapon(data)
	var changes := [0]
	weapon.ammo_changed.connect(func() -> void: changes[0] += 1)
	weapon.try_fire()
	var after_shot: int = changes[0]
	assert_true(after_shot > 0, "a shot changes the ammo")
	changes[0] = 0
	weapon.start_reload()
	await run_seconds(data.reload_time + FRAME_MARGIN / float(Engine.physics_ticks_per_second))
	var after_reload: int = changes[0]
	assert_true(after_reload > 0, "a reload changes the ammo")


func test_damaged_reports_the_target_and_whether_the_shot_killed_it() -> void:
	var data := _data()
	var weapon := _spawn_weapon(data)
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	var health := Health.find_on(dummy)
	health.damage(health.max_health - data.damage * 2.0)
	var kills: Array[bool] = []
	var targets: Array[Node] = []
	weapon.damaged.connect(func(target: Node, killed: bool, _headshot: bool) -> void:
		targets.append(target)
		kills.append(killed))
	weapon.try_fire()
	weapon.try_fire()
	assert_eq(kills, [false, true] as Array[bool], "only the second shot kills")
	assert_true(targets.all(func(target: Node) -> bool: return target == dummy), "the target is the dummy")


func test_reload_action_starts_a_reload() -> void:
	var weapon := _spawn_weapon(_data())
	weapon.try_fire()
	Input.action_press("reload")
	await physics_frames(2)
	assert_true(weapon.is_reloading(), "reload key starts a reload")


func test_automatic_weapon_keeps_firing_while_held_and_semi_auto_fires_once() -> void:
	var auto_data := _data()
	auto_data.automatic = true
	auto_data.fire_interval = 0.05
	var auto_weapon := _spawn_weapon(auto_data)
	var semi_data := _data()
	var semi_weapon := _spawn_weapon(semi_data)
	Input.action_press("fire")
	await run_seconds(0.5)
	assert_true(auto_weapon.ammo < auto_data.magazine_size - 3, "automatic fired several shots, ammo %s" % auto_weapon.ammo)
	assert_eq(semi_weapon.ammo, semi_data.magazine_size - 1, "semi-auto fired exactly once")


func test_pistol_on_player_damages_dummy_and_never_hits_the_player() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var weapon := player.weapon
	assert_true(weapon.data == PISTOL, "player carries the pistol")
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	var dummy_health := Health.find_on(dummy)
	var player_health := Health.find_on(player)
	var hit_colliders: Array[Object] = []
	weapon.hit.connect(func(collider: Object, _point: Vector3) -> void: hit_colliders.append(collider))
	Input.action_press("fire")
	await physics_frames(3)
	assert_almost_eq(dummy_health.current, dummy_health.max_health - PISTOL.damage, 0.001, "dummy lost pistol damage once")
	assert_almost_eq(player_health.current, player_health.max_health, 0.001, "player is unharmed")
	assert_true(hit_colliders.size() == 1 and hit_colliders[0] == dummy, "the only hit is the dummy")
	assert_eq(weapon.ammo, PISTOL.magazine_size - 1, "one round used")


func test_player_cannot_fire_while_sprinting_and_can_after() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var weapon := player.weapon
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await physics_frames(5)
	assert_true(player.is_sprinting(), "the player sprints")
	Input.action_press("fire")
	await physics_frames(3)
	assert_eq(weapon.ammo, PISTOL.magazine_size, "no shot while sprinting")
	assert_true(not weapon.try_fire(), "try_fire is refused while sprinting")
	Input.action_release("fire")
	Input.action_release("sprint")
	await physics_frames(2)
	assert_eq(weapon.ammo, PISTOL.magazine_size, "the held fire did not queue a shot")
	Input.action_press("fire")
	await physics_frames(2)
	assert_eq(weapon.ammo, PISTOL.magazine_size - 1, "fires after the sprint ends")


func test_player_sees_the_pistol_model() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var camera := player.camera
	var meshes := player.weapon.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 0, "the pistol has a model")
	var in_view := 0
	for node in meshes:
		var mesh := node as MeshInstance3D
		var center := mesh.global_transform * mesh.get_aabb().get_center()
		if mesh.is_visible_in_tree() and camera.is_position_in_frustum(center):
			in_view += 1
	assert_true(in_view > 0, "the pistol model is in the camera view")


func test_shot_goes_through_a_thrown_gun() -> void:
	var weapon := _spawn_weapon(_data())
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	var gun := THROWN_GUN_SCENE.instantiate() as RigidBody3D
	gun.freeze = true
	add_child(gun)
	gun.global_position = Vector3(0.0, weapon.global_position.y, -TARGET_DISTANCE / 2.0)
	await physics_frames(FRAME_MARGIN)
	var health := Health.find_on(dummy)
	assert_true(weapon.try_fire(), "shot fires")
	assert_true(health.current < health.max_health, "the dummy behind the thrown gun is hit")


func _data() -> WeaponData:
	var data := WeaponData.new()
	data.damage = 20.0
	data.fire_interval = 0.0
	data.magazine_size = 4
	data.reload_time = 0.5
	data.max_range = 50.0
	data.automatic = false
	return data


func _spawn_weapon(data: WeaponData) -> Weapon:
	var weapon := WEAPON_SCENE.instantiate() as Weapon
	weapon.data = data
	add_child(weapon)
	return weapon
