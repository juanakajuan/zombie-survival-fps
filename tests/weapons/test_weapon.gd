extends TestCase

const DUMMY_SCENE: PackedScene = preload("res://targets/target_dummy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const WEAPON_SCENE: PackedScene = preload("res://weapons/weapon.tscn")
const PISTOL: WeaponData = preload("res://weapons/pistol.tres")
const TARGET_DISTANCE := 5.0
const FRAME_MARGIN := 2


func test_shot_at_dummy_in_front_damages_it_by_weapon_damage() -> void:
	var data := _data()
	var weapon := _spawn_weapon(data)
	var dummy := await _spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	var health := Health.find_on(dummy)
	assert_true(weapon.try_fire(), "shot fires")
	assert_almost_eq(health.current, health.max_health - data.damage, 0.001, "dummy lost data.damage")


func test_hit_signal_reports_collider_and_point() -> void:
	var weapon := _spawn_weapon(_data())
	var dummy := await _spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
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
	var dummy := await _spawn_dummy(Vector3(4.0, 0.0, -TARGET_DISTANCE))
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
	var dummy := await _spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
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
	await _run_seconds(data.fire_interval / 2.0)
	assert_true(not weapon.try_fire(), "half an interval later is still refused")
	await _run_seconds(data.fire_interval / 2.0 + FRAME_MARGIN / float(Engine.physics_ticks_per_second))
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
	await _run_seconds(data.reload_time * 0.5)
	assert_true(weapon.is_reloading(), "still reloading halfway")
	assert_eq(weapon.ammo, data.magazine_size - 1, "ammo not refilled early")
	await _run_seconds(data.reload_time * 0.5 + FRAME_MARGIN / float(Engine.physics_ticks_per_second))
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
	await _run_seconds(0.5)
	assert_true(auto_weapon.ammo < auto_data.magazine_size - 3, "automatic fired several shots, ammo %s" % auto_weapon.ammo)
	assert_eq(semi_weapon.ammo, semi_data.magazine_size - 1, "semi-auto fired exactly once")


func test_pistol_on_player_damages_dummy_and_never_hits_the_player() -> void:
	var player := await _spawn_player()
	var weapon := player.get_node("Head/Camera3D/Weapon") as Weapon
	assert_true(weapon.data == PISTOL, "player carries the pistol")
	var dummy := await _spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
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


func _spawn_dummy(at: Vector3) -> TargetDummy:
	var dummy := DUMMY_SCENE.instantiate() as TargetDummy
	dummy.position = at
	add_child(dummy)
	await physics_frames(2)
	return dummy


func _spawn_player() -> Player:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await physics_frames(5)
	return player


func _run_seconds(seconds: float) -> void:
	await physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


func test_click_that_recaptures_the_mouse_does_not_fire() -> void:
	await _spawn_player()
	var dummy := await _spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	var dummy_health := Health.find_on(dummy)
	_send_key(KEY_ESCAPE, true)
	_send_key(KEY_ESCAPE, false)
	_send_click(true)
	await physics_frames(3)
	_send_click(false)
	await physics_frames(3)
	assert_almost_eq(dummy_health.current, dummy_health.max_health, 0.001, "the recapture click does not shoot")
	_send_click(true)
	await physics_frames(3)
	_send_click(false)
	assert_almost_eq(dummy_health.current, dummy_health.max_health - PISTOL.damage, 0.001, "the next click shoots")


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
