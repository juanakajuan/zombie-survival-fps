extends TestCase

const POWER_SWITCH_SCENE := preload("res://perks/power_switch.tscn")
const IRON_GUT := preload("res://perks/iron_gut.tres")
const QUICK_HANDS := preload("res://perks/quick_hands.tres")
const HAIR_TRIGGER := preload("res://perks/hair_trigger.tres")
const ROOM := Rect2(12.0, 12.0, 8.0, 8.0)


func test_a_machine_with_no_power_does_not_sell() -> void:
	var player := await spawn_player()
	var power := _spawn_switch(Vector3(3.0, 0.0, 0.0))
	var machine := _spawn_machine(IRON_GUT, power)
	player.wallet.add(IRON_GUT.cost)
	assert_eq(machine.prompt_text(player), "NEEDS POWER", "prompt")
	assert_true(not machine.buy(player), "the purchase fails")
	assert_eq(player.wallet.points, IRON_GUT.cost, "no points spent")
	assert_true(player.perks.held.is_empty(), "no perk held")


func test_the_player_turns_on_the_power_and_the_machine_sells() -> void:
	var player := await spawn_player(Vector3.ZERO, 5)
	var power := _spawn_switch(Vector3(0.0, 0.0, -2.0))
	var machine := _spawn_machine(IRON_GUT, power)
	player.wallet.add(IRON_GUT.cost + 10)
	look_at_point(player, power.global_position + Vector3.UP * 0.9)
	await physics_frames(2)
	assert_eq(player.hud.readout().prompt_text, "E  TURN ON POWER", "the switch prompt")
	Input.action_press("interact")
	await physics_frames(2)
	assert_true(power.is_on(), "the power is on")
	assert_true(not player.hud.readout().prompt_visible, "an on switch shows no prompt")
	assert_eq(machine.prompt_text(player), "E  BUY IRON GUT  %d" % IRON_GUT.cost, "machine prompt with power")
	assert_true(machine.buy(player), "the purchase succeeds")
	assert_eq(player.wallet.points, 10, "points after the cost")
	assert_eq(player.hud.readout().perk_icons, PackedStringArray([IRON_GUT.icon_text]), "the HUD shows the perk icon")


func test_the_power_turns_on_once() -> void:
	var power := _spawn_switch(Vector3.ZERO)
	var count := [0]
	power.turned_on.connect(func() -> void: count[0] += 1)
	power.turn_on()
	power.turn_on()
	assert_eq(count[0], 1, "turned_on signals")


func test_more_health_raises_max_health_and_health() -> void:
	var player := await spawn_player()
	var start_max := player.health.max_health
	player.health.damage(20.0)
	_buy(player, IRON_GUT)
	assert_almost_eq(player.health.max_health, start_max + IRON_GUT.max_health_bonus, 0.001, "max health")
	assert_almost_eq(player.health.current, start_max - 20.0 + IRON_GUT.max_health_bonus, 0.001, "health")
	var readout := player.hud.readout()
	assert_eq(readout.health_text, str(ceili(player.health.current)), "HUD health")


func test_fast_reload_finishes_the_reload_sooner() -> void:
	var player := await spawn_player()
	_buy(player, QUICK_HANDS)
	var weapon := player.weapon
	var reload_time := weapon.data.reload_time * QUICK_HANDS.reload_time_scale
	weapon.ammo = 0
	weapon.start_reload()
	await run_seconds(reload_time - 0.1)
	assert_true(weapon.is_reloading(), "still reloading just before the shorter time")
	await run_seconds(0.15)
	assert_true(not weapon.is_reloading(), "the reload ended before the base time of %.2f s" % weapon.data.reload_time)
	assert_eq(weapon.ammo, weapon.data.magazine_size, "the magazine is full")


func test_fast_fire_fires_again_sooner() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	assert_true(weapon.try_fire(), "the first shot")
	var interval := weapon.data.fire_interval * HAIR_TRIGGER.fire_interval_scale
	await run_seconds(interval + 2.0 / 60.0)
	assert_true(not weapon.try_fire(), "with no perk, the weapon is still cooling down")
	_buy(player, HAIR_TRIGGER)
	await run_seconds(weapon.data.fire_interval)
	assert_true(weapon.try_fire(), "the second shot")
	await run_seconds(interval + 2.0 / 60.0)
	assert_true(weapon.try_fire(), "with the perk, the weapon fires again after the shorter interval")


func test_the_player_cannot_hold_more_than_the_limit_or_the_same_perk_twice() -> void:
	var player := await spawn_player()
	player.perks.max_held = 2
	_buy(player, IRON_GUT)
	var iron_gut_again := _spawn_machine(IRON_GUT, null)
	player.wallet.add(IRON_GUT.cost)
	assert_true(not iron_gut_again.buy(player), "a held perk does not sell again")
	_buy(player, QUICK_HANDS)
	var third := _spawn_machine(HAIR_TRIGGER, null)
	player.wallet.add(HAIR_TRIGGER.cost)
	assert_true(not third.buy(player), "a perk over the limit does not sell")
	assert_eq(player.wallet.points, IRON_GUT.cost + HAIR_TRIGGER.cost, "the refused purchases cost nothing")
	assert_eq(player.hud.readout().perk_icons, PackedStringArray([IRON_GUT.icon_text, QUICK_HANDS.icon_text]), "HUD icons")


func test_the_test_range_power_switch_is_behind_the_room_door_and_powers_every_perk_machine() -> void:
	var level := await spawn_level()
	var power := level.get_node("PowerSwitch") as PowerSwitch
	assert_true(ROOM.has_point(Vector2(power.global_position.x, power.global_position.z)), "the switch is in the room")
	var machines: Array[BuyStation] = stations_in(level).filter(func(station: BuyStation) -> bool: return station.item is PerkItem)
	assert_eq(machines.size(), 3, "perk machines")
	for machine: BuyStation in machines:
		assert_true(machine.power == power, "%s needs the switch" % machine.name)
		assert_true(not machine.has_power(), "%s has no power at the start" % machine.name)
	power.turn_on()
	for machine: BuyStation in machines:
		assert_true(machine.has_power(), "%s has power" % machine.name)


func _spawn_switch(at: Vector3) -> PowerSwitch:
	var power := POWER_SWITCH_SCENE.instantiate() as PowerSwitch
	power.position = at
	add_child(power)
	return power


func _spawn_machine(item: PerkItem, power: PowerSwitch) -> BuyStation:
	var machine := STATION_SCENE.instantiate() as BuyStation
	machine.item = item
	machine.power = power
	machine.position = Vector3(-3.0, 0.0, 0.0)
	add_child(machine)
	return machine


func _buy(player: Player, item: PerkItem) -> void:
	player.wallet.add(item.cost)
	assert_true(_spawn_machine(item, null).buy(player), "bought %s" % item.display_name)
