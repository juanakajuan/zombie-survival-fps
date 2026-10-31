extends TestCase

const SHOTGUN: WeaponData = preload("res://weapons/shotgun.tres")


func test_a_shot_sends_one_ray_for_each_pellet_inside_the_spread() -> void:
	var player := await spawn_player()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 40.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 0.0, -10.0)
	add_child(wall)
	var shotgun := player.give_weapon(SHOTGUN)
	await run_seconds(1.0)
	var points: Array[Vector3] = []
	shotgun.hit.connect(func(_collider: Object, point: Vector3) -> void: points.append(point))
	var aim := player.aim_transform()
	assert_true(shotgun.try_fire(), "the shot fires")
	assert_eq(points.size(), SHOTGUN.pellets, "rays that hit the wall")
	var directions: Array[Vector3] = []
	for point: Vector3 in points:
		var direction := (point - aim.origin).normalized()
		assert_true(rad_to_deg(direction.angle_to(-aim.basis.z)) <= SHOTGUN.spread + 0.01, "a ray is inside the spread")
		directions.append(direction)
	assert_true(directions.any(func(other: Vector3) -> bool: return not other.is_equal_approx(directions[0])), "the rays spread out")
	assert_eq(shotgun.ammo, SHOTGUN.magazine_size - 1, "the shot used one shell")


func test_each_pellet_that_hits_a_living_zombie_damages_it_and_pays_points() -> void:
	var player := await spawn_player()
	var data := SHOTGUN.duplicate() as WeaponData
	data.damage = 1.0
	var shotgun := player.give_weapon(data)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -3.0))
	await run_seconds(1.0)
	var health := Health.find_on(zombie)
	var hits: Array[int] = [0, 0]
	shotgun.damaged.connect(func(_target: Node, _killed: bool, headshot: bool) -> void: hits[1 if headshot else 0] += 1)
	shotgun.try_fire()
	var count := hits[0] + hits[1]
	assert_true(count >= 2, "more than one pellet hit, got %d" % count)
	var expected := hits[0] * data.damage + hits[1] * data.damage * zombie.weak_spot.damage_multiplier
	assert_almost_eq(health.max_health - health.current, expected, 0.001, "each pellet dealt its damage")
	assert_eq(player.wallet.points, count * player.wallet.points_per_hit, "each pellet paid the hit points")


func test_the_upgraded_shotgun_sends_more_pellets_with_more_damage_and_ammo() -> void:
	var player := await spawn_player()
	player.give_weapon(SHOTGUN)
	player.upgrade_weapon()
	var upgraded := player.weapon.data
	assert_true(upgraded == SHOTGUN.upgrade, "the upgraded shotgun is in hand")
	assert_true(upgraded.pellets > SHOTGUN.pellets, "more pellets")
	assert_true(upgraded.damage > SHOTGUN.damage, "more damage for each pellet")
	assert_true(upgraded.magazine_size > SHOTGUN.magazine_size, "a larger magazine")
	assert_true(upgraded.max_reserve > SHOTGUN.max_reserve, "a larger reserve")
	assert_true(upgraded.upgrade == null, "the upgraded shotgun cannot be upgraded again")
