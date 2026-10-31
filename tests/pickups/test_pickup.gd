extends TestCase

const MAX_AMMO: BuyItem = preload("res://pickups/max_ammo.tres")
const SMG_ITEM: WeaponItem = preload("res://economy/smg_item.tres")
const FAR := Vector3(10.0, 0.0, 0.0)


func test_walking_over_max_ammo_fills_the_reserve_of_every_held_weapon() -> void:
	var player := await spawn_player()
	SMG_ITEM.apply(player)
	for held: Weapon in player.weapons:
		held.reserve = 3
	var pickup := spawn_pickup(MAX_AMMO, Vector3.ZERO)
	await physics_frames(3)
	for held: Weapon in player.weapons:
		assert_eq(held.reserve, held.data.max_reserve, "%s reserve" % held.data.display_name)
	assert_true(not is_instance_valid(pickup), "the pickup is gone")


func test_a_pickup_that_would_do_nothing_stays_on_the_ground() -> void:
	var player := await spawn_player()
	var pickup := spawn_pickup(MAX_AMMO, Vector3.ZERO)
	await physics_frames(5)
	assert_true(is_instance_valid(pickup), "the max ammo pickup stays with full reserves")
	player.weapon.reserve = 1
	await physics_frames(3)
	assert_true(not is_instance_valid(pickup), "the max ammo pickup is taken once the reserve is low")


func test_a_pickup_far_from_the_player_is_not_taken() -> void:
	var player := await spawn_player()
	player.weapon.reserve = 1
	var pickup := spawn_pickup(MAX_AMMO, FAR)
	await physics_frames(5)
	assert_true(is_instance_valid(pickup), "the pickup stays")
	assert_eq(player.weapon.reserve, 1, "reserve")


func test_a_pickup_with_a_lifetime_expires_and_one_without_stays() -> void:
	var timed := spawn_pickup(MAX_AMMO, FAR, 1.0)
	var lasting := spawn_pickup(MAX_AMMO, FAR + Vector3.RIGHT * 3.0)
	await run_seconds(0.8)
	assert_true(is_instance_valid(timed), "the timed pickup stays before its lifetime ends")
	await run_seconds(0.5)
	assert_true(not is_instance_valid(timed), "the timed pickup is gone after its lifetime")
	await run_seconds(3.0)
	assert_true(is_instance_valid(lasting), "the pickup with lifetime 0 stays")


func test_the_pickup_shows_the_item_name() -> void:
	var pickup := spawn_pickup(MAX_AMMO, FAR)
	await physics_frames(1)
	assert_eq(pickup.label_text(), "MAX AMMO", "label")
