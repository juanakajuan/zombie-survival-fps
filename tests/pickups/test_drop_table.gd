extends TestCase

const MAX_AMMO: BuyItem = preload("res://pickups/max_ammo.tres")
const DOUBLE_POINTS: BuyItem = preload("res://pickups/double_points.tres")
const INSTA_KILL: BuyItem = preload("res://pickups/insta_kill.tres")
const NUKE: BuyItem = preload("res://pickups/nuke.tres")
const REPAIR_ALL: BuyItem = preload("res://pickups/repair_all.tres")


func test_a_zombie_with_chance_1_drops_a_pickup_at_its_feet_when_it_dies() -> void:
	var zombie := spawn_zombie(Vector3(3.0, 0.0, 4.0))
	zombie.drops = _table(1.0, [MAX_AMMO])
	assert_eq(pickups_in(self).size(), 0, "pickups while the zombie lives")
	Health.find_on(zombie).damage(1.0e6)
	await physics_frames(2)
	var dropped := pickups_in(self)
	assert_eq(dropped.size(), 1, "pickups after the death")
	assert_eq(dropped[0].item, MAX_AMMO, "item")
	assert_almost_eq(dropped[0].lifetime, 20.0, 0.001, "lifetime")
	assert_almost_eq(dropped[0].global_position.distance_to(Vector3(3.0, 0.0, 4.0)), 0.0, 0.01, "distance from the zombie's feet")


func test_a_zombie_with_chance_0_or_no_table_drops_nothing() -> void:
	var unlucky := spawn_zombie(Vector3(3.0, 0.0, 4.0))
	unlucky.drops = _table(0.0, [MAX_AMMO])
	var empty_handed := spawn_zombie(Vector3(-3.0, 0.0, 4.0))
	Health.find_on(unlucky).damage(1.0e6)
	Health.find_on(empty_handed).damage(1.0e6)
	await physics_frames(2)
	assert_eq(pickups_in(self).size(), 0, "pickups")


func test_the_drop_is_one_of_the_items_of_the_table() -> void:
	var seen: Dictionary[BuyItem, bool] = {}
	var table := _table(1.0, [MAX_AMMO, DOUBLE_POINTS])
	for _i: int in 60:
		seen[table.roll()] = true
	assert_eq(seen.size(), 2, "different items rolled")


func test_a_zombie_of_the_game_drops_by_the_table_of_its_scene() -> void:
	var zombie := ZOMBIE_SCENE.instantiate() as Zombie
	assert_true(zombie.drops != null, "the zombie scene has a drop table")
	assert_almost_eq(zombie.drops.chance, 0.1, 0.001, "chance")
	assert_eq(zombie.drops.items, [MAX_AMMO, DOUBLE_POINTS, INSTA_KILL, NUKE, REPAIR_ALL] as Array[BuyItem], "items")
	zombie.free()


func _table(chance: float, items: Array[BuyItem]) -> DropTable:
	var table := DropTable.new()
	table.chance = chance
	table.items = items
	table.lifetime = 20.0
	return table


func test_the_zombies_that_kill_all_kills_drop_nothing() -> void:
	var level := await spawn_level()
	await run_seconds(2.0)
	var manager := level.round_manager
	for child: Node in manager.get_children():
		if child is Zombie:
			(child as Zombie).drops = _table(1.0, [MAX_AMMO])
	manager.kill_all()
	await physics_frames(2)
	assert_eq(pickups_in(manager).size(), 0, "pickups after kill_all")


func test_zombies_drop_at_most_max_drops_pickups_in_a_round_and_again_in_the_next() -> void:
	await spawn_player()
	var settings := RoundSettings.new()
	settings.first_round_zombies = 4
	settings.zombies_per_round = 0
	settings.first_round_speed = 0.0
	settings.break_time = 0.5
	settings.spawn_interval = 0.1
	settings.max_drops = 2
	var manager := RoundManager.new()
	manager.settings = settings
	manager.zombie_scene = _scene_dropping(_table(1.0, [MAX_AMMO]))
	manager.add_child(SpawnPoint.new())
	add_child(manager)
	await _kill_each_zombie_as_it_spawns(manager)
	assert_eq(manager.round_number, 1, "round 1 ended")
	assert_eq(pickups_in(manager).size(), 2, "pickups dropped in round 1")
	await run_seconds(settings.break_time + 0.2)
	assert_eq(manager.round_number, 2, "round 2 started")
	await _kill_each_zombie_as_it_spawns(manager)
	assert_eq(pickups_in(manager).size(), 4, "pickups dropped in rounds 1 and 2")


func _scene_dropping(table: DropTable) -> PackedScene:
	var zombie := ZOMBIE_SCENE.instantiate() as Zombie
	zombie.drops = table
	var scene := PackedScene.new()
	scene.pack(zombie)
	zombie.free()
	return scene


func _kill_each_zombie_as_it_spawns(manager: RoundManager) -> void:
	while manager.state == RoundManager.State.ACTIVE:
		await physics_frames(1)
		for child: Node in manager.get_children():
			if child is Zombie and not (child as Zombie).is_dead():
				Health.find_on(child).damage(1.0e6)
