extends TestCase


func describe(weapon: WeaponDef) -> String:
	return "%s %s %.1f x%d %.3f %s %d/%d %.1f %.0f %.1f" % [weapon.id, weapon.display_name, weapon.damage, weapon.pellets, weapon.fire_interval, "auto" if weapon.automatic else "semi", weapon.magazine_size, weapon.reserve_max, weapon.reload_seconds, weapon.range, weapon.spread_degrees]


func test_arsenal() -> void:
	var table: Array[String] = []
	for weapon: WeaponDef in [Arsenal.pistol(), Arsenal.smg(), Arsenal.shotgun(), Arsenal.rifle(), Arsenal.lmg(), Arsenal.marksman()]:
		table.append(describe(weapon))
	ok(table == [
		"pistol Pistol 35.0 x1 0.150 semi 8/80 1.4 100 1.0",
		"smg SMG 30.0 x1 0.075 auto 30/150 2.0 60 3.0",
		"shotgun Shotgun 25.0 x8 0.800 semi 6/42 3.0 20 6.0",
		"rifle Rifle 80.0 x1 0.250 semi 15/90 2.2 150 0.5",
		"lmg LMG 55.0 x1 0.100 auto 75/300 4.5 120 2.5",
		"marksman Marksman 250.0 x1 0.900 semi 5/40 3.0 300 0.0",
	], "The arsenal has the six weapons of the design table")
	var pool: Array[StringName] = []
	for weapon: WeaponDef in Arsenal.box_pool():
		pool.append(weapon.id)
	ok(pool == [&"smg", &"shotgun", &"rifle", &"lmg", &"marksman"], "The box pool is the SMG, the shotgun, the rifle, the LMG, and the marksman")


func test_loadout() -> void:
	var loadout: Loadout = Loadout.new(Arsenal.pistol())
	ok(loadout_text(loadout) == "*pistol 8/80", "A new loadout has one slot with the pistol at 8 and 80")
	ok(not loadout.cycle() and loadout.active == 0, "cycle() with one slot returns false and changes nothing")
	loadout.current().magazine = 5
	loadout.give(Arsenal.smg())
	ok(loadout_text(loadout) == "pistol 5/80, *smg 30/150", "give(SMG) adds slot 2 with a full SMG and makes it active")
	loadout.give(Arsenal.rifle())
	ok(loadout_text(loadout) == "pistol 5/80, *rifle 15/90" and loadout.find(&"smg") == null, "give(rifle) with two slots replaces the SMG in the hands, and the pistol keeps its ammunition")
	loadout.give(Arsenal.pistol())
	ok(loadout_text(loadout) == "*pistol 8/80, rifle 15/90", "give(pistol) after 3 shots fills the pistol and makes it active")
	ok(loadout.cycle() and loadout_text(loadout) == "pistol 8/80, *rifle 15/90", "cycle() with two slots makes the other slot active")
	var rifle: Loadout.Slot = loadout.find(&"rifle")
	rifle.reserve = 0
	var after_shots: bool = rifle.is_full()
	rifle.fill()
	ok(not after_shots and rifle.is_full() and slot_text(rifle) == "rifle 15/90", "A slot with an empty reserve is not full, and fill() gives 15 and 90")


func test_wall_buy_offer() -> void:
	var wall: WallBuy = WallBuy.new(Arsenal.smg(), 1000)
	var loadout: Loadout = Loadout.new(Arsenal.pistol())
	ok(offer_text(wall.offer(loadout, Perks.new())) == "WEAPON 1000 \"Buy SMG\" smg" and loadout_text(loadout) == "*pistol 8/80", "Without the SMG the wall offers the SMG for 1000, and the offer changes nothing")
	loadout.give(Arsenal.smg())
	loadout.current().magazine = 29
	ok(offer_text(wall.offer(loadout, Perks.new())) == "AMMO 500 \"Buy SMG ammo\" smg", "With 29 of 30 SMG rounds the wall offers SMG ammo for 500")
	loadout.current().fill()
	ok(offer_text(wall.offer(loadout, Perks.new())) == "NONE 0 \"SMG ammo full\" -", "With full SMG ammunition the wall offers nothing and says so")
	wall.free()


func test_mystery_box() -> void:
	var box: MysteryBox = MysteryBox.new()
	box.rng.seed = 7
	var weapon: Weapon = Weapon.new()
	weapon.loadout.give(Arsenal.smg())
	var seen: PackedStringArray = []
	for roll: int in range(200):
		box.accept(box.offer(weapon.loadout, Perks.new()), weapon, Perks.new())
		if not seen.has(box.result.id):
			seen.append(box.result.id)
		box.advance(4.0)
		box.advance(10.0)
	seen.sort()
	ok(seen == PackedStringArray(["lmg", "marksman", "rifle", "shotgun"]), "In 200 rolls from a loadout of the pistol and the SMG the box gives the shotgun, the rifle, the LMG, and the marksman, and never the SMG or the pistol")
	ok(offer_text(box.offer(weapon.loadout, Perks.new())) == "BOX_ROLL 950 \"Mystery box\" -", "An idle box offers a roll for 950")
	box.accept(box.offer(weapon.loadout, Perks.new()), weapon, Perks.new())
	ok(box.phase == MysteryBox.Phase.ROLLING and offer_text(box.offer(weapon.loadout, Perks.new())) == "NONE 0 \"\" -", "A rolling box offers nothing and shows no prompt")
	box.advance(3.5)
	var rolling_at: MysteryBox.Phase = box.phase
	box.advance(0.5)
	ok(rolling_at == MysteryBox.Phase.ROLLING and box.phase == MysteryBox.Phase.OFFERING, "ROLLING lasts 4.0 s")
	var take: Station.Offer = box.offer(weapon.loadout, Perks.new())
	ok(offer_text(take) == "BOX_TAKE 0 \"Take %s\" %s" % [box.result.display_name, box.result.id], "An offering box offers its result for 0")
	box.advance(9.5)
	var offering_at: MysteryBox.Phase = box.phase
	box.advance(0.5)
	ok(offering_at == MysteryBox.Phase.OFFERING and box.phase == MysteryBox.Phase.IDLE and box.result == null, "OFFERING lasts 10.0 s, and then the weapon is gone")
	ok(loadout_text(weapon.loadout) == "pistol 8/80, *smg 30/150", "A timeout gives nothing")
	box.accept(box.offer(weapon.loadout, Perks.new()), weapon, Perks.new())
	box.advance(4.0)
	var offered: StringName = box.result.id
	box.accept(box.offer(weapon.loadout, Perks.new()), weapon, Perks.new())
	ok(box.phase == MysteryBox.Phase.IDLE and box.result == null and weapon.current().def.id == offered and weapon.loadout.find(&"smg") == null and weapon.state == Weapon.State.SWITCHING, "A take gives the offered weapon in place of the SMG in the hands and returns the box to IDLE")
	weapon.free()
	box.free()


func test_weapon() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(0.5, 3.0, 4.0), Vector3(3.0, 1.5, 0.0))
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	var weapon: Weapon = Weapon.new()
	weapon.loadout = Loadout.new(steady(Arsenal.pistol()))
	player.camera.add_child(weapon)
	var ahead: Zombie = make_still_zombie(level, Vector3(0.0, 0.0, -6.0))
	var behind_wall: Zombie = make_still_zombie(level, Vector3(6.0, 0.0, 0.0))
	var shots: Array[int] = [0]
	var hits: Array[String] = []
	var reloads: Array[String] = []
	weapon.fired.connect(func() -> void: shots[0] += 1)
	weapon.hit.connect(func(target: Zombie, damage: float, kind: Rules.HitKind) -> void:
		hits.append("%s %.1f %s" % ["ahead" if target == ahead else "other", damage, Rules.HitKind.find_key(kind)]))
	weapon.reload_started.connect(func() -> void: reloads.append("started %d" % Engine.get_physics_frames()))
	weapon.reload_finished.connect(func() -> void: reloads.append("finished %d" % Engine.get_physics_frames()))
	await ticks(5)
	ok(weapon.current().magazine == 8 and weapon.current().reserve == 80 and weapon.state == Weapon.State.READY, "The starting pistol is READY with 8 in the magazine and 80 in reserve")
	weapon.trigger_held = true
	await ticks(30)
	ok(shots[0] == 1 and weapon.current().magazine == 7, "Holding the trigger of a semi-automatic weapon for 0.5 s fires once")
	ok(hits == ["ahead 70.0 HEAD"], "A level shot from 1.65 m eye height hits the zombie 6 m ahead in the head for 70 damage")
	weapon.trigger_held = false
	player.look(0.0, -atan(0.65 / 5.65))
	await ticks(2)
	weapon.trigger_held = true
	await ticks(1)
	weapon.trigger_held = false
	ok(shots[0] == 2 and hits == ["ahead 70.0 HEAD", "ahead 35.0 BODY"], "A press aimed at 1.0 m height hits the body for 35 damage")
	player.look(-PI * 0.5, atan(0.65 / 5.65))
	await ticks(12)
	weapon.trigger_held = true
	await ticks(1)
	weapon.trigger_held = false
	ok(shots[0] == 3 and hits.size() == 2 and behind_wall.health == 150.0, "A shot at the zombie behind a wall fires but does not hit")
	for press: int in range(5):
		await ticks(12)
		weapon.trigger_held = true
		await ticks(1)
		weapon.trigger_held = false
	ok(shots[0] == 8 and weapon.current().magazine == 0, "Eight presses empty the 8-round magazine")
	await ticks(12)
	ok(weapon.state == Weapon.State.RELOADING and reloads.size() == 1, "The empty magazine starts a reload by itself")
	weapon.trigger_held = true
	await ticks(60)
	weapon.trigger_held = false
	ok(shots[0] == 8 and weapon.state == Weapon.State.RELOADING, "Presses during the reload do not fire")
	await ticks(30)
	ok(weapon.state == Weapon.State.READY and weapon.current().magazine == 8 and weapon.current().reserve == 72, "After the reload the magazine has 8 and the reserve has 72")
	var reload_ticks: int = int(reloads[1].split(" ")[1]) - int(reloads[0].split(" ")[1])
	measure("reload time", reload_ticks * TICK, "s")
	ok(reload_ticks == 84, "The reload takes 84 ticks, which is 1.4 s")
	weapon.trigger_held = true
	await ticks(1)
	weapon.trigger_held = false
	weapon.reload_requested = true
	await ticks(12)
	ok(weapon.state == Weapon.State.RELOADING and weapon.current().magazine == 7, "A reload request with 7 of 8 rounds starts a reload")
	weapon.fill(&"pistol")
	ok(weapon.state == Weapon.State.READY and weapon.current().magazine == 8 and weapon.current().reserve == 80, "fill() of the weapon in the hands ends its reload and fills the magazine and the reserve")
	await finish(level)


func test_melee() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(0.2, 3.0, 4.0), Vector3(0.8, 1.5, 0.0))
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	var weapon: Weapon = Weapon.new()
	weapon.loadout = Loadout.new(steady(Arsenal.pistol()))
	player.camera.add_child(weapon)
	var ahead: Zombie = make_still_zombie(level, Vector3(0.0, 0.0, -1.5), 1000.0)
	var behind_wall: Zombie = make_still_zombie(level, Vector3(1.6, 0.0, 0.0), 1000.0)
	var far: Zombie = make_still_zombie(level, Vector3(-3.0, 0.0, 0.0), 1000.0)
	var names: Dictionary[Zombie, String] = {ahead: "ahead", behind_wall: "behind wall", far: "far"}
	var shots: Array[int] = [0]
	var hits: Array[String] = []
	var reloads: Array[String] = []
	weapon.fired.connect(func() -> void: shots[0] += 1)
	weapon.hit.connect(func(target: Zombie, damage: float, kind: Rules.HitKind) -> void:
		hits.append("%s %.1f %s" % [names[target], damage, Rules.HitKind.find_key(kind)]))
	weapon.reload_started.connect(func() -> void: reloads.append("started"))
	weapon.reload_finished.connect(func() -> void: reloads.append("finished"))
	await ticks(5)
	weapon.melee_requested = true
	await ticks(1)
	ok(weapon.state == Weapon.State.MELEE and hits == ["ahead 150.0 MELEE"], "A melee hits the zombie 1.5 m ahead once for 150 damage")
	weapon.trigger_held = true
	await ticks(9)
	weapon.melee_requested = true
	var shots_in_melee: int = -1
	var hits_in_melee: int = -1
	var melee_ticks: int = 10
	for tick: int in range(60):
		await tree.physics_frame
		if weapon.state != Weapon.State.MELEE:
			break
		shots_in_melee = shots[0]
		hits_in_melee = hits.size()
		melee_ticks += 1
	weapon.trigger_held = false
	measure("melee time", melee_ticks * TICK, "s")
	ok(melee_ticks == 36, "MELEE lasts 36 ticks, which is 0.6 s, and a second melee request during MELEE does not make it longer")
	ok(shots_in_melee == 0 and hits_in_melee == 1, "A held trigger does not fire during MELEE, and the second melee request does not hit")
	ok(shots[0] == 1 and weapon.current().magazine == 7 and hits == ["ahead 150.0 MELEE", "ahead 70.0 HEAD"], "The press held through MELEE fires once when MELEE ends")
	player.look(-PI * 0.5, 0.0)
	await ticks(12)
	weapon.melee_requested = true
	await ticks(1)
	ok(weapon.state == Weapon.State.MELEE and hits.size() == 2, "A wall between the player and a zombie 1.6 m away blocks the melee")
	player.look(PI, 0.0)
	await ticks(40)
	weapon.melee_requested = true
	await ticks(1)
	ok(weapon.state == Weapon.State.MELEE and hits.size() == 2, "A melee does not hit the zombie 3 m away")
	await wait_for_weapon_state(weapon, Weapon.State.READY, 40)
	weapon.reload_requested = true
	await ticks(30)
	ok(weapon.state == Weapon.State.RELOADING and reloads == ["started"], "A reload request with 7 of 8 rounds starts a reload")
	weapon.melee_requested = true
	await ticks(1)
	ok(weapon.state == Weapon.State.MELEE and weapon.current().magazine == 7 and weapon.current().reserve == 80, "A melee interrupts the reload and leaves 7 in the magazine and 80 in reserve")
	var restarted_after: int = await wait_for_weapon_state(weapon, Weapon.State.RELOADING, 40)
	ok(restarted_after == 36 and reloads == ["started", "started"], "The reload starts again on the tick that MELEE ends")
	var finished_after: int = await wait_for_weapon_state(weapon, Weapon.State.READY, 120)
	ok(finished_after == 84 and weapon.current().magazine == 8 and weapon.current().reserve == 79 and reloads == ["started", "started", "finished"], "The restarted reload takes the full 84 ticks and loads 1 round from the reserve")
	await finish(level)


func test_weapon_switch() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	var weapon: Weapon = Weapon.new()
	weapon.loadout = Loadout.new(Arsenal.pistol())
	weapon.loadout.give(Arsenal.smg())
	weapon.loadout.find(&"pistol").magazine = 5
	weapon.loadout.find(&"smg").magazine = 12
	player.camera.add_child(weapon)
	var events: Array[String] = []
	weapon.equipped.connect(func(def: WeaponDef) -> void: events.append("equipped %s" % def.id))
	weapon.ammo_changed.connect(func(magazine: int, reserve: int) -> void: events.append("ammo %d/%d" % [magazine, reserve]))
	var shots: Array[int] = [0]
	weapon.fired.connect(func() -> void: shots[0] += 1)
	await ticks(5)
	weapon.switch_requested = true
	await ticks(1)
	ok(weapon.state == Weapon.State.SWITCHING and weapon.current().def.id == &"pistol" and events == ["equipped pistol", "ammo 5/80"], "A switch request makes the pistol active on the first tick of SWITCHING and reports it with its 5 and 80")
	var switch_ticks: int = await ticks_in_state(weapon, Weapon.State.SWITCHING, 60)
	measure("weapon change time", switch_ticks * TICK, "s")
	ok(switch_ticks == 30 and weapon.state == Weapon.State.READY, "SWITCHING lasts 30 ticks, which is 0.5 s")
	ok(loadout_text(weapon.loadout) == "*pistol 5/80, smg 12/150", "A change keeps the ammunition of both slots")
	weapon.reload_requested = true
	await ticks(30)
	ok(weapon.state == Weapon.State.RELOADING, "A reload request with 5 of 8 rounds starts a reload")
	weapon.switch_requested = true
	await ticks(1)
	ok(weapon.state == Weapon.State.SWITCHING and loadout_text(weapon.loadout) == "pistol 5/80, *smg 12/150", "A change during the reload stops it with no change to the ammunition")
	await ticks_in_state(weapon, Weapon.State.SWITCHING, 60)
	weapon.switch_requested = true
	await ticks(1)
	await ticks_in_state(weapon, Weapon.State.SWITCHING, 60)
	await ticks(10)
	ok(weapon.state == Weapon.State.READY and loadout_text(weapon.loadout) == "*pistol 5/80, smg 12/150", "Back on the pistol, the stopped reload does not start again")
	weapon.melee_requested = true
	await ticks(1)
	weapon.switch_requested = true
	await ticks(1)
	ok(weapon.state == Weapon.State.MELEE and weapon.current().def.id == &"pistol", "A switch request during MELEE is cleared and does nothing")
	await wait_for_weapon_state(weapon, Weapon.State.READY, 60)
	weapon.equip(Arsenal.rifle())
	ok(weapon.state == Weapon.State.SWITCHING and loadout_text(weapon.loadout) == "*rifle 15/90, smg 12/150", "equip() of a third weapon replaces the pistol in the hands and starts SWITCHING")
	weapon.trigger_held = true
	var fired_at: int = -1
	for tick: int in range(1, 61):
		await tree.physics_frame
		if fired_at < 0 and shots[0] > 0:
			fired_at = tick
	weapon.trigger_held = false
	ok(shots[0] == 1 and fired_at == 30 and weapon.current().magazine == 14, "A press held through SWITCHING fires one time, on the tick that SWITCHING ends")
	weapon.loadout = Loadout.new(Arsenal.pistol())
	events.clear()
	weapon.switch_requested = true
	await ticks(1)
	ok(weapon.state != Weapon.State.SWITCHING and events.is_empty() and weapon.loadout.active == 0, "A switch request with one slot does nothing")
	await finish(level)


func test_shotgun() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	var weapon: Weapon = Weapon.new()
	weapon.loadout = Loadout.new(steady(Arsenal.shotgun()))
	player.camera.add_child(weapon)
	var ahead: Zombie = make_still_zombie(level, Vector3(0.0, 0.0, -3.0), 1000.0)
	var hits: Array[String] = []
	weapon.hit.connect(func(target: Zombie, damage: float, kind: Rules.HitKind) -> void:
		hits.append("%s %.1f %s" % ["ahead" if target == ahead else "other", damage, Rules.HitKind.find_key(kind)]))
	player.look(0.0, -atan(0.65 / 2.65))
	await ticks(5)
	weapon.trigger_held = true
	await ticks(1)
	weapon.trigger_held = false
	ok(hits == ["ahead 200.0 BODY"] and weapon.current().magazine == 5, "A shotgun shot with no spread at a zombie 3 m ahead emits one hit for 8 x 25 = 200 damage of kind BODY")
	player.look(0.0, atan(0.65 / 2.65))
	await ticks(60)
	weapon.trigger_held = true
	await ticks(1)
	weapon.trigger_held = false
	ok(hits == ["ahead 200.0 BODY", "ahead 400.0 HEAD"], "A level shotgun shot hits the head with all 8 pellets for 400 damage of kind HEAD")
	await finish(level)
