extends TestCase


func wait_for_state(player: Player, state: Player.MoveState, limit: int) -> int:
	for tick: int in range(1, limit + 1):
		await tree.physics_frame
		if player.move_state == state:
			return tick
	return -1


func test_ground_speed() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await ticks(5)
	ok(player.move_state == Player.MoveState.GROUND and player.horizontal_speed() == 0.0, "Spawned body rests on the floor in GROUND with no speed")
	player.intent.move = Vector2(0.0, 1.0)
	var ticks_to_ninety: int = -1
	for tick: int in range(1, 31):
		await tree.physics_frame
		if ticks_to_ninety < 0 and player.horizontal_speed() >= 6.3:
			ticks_to_ninety = tick
	measure("time to 90% walk speed", ticks_to_ninety * TICK, "s")
	ok(ticks_to_ninety > 0 and ticks_to_ninety * TICK <= 0.15, "Holding forward from rest reaches 6.3 m/s (90% of 7.0) within 0.15 s")
	var start_z: float = player.global_position.z
	await ticks(60)
	var covered: float = start_z - player.global_position.z
	measure("settled walk speed", player.horizontal_speed(), "m/s")
	ok(absf(player.horizontal_speed() - 7.0) <= 0.14, "Holding forward settles within 2% of 7.0 m/s")
	ok(absf(covered - 7.0) <= 0.14, "With yaw 0 the body covers 7.0 m toward -Z in one second of walking")
	player.intent.move = Vector2.ZERO
	var ticks_to_stop: int = -1
	for tick: int in range(1, 61):
		await tree.physics_frame
		if player.horizontal_speed() < 0.01:
			ticks_to_stop = tick
			break
	measure("stop time from walk speed", ticks_to_stop * TICK, "s")
	ok(ticks_to_stop > 0 and ticks_to_stop * TICK <= 0.25, "Releasing input stops the body from 7.0 m/s within 0.25 s")
	player.look(PI * 0.5, 0.0)
	player.intent.move = Vector2(0.0, 1.0)
	await ticks(30)
	ok(player.velocity.x < -6.5 and absf(player.velocity.z) < 0.1, "After look() turns 90 degrees left, forward input moves the body toward -X")
	await finish(level)


func test_jump_height() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await ticks(5)
	var start_y: float = player.global_position.y
	press_jump(player)
	var apex: float = 0.0
	var apex_tick: int = 0
	for tick: int in range(1, 61):
		await tree.physics_frame
		var height: float = player.global_position.y - start_y
		if height > apex:
			apex = height
			apex_tick = tick
	measure("held jump apex", apex, "m")
	measure("held jump time to apex", apex_tick * TICK, "s")
	ok(jumps == 1, "Jump press emits jumped once")
	ok(absf(apex - 1.25) <= 0.0625, "Held jump peaks at 1.25 m within 5%")
	ok(absf(apex_tick * TICK - 0.32) <= 0.034, "Held jump reaches its apex about 0.32 s after the press")
	ok(player.move_state == Player.MoveState.GROUND, "Body is back in GROUND one second after the jump")
	player.intent.jump_held = false
	await ticks(5)
	press_jump(player)
	await ticks(3)
	player.intent.jump_held = false
	var tap_apex: float = 0.0
	for tick: int in range(1, 61):
		await tree.physics_frame
		tap_apex = maxf(tap_apex, player.global_position.y - start_y)
	measure("tap jump apex (released after 0.05 s)", tap_apex, "m")
	ok(tap_apex > 0.25 and tap_apex < 0.6, "Jump released after 0.05 s peaks between 0.25 m and 0.6 m, clearly below the 1.25 m held jump")
	player.intent.jump_pressed = true
	var bot_apex: float = 0.0
	for tick: int in range(1, 61):
		await tree.physics_frame
		bot_apex = maxf(bot_apex, player.global_position.y - start_y)
	ok(absf(bot_apex - 1.25) <= 0.0625, "A jump press with jump_held never set gives the full 1.25 m jump, because only a release cuts the jump")
	await finish(level)


func test_air_control() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	press_jump(player)
	var air_speed: float = 0.0
	for tick: int in range(90):
		await tree.physics_frame
		if player.move_state != Player.MoveState.AIR:
			break
		air_speed = player.horizontal_speed()
	measure("air speed from a standing jump with forward held", air_speed, "m/s")
	ok(air_speed >= 4.5, "Holding forward during a standing jump gives at least 4.5 m/s before landing")
	await ticks(60)
	press_jump(player)
	await ticks(1)
	player.intent.move = Vector2(1.0, 0.0)
	var air_velocity: Vector3 = player.velocity
	for tick: int in range(90):
		await tree.physics_frame
		if player.move_state != Player.MoveState.AIR:
			break
		air_velocity = player.velocity
	var turn: float = rad_to_deg(Vector2(air_velocity.x, -air_velocity.z).angle_to(Vector2(0.0, 1.0)))
	measure("path turn from a walk jump with only the right key held", turn, "deg")
	ok(turn >= 30.0, "Holding only the right key during a walk jump turns the path right by at least 30 degrees")
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await ticks(60)
	press_jump(player)
	await ticks(1)
	player.intent.move = Vector2(1.0, 0.0)
	for tick: int in range(25):
		player.look(-0.02, 0.0)
		await tree.physics_frame
	measure("air strafe speed after 25 ticks from 10.5 m/s", player.horizontal_speed(), "m/s")
	ok(player.move_state == Player.MoveState.AIR and player.horizontal_speed() >= 11.0, "Strafing while turning in the air raises speed from 10.5 m/s to at least 11.0 m/s")
	await finish(level)


func test_coyote_time() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(10.0, 4.0, 10.0), Vector3(0.0, 2.0, 0.0))
	var player: Player = spawn(level, tuning(), Vector3(0.0, 4.0, 0.0), 0.0)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	var left_at: int = await wait_for_state(player, Player.MoveState.AIR, 120)
	ok(left_at > 0 and jumps == 0, "Walking off a 4 m ledge enters AIR without a jump")
	await ticks(3)
	press_jump(player)
	await ticks(1)
	ok(jumps == 1 and player.velocity.y > 0.0, "Jump pressed 0.05 s after leaving the ledge jumps (coyote time)")
	player.teleport(Vector3(0.0, 4.0, 0.0), 0.0)
	clear_events()
	await ticks(5)
	left_at = await wait_for_state(player, Player.MoveState.AIR, 120)
	await ticks(15)
	press_jump(player)
	await ticks(2)
	ok(jumps == 0 and player.velocity.y < 0.0, "Jump pressed 0.25 s after leaving the ledge does not jump")
	await wait_for_state(player, Player.MoveState.GROUND, 120)
	await ticks(5)
	ok(jumps == 0 and landings.size() == 1, "The late press expires before landing, so the landing does not jump")
	await finish(level)


func test_jump_buffer() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3(0.0, 2.5, 0.0), 0.0)
	ok(player.move_state == Player.MoveState.AIR, "Teleport to 2.5 m above the floor starts in AIR")
	press_jump(player)
	await ticks(1)
	player.intent.jump_held = false
	await wait_for_state(player, Player.MoveState.GROUND, 120)
	await ticks(3)
	ok(jumps == 0 and player.move_state == Player.MoveState.GROUND, "Jump pressed 0.39 s before landing is not kept until the landing")
	player.teleport(Vector3(0.0, 2.5, 0.0), 0.0)
	clear_events()
	var pressed: bool = false
	for tick: int in range(120):
		await tree.physics_frame
		if not pressed and player.global_position.y < 0.45:
			press_jump(player)
			pressed = true
		if landings.size() > 0:
			break
	ok(pressed and landings.size() == 1, "Body falls and lands once after the late press")
	await ticks(2)
	ok(jumps == 1 and player.velocity.y > 0.0, "Jump pressed just before landing jumps on the landing tick (jump buffer)")
	var rise: float = 0.0
	for tick: int in range(30):
		await tree.physics_frame
		rise = maxf(rise, player.global_position.y)
	ok(rise > 1.0, "The buffered jump rises above 1.0 m")
	await finish(level)


func test_sprint_and_slide() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await ticks(60)
	measure("sprint speed", player.horizontal_speed(), "m/s")
	ok(absf(player.horizontal_speed() - 10.5) <= 0.21, "Sprint settles within 2% of 10.5 m/s")
	clear_events()
	player.intent.crouch_held = true
	await ticks(1)
	ok(player.move_state == Player.MoveState.SLIDE and player.stance == Player.Stance.CROUCH, "Crouch press at sprint speed starts a crouched SLIDE")
	var peak: float = player.horizontal_speed()
	measure("slide speed on the first tick", peak, "m/s")
	ok(peak >= 13.5 and peak <= 14.0, "Slide boost lifts 10.5 m/s to between 13.5 and 14.0 m/s")
	var slide_ticks: int = await wait_for_state(player, Player.MoveState.GROUND, 240)
	measure("flat slide duration", slide_ticks * TICK, "s")
	ok(slide_ticks * TICK >= 1.5 and slide_ticks * TICK <= 1.6, "A flat slide from 13.89 m/s lasts between 1.5 s and 1.6 s before it drops below 4.0 m/s")
	ok(player.horizontal_speed() < 4.0, "Slide ends when speed drops below 4.0 m/s")
	ok(transitions == ["GROUND>SLIDE", "SLIDE>GROUND"], "move_state_changed reports GROUND>SLIDE then SLIDE>GROUND")
	ok(player.stance == Player.Stance.CROUCH, "Body stays crouched after the slide while crouch is held")
	player.intent.crouch_held = false
	player.intent.sprint_held = true
	await ticks(60)
	clear_events()
	player.intent.crouch_held = true
	await ticks(1)
	player.intent.crouch_held = false
	await ticks(1)
	player.intent.crouch_held = true
	await ticks(1)
	ok(transitions == ["GROUND>SLIDE", "SLIDE>GROUND"], "A second crouch press inside the 0.6 s cooldown does not start a slide")
	await finish(level)


func test_slide_jump_and_landing_slide() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await ticks(60)
	player.intent.crouch_held = true
	await ticks(5)
	clear_events()
	press_jump(player)
	await ticks(1)
	var takeoff: float = player.horizontal_speed()
	await ticks(15)
	measure("speed 0.25 s after a slide jump", player.horizontal_speed(), "m/s")
	ok(transitions == ["SLIDE>AIR"] and player.horizontal_speed() > 12.5, "Jumping out of a slide carries more than 12.5 m/s into the air")
	ok(absf(player.horizontal_speed() - takeoff) < 0.05, "Holding forward in the air after a slide jump loses no horizontal speed")
	await wait_for_state(player, Player.MoveState.SLIDE, 90)
	ok(transitions == ["SLIDE>AIR", "AIR>SLIDE"] and landings.size() == 1, "Landing with crouch held at slide speed goes straight into SLIDE and emits landed")
	await finish(level)


func test_stairs() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(4.0, 0.3, 10.0), Vector3(0.0, 0.15, -8.0))
	add_box(level, Vector3(4.0, 0.35, 10.0), Vector3(10.0, 0.175, -8.0))
	add_box(level, Vector3(4.0, 0.6, 10.0), Vector3(20.0, 0.3, -8.0))
	var values: PlayerSettings = tuning()
	var player: Player = spawn(level, values, Vector3(0.0, 0.0, 2.0), 0.0)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	var entered: int = -1
	var exited: int = -1
	var slowest: float = INF
	for tick: int in range(1, 121):
		await tree.physics_frame
		var z: float = player.global_position.z
		if entered < 0 and z <= -2.0:
			entered = tick
		if entered > 0 and exited < 0:
			slowest = minf(slowest, player.horizontal_speed())
		if exited < 0 and z <= -4.0:
			exited = tick
	var crossing_speed: float = 2.0 / ((exited - entered) * TICK) if exited > entered else 0.0
	measure("average speed across a 0.3 m step", crossing_speed, "m/s")
	measure("slowest speed across a 0.3 m step", slowest, "m/s")
	ok(absf(player.global_position.y - 0.3) < 0.02, "Walking into a 0.3 m step ends on top of it")
	ok(crossing_speed >= 5.6, "Crossing the 0.3 m step averages at least 5.6 m/s (80% of 7.0)")
	ok(transitions.is_empty(), "Climbing the 0.3 m step never leaves GROUND")
	player.teleport(Vector3(0.0, 0.3, -8.0), PI)
	clear_events()
	await ticks(60)
	ok(absf(player.global_position.y) < 0.02 and transitions.is_empty(), "Walking down off the 0.3 m step stays in GROUND and ends on the floor")
	player.teleport(Vector3(10.0, 0.0, 2.0), 0.0)
	player.intent.crouch_held = true
	clear_events()
	await ticks(120)
	ok(absf(player.global_position.y - 0.35) < 0.02 and transitions.is_empty(), "Crouch walking into a 0.35 m step climbs it")
	player.intent.crouch_held = false
	player.teleport(Vector3(20.0, 0.0, 2.0), 0.0)
	clear_events()
	await ticks(120)
	ok(player.global_position.y < 0.05 and player.global_position.z > -2.7 and transitions.is_empty(), "A 0.6 m step blocks the body when it walks with no jump")
	await finish(level)


func test_staircases() -> void:
	var level: Node3D = make_level()
	add_staircase(level, 0.0, 0.2, 0.3, 8)
	add_staircase(level, 5.0, 0.35, 0.35, 5)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 0.0), 0.0)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.crouch_held = true
	await ticks(180)
	ok(absf(player.global_position.y - 1.6) < 0.02 and transitions.is_empty(), "Crouch walking climbs eight 0.2 m steps with 0.3 m treads to 1.6 m without leaving GROUND")
	player.intent.crouch_held = false
	player.teleport(Vector3(5.0, 1.75, -6.0), PI)
	clear_events()
	await ticks(90)
	ok(absf(player.global_position.y) < 0.02 and transitions.is_empty(), "Walking down five 0.35 m steps with 0.35 m treads stays in GROUND to the floor")
	player.teleport(Vector3(1.5, 0.0, 0.0), deg_to_rad(-30.0))
	var highest: float = 0.0
	for tick: int in range(90):
		await tree.physics_frame
		highest = maxf(highest, player.global_position.y)
	ok(absf(highest - 1.75) < 0.02, "Walking at 30 degrees into the corner of the 0.35 m staircase climbs it from the side to 1.75 m")
	await finish(level)


func test_ceiling() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(4.0, 0.3, 6.0), Vector3(0.0, 1.45, -6.0))
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.crouch_held = true
	await ticks(75)
	ok(player.global_position.z < -3.4 and player.stance == Player.Stance.CROUCH, "Crouched body walks under the 1.3 m ceiling")
	player.intent.crouch_held = false
	await ticks(10)
	ok(player.stance == Player.Stance.CROUCH and absf(player.global_position.y) < 0.02, "Releasing crouch under the ceiling keeps the body crouched on the floor")
	for tick: int in range(150):
		await tree.physics_frame
		if player.global_position.z < -9.5:
			break
	await ticks(2)
	ok(player.global_position.z < -9.5 and player.stance == Player.Stance.STAND, "Body stands up after it clears the ceiling")
	await finish(level)


func ticks_in_mantle(player: Player, limit: int) -> int:
	var count: int = 0
	for tick: int in range(limit):
		await tree.physics_frame
		if player.move_state == Player.MoveState.MANTLE:
			count += 1
	return count


func test_mantle() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	add_ledge(level, 10.0, 1.5)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 0.0), 0.0)
	await ticks(5)
	await push_into_wall(player)
	await ticks(30)
	ok(player.global_position.y < 0.05 and player.global_position.z > -3.8 and transitions.is_empty(), "Walking into a 1.0 m ledge with no jump stops at the ledge and never starts a mantle")
	press_jump(player)
	var mantle_ticks: int = await ticks_in_mantle(player, 40)
	measure("ticks in MANTLE for a 1.0 m ledge", mantle_ticks, "ticks")
	ok(absf(player.global_position.y - 1.0) < 0.02 and player.global_position.z < -4.3, "A jump press against a 1.0 m ledge ends on top of it")
	ok(transitions == ["GROUND>MANTLE", "MANTLE>GROUND"] and jumps == 0, "The jump press at the 1.0 m ledge goes GROUND to MANTLE to GROUND, with no jump")
	ok(mantle_ticks >= 24 and mantle_ticks <= 25, "The mantle takes mantle_time, 0.4 s, within one tick")
	player.teleport(Vector3(10.0, 0.0, 0.0), 0.0)
	player.intent.jump_held = false
	clear_events()
	await push_into_wall(player)
	press_jump(player)
	await ticks(90)
	ok(player.global_position.y < 0.05 and player.global_position.z > -3.8, "A 1.5 m ledge is above mantle_max_height, so it blocks the body")
	ok(not transitions.has("GROUND>MANTLE") and not transitions.has("AIR>MANTLE") and jumps == 1, "A jump press at the 1.5 m ledge is a normal jump and never starts a mantle")
	player.intent.jump_held = false
	player.teleport(Vector3(0.0, 0.0, 0.0), 0.0)
	player.intent.move = Vector2(0.0, -1.0)
	clear_events()
	await ticks(60)
	ok(transitions.is_empty() and player.global_position.z > 0.0, "Walking away from a wall never starts a mantle")
	await finish(level)


func jump_toward_ledge(player: Player, run_up: float) -> void:
	player.intent.move = Vector2(0.0, 1.0)
	while player.global_position.z > -run_up:
		await tree.physics_frame
	press_jump(player)


func test_mantle_in_air() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	add_ledge(level, 10.0, 2.0)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 4.0), 0.0)
	await ticks(5)
	await jump_toward_ledge(player, 0.15)
	await ticks(90)
	ok(absf(player.global_position.y - 1.0) < 0.02 and player.global_position.z < -4.3, "A running jump that is too short for a 1.0 m ledge ends on top of it")
	ok(transitions == ["GROUND>AIR", "AIR>MANTLE", "MANTLE>GROUND"], "The short jump goes GROUND to AIR to MANTLE to GROUND")
	player.teleport(Vector3(10.0, 0.0, 4.0), 0.0)
	clear_events()
	await jump_toward_ledge(player, 0.15)
	await ticks(90)
	ok(player.global_position.y < 0.05 and not transitions.has("AIR>MANTLE"), "A jump at a 2.0 m ledge does not mantle, because the reach is measured from the last floor")
	player.teleport(Vector3(0.0, 0.0, 4.0), 0.0)
	player.intent.jump_held = false
	clear_events()
	await jump_toward_ledge(player, 0.15)
	await tree.physics_frame
	player.intent.jump_held = false
	await ticks(90)
	ok(player.global_position.y < 0.05 and not transitions.has("AIR>MANTLE"), "A short jump with jump released before the ledge does not mantle")
	await finish(level)


func test_mantle_headroom() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	add_box(level, Vector3(6.0, 0.5, 4.0), Vector3(0.0, 2.15, -6.0))
	add_ledge(level, 10.0, 1.0)
	add_box(level, Vector3(6.0, 0.5, 4.0), Vector3(10.0, 2.65, -6.0))
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 0.0), 0.0)
	await ticks(5)
	await push_into_wall(player)
	press_jump(player)
	await ticks(1)
	player.intent.jump_held = false
	await ticks(90)
	ok(player.global_position.y < 0.05 and not transitions.has("GROUND>MANTLE"), "A ledge with a ceiling too low even for a crouched body is refused")
	ok(player.stance == Player.Stance.STAND, "A refused mantle leaves the stance unchanged")
	player.teleport(Vector3(10.0, 0.0, 0.0), 0.0)
	await ticks(5)
	clear_events()
	await push_into_wall(player)
	press_jump(player)
	await ticks(30)
	ok(absf(player.global_position.y - 1.0) < 0.02 and transitions == ["GROUND>MANTLE", "MANTLE>GROUND"], "A ledge with a ceiling that fits a crouched body but not a standing one is climbed")
	ok(player.stance == Player.Stance.CROUCH, "The body ends the mantle crouched under that ceiling")
	await ticks(120)
	ok(player.global_position.z < -8.3 and player.stance == Player.Stance.STAND, "The body stands up once it walks out from under the ceiling")
	await finish(level)


func test_mantle_route() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 3.0), 0.0)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	await ticks(60)
	press_jump(player)
	await ticks(40)
	player.look(deg_to_rad(90.0), 0.0)
	await ticks(20)
	player.intent.move = Vector2.ZERO
	await ticks(30)
	var position: Vector3 = player.global_position
	measure("route end x", position.x, "m")
	measure("route end y", position.y, "m")
	measure("route end z", position.z, "m")
	ok(position.distance_to(Vector3(-2.619, 1.0, -6.518)) < 0.02, "The scripted route that walks, jumps to mantle a 1.0 m ledge, turns left and walks on ends at the expected position")
	ok(transitions == ["GROUND>MANTLE", "MANTLE>GROUND"], "The scripted route mantles exactly once")
	await finish(level)


func start_slide(level: Node3D, at: Vector3, facing: float) -> Player:
	var player: Player = spawn(level, tuning(), at, facing)
	await ticks(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await ticks(30)
	player.intent.crouch_held = true
	await ticks(1)
	return player


func test_slope_slide() -> void:
	var flat: Node3D = make_level()
	var flat_player: Player = await start_slide(flat, Vector3.ZERO, 0.0)
	var flat_entry: float = flat_player.horizontal_speed()
	await ticks(30)
	var flat_speed: float = flat_player.horizontal_speed()
	var flat_sliding: bool = flat_player.move_state == Player.MoveState.SLIDE
	await finish(flat)
	var hill: Node3D = make_level()
	var slope: float = deg_to_rad(20.0)
	add_box(hill, Vector3(6.0, 1.0, 40.0), Vector3(0.0, 0.0, 0.0), Basis(Vector3.RIGHT, slope))
	var top_z: float = -15.0
	var top_y: float = -top_z * tan(slope) + 0.5 / cos(slope)
	var ramp_player: Player = await start_slide(hill, Vector3(0.0, top_y + 0.05, top_z), PI)
	var ramp_entry: float = ramp_player.horizontal_speed()
	await ticks(30)
	var ramp_speed: float = ramp_player.horizontal_speed()
	var ramp_sliding: bool = ramp_player.move_state == Player.MoveState.SLIDE
	measure("flat slide entry speed", flat_entry, "m/s")
	measure("flat slide speed 0.5 s after entry", flat_speed, "m/s")
	measure("20 degree downhill slide entry speed", ramp_entry, "m/s")
	measure("20 degree downhill slide speed 0.5 s after entry", ramp_speed, "m/s")
	ok(flat_sliding and absf(flat_speed - 10.64) < 0.02, "A flat slide loses 6.5 m/s per second, so 0.5 s after entry it has 10.64 m/s")
	ok(ramp_sliding and absf(ramp_entry - 14.03) < 0.02 and absf(ramp_speed - 14.96) < 0.02, "A slide down a 20 degree ramp gains speed from 14.03 m/s at entry to 14.96 m/s 0.5 s later, because g sin(20) is 1.85 m/s² more than 6.5 m/s²")
	await finish(hill)


func test_landed_signal() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3(0.0, 2.0, 0.0), 0.0)
	await ticks(60)
	measure("impact speed after a 2 m drop", landings[0] if landings.size() > 0 else 0.0, "m/s")
	ok(landings.size() == 1 and landings[0] > 10.5 and landings[0] < 12.5, "A 2 m drop emits landed once with an impact speed near 11.5 m/s")
	press_jump(player)
	await ticks(60)
	ok(landings.size() == 2 and landings[1] > 8.0, "A jump from the floor emits landed once more with a positive impact speed")
	await finish(level)


func test_camera_rig() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3(3.0, 0.0, 4.0), 0.0)
	ok(player.camera.global_position.distance_to(Vector3(3.0, 1.65, 4.0)) < 0.01, "Spawn teleport places the camera at eye height with no smoothing")
	await ticks(30)
	player.teleport(Vector3(-20.0, 0.0, 10.0), 0.0)
	ok(player.camera.global_position.distance_to(Vector3(-20.0, 1.65, 10.0)) < 0.01, "A second teleport moves the camera at once")
	await ticks(60)
	var idle_fov: float = player.camera.fov
	measure("idle vertical FOV", idle_fov, "deg")
	ok(absf(idle_fov - 58.72) < 0.1, "Standing still settles at 90 degrees horizontal FOV, 58.72 degrees vertical at 16:9")
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await ticks(90)
	var sprint_fov: float = player.camera.fov
	measure("sprint vertical FOV", sprint_fov, "deg")
	ok(sprint_fov > 62.5, "Sprinting at 10.5 m/s widens the vertical FOV above 62.5 degrees")
	var offset: Vector3 = player.camera.global_position - player.global_position
	ok(Vector2(offset.x, offset.z).length() < 0.25 and offset.y > 1.55 and offset.y < 1.75, "Camera follows the moving body at about 1.65 m eye height")
	player.intent.move = Vector2.ZERO
	player.intent.crouch_held = true
	await ticks(60)
	offset = player.camera.global_position - player.global_position
	ok(absf(offset.y - 1.0) < 0.05, "Crouching lowers the camera to 1.0 m eye height")
	await finish(level)


func test_player_input() -> void:
	var level: Node3D = make_level()
	var player: Player = Player.new()
	player.settings = tuning()
	level.add_child(player)
	player.teleport(Vector3.ZERO, 0.0)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await ticks(60)
	ok(absf(player.horizontal_speed() - 10.5) <= 0.21 and player.velocity.z < -10.0, "Held move_forward and sprint actions drive a player-controlled body at 10.5 m/s toward -Z")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	Input.action_press(&"look_right")
	await ticks(30)
	Input.action_release(&"look_right")
	var turned: float = rad_to_deg(-player.yaw)
	measure("gamepad turn in 0.5 s at full stick", turned, "deg")
	ok(turned > 100.0 and turned < 140.0, "Full right stick turns the view right by about 120 degrees in 0.5 s (240 degrees per second)")
	await finish(level)


func test_player_health() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	player.take_damage(30.0)
	ok(player.health == 70.0, "30 damage leaves 70 health")
	await ticks(234)
	ok(player.health == 70.0, "3.9 s after the damage there is no regeneration")
	await ticks(24)
	measure("health 4.3 s after 30 damage", player.health, "hp")
	ok(player.health > 83.0 and player.health < 86.0, "0.3 s into regeneration at 50 per second the health is near 85")
	await ticks(42)
	ok(player.health == 100.0, "5.0 s after the damage the health is back at 100 and stops there")
	var dying: Player = spawn(level, tuning(), Vector3(5.0, 0.0, 0.0), 0.0)
	dying.player_controlled = true
	dying.intent.move = Vector2(0.0, 1.0)
	var healths: Array[float] = []
	var deaths: Array[int] = [0]
	dying.health_changed.connect(func(value: float, _max_health: float) -> void: healths.append(value))
	dying.died.connect(func() -> void: deaths[0] += 1)
	dying.take_damage(40.0)
	dying.take_damage(40.0)
	dying.take_damage(40.0)
	dying.take_damage(40.0)
	ok(healths == [60.0, 20.0, 0.0] and deaths[0] == 1, "Three 40 damage hits report 60, 20, 0 and one death, and a fourth hit changes nothing")
	ok(not dying.alive and not dying.player_controlled and dying.intent.move == Vector2.ZERO, "A dead player is not alive, not player controlled, and has no move intent")
	await ticks(30)
	ok(dying.health == 0.0 and dying.horizontal_speed() < 0.01, "A dead player does not regenerate or move")
	await finish(level)
