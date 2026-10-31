extends TestCase

const DOUBLE_POINTS: DoublePointsItem = preload("res://pickups/double_points.tres")
const MAX_AMMO: BuyItem = preload("res://pickups/max_ammo.tres")
const NUKE: NukeItem = preload("res://pickups/nuke.tres")
const REPAIR_ALL: RepairAllItem = preload("res://pickups/repair_all.tres")
const BARRICADE_SCENE: PackedScene = preload("res://barricades/barricade.tscn")


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


func test_insta_kill_makes_one_shot_kill_a_full_health_zombie_and_pays_as_usual() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -4.0), player)
	await physics_frames(2)
	player.powerups.start(_insta_kill(5.0))
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_true(zombie.is_dead(), "one shot kills a full health zombie")
	assert_eq(player.wallet.points, player.wallet.points_per_hit + player.wallet.kill_bonus, "hit and kill bonus")


func test_insta_kill_makes_one_punch_kill_a_full_health_zombie() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -1.2), player)
	player.powerups.start(_insta_kill(5.0))
	Input.action_press("melee")
	await physics_frames(2)
	Input.action_release("melee")
	await run_seconds(player.melee.wind_up_time + player.melee.recover_time + 0.1)
	assert_true(zombie.is_dead(), "one punch kills a full health zombie")
	assert_eq(player.wallet.points, player.wallet.points_per_hit + player.wallet.kill_bonus, "hit and kill bonus")


func test_a_shot_does_not_kill_once_insta_kill_has_ended() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var zombie := _still_zombie(Vector3(0.0, 0.0, -4.0), player)
	await physics_frames(2)
	player.powerups.start(_insta_kill(0.5))
	await run_seconds(0.7)
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_true(not zombie.is_dead(), "the zombie survives a shot")


func test_insta_kill_does_not_one_shot_a_target_dummy() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -4.0))
	player.powerups.start(_insta_kill(5.0))
	assert_true(player.weapon.try_fire(), "shot fires")
	var health := Health.find_on(dummy)
	assert_almost_eq(health.current, health.max_health - player.weapon.data.damage, 0.001, "the dummy takes the normal damage")


func _still_zombie(at: Vector3, player: Player) -> Zombie:
	var zombie := spawn_zombie(at, player)
	zombie.move_speed = 0.0
	return zombie


func _insta_kill(duration: float) -> InstaKillItem:
	var item := InstaKillItem.new()
	item.display_name = "INSTA-KILL"
	item.duration = duration
	return item


func test_a_nuke_kills_every_living_zombie_pays_its_points_and_drops_nothing() -> void:
	var player := await spawn_player()
	var table := DropTable.new()
	table.chance = 1.0
	table.items = [MAX_AMMO] as Array[BuyItem]
	var zombies: Array[Zombie] = []
	for x: int in [-6, 6, 9]:
		var zombie := spawn_zombie(Vector3(x, 0.0, -4.0))
		zombie.drops = table
		zombies.append(zombie)
	player.powerups.start(DOUBLE_POINTS)
	spawn_pickup(NUKE, Vector3.ZERO)
	await physics_frames(3)
	for zombie: Zombie in zombies:
		assert_true(zombie.is_dead(), "the zombie at %s is dead" % zombie.position)
	assert_eq(player.wallet.points, NUKE.points, "a fixed payment, not doubled, with no points for the kills")
	assert_eq(pickups_in(self).size(), 0, "the dead zombies dropped nothing")


func test_repair_all_fills_every_barricade_and_pays_its_points() -> void:
	var player := await spawn_player()
	var barricades: Array[Barricade] = []
	for x: int in [10, 15]:
		var barricade := BARRICADE_SCENE.instantiate() as Barricade
		barricade.position = Vector3(x, 0.0, 0.0)
		add_child(barricade)
		barricade.remove_board()
		barricade.remove_board()
		barricades.append(barricade)
	player.powerups.start(DOUBLE_POINTS)
	spawn_pickup(REPAIR_ALL, Vector3.ZERO)
	await physics_frames(3)
	for barricade: Barricade in barricades:
		assert_true(barricade.is_full(), "the barricade at %s is full" % barricade.position)
	assert_eq(player.wallet.points, REPAIR_ALL.points, "a fixed payment, not doubled")
