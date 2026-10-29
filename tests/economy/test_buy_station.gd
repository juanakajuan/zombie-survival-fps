extends TestCase

const STATION_AT := Vector3(0.0, 0.0, -2.0)
const AMMO_COST := 250


func test_looking_at_the_station_focuses_it_and_looking_away_does_not() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(STATION_AT)
	await physics_frames(2)
	assert_true(player.focused_station() == null, "nothing is focused when looking along the floor")
	look_at_point(player, station.global_position + Vector3.UP * 0.6)
	await physics_frames(2)
	assert_true(player.focused_station() == station, "the station is focused")
	player.look(Vector2(1000.0, 0.0))
	await physics_frames(2)
	assert_true(player.focused_station() == null, "looking away drops the focus")


func test_a_station_beyond_interact_range_is_not_focused() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(Vector3(0.0, 0.0, -(player.interact_range + 1.0)))
	await physics_frames(2)
	look_at_point(player, station.global_position + Vector3.UP * 0.6)
	await physics_frames(2)
	assert_true(player.focused_station() == null, "too far away")


func test_a_wall_between_the_player_and_the_station_blocks_the_focus() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(Vector3(0.0, 0.0, -2.2))
	var wall := _box(Vector3(4.0, 3.0, 0.2), Vector3(0.0, 1.5, -1.0))
	add_child(wall)
	await physics_frames(2)
	look_at_point(player, station.global_position + Vector3.UP * 0.6)
	await physics_frames(2)
	assert_true(player.focused_station() == null, "the wall hides the station")


func test_the_prompt_shows_the_item_and_its_cost() -> void:
	var station := spawn_station(STATION_AT)
	assert_eq(station.prompt_text(), "E  BUY AMMO  %d" % AMMO_COST, "prompt")


func test_e_buys_ammo_with_points_and_fills_the_reserve() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(STATION_AT)
	player.wallet.add(AMMO_COST + 40)
	player.weapon.reserve = 5
	look_at_point(player, station.global_position + Vector3.UP * 0.6)
	await physics_frames(2)
	var purchases := [0]
	station.purchased.connect(func() -> void: purchases[0] += 1)
	Input.action_press("interact")
	await physics_frames(2)
	assert_eq(player.wallet.points, 40, "points were spent")
	assert_eq(player.weapon.reserve, player.weapon.data.max_reserve, "reserve is full")
	assert_eq(purchases[0], 1, "purchased emitted once")
	Input.action_release("interact")


func test_holding_e_buys_once() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(STATION_AT)
	player.wallet.add(AMMO_COST * 3)
	player.weapon.reserve = 0
	look_at_point(player, station.global_position + Vector3.UP * 0.6)
	await physics_frames(2)
	Input.action_press("interact")
	await physics_frames(10)
	assert_eq(player.wallet.points, AMMO_COST * 2, "one purchase")


func test_too_few_points_buy_nothing() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(STATION_AT)
	player.wallet.add(AMMO_COST - 1)
	player.weapon.reserve = 5
	assert_true(not station.buy(player), "the purchase fails")
	assert_eq(player.wallet.points, AMMO_COST - 1, "no points spent")
	assert_eq(player.weapon.reserve, 5, "reserve unchanged")


func test_a_full_reserve_buys_nothing_and_costs_nothing() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var station := spawn_station(STATION_AT)
	player.wallet.add(AMMO_COST)
	assert_true(not station.buy(player), "the purchase fails")
	assert_eq(player.wallet.points, AMMO_COST, "no points spent")
