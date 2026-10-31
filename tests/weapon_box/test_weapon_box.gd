extends TestCase

const BOX_SCENE: PackedScene = preload("res://weapon_box/weapon_box.tscn")
const SMG_ITEM: WeaponItem = preload("res://economy/smg_item.tres")


func test_a_use_costs_the_price_and_offers_a_weapon_from_the_table() -> void:
	var player := await spawn_player()
	var box := _spawn_box(0.0)
	player.wallet.add(box.cost + 5)
	assert_eq(box.prompt_text(player), "E  WEAPON BOX  %d" % box.cost, "prompt before a use")
	assert_true(box.use(player), "the use works")
	assert_eq(player.wallet.points, 5, "the cost was spent")
	assert_true(box.offer() != null, "a weapon is over the box")
	assert_true(_table_items(box).has(box.offer()), "the weapon is from the table")
	assert_eq(box.offer_text(), box.offer().display_name, "the weapon name shows over the box")
	assert_eq(box.prompt_text(player), "E  TAKE %s" % box.offer().display_name, "prompt while a weapon is offered")


func test_the_player_takes_the_offered_weapon_with_interact() -> void:
	var player := await spawn_player()
	var box := _spawn_box(0.0)
	player.wallet.add(box.cost)
	box.use(player)
	var offered := box.offer()
	box.press(player)
	assert_eq(player.weapon.data, offered.weapon, "the offered weapon is in hand")
	assert_eq(player.weapons.size(), 2, "the pistol is still held")
	assert_eq(box.offer_text(), "", "nothing is over the box")


func test_the_box_never_gives_a_weapon_the_player_holds() -> void:
	var player := await spawn_player()
	var box := _spawn_box(0.0)
	box.offer_time = 1.0
	for _i: int in 10:
		player.wallet.add(box.cost)
		assert_true(box.use(player), "the use works")
		assert_eq(box.offer(), SMG_ITEM, "the pistol is held, so the box offers the SMG")
		await run_seconds(box.offer_time + 0.1)


func test_a_box_with_no_new_weapon_takes_no_points() -> void:
	var player := await spawn_player()
	var box := _spawn_box(0.0)
	player.give_weapon(SMG_ITEM.weapon)
	player.wallet.add(box.cost)
	assert_eq(box.prompt_text(player), "NO NEW WEAPONS", "prompt")
	assert_true(not box.use(player), "the use fails")
	assert_eq(player.wallet.points, box.cost, "no points spent")


func test_too_few_points_roll_nothing() -> void:
	var player := await spawn_player()
	var box := _spawn_box(0.0)
	player.wallet.add(box.cost - 1)
	assert_true(not box.use(player), "the use fails")
	assert_true(box.offer() == null, "no weapon is over the box")


func test_an_offer_that_is_not_taken_goes_away() -> void:
	var player := await spawn_player()
	var box := _spawn_box(0.0)
	box.offer_time = 1.0
	player.wallet.add(box.cost)
	box.use(player)
	await run_seconds(1.1)
	assert_true(box.offer() == null, "the offer is gone")
	assert_eq(player.weapons.size(), 1, "no weapon was given")
	assert_eq(player.wallet.points, 0, "the points are not given back")


func test_the_box_moves_and_refunds_after_its_safe_uses() -> void:
	var player := await spawn_player()
	var box := _spawn_box(1.0)
	box.safe_uses = 1
	var start := _place(Vector3(0.0, 0.0, -2.0))
	var other := _place(Vector3(10.0, 0.0, -2.0))
	box.places = [start, other]
	var moves: Array[int] = [0]
	box.moved.connect(func() -> void: moves[0] += 1)
	player.wallet.add(box.cost)
	box.use(player)
	assert_true(box.offer() != null, "the safe use gives a weapon")
	box.take(player)
	player.give_weapon(preload("res://weapons/pistol.tres"))
	player.wallet.add(box.cost)
	assert_true(box.use(player), "the use works")
	assert_true(box.offer() == null, "a move gives no weapon")
	assert_eq(player.wallet.points, box.cost, "the points came back")
	assert_eq(box.global_position, other.global_position, "the box is at the other place")
	assert_eq(moves[0], 1, "moved was emitted once")


func test_the_test_range_box_stands_at_one_of_its_places() -> void:
	var level := await spawn_level()
	var box := level.get_node("WeaponBox") as WeaponBox
	assert_true(box.places.size() > 1, "the box has more than one place")
	var at_place := box.places.any(func(place: Node3D) -> bool: return place.global_position.is_equal_approx(box.global_position))
	assert_true(at_place, "the box starts at one of its places")


func _spawn_box(move_chance: float) -> WeaponBox:
	var box := BOX_SCENE.instantiate() as WeaponBox
	box.move_chance = move_chance
	box.position = Vector3(0.0, 0.0, -2.0)
	add_child(box)
	return box


func _place(at: Vector3) -> Marker3D:
	var place := Marker3D.new()
	place.position = at
	add_child(place)
	return place


func _table_items(box: WeaponBox) -> Array[WeaponItem]:
	var items: Array[WeaponItem] = []
	for entry: WeaponBoxEntry in box.table.entries:
		items.append(entry.item)
	return items
