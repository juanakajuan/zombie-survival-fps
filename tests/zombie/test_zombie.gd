extends TestCase

const WEAPON_SCENE: PackedScene = preload("res://weapons/weapon.tscn")
const PISTOL: WeaponData = preload("res://weapons/pistol.tres")
const RIFLE: WeaponData = preload("res://weapons/rifle.tres")
const FRAME_MARGIN := 3


func test_zombie_walks_toward_a_still_player() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0), player)
	var start := _flat_distance(zombie, player)
	await run_seconds(2.0)
	var closed := start - _flat_distance(zombie, player)
	assert_true(closed >= zombie.move_speed * 1.0, "zombie closed %s m in 2 s, speed is %s m/s" % [closed, zombie.move_speed])


func test_zombie_goes_around_a_wall_to_reach_the_player() -> void:
	await spawn_nav_world(true)
	var player := await spawn_player(Vector3(0.0, 0.0, 6.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -6.0), player)
	zombie.attack_damage = 0.0
	var reach := zombie.attack_range + zombie.attack_exit_margin
	for _i: int in 15:
		await run_seconds(1.0)
		if _flat_distance(zombie, player) <= reach:
			break
	assert_true(_flat_distance(zombie, player) <= reach, "zombie reached the player, distance %s" % _flat_distance(zombie, player))


func test_zombie_in_range_hits_once_per_interval_and_not_before_the_first() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -1.0), player)
	zombie.attack_interval = 0.5
	var health := Health.find_on(player)
	await run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health, 0.001, "no hit before the first interval")
	await run_seconds(zombie.attack_interval * 0.5 + FRAME_MARGIN / 60.0)
	assert_almost_eq(health.current, health.max_health - zombie.attack_damage, 0.001, "one hit after the first interval")
	await run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health - zombie.attack_damage, 0.001, "still one hit half an interval later")
	await run_seconds(zombie.attack_interval * 0.5)
	assert_almost_eq(health.current, health.max_health - 2.0 * zombie.attack_damage, 0.001, "two hits after two intervals")


func test_zombie_out_of_range_does_no_damage() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3.ZERO, player)
	zombie.position.z = -(zombie.attack_range + 2.0)
	zombie.move_speed = 0.0
	zombie.attack_interval = 0.3
	await run_seconds(zombie.attack_interval * 3.0)
	var health := Health.find_on(player)
	assert_almost_eq(health.current, health.max_health, 0.001, "player is unharmed")


func test_enough_pistol_shots_kill_the_zombie_and_remove_it() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	await physics_frames(3)
	var shots := ceili(Health.find_on(zombie).max_health / PISTOL.damage)
	for _i: int in shots:
		assert_true(weapon.try_fire(), "shot fires")
		await run_seconds(PISTOL.fire_interval + FRAME_MARGIN / 60.0)
	await physics_frames(2)
	assert_true(zombie.is_dead(), "zombie is dead")
	await run_seconds(zombie.animator.death_length() + FRAME_MARGIN / 60.0)
	assert_true(not is_instance_valid(zombie) or not zombie.is_inside_tree(), "zombie left the tree after its death animation")


func test_fewer_pistol_shots_leave_the_zombie_alive() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 0.0), null)
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	await physics_frames(3)
	var health := Health.find_on(zombie)
	var shots := ceili(health.max_health / PISTOL.damage) - 1
	for _i: int in shots:
		assert_true(weapon.try_fire(), "shot fires")
		await run_seconds(PISTOL.fire_interval + FRAME_MARGIN / 60.0)
	assert_true(zombie.is_inside_tree(), "zombie still in the tree")
	assert_almost_eq(health.current, health.max_health - shots * PISTOL.damage, 0.001, "zombie lost damage per shot")


func test_headshot_deals_multiplied_damage_and_a_body_shot_deals_base_damage() -> void:
	var zombie := _tall_zombie()
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	var health := Health.find_on(zombie)
	var reports: Array[bool] = []
	weapon.damaged.connect(func(_target: Node, _killed: bool, headshot: bool) -> void: reports.append(headshot))
	await physics_frames(FRAME_MARGIN)
	_aim_at(weapon, zombie.global_position + Vector3(0.0, 0.7, 0.0))
	assert_true(weapon.try_fire(), "body shot fires")
	assert_almost_eq(health.current, health.max_health - PISTOL.damage, 0.001, "a body shot takes base damage")
	await run_seconds(PISTOL.fire_interval + FRAME_MARGIN / 60.0)
	_aim_at(weapon, zombie.weak_spot.global_position)
	var before := health.current
	assert_true(weapon.try_fire(), "head shot fires")
	assert_almost_eq(health.current, before - PISTOL.damage * zombie.weak_spot.damage_multiplier, 0.001, "a headshot takes multiplied damage")
	assert_eq(reports, [false, true] as Array[bool], "only the second shot is a headshot")


func test_runner_closes_in_faster_than_a_walker() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var walker := spawn_zombie(Vector3(-5.0, 0.0, -20.0), player)
	var runner := spawn_zombie(Vector3(5.0, 0.0, -20.0), player, Zombie.Gait.RUN)
	var walker_start := _flat_distance(walker, player)
	var runner_start := _flat_distance(runner, player)
	var seconds := 2.0
	await run_seconds(seconds)
	var walker_speed := (walker_start - _flat_distance(walker, player)) / seconds
	var runner_speed := (runner_start - _flat_distance(runner, player)) / seconds
	assert_true(runner_speed > ROUND_SETTINGS.runner_speed * 0.8 and runner_speed < ROUND_SETTINGS.runner_speed * 1.05,
		"runner moves at %s m/s, settings say %s m/s" % [runner_speed, ROUND_SETTINGS.runner_speed])
	assert_true(runner_speed > walker_speed * 1.5, "runner %s m/s, walker %s m/s" % [runner_speed, walker_speed])


func test_runner_wears_a_red_shirt_and_grey_pants_and_a_walker_does_not() -> void:
	var walker := spawn_zombie(Vector3.ZERO)
	var runner := spawn_zombie(Vector3(3.0, 0.0, 0.0), null, Zombie.Gait.RUN)
	await physics_frames(1)
	var worn_shirt := runner.body_material("ShamblerShirt").albedo_color
	assert_true(worn_shirt.r > worn_shirt.g * 2.0 and worn_shirt.r > worn_shirt.b * 2.0, "runner shirt is red, %s" % worn_shirt)
	var worn_pants := runner.body_material("ShamblerPants").albedo_color
	assert_true(absf(worn_pants.r - worn_pants.g) < 0.05 and absf(worn_pants.g - worn_pants.b) < 0.1, "runner pants are grey, %s" % worn_pants)
	var shirt := walker.body_material("ShamblerShirt").albedo_color
	assert_true(shirt.r < shirt.g * 2.0, "walker shirt is not red, %s" % shirt)
	assert_true(runner.body_material("ShamblerSkin").albedo_color.is_equal_approx(walker.body_material("ShamblerSkin").albedo_color), "the skin is the same")


func test_a_strong_shot_to_the_legs_makes_the_zombie_crawl_slowly() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3.ZERO, 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0), player)
	var weapon := _spawn_weapon(Vector3(3.0, 1.0, -10.0), RIFLE)
	await physics_frames(FRAME_MARGIN)
	assert_true(RIFLE.damage >= zombie.leg_loss_damage, "the rifle is strong enough to take the legs")
	_aim_at(weapon, zombie.global_position + Vector3(0.0, 0.3, 0.0))
	assert_true(weapon.try_fire(), "leg shot fires")
	assert_true(not zombie.is_dead(), "a round 1 zombie lives through one rifle shot")
	assert_eq(zombie.gait, Zombie.Gait.CRAWL, "gait after the leg shot")
	await physics_frames(FRAME_MARGIN)
	assert_true(not zombie.animator.has_legs(), "the legs are gone")
	var start := _flat_distance(zombie, player)
	var seconds := 2.0
	await run_seconds(seconds)
	var speed := (start - _flat_distance(zombie, player)) / seconds
	assert_true(speed > ROUND_SETTINGS.crawl_speed * 0.7 and speed < ROUND_SETTINGS.crawl_speed * 1.05,
		"crawler moves at %s m/s, settings say %s m/s" % [speed, ROUND_SETTINGS.crawl_speed])


func test_a_shot_at_chest_height_goes_over_a_crawler() -> void:
	var zombie := _tall_zombie()
	var health := Health.find_on(zombie)
	var weapon := _spawn_weapon(Vector3(0.0, 1.2, 5.0))
	await physics_frames(FRAME_MARGIN)
	_aim_at(weapon, zombie.global_position + Vector3(0.0, 1.2, 0.0))
	assert_true(weapon.try_fire(), "chest shot at a standing zombie fires")
	assert_almost_eq(health.current, health.max_health - PISTOL.damage, 0.001, "the chest shot hits a standing zombie")
	health.damage_at(zombie.leg_loss_damage, zombie.global_position)
	await run_seconds(1.0)
	var before := health.current
	await run_seconds(PISTOL.fire_interval)
	assert_true(weapon.try_fire(), "chest shot at the crawler fires")
	assert_almost_eq(health.current, before, 0.001, "the chest shot goes over the crawler")


func test_a_weak_shot_to_the_legs_or_a_strong_shot_to_the_body_leaves_the_legs() -> void:
	var zombie := _tall_zombie()
	var pistol := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	var rifle := _spawn_weapon(Vector3(2.0, 1.0, 5.0), RIFLE)
	await physics_frames(FRAME_MARGIN)
	assert_true(PISTOL.damage < zombie.leg_loss_damage, "the pistol is too weak to take the legs")
	_aim_at(pistol, zombie.global_position + Vector3(0.0, 0.3, 0.0))
	assert_true(pistol.try_fire(), "pistol leg shot fires")
	_aim_at(rifle, zombie.global_position + Vector3(0.0, 1.0, 0.0))
	assert_true(rifle.try_fire(), "rifle body shot fires")
	await physics_frames(FRAME_MARGIN)
	assert_eq(zombie.gait, Zombie.Gait.WALK, "gait")
	assert_true(zombie.animator.has_legs(), "the legs are on")


func test_a_crawler_dies_on_its_front_and_goes() -> void:
	var zombie := spawn_zombie(Vector3.ZERO)
	var health := Health.find_on(zombie)
	health.damage_at(zombie.leg_loss_damage, zombie.global_position)
	await run_seconds(1.0)
	health.damage(health.current)
	var animator := zombie.animator as ZombieAnimator
	await run_seconds(animator.fall_time + animator.bounce_time)
	assert_almost_eq(animator.fall_tilt(), 0.0, 0.01, "the crawler does not fall back")
	assert_true(not zombie.animator.has_legs(), "the dead crawler has no legs")
	await run_seconds(zombie.animator.death_length() + FRAME_MARGIN / 60.0)
	assert_true(not is_instance_valid(zombie) or not zombie.is_inside_tree(), "the crawler left the tree after its death")


func test_the_head_shape_follows_the_animated_head() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -20.0), player)
	var height := await sample_range(func() -> float: return zombie.weak_spot.global_position.y - zombie.global_position.y, 1.0)
	assert_true(height.y - height.x > 0.01, "the head shape moves with the walk bob, range %s" % (height.y - height.x))


func test_a_walking_zombie_still_takes_a_headshot() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 10.0), 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0), player)
	var health := Health.find_on(zombie)
	health.max_health = 10000.0
	health.reset()
	await run_seconds(1.0)
	var reports: Array[bool] = []
	var weapon := _spawn_weapon(Vector3(0.0, 1.6, 8.0))
	weapon.damaged.connect(func(_target: Node, _killed: bool, headshot: bool) -> void: reports.append(headshot))
	_aim_at(weapon, zombie.weak_spot.global_position)
	assert_true(zombie.velocity.length() > 0.1, "the zombie moves")
	assert_true(weapon.try_fire(), "shot fires")
	assert_eq(reports, [true] as Array[bool], "the shot at the head of a walking zombie is a headshot")


func test_a_dead_zombie_takes_no_shot_at_its_head() -> void:
	var zombie := _tall_zombie()
	var weapon := _spawn_weapon(Vector3(0.0, 1.0, 5.0))
	var health := Health.find_on(zombie)
	await physics_frames(FRAME_MARGIN)
	var aim_point := zombie.weak_spot.global_position
	health.damage(health.max_health)
	await physics_frames(FRAME_MARGIN)
	var hits := [0]
	weapon.hit.connect(func(_collider: Object, _point: Vector3) -> void: hits[0] += 1)
	_aim_at(weapon, aim_point)
	weapon.try_fire()
	assert_eq(hits[0], 0, "the shot goes through the corpse")


func test_zombie_ignores_a_dead_player() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3(0.0, 0.0, 0.0), 3)
	Health.find_on(player).damage(1000000.0)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -6.0), player)
	zombie.attack_interval = 0.3
	var start := zombie.global_position
	await run_seconds(1.5)
	assert_almost_eq(zombie.global_position.distance_to(start), 0.0, 0.05, "zombie stays where it is")


func _spawn_weapon(at: Vector3, data: WeaponData = PISTOL) -> Weapon:
	var weapon := WEAPON_SCENE.instantiate() as Weapon
	weapon.data = data
	weapon.position = at
	add_child(weapon)
	return weapon


func _tall_zombie() -> Zombie:
	var zombie := spawn_zombie(Vector3.ZERO)
	var health := Health.find_on(zombie)
	health.max_health = 10000.0
	health.reset()
	return zombie


func _aim_at(weapon: Weapon, point: Vector3) -> void:
	weapon.look_at(point)


func _flat_distance(a: Node3D, b: Node3D) -> float:
	var offset := a.global_position - b.global_position
	offset.y = 0.0
	return offset.length()
