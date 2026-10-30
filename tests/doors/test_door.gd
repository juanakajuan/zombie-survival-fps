extends TestCase

const ROOM := Rect2(12.0, 12.0, 8.0, 8.0)
const OUTSIDE_THE_DOORWAY := Vector3(16.5, 0.0, 9.0)
const INSIDE_THE_ROOM := Vector3(16.0, 0.0, 17.0)


func test_a_player_with_enough_points_buys_the_door_and_it_opens() -> void:
	var level := await spawn_level()
	var player := level.player
	var door := level.get_node("RoomDoor") as Door
	player.wallet.add(1000)
	assert_true(not door.is_open(), "the door is closed at the start")
	assert_true(door.station.buy(player), "the purchase succeeds")
	assert_true(door.is_open(), "the door is open")
	assert_eq(player.wallet.points, 250, "points after the 750 cost")
	assert_true(not door.station.visible, "the open door is not drawn")
	assert_eq(door.station.collision_layer, 0, "an open door has no collider")


func test_a_player_with_too_few_points_cannot_buy_the_door() -> void:
	var level := await spawn_level()
	var player := level.player
	var door := level.get_node("RoomDoor") as Door
	player.wallet.add(700)
	assert_true(not door.station.buy(player), "the purchase fails")
	assert_true(not door.is_open(), "the door stays closed")
	assert_eq(player.wallet.points, 700, "points")


func test_the_player_cannot_buy_an_open_door_again() -> void:
	var level := await spawn_level()
	var player := level.player
	var door := level.get_node("RoomDoor") as Door
	player.wallet.add(2000)
	var opened_count := [0]
	door.opened.connect(func() -> void: opened_count[0] += 1)
	door.open()
	door.open()
	assert_eq(opened_count[0], 1, "opened signals")
	player.global_position = OUTSIDE_THE_DOORWAY
	player.look(player.mouse_delta_to_angles(PI, 0.0))
	await physics_frames(3)
	assert_true(player.focused_station() == null, "the player does not focus the open door")


func test_the_player_looks_at_the_closed_door_and_sees_its_price() -> void:
	var level := await spawn_level()
	var player := level.player
	player.global_position = Vector3(16.5, 0.0, 10.5)
	player.look(player.mouse_delta_to_angles(PI, 0.0))
	await physics_frames(3)
	assert_eq(player.focused_station().prompt_text(player), "E  BUY DOOR  750", "prompt")


func test_the_closed_door_blocks_a_zombie_and_the_open_door_lets_it_through() -> void:
	var settings := _still_zombies()
	var level := await spawn_level(settings)
	var player := level.player
	player.global_position = OUTSIDE_THE_DOORWAY
	var closed_zombie := spawn_zombie(INSIDE_THE_ROOM, player)
	await run_seconds(6.0)
	assert_true(ROOM.has_point(Vector2(closed_zombie.global_position.x, closed_zombie.global_position.z)), "a zombie in the closed room stays in the room, at %s" % closed_zombie.global_position)
	closed_zombie.queue_free()
	(level.get_node("RoomDoor") as Door).open()
	await run_seconds(1.0)
	var zombie := spawn_zombie(INSIDE_THE_ROOM, player)
	await run_seconds(8.0)
	assert_true(_flat_distance(zombie, player) < 2.0, "a zombie in the open room reaches the player outside the doorway, %.1f m away" % _flat_distance(zombie, player))


func test_the_room_spawn_point_waits_for_its_door() -> void:
	var settings := _still_zombies()
	settings.first_round_zombies = 10
	var level := await spawn_level(settings)
	var manager := level.round_manager
	var door := level.get_node("RoomDoor") as Door
	var waiting: Array[SpawnPoint] = spawn_points_in(level).filter(func(point: SpawnPoint) -> bool: return not point.is_active())
	assert_eq(waiting.size(), 1, "spawn points that wait at the start")
	var room_point := waiting[0]
	assert_true(ROOM.has_point(Vector2(room_point.global_position.x, room_point.global_position.z)), "the waiting point is in the room")
	await run_seconds(1.5)
	assert_eq(_zombies_in_room(manager), 0, "zombies in the closed room")
	assert_eq(_zombies(manager).size(), 10, "zombies of the round")
	door.open()
	assert_true(room_point.is_active(), "the room point is active once the door is open")
	manager.kill_all()
	manager.skip_break()
	await run_seconds(1.5)
	assert_true(_zombies_in_room(manager) > 0, "zombies in the open room, with %d zombies" % _zombies(manager).size())


func _still_zombies() -> RoundSettings:
	var settings := RoundSettings.new()
	settings.first_round_speed = 0.0
	settings.speed_per_round = 0.0
	settings.max_speed = 0.0
	settings.first_round_zombies = 10
	settings.zombies_per_round = 0
	settings.spawn_interval = 0.1
	return settings


func _zombies(manager: RoundManager) -> Array[Zombie]:
	var found: Array[Zombie] = []
	for child: Node in manager.get_children():
		if child is Zombie and not (child as Zombie).is_dead():
			found.append(child as Zombie)
	return found


func _zombies_in_room(manager: RoundManager) -> int:
	return _zombies(manager).filter(func(zombie: Zombie) -> bool: return ROOM.has_point(Vector2(zombie.global_position.x, zombie.global_position.z))).size()


func _flat_distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
