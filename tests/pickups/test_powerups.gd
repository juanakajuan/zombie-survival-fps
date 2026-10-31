extends TestCase

const DOUBLE_POINTS: BuyItem = preload("res://pickups/double_points.tres")


func test_a_second_pickup_of_the_same_effect_starts_its_time_again() -> void:
	var player := await spawn_player()
	var item := _insta_kill(1.0)
	player.powerups.start(item)
	await run_seconds(0.8)
	player.powerups.start(item)
	await run_seconds(0.8)
	assert_true(player.powerups.kills_on_hit(), "the effect still runs")
	assert_almost_eq(player.powerups.time_left(item), 0.2, 0.05, "time left")
	await run_seconds(0.4)
	assert_true(not player.powerups.kills_on_hit(), "the effect has ended")
	assert_eq(player.powerups.time_left(item), 0.0, "no time left")


func test_the_hud_lists_each_running_effect_in_start_order_until_it_ends() -> void:
	var player := await spawn_player()
	assert_eq(player.hud.readout().powerups, PackedStringArray(), "nothing runs at start")
	var kill := _insta_kill(2.0)
	var double := DoublePointsItem.new()
	double.display_name = "DOUBLE POINTS"
	double.duration = 1.0
	player.powerups.start(kill)
	player.powerups.start(double)
	assert_eq(player.hud.readout().powerups, PackedStringArray(["INSTA-KILL  2", "DOUBLE POINTS  1"]), "both effects")
	await run_seconds(1.2)
	assert_eq(player.hud.readout().powerups, PackedStringArray(["INSTA-KILL  1"]), "the first to end leaves the other")
	await run_seconds(1.0)
	assert_eq(player.hud.readout().powerups, PackedStringArray(), "nothing runs at the end")


func test_walking_over_a_pickup_does_nothing_for_a_dead_player() -> void:
	var player := await spawn_player()
	player.health.damage(1.0e6)
	var pickup := spawn_pickup(DOUBLE_POINTS, Vector3.ZERO)
	await physics_frames(3)
	assert_true(is_instance_valid(pickup), "the pickup stays")
	assert_eq(player.powerups.running().size(), 0, "no effect runs")


func _insta_kill(duration: float) -> InstaKillItem:
	var item := InstaKillItem.new()
	item.display_name = "INSTA-KILL"
	item.duration = duration
	return item
