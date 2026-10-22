extends TestCase


func start_game() -> Game:
	var game: Game = (load("res://game/main.tscn") as PackedScene).instantiate() as Game
	tree.root.add_child(game)
	tree.current_scene = game
	game.player.player_controlled = false
	return game


func place_in_front(game: Game, zombie: Zombie, distance: float) -> void:
	zombie.global_position = game.player.global_position + Vector3.FORWARD.rotated(Vector3.UP, game.player.yaw) * distance


func live_zombies(game: Game) -> Array[Zombie]:
	var found: Array[Zombie] = []
	for child: Node in game.zombies.get_children():
		var zombie: Zombie = child as Zombie
		if zombie.state != Zombie.State.DEAD:
			found.append(zombie)
	return found


func send_action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func test_game() -> void:
	var game: Game = start_game()
	var started: int = -1
	for tick: int in range(1, 241):
		await tree.physics_frame
		if game.director.phase == RoundDirector.Phase.ACTIVE:
			started = tick
			break
	ok(started >= 179 and started <= 181 and game.director.round_number == 1 and live_zombies(game).size() == 1, "Round 1 starts 3 s after the game starts and spawns one zombie")
	ok(game.hud.round_label.text == "1" and game.hud.points_label.text == "500" and game.hud.weapon_label.text == "Pistol" and game.hud.ammo_label.text == "8 / 80", "The HUD shows round 1, 500 points, the pistol, and 8 / 80 ammo")
	var first: Zombie = live_zombies(game)[0]
	ok(first.health == 150.0 and first.speed == 1.6, "A round 1 zombie has 150 health and walks at 1.6 m/s")
	game.weapon.hit.emit(first, 35.0, Rules.HitKind.BODY)
	ok(game.points.balance == 510 and first.health == 115.0, "A body hit for 35 earns 10 points")
	game.weapon.hit.emit(first, 200.0, Rules.HitKind.BODY)
	ok(game.points.balance == 570 and first.state == Zombie.State.DEAD, "A body kill earns 60 points")
	game.weapon.hit.emit(first, 200.0, Rules.HitKind.HEAD)
	ok(game.points.balance == 570, "A hit on a dead zombie earns nothing")
	var headshot_done: bool = false
	for tick: int in range(900):
		await tree.physics_frame
		for zombie: Zombie in live_zombies(game):
			game.weapon.hit.emit(zombie, 1000.0, Rules.HitKind.BODY if headshot_done else Rules.HitKind.HEAD)
			if not headshot_done:
				ok(game.points.balance == 670, "A headshot kill earns 100 points")
				headshot_done = true
		if game.director.phase == RoundDirector.Phase.INTERMISSION:
			break
	ok(game.director.phase == RoundDirector.Phase.INTERMISSION and game.director.rounds_survived() == 1, "Killing all 6 zombies of round 1 clears it into INTERMISSION")
	ok(game.points.balance == 910 and game.points.earned == 410, "Round 1 earns 10 + 60 + 100 + 4 x 60 = 410 points, for a balance of 910")
	game.weapon.trigger_held = true
	await ticks(2)
	game.weapon.trigger_held = false
	ok(game.weapon.current().magazine == 7, "A shot in the intermission leaves 7 rounds")
	for tick: int in range(660):
		await tree.physics_frame
		if game.director.phase == RoundDirector.Phase.ACTIVE:
			break
	ok(game.director.round_number == 2 and game.weapon.current().magazine == 7 and game.weapon.current().reserve == 80 and game.hud.round_label.text == "2", "Round 2 starts after the intermission, shows round 2, and does not refill the weapon")
	var second: Zombie = live_zombies(game)[0]
	ok(second.health == 250.0, "A round 2 zombie has 250 health")
	place_in_front(game, second, 1.5)
	await ticks(2)
	game.weapon.melee_requested = true
	await ticks(1)
	ok(second.health == 100.0 and second.state != Zombie.State.DEAD and game.points.balance == 920, "A melee on a 250 health zombie does 150 damage and earns 10 points")
	send_action(&"pause")
	await ticks(30)
	var paused_position: Vector3 = second.global_position
	await ticks(30)
	ok(tree.paused and game.hud.pause_screen.visible and second.global_position == paused_position, "Pause stops the zombies and shows the pause screen")
	send_action(&"pause")
	await ticks(2)
	ok(not tree.paused and not game.hud.pause_screen.visible, "A second pause press resumes the game")
	game.player.take_damage(100.0)
	await ticks(1)
	ok(game.director.phase == RoundDirector.Phase.GAME_OVER and game.hud.death_screen.visible, "Player death ends the game and shows the death screen")
	ok(game.hud.death_text.text.begins_with("You survived 1 round.\nYou earned 420 points."), "The death screen shows 1 round survived and 420 points earned")
	ok(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Death releases the mouse")
	var zombies_at_death: Array[Node] = game.zombies.get_children()
	await ticks(150)
	ok(game.zombies.get_children().all(func(zombie: Node) -> bool: return zombie in zombies_at_death), "No zombie spawns in the 2.5 s after the game is over")
	send_action(&"restart")
	await ticks(3)
	var fresh: Game = tree.current_scene as Game
	ok(fresh != null and fresh != game and not is_instance_valid(game), "Enter after death reloads the scene with a new Game")
	ok(fresh.director.phase == RoundDirector.Phase.STARTING and fresh.points.balance == 500 and fresh.player.alive, "The new game starts over with 500 points and a living player")
	tree.current_scene = null
	fresh.queue_free()
	await tree.physics_frame


func test_game_melee() -> void:
	var game: Game = start_game()
	for tick: int in range(240):
		await tree.physics_frame
		if game.director.phase == RoundDirector.Phase.ACTIVE:
			break
	var first: Zombie = live_zombies(game)[0]
	place_in_front(game, first, 1.5)
	await ticks(2)
	game.weapon.melee_requested = true
	await ticks(1)
	ok(first.state == Zombie.State.DEAD and game.points.balance == 630 and game.hud.points_label.text == "630", "One melee kills a round 1 zombie and earns 130 points")
	ok(game.weapon.current().magazine == 8 and game.weapon.current().reserve == 80, "The melee uses no ammunition")
	tree.current_scene = null
	game.queue_free()
	await tree.physics_frame


func first_spawn(rng_seed: int) -> Vector3:
	GameConfig.rng_seed = rng_seed
	var game: Game = start_game()
	GameConfig.rng_seed = 0
	var at: Vector3 = Vector3.INF
	for tick: int in range(240):
		await tree.physics_frame
		var live: Array[Zombie] = live_zombies(game)
		if not live.is_empty():
			at = live[0].global_position
			break
	tree.current_scene = null
	game.queue_free()
	await tree.physics_frame
	return at


func test_spawn_seed() -> void:
	var first: Vector3 = await first_spawn(1)
	var again: Vector3 = await first_spawn(1)
	var other: Vector3 = await first_spawn(2)
	ok(first != Vector3.INF and first == again, "Two games with one rng_seed spawn the first zombie at the same point")
	ok(other != Vector3.INF and other != first, "A different rng_seed spawns the first zombie at another point")


func prompt_text(game: Game) -> String:
	return game.hud.prompt_label.text if game.hud.prompt_label.visible else ""


func perk_row_texts(game: Game) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in game.hud.perk_box.get_children():
		if child is Label:
			texts.append((child as Label).text)
	return texts


func send_wheel(button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)


## The first zombie comes 3 s after the start, so the buys happen with no zombie alive.
func test_game_stations() -> void:
	var game: Game = start_game()
	game.player.teleport(Vector3(-8.0, 0.0, -18.45), 0.0)
	await ticks(3)
	ok(prompt_text(game) == "E  Buy SMG  1000" and game.hud.prompt_label.modulate == Hud.PROMPT_GRAY, "1.5 m from the SMG wall buy the prompt is \"E  Buy SMG  1000\" in gray, because 500 points are not enough")
	ok(not game.interact() and game.points.balance == 500 and loadout_text(game.weapon.loadout) == "*pistol 8/80", "With 500 points a press buys nothing and the balance stays 500")
	game.points.earn(500)
	await ticks(1)
	ok(game.hud.prompt_label.modulate == Color.WHITE, "With 1000 points the prompt is white")
	ok(game.interact() and game.points.balance == 0 and loadout_text(game.weapon.loadout) == "pistol 8/80, *smg 30/150", "With 1000 points a press buys the SMG into slot 2 and leaves 0 points")
	ok(game.hud.weapon_label.text == "SMG" and game.hud.ammo_label.text == "30 / 150", "The HUD shows the SMG and its 30 / 150 ammunition at once")
	await ticks(1)
	ok(prompt_text(game) == "SMG ammo full" and not game.interact() and game.points.balance == 0, "With a full SMG the prompt says \"SMG ammo full\" and a press does nothing")
	await wait_for_weapon_state(game.weapon, Weapon.State.READY, 60)
	game.weapon.trigger_held = true
	await ticks(10)
	game.weapon.trigger_held = false
	await ticks(1)
	var after_burst: int = game.weapon.current().magazine
	game.points.earn(500)
	await ticks(1)
	ok(after_burst < 30 and prompt_text(game) == "E  Buy SMG ammo  500", "After a burst the SMG wall offers ammo for 500")
	ok(game.interact() and game.points.balance == 0 and slot_text(game.weapon.current()) == "smg 30/150", "The ammo buy fills the SMG to 30 and 150 for 500 points")
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(3.0, 3.0, 0.1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(-8.0, 1.5, -19.0)
	game.arena.add_child(wall)
	await ticks(2)
	ok(prompt_text(game) == "" and not game.interact(), "A wall between the player and the station hides the prompt, and a press does nothing")
	wall.queue_free()
	game.player.player_controlled = true
	send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await ticks(2)
	ok(game.weapon.state == Weapon.State.SWITCHING and game.weapon.current().def.id == &"pistol" and game.hud.weapon_label.text == "Pistol", "A turn of the mouse wheel changes to the pistol")
	game.player.player_controlled = false
	game.player.teleport(Vector3(10.0, 0.0, 18.2), PI)
	game.points.earn(950)
	await ticks(2)
	ok(prompt_text(game) == "E  Mystery box  950", "In front of the box the prompt is \"E  Mystery box  950\"")
	ok(game.interact() and game.points.balance == 0 and game.arena.box.phase == MysteryBox.Phase.ROLLING, "A roll through Game removes 950 points")
	await ticks(1)
	ok(prompt_text(game) == "", "A rolling box shows no prompt")
	game.arena.box.advance(4.0)
	await ticks(1)
	ok(prompt_text(game) == "E  Take %s" % game.arena.box.result.display_name and game.hud.prompt_label.modulate == Color.WHITE, "An offering box shows \"E  Take\" and the weapon name")
	game.arena.box.advance(10.0)
	await ticks(1)
	ok(game.arena.box.phase == MysteryBox.Phase.IDLE and game.points.balance == 0 and loadout_text(game.weapon.loadout) == "*pistol 8/80, smg 30/150", "A timeout gives no weapon and does not give the 950 points back")
	ok(game.director.phase == RoundDirector.Phase.STARTING, "All buys happened before round 1")
	tree.current_scene = null
	game.queue_free()
	await tree.physics_frame


func test_game_perks() -> void:
	var game: Game = start_game()
	for machine: Machine in game.arena.machines:
		machine.powered = true
	game.player.teleport(Vector3(8.0, 0.0, -18.45), 0.0)
	game.points.earn(1000)
	await ticks(3)
	ok(prompt_text(game) == "E  Buy Mender  1500" and game.interact() and game.points.balance == 0, "At the Mender machine the prompt is \"E  Buy Mender  1500\", and the press takes 1500 points")
	await ticks(1)
	ok(game.perks.has(Perks.Kind.MENDER) and perk_row_texts(game) == PackedStringArray(["Mender"]), "The perk row shows Mender")
	ok(prompt_text(game) == "Mender owned" and not game.interact(), "A second press at an owned perk does nothing")
	game.player.teleport(Vector3(-18.45, 0.0, -8.0), PI * 0.5)
	game.points.earn(3000)
	game.player.take_damage(40.0)
	await ticks(3)
	ok(game.interact() and game.perks.has(Perks.Kind.TOUGH) and game.player.health == 160.0, "Buying Tough for 3000 puts the player at 160 health")
	game.player.teleport(Vector3(-10.0, 0.0, 18.45), PI)
	game.points.earn(4000)
	await ticks(3)
	ok(prompt_text(game) == "E  Upgrade Pistol  4000" and game.interact() and game.points.balance == 0, "At the upgrade machine the prompt is \"E  Upgrade Pistol  4000\", and the press takes 4000 points")
	ok(slot_text(game.weapon.current()) == "pistol 12/120" and game.hud.weapon_label.text == "Upgraded Pistol", "The pistol is upgraded and the HUD shows its name")
	await ticks(1)
	ok(prompt_text(game) == "Already upgraded" and not game.interact(), "A second upgrade is refused")
	tree.current_scene = null
	game.queue_free()
	await tree.physics_frame


func test_doors() -> void:
	var game: Game = start_game()
	game.player.teleport(Vector3(17.5, 0.0, 0.0), -PI * 0.5)
	await ticks(3)
	ok(prompt_text(game) == "E  Open Warehouse  1250" and game.hud.prompt_label.modulate == Hud.PROMPT_GRAY, "Facing the east door the prompt is \"E  Open Warehouse  1250\" in gray")
	game.player.intent.move = Vector2(0.0, 1.0)
	await ticks(60)
	ok(game.player.global_position.x < 20.0, "The player cannot walk through a closed door")
	game.player.intent.move = Vector2.ZERO
	game.player.teleport(Vector3(17.5, 0.0, 0.0), -PI * 0.5)
	await ticks(3)
	ok(not game.interact() and game.arena.spawns().size() == 8, "Without points a press does nothing and no zone opens")
	game.points.earn(1000)
	await ticks(1)
	ok(game.interact() and game.points.balance == 250 and game.arena.open_zones == [&"yard", &"warehouse"], "With 1500 points the press takes 1250 and opens the Warehouse")
	await ticks(2)
	ok(prompt_text(game) == "" and not game.interact(), "An open door shows no prompt and a press does nothing")
	game.player.teleport(Vector3(17.5, 0.0, 0.0), -PI * 0.5)
	await ticks(1)
	game.player.intent.move = Vector2(0.0, 1.0)
	await ticks(90)
	ok(game.player.global_position.x > 24.0, "After the door opens the player walks into the Warehouse")
	game.player.intent.move = Vector2.ZERO
	var runner: Zombie = make_zombie(game.arena, Vector3(26.0, 0.0, -12.0), 150.0, 3.2, game.player)
	game.player.teleport(Vector3(8.0, 0.0, 0.0), 0.0)
	var reached: int = -1
	for tick: int in range(1, 1801):
		await tree.physics_frame
		if runner.state == Zombie.State.ATTACK:
			reached = tick
			break
	measure("time for a Warehouse zombie to reach the Yard player", reached * TICK, "s")
	ok(reached > 0 and reached * TICK < 30.0, "A zombie spawned in the Warehouse reaches a player in the Yard within 30 s")
	tree.current_scene = null
	game.queue_free()
	await tree.physics_frame
	var north: Game = start_game()
	north.player.teleport(Vector3(0.0, 0.0, -17.5), 0.0)
	north.points.earn(1500)
	await ticks(3)
	ok(prompt_text(north) == "E  Open Courtyard  1750" and north.points.balance == 2000 and north.interact() and north.arena.open_zones == [&"yard", &"courtyard"], "The north door costs 1750 and opens the Courtyard")
	tree.current_scene = null
	north.queue_free()
	await tree.physics_frame


func test_power() -> void:
	var game: Game = start_game()
	ok(game.arena.machines.size() == 5 and game.arena.machines.all(func(machine: Machine) -> bool: return not machine.powered), "A new arena has 5 machines and no power")
	game.player.teleport(Vector3(8.0, 0.0, -18.45), 0.0)
	game.points.earn(2000)
	await ticks(3)
	ok(prompt_text(game) == "No power" and not game.interact() and game.points.balance == 2500, "Without power a machine says \"No power\" and a press does nothing")
	var switch: PowerSwitch = null
	for station: Station in game.arena.stations:
		if station is PowerSwitch:
			switch = station as PowerSwitch
	game.player.teleport(Vector3(58.0, 0.0, 0.0), -PI * 0.5)
	await ticks(3)
	ok(prompt_text(game) == "E  Turn on power" and game.interact() and switch.is_on, "The switch prompt is \"E  Turn on power\", and the press turns it on at no cost")
	await ticks(2)
	ok(game.points.balance == 2500 and prompt_text(game) == "Power is on" and not game.interact(), "The switch costs nothing and works one time")
	ok(game.arena.machines.all(func(machine: Machine) -> bool: return machine.powered), "All 5 machines have power")
	game.player.teleport(Vector3(8.0, 0.0, -18.45), 0.0)
	await ticks(3)
	ok(prompt_text(game) == "E  Buy Mender  1500" and game.interact() and game.perks.has(Perks.Kind.MENDER), "With power the Mender machine sells")
	tree.current_scene = null
	game.queue_free()
	await tree.physics_frame


func test_secret() -> void:
	var game: Game = start_game()
	var secret: Secret = game.arena.get_node(^"Secret") as Secret
	var sigils: Array[Sigil] = []
	for node: Node in secret.find_children("*", "Sigil", false):
		sigils.append(node as Sigil)
	ok(sigils.size() == 3 and not secret.cache.revealed, "The secret has 3 sigils and a hidden cache")
	game.player.teleport(Vector3(18.0, 0.0, -43.0), -PI * 0.5)
	await ticks(3)
	ok(prompt_text(game) == "" and not game.interact(), "In front of the closed panel there is no prompt, and a press does nothing")
	sigils[0].light()
	sigils[1].light()
	sigils[1].light()
	ok(not secret.revealed and not secret.cache.revealed, "Two lit sigils do not reveal the cache")
	var third: Sigil = sigils[2]
	game.player.teleport(Vector3(third.position.x, 0.0, -57.0), 0.0)
	await ticks(10)
	game.weapon.trigger_held = true
	await ticks(3)
	game.weapon.trigger_held = false
	ok(third.is_lit and secret.revealed and secret.cache.revealed, "A pistol shot at the third sigil lights it and reveals the cache")
	await ticks(70)
	ok(not is_instance_valid(secret.panel), "The panel sinks and frees itself")
	game.player.teleport(Vector3(18.0, 0.0, -43.0), -PI * 0.5)
	game.weapon.loadout.current().magazine = 1
	game.weapon.loadout.current().reserve = 3
	var before: int = game.points.balance
	await ticks(3)
	ok(prompt_text(game) == "E  Take the cache", "In the alcove the prompt is \"E  Take the cache\"")
	ok(game.interact() and game.points.balance == before + 1500 and slot_text(game.weapon.current()) == "pistol 8/80", "The cache gives 1500 points and fills the weapon")
	await ticks(2)
	ok(not game.interact() and game.points.balance == before + 1500, "The cache works one time")
	tree.current_scene = null
	game.queue_free()
	await tree.physics_frame
