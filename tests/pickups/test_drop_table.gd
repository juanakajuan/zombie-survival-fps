extends TestCase

const MAX_AMMO: BuyItem = preload("res://pickups/max_ammo.tres")


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
	var table := _table(1.0, [MAX_AMMO, MAX_AMMO.duplicate()])
	for _i: int in 60:
		seen[table.roll()] = true
	assert_eq(seen.size(), 2, "different items rolled")


func test_a_zombie_of_the_game_drops_by_the_table_of_its_scene() -> void:
	var zombie := ZOMBIE_SCENE.instantiate() as Zombie
	assert_true(zombie.drops != null, "the zombie scene has a drop table")
	assert_almost_eq(zombie.drops.chance, 0.1, 0.001, "chance")
	assert_eq(zombie.drops.items, [MAX_AMMO] as Array[BuyItem], "items")
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
