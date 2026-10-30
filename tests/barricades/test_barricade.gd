extends TestCase

const BARRICADE_SCENE: PackedScene = preload("res://barricades/barricade.tscn")
const REPAIR_PROMPT := "HOLD E  REPAIR  %d/%d"
const STILL_SPEED := 0.0


func test_a_zombie_stops_at_a_full_barricade_pulls_the_boards_one_by_one_and_then_crosses() -> void:
	await spawn_nav_world()
	var barricade := _spawn_barricade(Vector3.ZERO, 3)
	var player := await spawn_player(Vector3(0.0, 0.0, -8.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 3.0), player)
	zombie.board_pull_interval = 0.3
	zombie.attack_damage = 0.0
	var counts: Array[int] = []
	barricade.boards_changed.connect(func(boards: int) -> void: counts.append(boards))
	var crossed_with_boards := false
	for _i: int in roundi(5.0 * Engine.physics_ticks_per_second):
		await physics_frames(1)
		crossed_with_boards = crossed_with_boards or (barricade.has_boards() and barricade.is_inside(zombie.global_position))
	assert_true(not crossed_with_boards, "the zombie crossed the plane while boards were left")
	assert_eq(counts, [2, 1, 0] as Array[int], "the boards go down one at a time")
	assert_true(barricade.is_inside(zombie.global_position), "the zombie crossed once the last board was off, at %s" % zombie.global_position)


func test_a_zombie_at_the_window_hits_a_player_who_repairs_it_and_pulls_no_board_meanwhile() -> void:
	await spawn_nav_world()
	var barricade := _spawn_barricade(Vector3.ZERO, 3)
	var player := await spawn_player(Vector3(0.0, 0.0, -0.7), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 3.0), player)
	zombie.board_pull_interval = 0.3
	await run_seconds(2.0)
	assert_true(player.health.current < player.health.max_health, "the zombie at the window hits the player just inside it")
	assert_eq(barricade.boards, 3, "a zombie that hits pulls no board")
	player.position = Vector3(0.0, 0.0, -6.0)
	await run_seconds(1.5)
	assert_true(barricade.boards < 3, "with the player out of reach, the zombie pulls boards again")


func test_two_zombies_at_a_window_pull_boards_faster_than_one() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, -10.0), 3)
	var alone := await _boards_pulled_in(player, [Vector3(0.0, 0.0, 2.0)] as Array[Vector3], 2.0)
	var pair := await _boards_pulled_in(player, [Vector3(-0.5, 0.0, 2.0), Vector3(0.5, 0.0, 2.0)] as Array[Vector3], 2.0)
	assert_true(pair > alone, "two zombies pull %d boards and one pulls %d" % [pair, alone])


func test_holding_interact_on_a_damaged_barricade_adds_a_board_and_points() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var barricade := _spawn_barricade(Vector3(0.0, 0.0, -1.2), 5)
	barricade.repair_time = 0.5
	barricade.remove_board()
	barricade.remove_board()
	await physics_frames(2)
	look_at_point(player, barricade.global_position + Vector3.UP)
	await physics_frames(2)
	Input.action_press("interact")
	await run_seconds(barricade.repair_time * 0.5)
	assert_eq(barricade.boards, 3, "no board before repair_time")
	await run_seconds(barricade.repair_time * 0.5 + 3.0 / 60.0)
	assert_eq(barricade.boards, 4, "one board after repair_time")
	assert_eq(player.wallet.points, player.wallet.points_per_board, "points for one board")
	await run_seconds(barricade.repair_time * 2.0)
	assert_eq(barricade.boards, 5, "a full barricade takes no more boards")
	assert_eq(player.wallet.points, player.wallet.points_per_board * 2, "points for two boards")
	Input.action_release("interact")


func test_a_player_beyond_repair_range_sees_no_prompt_and_repairs_nothing() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var barricade := _spawn_barricade(Vector3(0.0, 0.0, -2.2), 5)
	barricade.repair_time = 0.2
	barricade.remove_board()
	await physics_frames(2)
	look_at_point(player, barricade.global_position + Vector3.UP)
	await physics_frames(3)
	assert_true(player.focused() == barricade, "the barricade is focused from %.1f m" % absf(barricade.global_position.z))
	assert_true(not player.hud.readout().prompt_visible, "the HUD shows no prompt out of repair range")
	Input.action_press("interact")
	await run_seconds(barricade.repair_time * 3.0)
	Input.action_release("interact")
	assert_eq(barricade.boards, 4, "no board is repaired out of repair range")
	assert_eq(player.wallet.points, 0, "no points out of repair range")


func test_repairs_give_points_up_to_the_round_limit_and_a_new_round_restores_it() -> void:
	var player := await spawn_player()
	var barricade := _spawn_barricade(Vector3(0.0, 0.0, -1.2), 10)
	var wallet := player.wallet
	var repairs := wallet.board_points_per_round / wallet.points_per_board + 2
	for _i: int in repairs:
		barricade.remove_board()
	for _i: int in repairs:
		barricade.hold(player, barricade.repair_time)
	assert_eq(barricade.boards, 10, "every repair puts a board back")
	assert_eq(wallet.points, wallet.board_points_per_round, "points stop at the limit")
	barricade.remove_board()
	wallet.start_round()
	barricade.hold(player, barricade.repair_time)
	assert_eq(wallet.points, wallet.board_points_per_round + wallet.points_per_board, "a new round gives points again")


func test_a_new_round_in_the_level_restores_the_repair_points() -> void:
	var level := await spawn_level(_still_zombies())
	var wallet := level.player.wallet
	for _i: int in wallet.board_points_per_round / wallet.points_per_board + 1:
		wallet.reward_board()
	assert_eq(wallet.points, wallet.board_points_per_round, "points at the limit")
	level.round_manager.kill_all()
	level.round_manager.skip_break()
	wallet.reward_board()
	assert_eq(wallet.points, wallet.board_points_per_round + wallet.points_per_board, "points in the next round")


func test_a_full_barricade_shows_no_prompt_and_a_damaged_one_shows_the_repair_prompt() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var barricade := _spawn_barricade(Vector3(0.0, 0.0, -1.2), 5)
	await physics_frames(2)
	look_at_point(player, barricade.global_position + Vector3.UP)
	await physics_frames(3)
	assert_true(player.focused() == barricade, "the barricade is focused")
	assert_eq(barricade.prompt_text(player), "", "prompt of a full barricade")
	assert_true(not player.hud.readout().prompt_visible, "the HUD shows no prompt")
	barricade.remove_board()
	await physics_frames(3)
	assert_eq(barricade.prompt_text(player), REPAIR_PROMPT % [4, 5], "prompt of a damaged barricade")
	assert_true(player.hud.readout().prompt_visible, "the HUD shows the prompt")
	assert_eq(player.hud.readout().prompt_text, REPAIR_PROMPT % [4, 5], "HUD prompt text")


func test_the_barricade_stops_the_player_and_not_a_shot() -> void:
	var player := await spawn_player(Vector3(0.0, 0.0, 2.0), 5)
	_spawn_barricade(Vector3.ZERO, 5)
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -3.0))
	await physics_frames(2)
	Input.action_press("move_forward")
	await run_seconds(1.5)
	Input.action_release("move_forward")
	assert_true(player.global_position.z > 0.0, "the player stays outside the barricade, at %s" % player.global_position)
	look_at_point(player, dummy.global_position + Vector3.UP)
	var health := Health.find_on(dummy)
	var before := health.current
	player.weapon.try_fire()
	await physics_frames(2)
	assert_true(health.current < before, "a shot goes through the barricade")


func test_a_zombie_from_a_spawn_point_with_a_barricade_walks_through_it() -> void:
	var level := await spawn_level(_still_zombies())
	var with_barricade: Array[SpawnPoint] = spawn_points_in(level).filter(func(point: SpawnPoint) -> bool: return point.barricade != null)
	assert_eq(with_barricade.size(), 1, "spawn points that name a barricade")
	var spawn := with_barricade[0]
	var barricade := spawn.barricade
	assert_true(barricade != null, "the yard spawn point names a barricade")
	assert_true(not barricade.is_inside(spawn.global_position), "the spawn point is outside")
	var zombie := ZOMBIE_SCENE.instantiate() as Zombie
	zombie.configure(ROUND_SETTINGS.zombie_speed(1), ROUND_SETTINGS.zombie_health(1), level.player, spawn.barricade)
	zombie.board_pull_interval = 0.2
	zombie.move_speed = 6.0
	zombie.drops = null
	zombie.transform = spawn.global_transform
	level.add_child(zombie)
	var crossed_with_boards := false
	for _i: int in roundi(8.0 * Engine.physics_ticks_per_second):
		await physics_frames(1)
		crossed_with_boards = crossed_with_boards or (barricade.has_boards() and barricade.is_inside(zombie.global_position))
		if not barricade.has_boards() and Vector2(zombie.global_position.x - level.player.global_position.x, zombie.global_position.z - level.player.global_position.z).length() < 2.0:
			break
	assert_true(not crossed_with_boards, "the zombie crossed while boards were left")
	assert_eq(barricade.boards, 0, "the zombie pulled all the boards")
	assert_true(barricade.is_inside(zombie.global_position), "the zombie is inside, at %s" % zombie.global_position)
	assert_true(zombie.entry == null, "the zombie dropped its entry once inside")


## The boards that zombies from `starts` pull off a 10-board barricade at the origin in `seconds`. The zombies are freed after.
func _boards_pulled_in(player: Player, starts: Array[Vector3], seconds: float) -> int:
	var barricade := _spawn_barricade(Vector3.ZERO, 10)
	var zombies: Array[Zombie] = []
	for start: Vector3 in starts:
		var zombie := spawn_zombie(start, player)
		zombie.board_pull_interval = 0.3
		zombies.append(zombie)
	await run_seconds(seconds)
	var pulled := barricade.max_boards - barricade.boards
	for zombie: Zombie in zombies:
		zombie.free()
	barricade.free()
	await physics_frames(1)
	return pulled


func _spawn_barricade(at: Vector3, boards: int) -> Barricade:
	var barricade := BARRICADE_SCENE.instantiate() as Barricade
	barricade.max_boards = boards
	barricade.position = at
	add_child(barricade)
	return barricade


func _still_zombies() -> RoundSettings:
	var settings := RoundSettings.new()
	settings.first_round_speed = STILL_SPEED
	settings.speed_per_round = 0.0
	settings.max_speed = STILL_SPEED
	settings.first_round_zombies = 1
	settings.zombies_per_round = 0
	return settings
