extends TestCase


func test_perks() -> void:
	var none: Perks = Perks.new()
	var smg: WeaponDef = Arsenal.smg()
	ok([Rules.max_health(none), Rules.regen_delay(none), Rules.regen_rate(none), Rules.fire_interval(smg, none), Rules.reload_seconds(smg, none), Rules.switch_seconds(none)] == [100.0, 4.0, 50.0, 0.075, 2.0, 0.5], "With no perks the lookups give the base numbers")
	var tough: Perks = Perks.new()
	tough.grant(Perks.Kind.TOUGH)
	var mender: Perks = Perks.new()
	mender.grant(Perks.Kind.MENDER)
	var rapid: Perks = Perks.new()
	rapid.grant(Perks.Kind.RAPID)
	var quick: Perks = Perks.new()
	quick.grant(Perks.Kind.QUICK_HANDS)
	ok(Rules.max_health(tough) == 160.0 and Rules.regen_delay(tough) == 4.0 and Rules.fire_interval(smg, tough) == 0.075, "Tough changes the maximum health and nothing else")
	ok(Rules.regen_delay(mender) == 1.5 and Rules.regen_rate(mender) == 100.0 and Rules.max_health(mender) == 100.0, "Mender changes the regeneration delay and rate")
	ok(is_equal_approx(Rules.fire_interval(smg, rapid), 0.05625) and Rules.reload_seconds(smg, rapid) == 2.0, "Rapid cuts the SMG fire interval to 0.05625 s and leaves the reload")
	ok(Rules.reload_seconds(smg, quick) == 1.0 and Rules.switch_seconds(quick) == 0.25 and Rules.fire_interval(smg, quick) == 0.075, "Quick Hands halves the reload and the change")
	var granted: Array[int] = []
	none.granted.connect(func(kind: Perks.Kind) -> void: granted.append(kind))
	none.grant(Perks.Kind.RAPID)
	none.grant(Perks.Kind.RAPID)
	ok(none.owned == [Perks.Kind.RAPID] and granted == [Perks.Kind.RAPID], "A second grant of one perk adds nothing and emits no signal")
	var pistol: WeaponDef = Arsenal.pistol()
	var upgraded: WeaponDef = Arsenal.upgrade(pistol)
	ok("%s %s %.1f %d %d %d" % [upgraded.id, upgraded.display_name, upgraded.damage, upgraded.magazine_size, upgraded.reserve_max, upgraded.tier] == "pistol Upgraded Pistol 70.0 12 120 1" and pistol.damage == 35.0 and pistol.tier == 0, "The upgrade makes the pistol 70 damage, 12 and 120 rounds, tier 1, with the same id, and leaves the argument alone")
	var shotgun: WeaponDef = Arsenal.upgrade(Arsenal.shotgun())
	ok(shotgun.magazine_size == 9 and shotgun.reserve_max == 63 and shotgun.pellets == 8, "The upgrade makes the shotgun 9 and 63 rounds with 8 pellets")
	var loadout: Loadout = Loadout.new(Arsenal.pistol())
	loadout.current().magazine = 3
	loadout.current().upgrade()
	ok(slot_text(loadout.current()) == "pistol 12/120" and loadout.find(&"pistol").def.tier == 1, "Slot.upgrade() fills the slot at the new sizes and find() still finds it")
	loadout.give(Arsenal.pistol())
	ok(loadout.current().def.tier == 1, "give() of a weapon that the player has keeps its upgrade")
	var machine: PerkMachine = PerkMachine.new()
	machine.perk = Perks.Kind.TOUGH
	machine.price = 3000
	machine.powered = true
	var owned: Perks = Perks.new()
	ok(offer_text(machine.offer(loadout, owned)) == "PERK 3000 \"Buy Tough\" -", "A perk machine offers the perk for its price")
	owned.grant(Perks.Kind.TOUGH)
	ok(offer_text(machine.offer(loadout, owned)) == "NONE 0 \"Tough owned\" -", "A perk machine of an owned perk offers nothing and says so")
	var press: UpgradeMachine = UpgradeMachine.new()
	press.powered = true
	ok(offer_text(press.offer(loadout, owned)) == "NONE 0 \"Already upgraded\" -", "The upgrade machine refuses an upgraded weapon")
	ok(offer_text(press.offer(Loadout.new(Arsenal.pistol()), owned)) == "UPGRADE 4000 \"Upgrade Pistol\" pistol", "The upgrade machine offers to upgrade the pistol for 4000")
	machine.free()
	press.free()


func test_perk_effects() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	var perks: Perks = Perks.new()
	var weapon: Weapon = Weapon.new()
	weapon.perks = perks
	weapon.loadout = Loadout.new(steady(Arsenal.pistol()))
	weapon.loadout.give(steady(Arsenal.smg()))
	player.camera.add_child(weapon)
	var shots: Array[int] = [0]
	weapon.fired.connect(func() -> void: shots[0] += 1)
	await ticks(5)
	weapon.trigger_held = true
	await ticks(17)
	weapon.trigger_held = false
	ok(shots[0] == 4, "Without Rapid the SMG fires 4 shots in 17 ticks")
	await ticks(30)
	perks.grant(Perks.Kind.RAPID)
	shots[0] = 0
	weapon.trigger_held = true
	await ticks(17)
	weapon.trigger_held = false
	ok(shots[0] == 5, "With Rapid the SMG fires 5 shots in 17 ticks")
	perks.grant(Perks.Kind.QUICK_HANDS)
	weapon.switch_requested = true
	await ticks(1)
	ok(await ticks_in_state(weapon, Weapon.State.SWITCHING, 60) == 15 and weapon.current().def.id == &"pistol", "With Quick Hands a change takes 15 ticks")
	weapon.current().magazine = 4
	weapon.reload_requested = true
	await ticks(1)
	var reload_ticks: int = await ticks_in_state(weapon, Weapon.State.RELOADING, 120)
	ok(reload_ticks == 42 and weapon.current().magazine == 8, "With Quick Hands a pistol reload takes 42 ticks")
	weapon.upgrade_current()
	ok(slot_text(weapon.current()) == "pistol 12/120" and weapon.state == Weapon.State.READY, "upgrade_current() fills the pistol at the new sizes and does not start SWITCHING")
	var ahead: Zombie = make_still_zombie(level, Vector3(0.0, 0.0, -3.0), 1000.0)
	var hits: Array[String] = []
	weapon.hit.connect(func(target: Zombie, damage: float, kind: Rules.HitKind) -> void:
		hits.append("%.1f %s" % [damage, Rules.HitKind.find_key(kind)]))
	player.look(0.0, -atan(0.65 / 2.65))
	await ticks(5)
	weapon.trigger_held = true
	await ticks(1)
	weapon.trigger_held = false
	ok(hits == ["70.0 BODY"] and is_instance_valid(ahead), "An upgraded pistol hits for 70 damage")
	await finish(level)
	var tough_level: Node3D = make_level()
	var hurt: Player = spawn(tough_level, tuning(), Vector3.ZERO, 0.0)
	hurt.perks = Perks.new()
	hurt.perks.grant(Perks.Kind.TOUGH)
	hurt.heal_to_max()
	for hit_number: int in range(3):
		hurt.take_damage(40.0)
	ok(hurt.health == 40.0 and hurt.alive, "With Tough three zombie hits leave 40 health")
	hurt.take_damage(40.0)
	ok(not hurt.alive, "With Tough a fourth hit kills")
	await finish(tough_level)
	var mender_level: Node3D = make_level()
	var healing: Player = spawn(mender_level, tuning(), Vector3.ZERO, 0.0)
	healing.perks = Perks.new()
	healing.perks.grant(Perks.Kind.MENDER)
	healing.take_damage(30.0)
	await ticks(84)
	ok(healing.health == 70.0, "With Mender the player does not heal 1.4 s after a hit")
	await ticks(18)
	measure("health 1.7 s after 30 damage with Mender", healing.health, "hp")
	ok(healing.health > 85.0 and healing.health < 92.0, "With Mender, 0.2 s into regeneration at 100 per second the health is near 90")
	await finish(mender_level)
