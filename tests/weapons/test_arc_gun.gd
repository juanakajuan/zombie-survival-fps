extends TestCase

const ARC_GUN: WeaponData = preload("res://weapons/arc_gun.tres")
const BOX_TABLE: WeaponBoxTable = preload("res://weapon_box/weapon_box_table.tres")
const COMPOUND_SCENE: PackedScene = preload("res://levels/compound.tscn")


func test_the_arc_jumps_to_the_nearest_zombies_with_less_damage_each_jump() -> void:
	var player := await spawn_player()
	var data := ARC_GUN.duplicate() as WeaponData
	data.damage = 40.0
	var arc_gun := player.give_weapon(data)
	var first := spawn_zombie(Vector3(0.0, 0.0, -4.0))
	var second := spawn_zombie(Vector3(1.5, 0.0, -5.0))
	var third := spawn_zombie(Vector3(3.0, 0.0, -6.0))
	var far := spawn_zombie(Vector3(0.0, 0.0, -4.0 - data.chain_range * 3.0))
	await run_seconds(1.0)
	look_at_point(player, first.global_position + Vector3.UP * data.chain_aim_height)
	await physics_frames(1)
	assert_true(arc_gun.try_fire(), "the shot fires")
	var second_damage := data.damage * data.chain_damage_scale
	assert_almost_eq(_lost(first), data.damage, 0.001, "the first zombie took the full damage")
	assert_almost_eq(_lost(second), second_damage, 0.001, "the nearest zombie to it took the first jump")
	assert_almost_eq(_lost(third), second_damage * data.chain_damage_scale, 0.001, "the next zombie took the second jump")
	assert_almost_eq(_lost(far), 0.0, 0.001, "a zombie out of range took nothing")
	assert_eq(player.wallet.points, 3 * player.wallet.points_per_hit, "each zombie hit paid the hit points")


func test_the_arc_does_not_jump_through_a_wall() -> void:
	var player := await spawn_player()
	var arc_gun := player.give_weapon(ARC_GUN)
	var first := spawn_zombie(Vector3(0.0, 0.0, -4.0))
	var hidden := spawn_zombie(Vector3(3.0, 0.0, -4.0))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 4.0, 4.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(1.5, 2.0, -4.0)
	add_child(wall)
	await run_seconds(1.0)
	look_at_point(player, first.global_position + Vector3.UP * ARC_GUN.chain_aim_height)
	await physics_frames(1)
	arc_gun.try_fire()
	assert_true(_lost(first) > 0.0, "the first zombie was hit")
	assert_almost_eq(_lost(hidden), 0.0, 0.001, "the zombie behind the wall took nothing")


func test_the_upgraded_arc_gun_jumps_further_and_to_more_targets() -> void:
	var player := await spawn_player()
	player.give_weapon(ARC_GUN)
	player.upgrade_weapon()
	var upgraded := player.weapon.data
	assert_true(upgraded == ARC_GUN.upgrade, "the upgraded arc gun is in hand")
	assert_true(upgraded.chain_targets > ARC_GUN.chain_targets, "more jumps")
	assert_true(upgraded.chain_range > ARC_GUN.chain_range, "longer jumps")
	assert_true(upgraded.damage > ARC_GUN.damage, "more damage")
	assert_true(upgraded.magazine_size > ARC_GUN.magazine_size, "a larger magazine")
	assert_true(upgraded.upgrade == null, "the upgraded arc gun cannot be upgraded again")


func test_only_the_weapon_box_gives_the_arc_gun() -> void:
	assert_true(BOX_TABLE.entries.any(func(entry: WeaponBoxEntry) -> bool: return entry.item.weapon == ARC_GUN), "the box can roll it")
	for scene: PackedScene in [LEVEL_SCENE, COMPOUND_SCENE]:
		var level := await spawn_level(null, scene)
		assert_true(not sells_weapon(level, ARC_GUN.display_name), "no station in %s sells it" % level.name)
		level.queue_free()
		await physics_frames(1)


func _lost(zombie: Zombie) -> float:
	var health := Health.find_on(zombie)
	return health.max_health - health.current
