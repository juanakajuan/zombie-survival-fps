extends TestCase

const WEAPON_SCENE: PackedScene = preload("res://weapons/weapon.tscn")
const RIFLE: WeaponData = preload("res://weapons/rifle.tres")
const PISTOL: WeaponData = preload("res://weapons/pistol.tres")


func test_the_rifle_fires_once_for_each_press_of_fire() -> void:
	var player := await spawn_player()
	var rifle := player.give_weapon(RIFLE)
	await run_seconds(1.0)
	Input.action_press("fire")
	await run_seconds(1.0)
	Input.action_release("fire")
	assert_eq(rifle.ammo, RIFLE.magazine_size - 1, "a held press fired one shot")


func test_the_rifle_kills_a_round_1_zombie_in_fewer_body_shots_than_the_pistol() -> void:
	await spawn_nav_world()
	var zombie := spawn_zombie(Vector3.ZERO)
	var weapon := WEAPON_SCENE.instantiate() as Weapon
	weapon.data = RIFLE
	weapon.position = Vector3(0.0, 1.0, 5.0)
	add_child(weapon)
	await physics_frames(3)
	var max_health := Health.find_on(zombie).max_health
	var shots := ceili(max_health / RIFLE.damage)
	assert_true(shots < ceili(max_health / PISTOL.damage), "the rifle needs fewer shots than the pistol")
	for _i: int in shots:
		assert_true(weapon.try_fire(), "the shot fires")
		await run_seconds(RIFLE.fire_interval + 2.0 / Engine.physics_ticks_per_second)
	assert_true(zombie.is_dead(), "the zombie is dead after %d rifle shots" % shots)
