extends TestCase

const SMG_ITEM: WeaponItem = preload("res://economy/smg_item.tres")


func test_buying_the_weapon_charges_the_cost_and_equips_it() -> void:
	var player := await spawn_player()
	var station := _smg_station()
	player.wallet.add(SMG_ITEM.cost + 5)
	assert_eq(station.prompt_text(player), "E  BUY SMG  %d" % SMG_ITEM.cost, "prompt before the purchase")
	assert_true(station.buy(player), "the purchase works")
	assert_eq(player.wallet.points, 5, "the cost was spent")
	assert_eq(player.weapon.data, SMG_ITEM.weapon, "the SMG is in hand")
	assert_eq(player.hud.readout().weapon_name, "SMG", "HUD name")


func test_too_few_points_buy_no_weapon() -> void:
	var player := await spawn_player()
	var station := _smg_station()
	player.wallet.add(SMG_ITEM.cost - 1)
	assert_true(not station.buy(player), "the purchase fails")
	assert_eq(player.weapons.size(), 1, "no weapon was added")
	assert_eq(player.wallet.points, SMG_ITEM.cost - 1, "no points spent")


func test_a_second_purchase_sells_ammo_for_the_ammo_cost() -> void:
	var player := await spawn_player()
	var station := _smg_station()
	player.wallet.add(SMG_ITEM.cost + SMG_ITEM.ammo_cost)
	station.buy(player)
	var smg := player.weapon
	smg.reserve = 10
	assert_eq(station.prompt_text(player), "E  BUY SMG AMMO  %d" % SMG_ITEM.ammo_cost, "prompt once the SMG is held")
	assert_true(station.buy(player), "the ammo purchase works")
	assert_eq(player.wallet.points, 0, "the ammo cost was spent")
	assert_eq(smg.reserve, SMG_ITEM.weapon.max_reserve, "the SMG reserve is full")
	assert_eq(player.weapons.size(), 2, "no second SMG")


func test_ammo_goes_to_the_smg_when_the_pistol_is_in_hand() -> void:
	var player := await spawn_player()
	var station := _smg_station()
	player.wallet.add(SMG_ITEM.cost + SMG_ITEM.ammo_cost)
	station.buy(player)
	var smg := player.weapon
	smg.reserve = 0
	press_action(&"weapon_1")
	var pistol_reserve := player.weapon.reserve
	assert_true(station.buy(player), "the ammo purchase works")
	assert_eq(smg.reserve, SMG_ITEM.weapon.max_reserve, "the SMG reserve is full")
	assert_eq(player.weapon.reserve, pistol_reserve, "the pistol reserve is unchanged")


func test_a_full_smg_reserve_charges_nothing() -> void:
	var player := await spawn_player()
	var station := _smg_station()
	player.wallet.add(SMG_ITEM.cost + SMG_ITEM.ammo_cost)
	station.buy(player)
	assert_true(not station.buy(player), "nothing to buy")
	assert_eq(player.wallet.points, SMG_ITEM.ammo_cost, "no points spent")


func _smg_station() -> BuyStation:
	var station := spawn_station(Vector3(0.0, 0.0, -2.0))
	station.item = SMG_ITEM
	return station
