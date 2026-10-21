extends SceneTree

const TICK: float = 1.0 / 60.0

var checks: int = 0
var failures: int = 0
var jumps: int = 0
var landings: Array[float] = []
var transitions: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)


func measure(label: String, value: float, unit: String) -> void:
	print("MEASURE: %s = %.3f %s" % [label, value, unit])


func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func run() -> void:
	print("Physics engine setting: %s" % str(ProjectSettings.get_setting("physics/3d/physics_engine")))
	test_rules()
	test_round_director_start()
	test_round_director_spawn_cap()
	test_round_director_game_over()
	test_points()
	test_arsenal()
	test_loadout()
	test_wall_buy_offer()
	test_mystery_box()
	test_perks()
	await test_ground_speed()
	await test_jump_height()
	await test_air_control()
	await test_coyote_time()
	await test_jump_buffer()
	await test_sprint_and_slide()
	await test_slide_jump_and_landing_slide()
	await test_stairs()
	await test_staircases()
	await test_ceiling()
	await test_mantle()
	await test_mantle_in_air()
	await test_mantle_headroom()
	await test_camera_on_mantle()
	await test_mantle_route()
	await test_slope_slide()
	await test_landed_signal()
	await test_camera_rig()
	await test_camera_on_stairs()
	await test_player_input()
	await test_player_health()
	await test_weapon()
	await test_melee()
	await test_weapon_switch()
	await test_shotgun()
	await test_arena_navigation()
	await test_zombie()
	await test_game()
	await test_game_melee()
	await test_game_stations()
	await test_perk_effects()
	await test_game_perks()
	test_pick_spawn()
	await test_zones()
	await test_doors()
	await test_power()
	await test_secret()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func tuning() -> PlayerSettings:
	var values: PlayerSettings = PlayerSettings.new()
	values.capsule_radius = 0.35
	values.stand_height = 1.8
	values.crouch_height = 1.1
	values.stand_eye_height = 1.65
	values.crouch_eye_height = 1.0
	values.step_height = 0.35
	values.floor_max_angle_degrees = 46.0
	values.walk_speed = 7.0
	values.sprint_speed = 10.5
	values.crouch_speed = 3.5
	values.ground_acceleration = 12.0
	values.ground_friction = 8.0
	values.stop_speed = 3.0
	values.jump_height = 1.25
	values.jump_time_to_apex = 0.32
	values.fall_gravity_multiplier = 1.35
	values.jump_cut_multiplier = 0.5
	values.coyote_time = 0.12
	values.jump_buffer_time = 0.12
	values.terminal_fall_speed = 50.0
	values.air_acceleration = 10.0
	values.air_max_wish_speed = 5.0
	values.slide_min_speed = 8.0
	values.slide_boost = 3.5
	values.slide_max_speed = 15.0
	values.slide_deceleration = 6.5
	values.slide_exit_speed = 4.0
	values.slide_cooldown = 0.6
	values.slide_steer_acceleration = 8.0
	values.mantle_max_height = 1.2
	values.mantle_time = 0.4
	values.base_fov = 90.0
	values.fov_kick_max = 12.0
	values.fov_kick_full_speed = 15.0
	values.fov_smoothing = 6.0
	values.strafe_roll_degrees = 2.0
	values.roll_smoothing = 8.0
	values.head_bob_enabled = true
	values.head_bob_amplitude = 0.035
	values.head_bob_frequency = 1.4
	values.eye_height_smoothing = 12.0
	values.step_smoothing = 14.0
	values.landing_dip_per_speed = 0.01
	values.landing_dip_max = 0.2
	values.landing_dip_frequency = 10.0
	return values


func make_level() -> Node3D:
	var level: Node3D = Node3D.new()
	root.add_child(level)
	add_box(level, Vector3(400.0, 1.0, 400.0), Vector3(0.0, -0.5, 0.0))
	return level


func add_box(level: Node3D, size: Vector3, center: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = box
	var body: StaticBody3D = StaticBody3D.new()
	body.add_child(shape)
	body.transform = Transform3D(basis, center)
	level.add_child(body)


func spawn(level: Node3D, values: PlayerSettings, at: Vector3, facing: float) -> Player:
	var player: Player = Player.new()
	player.settings = values
	player.player_controlled = false
	level.add_child(player)
	player.teleport(at, facing)
	player.jumped.connect(func() -> void: jumps += 1)
	player.landed.connect(func(impact_speed: float) -> void: landings.append(impact_speed))
	player.move_state_changed.connect(func(previous: Player.MoveState, current: Player.MoveState) -> void:
		transitions.append("%s>%s" % [Player.MoveState.find_key(previous), Player.MoveState.find_key(current)]))
	return player


func clear_events() -> void:
	jumps = 0
	landings.clear()
	transitions.clear()


func finish(level: Node3D) -> void:
	level.queue_free()
	await physics_frame
	clear_events()


func press_jump(player: Player) -> void:
	player.intent.jump_pressed = true
	player.intent.jump_held = true


func wait_for_state(player: Player, state: Player.MoveState, limit: int) -> int:
	for tick: int in range(1, limit + 1):
		await physics_frame
		if player.move_state == state:
			return tick
	return -1


func test_ground_speed() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	check(player.move_state == Player.MoveState.GROUND and player.horizontal_speed() == 0.0, "Spawned body rests on the floor in GROUND with no speed")
	player.intent.move = Vector2(0.0, 1.0)
	var ticks_to_ninety: int = -1
	for tick: int in range(1, 31):
		await physics_frame
		if ticks_to_ninety < 0 and player.horizontal_speed() >= 6.3:
			ticks_to_ninety = tick
	measure("time to 90% walk speed", ticks_to_ninety * TICK, "s")
	check(ticks_to_ninety > 0 and ticks_to_ninety * TICK <= 0.15, "Holding forward from rest reaches 6.3 m/s (90% of 7.0) within 0.15 s")
	var start_z: float = player.global_position.z
	await frames(60)
	var covered: float = start_z - player.global_position.z
	measure("settled walk speed", player.horizontal_speed(), "m/s")
	check(absf(player.horizontal_speed() - 7.0) <= 0.14, "Holding forward settles within 2% of 7.0 m/s")
	check(absf(covered - 7.0) <= 0.14, "With yaw 0 the body covers 7.0 m toward -Z in one second of walking")
	player.intent.move = Vector2.ZERO
	var ticks_to_stop: int = -1
	for tick: int in range(1, 61):
		await physics_frame
		if player.horizontal_speed() < 0.01:
			ticks_to_stop = tick
			break
	measure("stop time from walk speed", ticks_to_stop * TICK, "s")
	check(ticks_to_stop > 0 and ticks_to_stop * TICK <= 0.25, "Releasing input stops the body from 7.0 m/s within 0.25 s")
	player.look(PI * 0.5, 0.0)
	player.intent.move = Vector2(0.0, 1.0)
	await frames(30)
	check(player.velocity.x < -6.5 and absf(player.velocity.z) < 0.1, "After look() turns 90 degrees left, forward input moves the body toward -X")
	await finish(level)


func test_jump_height() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	var start_y: float = player.global_position.y
	press_jump(player)
	var apex: float = 0.0
	var apex_tick: int = 0
	for tick: int in range(1, 61):
		await physics_frame
		var height: float = player.global_position.y - start_y
		if height > apex:
			apex = height
			apex_tick = tick
	measure("held jump apex", apex, "m")
	measure("held jump time to apex", apex_tick * TICK, "s")
	check(jumps == 1, "Jump press emits jumped once")
	check(absf(apex - 1.25) <= 0.0625, "Held jump peaks at 1.25 m within 5%")
	check(absf(apex_tick * TICK - 0.32) <= 0.034, "Held jump reaches its apex about 0.32 s after the press")
	check(player.move_state == Player.MoveState.GROUND, "Body is back in GROUND one second after the jump")
	player.intent.jump_held = false
	await frames(5)
	press_jump(player)
	await frames(3)
	player.intent.jump_held = false
	var tap_apex: float = 0.0
	for tick: int in range(1, 61):
		await physics_frame
		tap_apex = maxf(tap_apex, player.global_position.y - start_y)
	measure("tap jump apex (released after 0.05 s)", tap_apex, "m")
	check(tap_apex > 0.25 and tap_apex < 0.6, "Jump released after 0.05 s peaks between 0.25 m and 0.6 m, clearly below the 1.25 m held jump")
	player.intent.jump_pressed = true
	var bot_apex: float = 0.0
	for tick: int in range(1, 61):
		await physics_frame
		bot_apex = maxf(bot_apex, player.global_position.y - start_y)
	check(absf(bot_apex - 1.25) <= 0.0625, "A jump press with jump_held never set gives the full 1.25 m jump, because only a release cuts the jump")
	await finish(level)


func test_air_control() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	press_jump(player)
	var air_speed: float = 0.0
	for tick: int in range(90):
		await physics_frame
		if player.move_state != Player.MoveState.AIR:
			break
		air_speed = player.horizontal_speed()
	measure("air speed from a standing jump with forward held", air_speed, "m/s")
	check(air_speed >= 4.5, "Holding forward during a standing jump gives at least 4.5 m/s before landing")
	await frames(60)
	press_jump(player)
	await frames(1)
	player.intent.move = Vector2(1.0, 0.0)
	var air_velocity: Vector3 = player.velocity
	for tick: int in range(90):
		await physics_frame
		if player.move_state != Player.MoveState.AIR:
			break
		air_velocity = player.velocity
	var turn: float = rad_to_deg(Vector2(air_velocity.x, -air_velocity.z).angle_to(Vector2(0.0, 1.0)))
	measure("path turn from a walk jump with only the right key held", turn, "deg")
	check(turn >= 30.0, "Holding only the right key during a walk jump turns the path right by at least 30 degrees")
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(60)
	press_jump(player)
	await frames(1)
	player.intent.move = Vector2(1.0, 0.0)
	for tick: int in range(25):
		player.look(-0.02, 0.0)
		await physics_frame
	measure("air strafe speed after 25 ticks from 10.5 m/s", player.horizontal_speed(), "m/s")
	check(player.move_state == Player.MoveState.AIR and player.horizontal_speed() >= 11.0, "Strafing while turning in the air raises speed from 10.5 m/s to at least 11.0 m/s")
	await finish(level)


func test_coyote_time() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(10.0, 4.0, 10.0), Vector3(0.0, 2.0, 0.0))
	var player: Player = spawn(level, tuning(), Vector3(0.0, 4.0, 0.0), 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	var left_at: int = await wait_for_state(player, Player.MoveState.AIR, 120)
	check(left_at > 0 and jumps == 0, "Walking off a 4 m ledge enters AIR without a jump")
	await frames(3)
	press_jump(player)
	await frames(1)
	check(jumps == 1 and player.velocity.y > 0.0, "Jump pressed 0.05 s after leaving the ledge jumps (coyote time)")
	player.teleport(Vector3(0.0, 4.0, 0.0), 0.0)
	clear_events()
	await frames(5)
	left_at = await wait_for_state(player, Player.MoveState.AIR, 120)
	await frames(15)
	press_jump(player)
	await frames(2)
	check(jumps == 0 and player.velocity.y < 0.0, "Jump pressed 0.25 s after leaving the ledge does not jump")
	await wait_for_state(player, Player.MoveState.GROUND, 120)
	await frames(5)
	check(jumps == 0 and landings.size() == 1, "The late press expires before landing, so the landing does not jump")
	await finish(level)


func test_jump_buffer() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3(0.0, 2.5, 0.0), 0.0)
	check(player.move_state == Player.MoveState.AIR, "Teleport to 2.5 m above the floor starts in AIR")
	press_jump(player)
	await frames(1)
	player.intent.jump_held = false
	await wait_for_state(player, Player.MoveState.GROUND, 120)
	await frames(3)
	check(jumps == 0 and player.move_state == Player.MoveState.GROUND, "Jump pressed 0.39 s before landing is not kept until the landing")
	player.teleport(Vector3(0.0, 2.5, 0.0), 0.0)
	clear_events()
	var pressed: bool = false
	for tick: int in range(120):
		await physics_frame
		if not pressed and player.global_position.y < 0.45:
			press_jump(player)
			pressed = true
		if landings.size() > 0:
			break
	check(pressed and landings.size() == 1, "Body falls and lands once after the late press")
	await frames(2)
	check(jumps == 1 and player.velocity.y > 0.0, "Jump pressed just before landing jumps on the landing tick (jump buffer)")
	var rise: float = 0.0
	for tick: int in range(30):
		await physics_frame
		rise = maxf(rise, player.global_position.y)
	check(rise > 1.0, "The buffered jump rises above 1.0 m")
	await finish(level)


func test_sprint_and_slide() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(60)
	measure("sprint speed", player.horizontal_speed(), "m/s")
	check(absf(player.horizontal_speed() - 10.5) <= 0.21, "Sprint settles within 2% of 10.5 m/s")
	clear_events()
	player.intent.crouch_held = true
	await frames(1)
	check(player.move_state == Player.MoveState.SLIDE and player.stance == Player.Stance.CROUCH, "Crouch press at sprint speed starts a crouched SLIDE")
	var peak: float = player.horizontal_speed()
	measure("slide speed on the first tick", peak, "m/s")
	check(peak >= 13.5 and peak <= 14.0, "Slide boost lifts 10.5 m/s to between 13.5 and 14.0 m/s")
	var slide_ticks: int = await wait_for_state(player, Player.MoveState.GROUND, 240)
	measure("flat slide duration", slide_ticks * TICK, "s")
	check(slide_ticks * TICK >= 1.5 and slide_ticks * TICK <= 1.6, "A flat slide from 13.89 m/s lasts between 1.5 s and 1.6 s before it drops below 4.0 m/s")
	check(player.horizontal_speed() < 4.0, "Slide ends when speed drops below 4.0 m/s")
	check(transitions == ["GROUND>SLIDE", "SLIDE>GROUND"], "move_state_changed reports GROUND>SLIDE then SLIDE>GROUND")
	check(player.stance == Player.Stance.CROUCH, "Body stays crouched after the slide while crouch is held")
	player.intent.crouch_held = false
	player.intent.sprint_held = true
	await frames(60)
	clear_events()
	player.intent.crouch_held = true
	await frames(1)
	player.intent.crouch_held = false
	await frames(1)
	player.intent.crouch_held = true
	await frames(1)
	check(transitions == ["GROUND>SLIDE", "SLIDE>GROUND"], "A second crouch press inside the 0.6 s cooldown does not start a slide")
	await finish(level)


func test_slide_jump_and_landing_slide() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(60)
	player.intent.crouch_held = true
	await frames(5)
	clear_events()
	press_jump(player)
	await frames(1)
	var takeoff: float = player.horizontal_speed()
	await frames(15)
	measure("speed 0.25 s after a slide jump", player.horizontal_speed(), "m/s")
	check(transitions == ["SLIDE>AIR"] and player.horizontal_speed() > 12.5, "Jumping out of a slide carries more than 12.5 m/s into the air")
	check(absf(player.horizontal_speed() - takeoff) < 0.05, "Holding forward in the air after a slide jump loses no horizontal speed")
	await wait_for_state(player, Player.MoveState.SLIDE, 90)
	check(transitions == ["SLIDE>AIR", "AIR>SLIDE"] and landings.size() == 1, "Landing with crouch held at slide speed goes straight into SLIDE and emits landed")
	await finish(level)


func test_stairs() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(4.0, 0.3, 10.0), Vector3(0.0, 0.15, -8.0))
	add_box(level, Vector3(4.0, 0.35, 10.0), Vector3(10.0, 0.175, -8.0))
	add_box(level, Vector3(4.0, 0.6, 10.0), Vector3(20.0, 0.3, -8.0))
	var values: PlayerSettings = tuning()
	var player: Player = spawn(level, values, Vector3(0.0, 0.0, 2.0), 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	var entered: int = -1
	var exited: int = -1
	var slowest: float = INF
	for tick: int in range(1, 121):
		await physics_frame
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
	check(absf(player.global_position.y - 0.3) < 0.02, "Walking into a 0.3 m step ends on top of it")
	check(crossing_speed >= 5.6, "Crossing the 0.3 m step averages at least 5.6 m/s (80% of 7.0)")
	check(transitions.is_empty(), "Climbing the 0.3 m step never leaves GROUND")
	player.teleport(Vector3(0.0, 0.3, -8.0), PI)
	clear_events()
	await frames(60)
	check(absf(player.global_position.y) < 0.02 and transitions.is_empty(), "Walking down off the 0.3 m step stays in GROUND and ends on the floor")
	player.teleport(Vector3(10.0, 0.0, 2.0), 0.0)
	player.intent.crouch_held = true
	clear_events()
	await frames(120)
	check(absf(player.global_position.y - 0.35) < 0.02 and transitions.is_empty(), "Crouch walking into a 0.35 m step climbs it")
	player.intent.crouch_held = false
	player.teleport(Vector3(20.0, 0.0, 2.0), 0.0)
	clear_events()
	await frames(120)
	check(player.global_position.y < 0.05 and player.global_position.z > -2.7 and transitions.is_empty(), "A 0.6 m step blocks the body when it walks with no jump")
	await finish(level)


func add_staircase(level: Node3D, x: float, riser: float, tread: float, count: int) -> void:
	for step: int in range(count):
		var height: float = riser * (step + 1)
		add_box(level, Vector3(3.0, height, tread), Vector3(x, height * 0.5, -3.0 - tread * (step + 0.5)))
	var top: float = riser * count
	add_box(level, Vector3(3.0, top, 6.0), Vector3(x, top * 0.5, -6.0 - tread * count))


func test_staircases() -> void:
	var level: Node3D = make_level()
	add_staircase(level, 0.0, 0.2, 0.3, 8)
	add_staircase(level, 5.0, 0.35, 0.35, 5)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 0.0), 0.0)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.crouch_held = true
	await frames(180)
	check(absf(player.global_position.y - 1.6) < 0.02 and transitions.is_empty(), "Crouch walking climbs eight 0.2 m steps with 0.3 m treads to 1.6 m without leaving GROUND")
	player.intent.crouch_held = false
	player.teleport(Vector3(5.0, 1.75, -6.0), PI)
	clear_events()
	await frames(90)
	check(absf(player.global_position.y) < 0.02 and transitions.is_empty(), "Walking down five 0.35 m steps with 0.35 m treads stays in GROUND to the floor")
	player.teleport(Vector3(1.5, 0.0, 0.0), deg_to_rad(-30.0))
	var highest: float = 0.0
	for tick: int in range(90):
		await physics_frame
		highest = maxf(highest, player.global_position.y)
	check(absf(highest - 1.75) < 0.02, "Walking at 30 degrees into the corner of the 0.35 m staircase climbs it from the side to 1.75 m")
	await finish(level)


func test_ceiling() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(4.0, 0.3, 6.0), Vector3(0.0, 1.45, -6.0))
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.crouch_held = true
	await frames(75)
	check(player.global_position.z < -3.4 and player.stance == Player.Stance.CROUCH, "Crouched body walks under the 1.3 m ceiling")
	player.intent.crouch_held = false
	await frames(10)
	check(player.stance == Player.Stance.CROUCH and absf(player.global_position.y) < 0.02, "Releasing crouch under the ceiling keeps the body crouched on the floor")
	for tick: int in range(150):
		await physics_frame
		if player.global_position.z < -9.5:
			break
	await frames(2)
	check(player.global_position.z < -9.5 and player.stance == Player.Stance.STAND, "Body stands up after it clears the ceiling")
	await finish(level)


func add_ledge(level: Node3D, x: float, height: float) -> void:
	add_box(level, Vector3(6.0, height, 10.0), Vector3(x, height * 0.5, -9.0))


func ticks_in_mantle(player: Player, limit: int) -> int:
	var count: int = 0
	for tick: int in range(limit):
		await physics_frame
		if player.move_state == Player.MoveState.MANTLE:
			count += 1
	return count


func push_into_wall(player: Player) -> void:
	player.intent.move = Vector2(0.0, 1.0)
	await frames(10)
	for tick: int in range(120):
		await physics_frame
		if player.horizontal_speed() < 0.1:
			return


func test_mantle() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	add_ledge(level, 10.0, 1.5)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 0.0), 0.0)
	await frames(5)
	await push_into_wall(player)
	await frames(30)
	check(player.global_position.y < 0.05 and player.global_position.z > -3.8 and transitions.is_empty(), "Walking into a 1.0 m ledge with no jump stops at the ledge and never starts a mantle")
	press_jump(player)
	var mantle_ticks: int = await ticks_in_mantle(player, 40)
	measure("ticks in MANTLE for a 1.0 m ledge", mantle_ticks, "ticks")
	check(absf(player.global_position.y - 1.0) < 0.02 and player.global_position.z < -4.3, "A jump press against a 1.0 m ledge ends on top of it")
	check(transitions == ["GROUND>MANTLE", "MANTLE>GROUND"] and jumps == 0, "The jump press at the 1.0 m ledge goes GROUND to MANTLE to GROUND, with no jump")
	check(mantle_ticks >= 24 and mantle_ticks <= 25, "The mantle takes mantle_time, 0.4 s, within one tick")
	player.teleport(Vector3(10.0, 0.0, 0.0), 0.0)
	player.intent.jump_held = false
	clear_events()
	await push_into_wall(player)
	press_jump(player)
	await frames(90)
	check(player.global_position.y < 0.05 and player.global_position.z > -3.8, "A 1.5 m ledge is above mantle_max_height, so it blocks the body")
	check(not transitions.has("GROUND>MANTLE") and not transitions.has("AIR>MANTLE") and jumps == 1, "A jump press at the 1.5 m ledge is a normal jump and never starts a mantle")
	player.intent.jump_held = false
	player.teleport(Vector3(0.0, 0.0, 0.0), 0.0)
	player.intent.move = Vector2(0.0, -1.0)
	clear_events()
	await frames(60)
	check(transitions.is_empty() and player.global_position.z > 0.0, "Walking away from a wall never starts a mantle")
	await finish(level)


func jump_toward_ledge(player: Player, run_up: float) -> void:
	player.intent.move = Vector2(0.0, 1.0)
	while player.global_position.z > -run_up:
		await physics_frame
	press_jump(player)


func test_mantle_in_air() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	add_ledge(level, 10.0, 2.0)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 4.0), 0.0)
	await frames(5)
	await jump_toward_ledge(player, 0.15)
	await frames(90)
	check(absf(player.global_position.y - 1.0) < 0.02 and player.global_position.z < -4.3, "A running jump that is too short for a 1.0 m ledge ends on top of it")
	check(transitions == ["GROUND>AIR", "AIR>MANTLE", "MANTLE>GROUND"], "The short jump goes GROUND to AIR to MANTLE to GROUND")
	player.teleport(Vector3(10.0, 0.0, 4.0), 0.0)
	clear_events()
	await jump_toward_ledge(player, 0.15)
	await frames(90)
	check(player.global_position.y < 0.05 and not transitions.has("AIR>MANTLE"), "A jump at a 2.0 m ledge does not mantle, because the reach is measured from the last floor")
	player.teleport(Vector3(0.0, 0.0, 4.0), 0.0)
	player.intent.jump_held = false
	clear_events()
	await jump_toward_ledge(player, 0.15)
	await physics_frame
	player.intent.jump_held = false
	await frames(90)
	check(player.global_position.y < 0.05 and not transitions.has("AIR>MANTLE"), "A short jump with jump released before the ledge does not mantle")
	await finish(level)


func test_mantle_headroom() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	add_box(level, Vector3(6.0, 0.5, 4.0), Vector3(0.0, 2.15, -6.0))
	add_ledge(level, 10.0, 1.0)
	add_box(level, Vector3(6.0, 0.5, 4.0), Vector3(10.0, 2.65, -6.0))
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 0.0), 0.0)
	await frames(5)
	await push_into_wall(player)
	press_jump(player)
	await frames(1)
	player.intent.jump_held = false
	await frames(90)
	check(player.global_position.y < 0.05 and not transitions.has("GROUND>MANTLE"), "A ledge with a ceiling too low even for a crouched body is refused")
	check(player.stance == Player.Stance.STAND, "A refused mantle leaves the stance unchanged")
	player.teleport(Vector3(10.0, 0.0, 0.0), 0.0)
	await frames(5)
	clear_events()
	await push_into_wall(player)
	press_jump(player)
	await frames(30)
	check(absf(player.global_position.y - 1.0) < 0.02 and transitions == ["GROUND>MANTLE", "MANTLE>GROUND"], "A ledge with a ceiling that fits a crouched body but not a standing one is climbed")
	check(player.stance == Player.Stance.CROUCH, "The body ends the mantle crouched under that ceiling")
	await frames(120)
	check(player.global_position.z < -8.3 and player.stance == Player.Stance.STAND, "The body stands up once it walks out from under the ceiling")
	await finish(level)


func test_camera_on_mantle() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	var values: PlayerSettings = tuning()
	values.head_bob_enabled = false
	var player: Player = spawn(level, values, Vector3(0.0, 0.0, 0.0), 0.0)
	await frames(5)
	await push_into_wall(player)
	var previous_max_fps: int = Engine.max_fps
	Engine.max_fps = 240
	press_jump(player)
	var start_tick: int = Engine.get_physics_frames()
	var last_tick: int = start_tick
	var last_body_y: float = player.global_position.y
	var last_y: float = player.camera.global_position.y
	var worst_drop: float = 0.0
	var worst_rise: float = 0.0
	var worst_body_rise: float = 0.0
	var samples: int = 0
	while Engine.get_physics_frames() - start_tick < 100:
		await process_frame
		var y: float = player.camera.global_position.y
		worst_drop = maxf(worst_drop, last_y - y)
		worst_rise = maxf(worst_rise, y - last_y)
		last_y = y
		if Engine.get_physics_frames() != last_tick:
			last_tick = Engine.get_physics_frames()
			worst_body_rise = maxf(worst_body_rise, player.global_position.y - last_body_y)
			last_body_y = player.global_position.y
		samples += 1
	Engine.max_fps = previous_max_fps
	measure("worst camera drop in one frame during a mantle", worst_drop, "m")
	measure("worst camera rise in one frame during a mantle", worst_rise, "m")
	measure("worst body rise in one tick during a mantle", worst_body_rise, "m")
	check(absf(player.global_position.y - 1.0) < 0.02 and transitions.has("GROUND>MANTLE"), "The camera test body mantles onto the 1.0 m ledge")
	check(samples > 100, "At a 240 FPS cap more frames render than physics ticks run")
	check(worst_drop <= 0.01, "During a mantle no rendered frame moves the camera down by more than 0.01 m")
	check(worst_rise <= worst_body_rise + 0.01, "During a mantle no rendered frame moves the camera up by more than the body moves in one tick")
	await finish(level)


func test_mantle_route() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	var player: Player = spawn(level, tuning(), Vector3(0.0, 0.0, 3.0), 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	await frames(60)
	press_jump(player)
	await frames(40)
	player.look(deg_to_rad(90.0), 0.0)
	await frames(20)
	player.intent.move = Vector2.ZERO
	await frames(30)
	var position: Vector3 = player.global_position
	measure("route end x", position.x, "m")
	measure("route end y", position.y, "m")
	measure("route end z", position.z, "m")
	check(position.distance_to(Vector3(-2.619, 1.0, -6.518)) < 0.02, "The scripted route that walks, jumps to mantle a 1.0 m ledge, turns left and walks on ends at the expected position")
	check(transitions == ["GROUND>MANTLE", "MANTLE>GROUND"], "The scripted route mantles exactly once")
	await finish(level)


func start_slide(level: Node3D, at: Vector3, facing: float) -> Player:
	var player: Player = spawn(level, tuning(), at, facing)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(30)
	player.intent.crouch_held = true
	await frames(1)
	return player


func test_slope_slide() -> void:
	var flat: Node3D = make_level()
	var flat_player: Player = await start_slide(flat, Vector3.ZERO, 0.0)
	var flat_entry: float = flat_player.horizontal_speed()
	await frames(30)
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
	await frames(30)
	var ramp_speed: float = ramp_player.horizontal_speed()
	var ramp_sliding: bool = ramp_player.move_state == Player.MoveState.SLIDE
	measure("flat slide entry speed", flat_entry, "m/s")
	measure("flat slide speed 0.5 s after entry", flat_speed, "m/s")
	measure("20 degree downhill slide entry speed", ramp_entry, "m/s")
	measure("20 degree downhill slide speed 0.5 s after entry", ramp_speed, "m/s")
	check(flat_sliding and absf(flat_speed - 10.64) < 0.02, "A flat slide loses 6.5 m/s per second, so 0.5 s after entry it has 10.64 m/s")
	check(ramp_sliding and absf(ramp_entry - 14.03) < 0.02 and absf(ramp_speed - 14.96) < 0.02, "A slide down a 20 degree ramp gains speed from 14.03 m/s at entry to 14.96 m/s 0.5 s later, because g sin(20) is 1.85 m/s² more than 6.5 m/s²")
	await finish(hill)


func test_landed_signal() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3(0.0, 2.0, 0.0), 0.0)
	await frames(60)
	measure("impact speed after a 2 m drop", landings[0] if landings.size() > 0 else 0.0, "m/s")
	check(landings.size() == 1 and landings[0] > 10.5 and landings[0] < 12.5, "A 2 m drop emits landed once with an impact speed near 11.5 m/s")
	press_jump(player)
	await frames(60)
	check(landings.size() == 2 and landings[1] > 8.0, "A jump from the floor emits landed once more with a positive impact speed")
	await finish(level)


func test_camera_rig() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3(3.0, 0.0, 4.0), 0.0)
	check(player.camera.global_position.distance_to(Vector3(3.0, 1.65, 4.0)) < 0.01, "Spawn teleport places the camera at eye height with no smoothing")
	await frames(30)
	player.teleport(Vector3(-20.0, 0.0, 10.0), 0.0)
	check(player.camera.global_position.distance_to(Vector3(-20.0, 1.65, 10.0)) < 0.01, "A second teleport moves the camera at once")
	await frames(60)
	var idle_fov: float = player.camera.fov
	measure("idle vertical FOV", idle_fov, "deg")
	check(absf(idle_fov - 58.72) < 0.1, "Standing still settles at 90 degrees horizontal FOV, 58.72 degrees vertical at 16:9")
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(90)
	var sprint_fov: float = player.camera.fov
	measure("sprint vertical FOV", sprint_fov, "deg")
	check(sprint_fov > 62.5, "Sprinting at 10.5 m/s widens the vertical FOV above 62.5 degrees")
	var offset: Vector3 = player.camera.global_position - player.global_position
	check(Vector2(offset.x, offset.z).length() < 0.25 and offset.y > 1.55 and offset.y < 1.75, "Camera follows the moving body at about 1.65 m eye height")
	player.intent.move = Vector2.ZERO
	player.intent.crouch_held = true
	await frames(60)
	offset = player.camera.global_position - player.global_position
	check(absf(offset.y - 1.0) < 0.05, "Crouching lowers the camera to 1.0 m eye height")
	await finish(level)


func test_camera_on_stairs() -> void:
	var level: Node3D = make_level()
	add_staircase(level, 0.0, 0.3, 0.6, 20)
	var values: PlayerSettings = tuning()
	# The head bob moves the camera down on purpose, so it is off to isolate the step.
	values.head_bob_enabled = false
	var player: Player = spawn(level, values, Vector3.ZERO, 0.0)
	await frames(5)
	var previous_max_fps: int = Engine.max_fps
	Engine.max_fps = 240
	player.intent.move = Vector2(0.0, 1.0)
	var start_tick: int = Engine.get_physics_frames()
	var last_y: float = player.camera.global_position.y
	var worst_drop: float = 0.0
	var samples: int = 0
	while player.global_position.z > -16.5 and Engine.get_physics_frames() - start_tick < 240:
		await process_frame
		var y: float = player.camera.global_position.y
		worst_drop = maxf(worst_drop, last_y - y)
		last_y = y
		samples += 1
	var ticks: int = Engine.get_physics_frames() - start_tick
	Engine.max_fps = previous_max_fps
	measure("rendered frames while climbing twenty 0.3 m steps", samples, "frames")
	measure("physics ticks while climbing twenty 0.3 m steps", ticks, "ticks")
	measure("worst camera drop in one frame while climbing", worst_drop, "m")
	check(absf(player.global_position.y - 6.0) < 0.02, "Walking up twenty 0.3 m steps with 0.6 m treads reaches the 6.0 m top")
	check(samples > ticks, "At a 240 FPS cap more frames render than physics ticks run, so frames fall between ticks")
	check(worst_drop <= 0.01, "While the body climbs, no rendered frame moves the camera down by more than 0.01 m")
	await finish(level)


func test_player_input() -> void:
	var level: Node3D = make_level()
	var player: Player = Player.new()
	player.settings = tuning()
	level.add_child(player)
	player.teleport(Vector3.ZERO, 0.0)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await frames(60)
	check(absf(player.horizontal_speed() - 10.5) <= 0.21 and player.velocity.z < -10.0, "Held move_forward and sprint actions drive a player-controlled body at 10.5 m/s toward -Z")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	Input.action_press(&"look_right")
	await frames(30)
	Input.action_release(&"look_right")
	var turned: float = rad_to_deg(-player.yaw)
	measure("gamepad turn in 0.5 s at full stick", turned, "deg")
	check(turned > 100.0 and turned < 140.0, "Full right stick turns the view right by about 120 degrees in 0.5 s (240 degrees per second)")
	await finish(level)


func test_rules() -> void:
	check([Rules.zombie_count(1), Rules.zombie_count(2), Rules.zombie_count(5), Rules.zombie_count(6), Rules.zombie_count(10), Rules.zombie_count(20)] == [6, 9, 18, 27, 53, 153], "Zombie counts for rounds 1, 2, 5, 6, 10, 20 are 6, 9, 18, 27, 53, 153")
	check([Rules.zombie_health(1), Rules.zombie_health(2), Rules.zombie_health(5), Rules.zombie_health(9)] == [150.0, 250.0, 550.0, 950.0], "Zombie health for rounds 1, 2, 5, 9 is 150, 250, 550, 950")
	check(is_equal_approx(Rules.zombie_health(10), 1045.0) and absf(Rules.zombie_health(20) - 2710.46) < 0.01, "Zombie health grows 10% per round after round 9: 1045 at round 10 and 2710.46 at round 20")
	check([Rules.spawn_interval(1), Rules.spawn_interval(2), Rules.spawn_interval(5), Rules.spawn_interval(20)] == [2.0, 1.85, 1.4, 0.5] and is_equal_approx(Rules.spawn_interval(10), 0.65), "Spawn intervals for rounds 1, 2, 5, 10, 20 are 2.0, 1.85, 1.4, 0.65, 0.5 s")
	var rolls: Array[float] = [0.0, 0.1, 0.3, 0.5, 0.9, 0.99]
	var round_one: Array[float] = []
	var round_five: Array[float] = []
	var round_ten: Array[float] = []
	for roll: float in rolls:
		round_one.append(Rules.zombie_speed(1, roll))
		round_five.append(Rules.zombie_speed(5, roll))
		round_ten.append(Rules.zombie_speed(10, roll))
	check(round_one == [1.6, 1.6, 1.6, 1.6, 1.6, 1.6], "Round 1 has only walkers at 1.6 m/s")
	check(round_five == [5.0, 5.0, 3.2, 3.2, 1.6, 1.6], "Round 5 has 24% runners, 60% joggers, and 16% walkers")
	check(round_ten == [5.0, 5.0, 5.0, 5.0, 3.2, 3.2], "Round 10 has 80% runners and 20% joggers")
	var kinds: Array[Rules.HitKind] = [Rules.HitKind.BODY, Rules.HitKind.HEAD, Rules.HitKind.MELEE]
	var hit_points: Array[int] = []
	var kill_points: Array[int] = []
	for kind: Rules.HitKind in kinds:
		hit_points.append(Rules.points_for_hit(false, kind))
		kill_points.append(Rules.points_for_hit(true, kind))
	check(hit_points == [10, 10, 10] and kill_points == [60, 100, 130], "A hit of any kind earns 10. A body kill earns 60, a headshot kill 100, and a melee kill 130")
	check([Rules.ammo_price(1000), Rules.ammo_price(1200), Rules.ammo_price(1500)] == [500, 600, 750], "Ammo for the 1000, 1200, and 1500 weapons costs 500, 600, and 750")


func describe(weapon: WeaponDef) -> String:
	return "%s %s %.1f x%d %.3f %s %d/%d %.1f %.0f %.1f" % [weapon.id, weapon.display_name, weapon.damage, weapon.pellets, weapon.fire_interval, "auto" if weapon.automatic else "semi", weapon.magazine_size, weapon.reserve_max, weapon.reload_seconds, weapon.range, weapon.spread_degrees]


func test_arsenal() -> void:
	var table: Array[String] = []
	for weapon: WeaponDef in [Arsenal.pistol(), Arsenal.smg(), Arsenal.shotgun(), Arsenal.rifle(), Arsenal.lmg(), Arsenal.marksman()]:
		table.append(describe(weapon))
	check(table == [
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
	check(pool == [&"smg", &"shotgun", &"rifle", &"lmg", &"marksman"], "The box pool is the SMG, the shotgun, the rifle, the LMG, and the marksman")


func slot_text(slot: Loadout.Slot) -> String:
	return "%s %d/%d" % [slot.def.id, slot.magazine, slot.reserve]


func loadout_text(loadout: Loadout) -> String:
	var parts: PackedStringArray = []
	for index: int in range(loadout.slots.size()):
		parts.append(("*" if index == loadout.active else "") + slot_text(loadout.slots[index]))
	return ", ".join(parts)


func test_loadout() -> void:
	var loadout: Loadout = Loadout.new(Arsenal.pistol())
	check(loadout_text(loadout) == "*pistol 8/80", "A new loadout has one slot with the pistol at 8 and 80")
	check(not loadout.cycle() and loadout.active == 0, "cycle() with one slot returns false and changes nothing")
	loadout.current().magazine = 5
	loadout.give(Arsenal.smg())
	check(loadout_text(loadout) == "pistol 5/80, *smg 30/150", "give(SMG) adds slot 2 with a full SMG and makes it active")
	loadout.give(Arsenal.rifle())
	check(loadout_text(loadout) == "pistol 5/80, *rifle 15/90" and loadout.find(&"smg") == null, "give(rifle) with two slots replaces the SMG in the hands, and the pistol keeps its ammunition")
	loadout.give(Arsenal.pistol())
	check(loadout_text(loadout) == "*pistol 8/80, rifle 15/90", "give(pistol) after 3 shots fills the pistol and makes it active")
	check(loadout.cycle() and loadout_text(loadout) == "pistol 8/80, *rifle 15/90", "cycle() with two slots makes the other slot active")
	var rifle: Loadout.Slot = loadout.find(&"rifle")
	rifle.reserve = 0
	var after_shots: bool = rifle.is_full()
	rifle.fill()
	check(not after_shots and rifle.is_full() and slot_text(rifle) == "rifle 15/90", "A slot with an empty reserve is not full, and fill() gives 15 and 90")


func offer_text(offer: Station.Offer) -> String:
	return "%s %d \"%s\" %s" % [Station.Offer.Kind.find_key(offer.kind), offer.cost, offer.label, offer.weapon.id if offer.weapon != null else &"-"]


func test_wall_buy_offer() -> void:
	var wall: WallBuy = WallBuy.new()
	wall.weapon_id = &"smg"
	wall.price = 1000
	var loadout: Loadout = Loadout.new(Arsenal.pistol())
	check(offer_text(wall.offer(loadout, Perks.new())) == "WEAPON 1000 \"Buy SMG\" smg" and loadout_text(loadout) == "*pistol 8/80", "Without the SMG the wall offers the SMG for 1000, and the offer changes nothing")
	loadout.give(Arsenal.smg())
	loadout.current().magazine = 29
	check(offer_text(wall.offer(loadout, Perks.new())) == "AMMO 500 \"Buy SMG ammo\" smg", "With 29 of 30 SMG rounds the wall offers SMG ammo for 500")
	loadout.current().fill()
	check(offer_text(wall.offer(loadout, Perks.new())) == "NONE 0 \"SMG ammo full\" -", "With full SMG ammunition the wall offers nothing and says so")
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
	check(seen == PackedStringArray(["lmg", "marksman", "rifle", "shotgun"]), "In 200 rolls from a loadout of the pistol and the SMG the box gives the shotgun, the rifle, the LMG, and the marksman, and never the SMG or the pistol")
	check(offer_text(box.offer(weapon.loadout, Perks.new())) == "BOX_ROLL 950 \"Mystery box\" -", "An idle box offers a roll for 950")
	box.accept(box.offer(weapon.loadout, Perks.new()), weapon, Perks.new())
	check(box.phase == MysteryBox.Phase.ROLLING and offer_text(box.offer(weapon.loadout, Perks.new())) == "NONE 0 \"\" -", "A rolling box offers nothing and shows no prompt")
	box.advance(3.5)
	var rolling_at: MysteryBox.Phase = box.phase
	box.advance(0.5)
	check(rolling_at == MysteryBox.Phase.ROLLING and box.phase == MysteryBox.Phase.OFFERING, "ROLLING lasts 4.0 s")
	var take: Station.Offer = box.offer(weapon.loadout, Perks.new())
	check(offer_text(take) == "BOX_TAKE 0 \"Take %s\" %s" % [box.result.display_name, box.result.id], "An offering box offers its result for 0")
	box.advance(9.5)
	var offering_at: MysteryBox.Phase = box.phase
	box.advance(0.5)
	check(offering_at == MysteryBox.Phase.OFFERING and box.phase == MysteryBox.Phase.IDLE and box.result == null, "OFFERING lasts 10.0 s, and then the weapon is gone")
	check(loadout_text(weapon.loadout) == "pistol 8/80, *smg 30/150", "A timeout gives nothing")
	box.accept(box.offer(weapon.loadout, Perks.new()), weapon, Perks.new())
	box.advance(4.0)
	var offered: StringName = box.result.id
	box.accept(box.offer(weapon.loadout, Perks.new()), weapon, Perks.new())
	check(box.phase == MysteryBox.Phase.IDLE and box.result == null and weapon.current().def.id == offered and weapon.loadout.find(&"smg") == null and weapon.state == Weapon.State.SWITCHING, "A take gives the offered weapon in place of the SMG in the hands and returns the box to IDLE")
	weapon.free()
	box.free()


func clear_round(director: RoundDirector) -> void:
	while director.phase == RoundDirector.Phase.ACTIVE:
		director.tick(0.25)
		for zombie: int in range(director.alive):
			director.zombie_died()


func test_round_director_start() -> void:
	var director: RoundDirector = RoundDirector.new()
	var events: Array[String] = []
	director.round_started.connect(func(number: int) -> void: events.append("started %d" % number))
	director.round_cleared.connect(func(number: int) -> void: events.append("cleared %d" % number))
	var early: int = director.tick(2.5)
	check(early == 0 and director.phase == RoundDirector.Phase.STARTING and director.rounds_survived() == 0, "2.5 s after the start the director is STARTING, spawns nothing, and has 0 rounds survived")
	var first: int = director.tick(0.5)
	check(first == 1 and director.phase == RoundDirector.Phase.ACTIVE and director.round_number == 1 and director.to_spawn == 5 and director.alive == 1, "At 3.0 s round 1 starts and spawns its first zombie, with 5 left to spawn")
	var spawned: Array[int] = []
	for step: int in range(4):
		spawned.append(director.tick(0.5))
	check(spawned == [0, 0, 0, 1], "The next zombie comes 2.0 s later")
	director.tick(10.0)
	check(director.to_spawn == 0 and director.alive == 6, "A 10 s tick spawns the rest of round 1, so 6 zombies are alive")
	for zombie: int in range(5):
		director.zombie_died()
	check(director.phase == RoundDirector.Phase.ACTIVE and director.rounds_survived() == 0, "With one zombie alive round 1 is still ACTIVE and 0 rounds are survived")
	director.zombie_died()
	check(director.phase == RoundDirector.Phase.INTERMISSION and director.rounds_survived() == 1, "The last death clears round 1 into INTERMISSION with 1 round survived")
	check(director.tick(9.5) == 0 and director.phase == RoundDirector.Phase.INTERMISSION, "9.5 s into the intermission there is no new round")
	check(director.tick(0.5) == 1 and director.round_number == 2 and director.to_spawn == 8, "10 s after the clear round 2 starts with 9 zombies")
	check(director.rounds_survived() == 1, "During round 2, 1 round is survived")
	check(events == ["started 1", "cleared 1", "started 2"], "Signals are round_started 1, round_cleared 1, round_started 2")


func test_round_director_spawn_cap() -> void:
	var director: RoundDirector = RoundDirector.new()
	director.tick(3.0)
	for number: int in range(1, 7):
		clear_round(director)
		director.tick(10.0)
	check(director.round_number == 7 and director.to_spawn + director.alive == 33, "After six cleared rounds round 7 has 33 zombies")
	var most_alive: int = 0
	var total: int = director.alive
	for step: int in range(2400):
		total += director.tick(1.0 / 60.0)
		most_alive = maxi(most_alive, director.alive)
	check(most_alive == 24 and director.alive == 24 and director.to_spawn == 9 and total == 24, "With no deaths in round 7, spawns stop at 24 alive and 9 wait")
	director.zombie_died()
	director.zombie_died()
	var at_once: int = director.tick(1.0 / 60.0)
	var later: int = 0
	for step: int in range(70):
		later += director.tick(1.0 / 60.0)
	check(at_once == 1 and later == 1 and director.alive == 24 and director.to_spawn == 7, "After two deaths at the cap, one zombie spawns on the next tick and one 1.1 s later")


func test_round_director_game_over() -> void:
	var director: RoundDirector = RoundDirector.new()
	var results: Array[int] = []
	director.game_over.connect(func(survived: int) -> void: results.append(survived))
	director.tick(3.0)
	clear_round(director)
	director.tick(10.0)
	director.tick(5.0)
	director.player_died()
	director.player_died()
	check(director.phase == RoundDirector.Phase.GAME_OVER and results == [1], "A death in round 2 ends the game once with 1 round survived")
	check(director.tick(30.0) == 0 and director.round_number == 2, "After GAME_OVER, tick spawns nothing and no round starts")
	var in_break: RoundDirector = RoundDirector.new()
	var break_results: Array[int] = []
	in_break.game_over.connect(func(survived: int) -> void: break_results.append(survived))
	in_break.tick(3.0)
	clear_round(in_break)
	in_break.player_died()
	check(break_results == [1], "A death in the intermission after round 1 reports 1 round survived")
	var at_start: RoundDirector = RoundDirector.new()
	at_start.player_died()
	check(at_start.rounds_survived() == 0 and at_start.phase == RoundDirector.Phase.GAME_OVER, "A death before round 1 reports 0 rounds survived")


func test_points() -> void:
	var points: Points = Points.new()
	var balances: Array[int] = []
	points.changed.connect(func(balance: int) -> void: balances.append(balance))
	points.earn(60)
	points.earn(10)
	check(points.balance == 570 and points.earned == 70, "Earning 60 and 10 from 500 gives a balance of 570 and 70 earned")
	check(points.spend(400) and points.balance == 170 and points.earned == 70, "Spending 400 of 570 succeeds and leaves 170, and earned stays 70")
	check(not points.spend(171) and points.balance == 170, "Spending 171 of 170 fails and leaves the balance at 170")
	check(balances == [560, 570, 170], "changed reports 560, 570, 170 and nothing for the failed spend")


func test_player_health() -> void:
	var level: Node3D = make_level()
	var player: Player = spawn(level, tuning(), Vector3.ZERO, 0.0)
	player.take_damage(30.0)
	check(player.health == 70.0, "30 damage leaves 70 health")
	await frames(234)
	check(player.health == 70.0, "3.9 s after the damage there is no regeneration")
	await frames(24)
	measure("health 4.3 s after 30 damage", player.health, "hp")
	check(player.health > 83.0 and player.health < 86.0, "0.3 s into regeneration at 50 per second the health is near 85")
	await frames(42)
	check(player.health == 100.0, "5.0 s after the damage the health is back at 100 and stops there")
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
	check(healths == [60.0, 20.0, 0.0] and deaths[0] == 1, "Three 40 damage hits report 60, 20, 0 and one death, and a fourth hit changes nothing")
	check(not dying.alive and not dying.player_controlled and dying.intent.move == Vector2.ZERO, "A dead player is not alive, not player controlled, and has no move intent")
	await frames(30)
	check(dying.health == 0.0 and dying.horizontal_speed() < 0.01, "A dead player does not regenerate or move")
	await finish(level)


func make_zombie(level: Node3D, at: Vector3, start_health: float, move_speed: float, target: Node3D) -> Zombie:
	var zombie: Zombie = Zombie.new()
	zombie.setup(start_health, move_speed, target)
	zombie.position = at
	level.add_child(zombie)
	return zombie


## A zombie whose target is a marker at its own feet stands still in ATTACK.
func make_still_zombie(level: Node3D, at: Vector3, start_health: float = 150.0) -> Zombie:
	var marker: Marker3D = Marker3D.new()
	marker.position = at
	level.add_child(marker)
	return make_zombie(level, at, start_health, 1.6, marker)


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
	await frames(5)
	check(weapon.current().magazine == 8 and weapon.current().reserve == 80 and weapon.state == Weapon.State.READY, "The starting pistol is READY with 8 in the magazine and 80 in reserve")
	weapon.trigger_held = true
	await frames(30)
	check(shots[0] == 1 and weapon.current().magazine == 7, "Holding the trigger of a semi-automatic weapon for 0.5 s fires once")
	check(hits == ["ahead 70.0 HEAD"], "A level shot from 1.65 m eye height hits the zombie 6 m ahead in the head for 70 damage")
	weapon.trigger_held = false
	player.look(0.0, -atan(0.65 / 5.65))
	await frames(2)
	weapon.trigger_held = true
	await frames(1)
	weapon.trigger_held = false
	check(shots[0] == 2 and hits == ["ahead 70.0 HEAD", "ahead 35.0 BODY"], "A press aimed at 1.0 m height hits the body for 35 damage")
	player.look(-PI * 0.5, atan(0.65 / 5.65))
	await frames(12)
	weapon.trigger_held = true
	await frames(1)
	weapon.trigger_held = false
	check(shots[0] == 3 and hits.size() == 2 and behind_wall.health == 150.0, "A shot at the zombie behind a wall fires but does not hit")
	for press: int in range(5):
		await frames(12)
		weapon.trigger_held = true
		await frames(1)
		weapon.trigger_held = false
	check(shots[0] == 8 and weapon.current().magazine == 0, "Eight presses empty the 8-round magazine")
	await frames(12)
	check(weapon.state == Weapon.State.RELOADING and reloads.size() == 1, "The empty magazine starts a reload by itself")
	weapon.trigger_held = true
	await frames(60)
	weapon.trigger_held = false
	check(shots[0] == 8 and weapon.state == Weapon.State.RELOADING, "Presses during the reload do not fire")
	await frames(30)
	check(weapon.state == Weapon.State.READY and weapon.current().magazine == 8 and weapon.current().reserve == 72, "After the reload the magazine has 8 and the reserve has 72")
	var reload_ticks: int = int(reloads[1].split(" ")[1]) - int(reloads[0].split(" ")[1])
	measure("reload time", reload_ticks * TICK, "s")
	check(reload_ticks == 84, "The reload takes 84 ticks, which is 1.4 s")
	weapon.trigger_held = true
	await frames(1)
	weapon.trigger_held = false
	weapon.reload_requested = true
	await frames(12)
	check(weapon.state == Weapon.State.RELOADING and weapon.current().magazine == 7, "A reload request with 7 of 8 rounds starts a reload")
	weapon.fill(&"pistol")
	check(weapon.state == Weapon.State.READY and weapon.current().magazine == 8 and weapon.current().reserve == 80, "fill() of the weapon in the hands ends its reload and fills the magazine and the reserve")
	await finish(level)


## The weapon with no spread, so a test shot goes where the camera looks.
func steady(weapon: WeaponDef) -> WeaponDef:
	weapon.spread_degrees = 0.0
	return weapon


func wait_for_weapon_state(weapon: Weapon, state: Weapon.State, limit: int) -> int:
	for tick: int in range(1, limit + 1):
		await physics_frame
		if weapon.state == state:
			return tick
	return -1


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
	await frames(5)
	weapon.melee_requested = true
	await frames(1)
	check(weapon.state == Weapon.State.MELEE and hits == ["ahead 150.0 MELEE"], "A melee hits the zombie 1.5 m ahead once for 150 damage")
	weapon.trigger_held = true
	await frames(9)
	weapon.melee_requested = true
	var shots_in_melee: int = -1
	var hits_in_melee: int = -1
	var melee_ticks: int = 10
	for tick: int in range(60):
		await physics_frame
		if weapon.state != Weapon.State.MELEE:
			break
		shots_in_melee = shots[0]
		hits_in_melee = hits.size()
		melee_ticks += 1
	weapon.trigger_held = false
	measure("melee time", melee_ticks * TICK, "s")
	check(melee_ticks == 36, "MELEE lasts 36 ticks, which is 0.6 s, and a second melee request during MELEE does not make it longer")
	check(shots_in_melee == 0 and hits_in_melee == 1, "A held trigger does not fire during MELEE, and the second melee request does not hit")
	check(shots[0] == 1 and weapon.current().magazine == 7 and hits == ["ahead 150.0 MELEE", "ahead 70.0 HEAD"], "The press held through MELEE fires once when MELEE ends")
	player.look(-PI * 0.5, 0.0)
	await frames(12)
	weapon.melee_requested = true
	await frames(1)
	check(weapon.state == Weapon.State.MELEE and hits.size() == 2, "A wall between the player and a zombie 1.6 m away blocks the melee")
	player.look(PI, 0.0)
	await frames(40)
	weapon.melee_requested = true
	await frames(1)
	check(weapon.state == Weapon.State.MELEE and hits.size() == 2, "A melee does not hit the zombie 3 m away")
	await wait_for_weapon_state(weapon, Weapon.State.READY, 40)
	weapon.reload_requested = true
	await frames(30)
	check(weapon.state == Weapon.State.RELOADING and reloads == ["started"], "A reload request with 7 of 8 rounds starts a reload")
	weapon.melee_requested = true
	await frames(1)
	check(weapon.state == Weapon.State.MELEE and weapon.current().magazine == 7 and weapon.current().reserve == 80, "A melee interrupts the reload and leaves 7 in the magazine and 80 in reserve")
	var restarted_after: int = await wait_for_weapon_state(weapon, Weapon.State.RELOADING, 40)
	check(restarted_after == 36 and reloads == ["started", "started"], "The reload starts again on the tick that MELEE ends")
	var finished_after: int = await wait_for_weapon_state(weapon, Weapon.State.READY, 120)
	check(finished_after == 84 and weapon.current().magazine == 8 and weapon.current().reserve == 79 and reloads == ["started", "started", "finished"], "The restarted reload takes the full 84 ticks and loads 1 round from the reserve")
	await finish(level)


func ticks_in_state(weapon: Weapon, state: Weapon.State, limit: int) -> int:
	var ticks: int = 0
	while weapon.state == state and ticks < limit:
		await physics_frame
		ticks += 1
	return ticks


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
	await frames(5)
	weapon.switch_requested = true
	await frames(1)
	check(weapon.state == Weapon.State.SWITCHING and weapon.current().def.id == &"pistol" and events == ["equipped pistol", "ammo 5/80"], "A switch request makes the pistol active on the first tick of SWITCHING and reports it with its 5 and 80")
	var switch_ticks: int = await ticks_in_state(weapon, Weapon.State.SWITCHING, 60)
	measure("weapon change time", switch_ticks * TICK, "s")
	check(switch_ticks == 30 and weapon.state == Weapon.State.READY, "SWITCHING lasts 30 ticks, which is 0.5 s")
	check(loadout_text(weapon.loadout) == "*pistol 5/80, smg 12/150", "A change keeps the ammunition of both slots")
	weapon.reload_requested = true
	await frames(30)
	check(weapon.state == Weapon.State.RELOADING, "A reload request with 5 of 8 rounds starts a reload")
	weapon.switch_requested = true
	await frames(1)
	check(weapon.state == Weapon.State.SWITCHING and loadout_text(weapon.loadout) == "pistol 5/80, *smg 12/150", "A change during the reload stops it with no change to the ammunition")
	await ticks_in_state(weapon, Weapon.State.SWITCHING, 60)
	weapon.switch_requested = true
	await frames(1)
	await ticks_in_state(weapon, Weapon.State.SWITCHING, 60)
	await frames(10)
	check(weapon.state == Weapon.State.READY and loadout_text(weapon.loadout) == "*pistol 5/80, smg 12/150", "Back on the pistol, the stopped reload does not start again")
	weapon.melee_requested = true
	await frames(1)
	weapon.switch_requested = true
	await frames(1)
	check(weapon.state == Weapon.State.MELEE and weapon.current().def.id == &"pistol", "A switch request during MELEE is cleared and does nothing")
	await wait_for_weapon_state(weapon, Weapon.State.READY, 60)
	weapon.equip(Arsenal.rifle())
	check(weapon.state == Weapon.State.SWITCHING and loadout_text(weapon.loadout) == "*rifle 15/90, smg 12/150", "equip() of a third weapon replaces the pistol in the hands and starts SWITCHING")
	weapon.trigger_held = true
	var fired_at: int = -1
	for tick: int in range(1, 61):
		await physics_frame
		if fired_at < 0 and shots[0] > 0:
			fired_at = tick
	weapon.trigger_held = false
	check(shots[0] == 1 and fired_at == 30 and weapon.current().magazine == 14, "A press held through SWITCHING fires one time, on the tick that SWITCHING ends")
	weapon.loadout = Loadout.new(Arsenal.pistol())
	events.clear()
	weapon.switch_requested = true
	await frames(1)
	check(weapon.state != Weapon.State.SWITCHING and events.is_empty() and weapon.loadout.active == 0, "A switch request with one slot does nothing")
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
	await frames(5)
	weapon.trigger_held = true
	await frames(1)
	weapon.trigger_held = false
	check(hits == ["ahead 200.0 BODY"] and weapon.current().magazine == 5, "A shotgun shot with no spread at a zombie 3 m ahead emits one hit for 8 x 25 = 200 damage of kind BODY")
	player.look(0.0, atan(0.65 / 2.65))
	await frames(60)
	weapon.trigger_held = true
	await frames(1)
	weapon.trigger_held = false
	check(hits == ["ahead 200.0 BODY", "ahead 400.0 HEAD"], "A level shotgun shot hits the head with all 8 pellets for 400 damage of kind HEAD")
	await finish(level)


## The navigation map takes a few physics ticks to take in the baked region.
func make_arena() -> Arena:
	var arena: Arena = Game.ARENA_SCENE.instantiate() as Arena
	root.add_child(arena)
	var map: RID = arena.get_world_3d().navigation_map
	for tick: int in range(30):
		if not NavigationServer3D.map_get_path(map, arena.player_spawn.origin, arena.spawns()[0], true).is_empty():
			break
		await physics_frame
	return arena


func arena_shape_problems(arena: Arena) -> PackedStringArray:
	var problems: PackedStringArray = []
	for node: Node in arena.find_children("*", "StaticBody3D"):
		var body: StaticBody3D = node as StaticBody3D
		var shape: BoxShape3D = (body.get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D
		var mesh: BoxMesh = (body.get_node(^"Mesh") as MeshInstance3D).mesh as BoxMesh
		if body.collision_layer != Layers.WORLD or shape.size != mesh.size:
			problems.append(str(arena.get_path_to(body)))
	return problems


func test_arena_navigation() -> void:
	var arena: Arena = await make_arena()
	check(arena.navigation.navigation_mesh.get_polygon_count() > 0 and arena.spawns().size() == 8, "The arena bakes a navigation mesh and has 8 zombie spawn points")
	check(arena.stations.size() == 13 and arena.box != null and arena.box in arena.stations, "The arena has three wall buys, the box, four perk machines, the upgrade machine, two doors, the power switch, and the cache")
	check(arena_shape_problems(arena).is_empty(), "Each static body in the arena scene is on Layers.WORLD, and its collision box is the size of its mesh box: %s" % ", ".join(arena_shape_problems(arena)))
	var nav_mesh: NavigationMesh = arena.navigation.navigation_mesh
	check(is_equal_approx(nav_mesh.agent_height, Zombie.HEIGHT) and nav_mesh.geometry_collision_mask == Layers.WORLD and is_equal_approx(nav_mesh.cell_height, NavigationServer3D.map_get_cell_height(arena.get_world_3d().navigation_map)), "The navigation mesh uses the zombie height, the world layer, and the cell height of the navigation map")
	var crate_shape: BoxShape3D = (arena.box.get_parent().get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D
	check(crate_shape.size == MysteryBox.CRATE_SIZE, "The box crate in the arena scene is MysteryBox.CRATE_SIZE")
	var map: RID = arena.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(-10.0, 0.0, -3.0), Vector3(-10.0, 1.5, -10.0), true)
	var via_ramp: bool = false
	for point: Vector3 in path:
		via_ramp = via_ramp or point.x > -6.5
	check(path.size() > 0 and absf(path[path.size() - 1].y - 1.5) < 0.3 and via_ramp, "A path from the foot of the stairs to the platform top goes around by the ramp")
	var near_box: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(10.0, 0.0, 19.5))
	measure("distance from the box center to the walkable mesh", Vector2(near_box.x - 10.0, near_box.z - 19.5).length(), "m")
	check(Vector2(near_box.x - 10.0, near_box.z - 19.5).length() >= 0.9, "The bake cuts the box crate out, so the walkable mesh is 0.9 m or more from its center")
	await finish(arena)


func test_zombie() -> void:
	var arena: Arena = await make_arena()
	var player: Player = spawn(arena, tuning(), Vector3(8.0, 0.0, 7.0), 0.0)
	var zombie: Zombie = make_zombie(arena, Vector3(8.0, 0.0, 1.0), 150.0, 3.2, player)
	var attacks: Array[float] = []
	var deaths: Array[bool] = []
	zombie.attacked.connect(func(damage: float) -> void: attacks.append(damage))
	zombie.died.connect(func(headshot: bool) -> void: deaths.append(headshot))
	var reached: int = -1
	for tick: int in range(1, 601):
		await physics_frame
		if zombie.state == Zombie.State.ATTACK:
			reached = tick
			break
	measure("time for a 3.2 m/s zombie to reach the player around a 2 m block", reached * TICK, "s")
	var offset: Vector3 = player.global_position - zombie.global_position
	check(reached > 0 and reached * TICK < 6.0 and Vector2(offset.x, offset.z).length() <= 1.3, "A zombie behind a 2 m block reaches attack range of the player within 6 s")
	await frames(150)
	check(attacks == [40.0, 40.0, 40.0], "In 2.5 s of ATTACK the zombie attacks three times for 40, 1.2 s apart")
	player.teleport(Vector3(-5.0, 0.0, 15.0), 0.0)
	await frames(2)
	check(zombie.state == Zombie.State.CHASE, "The zombie goes back to CHASE when the player leaves range")
	zombie.take_damage(100.0, false)
	check(zombie.state == Zombie.State.CHASE and zombie.health == 50.0 and deaths.is_empty(), "100 damage leaves 50 health and the zombie keeps chasing")
	zombie.take_damage(70.0, true)
	zombie.take_damage(70.0, true)
	check(zombie.state == Zombie.State.DEAD and zombie.health == 0.0 and deaths == [true], "A 70 headshot at 50 health kills the zombie once and reports a headshot")
	await frames(30)
	check(is_instance_valid(zombie), "The dead zombie still sinks 0.5 s after death")
	await frames(40)
	check(not is_instance_valid(zombie), "The dead zombie frees itself 1.0 s after death")
	await finish(arena)


func start_game() -> Game:
	var game: Game = (load("res://game/main.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	current_scene = game
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
		await physics_frame
		if game.director.phase == RoundDirector.Phase.ACTIVE:
			started = tick
			break
	check(started >= 179 and started <= 181 and game.director.round_number == 1 and live_zombies(game).size() == 1, "Round 1 starts 3 s after the game starts and spawns one zombie")
	check(game.hud.round_label.text == "1" and game.hud.points_label.text == "500" and game.hud.weapon_label.text == "Pistol" and game.hud.ammo_label.text == "8 / 80", "The HUD shows round 1, 500 points, the pistol, and 8 / 80 ammo")
	var first: Zombie = live_zombies(game)[0]
	check(first.health == 150.0 and first.speed == 1.6, "A round 1 zombie has 150 health and walks at 1.6 m/s")
	game.weapon.hit.emit(first, 35.0, Rules.HitKind.BODY)
	check(game.points.balance == 510 and first.health == 115.0, "A body hit for 35 earns 10 points")
	game.weapon.hit.emit(first, 200.0, Rules.HitKind.BODY)
	check(game.points.balance == 570 and first.state == Zombie.State.DEAD, "A body kill earns 60 points")
	game.weapon.hit.emit(first, 200.0, Rules.HitKind.HEAD)
	check(game.points.balance == 570, "A hit on a dead zombie earns nothing")
	var headshot_done: bool = false
	for tick: int in range(900):
		await physics_frame
		for zombie: Zombie in live_zombies(game):
			game.weapon.hit.emit(zombie, 1000.0, Rules.HitKind.BODY if headshot_done else Rules.HitKind.HEAD)
			if not headshot_done:
				check(game.points.balance == 670, "A headshot kill earns 100 points")
				headshot_done = true
		if game.director.phase == RoundDirector.Phase.INTERMISSION:
			break
	check(game.director.phase == RoundDirector.Phase.INTERMISSION and game.director.rounds_survived() == 1, "Killing all 6 zombies of round 1 clears it into INTERMISSION")
	check(game.points.balance == 910 and game.points.earned == 410, "Round 1 earns 10 + 60 + 100 + 4 x 60 = 410 points, for a balance of 910")
	game.weapon.trigger_held = true
	await frames(2)
	game.weapon.trigger_held = false
	check(game.weapon.current().magazine == 7, "A shot in the intermission leaves 7 rounds")
	for tick: int in range(660):
		await physics_frame
		if game.director.phase == RoundDirector.Phase.ACTIVE:
			break
	check(game.director.round_number == 2 and game.weapon.current().magazine == 7 and game.weapon.current().reserve == 80 and game.hud.round_label.text == "2", "Round 2 starts after the intermission, shows round 2, and does not refill the weapon")
	var second: Zombie = live_zombies(game)[0]
	check(second.health == 250.0, "A round 2 zombie has 250 health")
	place_in_front(game, second, 1.5)
	await frames(2)
	game.weapon.melee_requested = true
	await frames(1)
	check(second.health == 100.0 and second.state != Zombie.State.DEAD and game.points.balance == 920, "A melee on a 250 health zombie does 150 damage and earns 10 points")
	send_action(&"pause")
	await frames(30)
	var paused_position: Vector3 = second.global_position
	await frames(30)
	check(paused and game.hud.pause_screen.visible and second.global_position == paused_position, "Pause stops the zombies and shows the pause screen")
	send_action(&"pause")
	await frames(2)
	check(not paused and not game.hud.pause_screen.visible, "A second pause press resumes the game")
	game.player.take_damage(100.0)
	await frames(1)
	check(game.director.phase == RoundDirector.Phase.GAME_OVER and game.hud.death_screen.visible, "Player death ends the game and shows the death screen")
	check(game.hud.death_text.text.begins_with("You survived 1 round.\nYou earned 420 points."), "The death screen shows 1 round survived and 420 points earned")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Death releases the mouse")
	var zombies_at_death: Array[Node] = game.zombies.get_children()
	await frames(150)
	check(game.zombies.get_children().all(func(zombie: Node) -> bool: return zombie in zombies_at_death), "No zombie spawns in the 2.5 s after the game is over")
	send_action(&"restart")
	await frames(3)
	var fresh: Game = current_scene as Game
	check(fresh != null and fresh != game and not is_instance_valid(game), "Enter after death reloads the scene with a new Game")
	check(fresh.director.phase == RoundDirector.Phase.STARTING and fresh.points.balance == 500 and fresh.player.alive, "The new game starts over with 500 points and a living player")
	current_scene = null
	fresh.queue_free()
	await physics_frame


func test_game_melee() -> void:
	var game: Game = start_game()
	for tick: int in range(240):
		await physics_frame
		if game.director.phase == RoundDirector.Phase.ACTIVE:
			break
	var first: Zombie = live_zombies(game)[0]
	place_in_front(game, first, 1.5)
	await frames(2)
	game.weapon.melee_requested = true
	await frames(1)
	check(first.state == Zombie.State.DEAD and game.points.balance == 630 and game.hud.points_label.text == "630", "One melee kills a round 1 zombie and earns 130 points")
	check(game.weapon.current().magazine == 8 and game.weapon.current().reserve == 80, "The melee uses no ammunition")
	current_scene = null
	game.queue_free()
	await physics_frame


func prompt_text(game: Game) -> String:
	return game.hud.prompt_label.text if game.hud.prompt_label.visible else ""


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
	await frames(3)
	check(prompt_text(game) == "E  Buy SMG  1000" and game.hud.prompt_label.modulate == Hud.PROMPT_GRAY, "1.5 m from the SMG wall buy the prompt is \"E  Buy SMG  1000\" in gray, because 500 points are not enough")
	check(not game.interact() and game.points.balance == 500 and loadout_text(game.weapon.loadout) == "*pistol 8/80", "With 500 points a press buys nothing and the balance stays 500")
	game.points.earn(500)
	await frames(1)
	check(game.hud.prompt_label.modulate == Color.WHITE, "With 1000 points the prompt is white")
	check(game.interact() and game.points.balance == 0 and loadout_text(game.weapon.loadout) == "pistol 8/80, *smg 30/150", "With 1000 points a press buys the SMG into slot 2 and leaves 0 points")
	check(game.hud.weapon_label.text == "SMG" and game.hud.ammo_label.text == "30 / 150", "The HUD shows the SMG and its 30 / 150 ammunition at once")
	await frames(1)
	check(prompt_text(game) == "SMG ammo full" and not game.interact() and game.points.balance == 0, "With a full SMG the prompt says \"SMG ammo full\" and a press does nothing")
	await wait_for_weapon_state(game.weapon, Weapon.State.READY, 60)
	game.weapon.trigger_held = true
	await frames(10)
	game.weapon.trigger_held = false
	await frames(1)
	var after_burst: int = game.weapon.current().magazine
	game.points.earn(500)
	await frames(1)
	check(after_burst < 30 and prompt_text(game) == "E  Buy SMG ammo  500", "After a burst the SMG wall offers ammo for 500")
	check(game.interact() and game.points.balance == 0 and slot_text(game.weapon.current()) == "smg 30/150", "The ammo buy fills the SMG to 30 and 150 for 500 points")
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(3.0, 3.0, 0.1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(-8.0, 1.5, -19.0)
	game.arena.add_child(wall)
	await frames(2)
	check(prompt_text(game) == "" and not game.interact(), "A wall between the player and the station hides the prompt, and a press does nothing")
	wall.queue_free()
	game.player.player_controlled = true
	send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await frames(2)
	check(game.weapon.state == Weapon.State.SWITCHING and game.weapon.current().def.id == &"pistol" and game.hud.weapon_label.text == "Pistol", "A turn of the mouse wheel changes to the pistol")
	game.player.player_controlled = false
	game.player.teleport(Vector3(10.0, 0.0, 18.2), PI)
	game.points.earn(950)
	await frames(2)
	check(prompt_text(game) == "E  Mystery box  950", "In front of the box the prompt is \"E  Mystery box  950\"")
	check(game.interact() and game.points.balance == 0 and game.arena.box.phase == MysteryBox.Phase.ROLLING, "A roll through Game removes 950 points")
	await frames(1)
	check(prompt_text(game) == "", "A rolling box shows no prompt")
	game.arena.box.advance(4.0)
	await frames(1)
	check(prompt_text(game) == "E  Take %s" % game.arena.box.result.display_name and game.hud.prompt_label.modulate == Color.WHITE, "An offering box shows \"E  Take\" and the weapon name")
	game.arena.box.advance(10.0)
	await frames(1)
	check(game.arena.box.phase == MysteryBox.Phase.IDLE and game.points.balance == 0 and loadout_text(game.weapon.loadout) == "*pistol 8/80, smg 30/150", "A timeout gives no weapon and does not give the 950 points back")
	check(game.director.phase == RoundDirector.Phase.STARTING, "All buys happened before round 1")
	current_scene = null
	game.queue_free()
	await physics_frame


func test_perks() -> void:
	var none: Perks = Perks.new()
	var smg: WeaponDef = Arsenal.smg()
	check([Rules.max_health(none), Rules.regen_delay(none), Rules.regen_rate(none), Rules.fire_interval(smg, none), Rules.reload_seconds(smg, none), Rules.switch_seconds(none)] == [100.0, 4.0, 50.0, 0.075, 2.0, 0.5], "With no perks the lookups give the base numbers")
	var tough: Perks = Perks.new()
	tough.grant(Perks.Kind.TOUGH)
	var mender: Perks = Perks.new()
	mender.grant(Perks.Kind.MENDER)
	var rapid: Perks = Perks.new()
	rapid.grant(Perks.Kind.RAPID)
	var quick: Perks = Perks.new()
	quick.grant(Perks.Kind.QUICK_HANDS)
	check(Rules.max_health(tough) == 160.0 and Rules.regen_delay(tough) == 4.0 and Rules.fire_interval(smg, tough) == 0.075, "Tough changes the maximum health and nothing else")
	check(Rules.regen_delay(mender) == 1.5 and Rules.regen_rate(mender) == 100.0 and Rules.max_health(mender) == 100.0, "Mender changes the regeneration delay and rate")
	check(is_equal_approx(Rules.fire_interval(smg, rapid), 0.05625) and Rules.reload_seconds(smg, rapid) == 2.0, "Rapid cuts the SMG fire interval to 0.05625 s and leaves the reload")
	check(Rules.reload_seconds(smg, quick) == 1.0 and Rules.switch_seconds(quick) == 0.25 and Rules.fire_interval(smg, quick) == 0.075, "Quick Hands halves the reload and the change")
	var granted: Array[int] = []
	none.granted.connect(func(kind: Perks.Kind) -> void: granted.append(kind))
	none.grant(Perks.Kind.RAPID)
	none.grant(Perks.Kind.RAPID)
	check(none.owned == [Perks.Kind.RAPID] and granted == [Perks.Kind.RAPID], "A second grant of one perk adds nothing and emits no signal")
	var pistol: WeaponDef = Arsenal.pistol()
	var upgraded: WeaponDef = Arsenal.upgrade(pistol)
	check("%s %s %.1f %d %d %d" % [upgraded.id, upgraded.display_name, upgraded.damage, upgraded.magazine_size, upgraded.reserve_max, upgraded.tier] == "pistol Upgraded Pistol 70.0 12 120 1" and pistol.damage == 35.0 and pistol.tier == 0, "The upgrade makes the pistol 70 damage, 12 and 120 rounds, tier 1, with the same id, and leaves the argument alone")
	var shotgun: WeaponDef = Arsenal.upgrade(Arsenal.shotgun())
	check(shotgun.magazine_size == 9 and shotgun.reserve_max == 63 and shotgun.pellets == 8, "The upgrade makes the shotgun 9 and 63 rounds with 8 pellets")
	var loadout: Loadout = Loadout.new(Arsenal.pistol())
	loadout.current().magazine = 3
	loadout.current().upgrade()
	check(slot_text(loadout.current()) == "pistol 12/120" and loadout.find(&"pistol").def.tier == 1, "Slot.upgrade() fills the slot at the new sizes and find() still finds it")
	loadout.give(Arsenal.pistol())
	check(loadout.current().def.tier == 1, "give() of a weapon that the player has keeps its upgrade")
	var machine: PerkMachine = PerkMachine.new()
	machine.perk = Perks.Kind.TOUGH
	machine.price = 3000
	machine.powered = true
	var owned: Perks = Perks.new()
	check(offer_text(machine.offer(loadout, owned)) == "PERK 3000 \"Buy Tough\" -", "A perk machine offers the perk for its price")
	owned.grant(Perks.Kind.TOUGH)
	check(offer_text(machine.offer(loadout, owned)) == "NONE 0 \"Tough owned\" -", "A perk machine of an owned perk offers nothing and says so")
	var press: UpgradeMachine = UpgradeMachine.new()
	press.powered = true
	check(offer_text(press.offer(loadout, owned)) == "NONE 0 \"Already upgraded\" -", "The upgrade machine refuses an upgraded weapon")
	check(offer_text(press.offer(Loadout.new(Arsenal.pistol()), owned)) == "UPGRADE 4000 \"Upgrade Pistol\" pistol", "The upgrade machine offers to upgrade the pistol for 4000")
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
	await frames(5)
	weapon.trigger_held = true
	await frames(17)
	weapon.trigger_held = false
	check(shots[0] == 4, "Without Rapid the SMG fires 4 shots in 17 ticks")
	await frames(30)
	perks.grant(Perks.Kind.RAPID)
	shots[0] = 0
	weapon.trigger_held = true
	await frames(17)
	weapon.trigger_held = false
	check(shots[0] == 5, "With Rapid the SMG fires 5 shots in 17 ticks")
	perks.grant(Perks.Kind.QUICK_HANDS)
	weapon.switch_requested = true
	await frames(1)
	check(await ticks_in_state(weapon, Weapon.State.SWITCHING, 60) == 15 and weapon.current().def.id == &"pistol", "With Quick Hands a change takes 15 ticks")
	weapon.current().magazine = 4
	weapon.reload_requested = true
	await frames(1)
	var reload_ticks: int = await ticks_in_state(weapon, Weapon.State.RELOADING, 120)
	check(reload_ticks == 42 and weapon.current().magazine == 8, "With Quick Hands a pistol reload takes 42 ticks")
	weapon.upgrade_current()
	check(slot_text(weapon.current()) == "pistol 12/120" and weapon.state == Weapon.State.READY, "upgrade_current() fills the pistol at the new sizes and does not start SWITCHING")
	var ahead: Zombie = make_still_zombie(level, Vector3(0.0, 0.0, -3.0), 1000.0)
	var hits: Array[String] = []
	weapon.hit.connect(func(target: Zombie, damage: float, kind: Rules.HitKind) -> void:
		hits.append("%.1f %s" % [damage, Rules.HitKind.find_key(kind)]))
	player.look(0.0, -atan(0.65 / 2.65))
	await frames(5)
	weapon.trigger_held = true
	await frames(1)
	weapon.trigger_held = false
	check(hits == ["70.0 BODY"] and is_instance_valid(ahead), "An upgraded pistol hits for 70 damage")
	await finish(level)
	var tough_level: Node3D = make_level()
	var hurt: Player = spawn(tough_level, tuning(), Vector3.ZERO, 0.0)
	hurt.perks = Perks.new()
	hurt.perks.grant(Perks.Kind.TOUGH)
	hurt.heal_to_max()
	for hit_number: int in range(3):
		hurt.take_damage(40.0)
	check(hurt.health == 40.0 and hurt.alive, "With Tough three zombie hits leave 40 health")
	hurt.take_damage(40.0)
	check(not hurt.alive, "With Tough a fourth hit kills")
	await finish(tough_level)
	var mender_level: Node3D = make_level()
	var healing: Player = spawn(mender_level, tuning(), Vector3.ZERO, 0.0)
	healing.perks = Perks.new()
	healing.perks.grant(Perks.Kind.MENDER)
	healing.take_damage(30.0)
	await frames(84)
	check(healing.health == 70.0, "With Mender the player does not heal 1.4 s after a hit")
	await frames(18)
	measure("health 1.7 s after 30 damage with Mender", healing.health, "hp")
	check(healing.health > 85.0 and healing.health < 92.0, "With Mender, 0.2 s into regeneration at 100 per second the health is near 90")
	await finish(mender_level)


func test_game_perks() -> void:
	var game: Game = start_game()
	for machine: Machine in game.arena.machines:
		machine.powered = true
	game.player.teleport(Vector3(8.0, 0.0, -18.45), 0.0)
	game.points.earn(1000)
	await frames(3)
	check(prompt_text(game) == "E  Buy Mender  1500" and game.interact() and game.points.balance == 0, "At the Mender machine the prompt is \"E  Buy Mender  1500\", and the press takes 1500 points")
	await frames(1)
	check(game.perks.has(Perks.Kind.MENDER) and game.hud.perk_box.get_child_count() == 1 and (game.hud.perk_box.get_child(0) as Label).text == "Mender", "The perk row shows Mender")
	check(prompt_text(game) == "Mender owned" and not game.interact(), "A second press at an owned perk does nothing")
	game.player.teleport(Vector3(-18.45, 0.0, -8.0), PI * 0.5)
	game.points.earn(3000)
	game.player.take_damage(40.0)
	await frames(3)
	check(game.interact() and game.perks.has(Perks.Kind.TOUGH) and game.player.health == 160.0, "Buying Tough for 3000 puts the player at 160 health")
	game.player.teleport(Vector3(-10.0, 0.0, 18.45), PI)
	game.points.earn(4000)
	await frames(3)
	check(prompt_text(game) == "E  Upgrade Pistol  4000" and game.interact() and game.points.balance == 0, "At the upgrade machine the prompt is \"E  Upgrade Pistol  4000\", and the press takes 4000 points")
	check(slot_text(game.weapon.current()) == "pistol 12/120" and game.hud.weapon_label.text == "Upgraded Pistol", "The pistol is upgraded and the HUD shows its name")
	await frames(1)
	check(prompt_text(game) == "Already upgraded" and not game.interact(), "A second upgrade is refused")
	current_scene = null
	game.queue_free()
	await physics_frame


func test_pick_spawn() -> void:
	var player: Vector3 = Vector3.ZERO
	var spawns: Array[Vector3] = [Vector3(30.0, 0.0, 0.0), Vector3(15.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)]
	check(Rules.pick_spawn(spawns, player) == Vector3(15.0, 0.0, 0.0), "pick_spawn takes the nearest candidate that is 12 m or more away")
	spawns = [Vector3(5.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)]
	check(Rules.pick_spawn(spawns, player) == Vector3(8.0, 0.0, 0.0), "pick_spawn takes the farthest candidate if all are closer than 12 m")
	spawns = [Vector3(12.0, 0.0, 0.0), Vector3(11.9, 0.0, 0.0)]
	check(Rules.pick_spawn(spawns, player) == Vector3(12.0, 0.0, 0.0), "A candidate at exactly 12 m counts as far")


func test_zones() -> void:
	var arena: Arena = await make_arena()
	check(arena.spawns().size() == 8 and arena.open_zones == [&"yard"], "At first only the 8 Yard spawn points are open")
	arena.open_zone(&"warehouse")
	arena.open_zone(&"warehouse")
	check(arena.spawns().size() == 11 and arena.open_zones == [&"yard", &"warehouse"], "open_zone adds the 3 Warehouse spawn points one time")
	var farthest: float = 0.0
	for spawn_point: Vector3 in arena.zone_spawns[&"warehouse"]:
		farthest = maxf(farthest, spawn_point.distance_to(Vector3(0.0, 0.0, 6.0)))
	check(farthest > 12.0, "The Warehouse spawn points are far from the player spawn")
	var map: RID = arena.get_world_3d().navigation_map
	for zone: StringName in arena.zone_spawns:
		for spawn_point: Vector3 in arena.zone_spawns[zone]:
			var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, spawn_point)
			check(Vector2(snapped.x - spawn_point.x, snapped.z - spawn_point.z).length() < 0.5 and not NavigationServer3D.map_get_path(map, arena.player_spawn.origin, spawn_point, true).is_empty(), "The %s spawn point %s is on the navigation mesh and has a path from the player spawn" % [zone, spawn_point])
	var doors: Array[Door] = []
	for station: Station in arena.stations:
		if station is Door:
			doors.append(station as Door)
	var zones: Array[StringName] = []
	for door: Door in doors:
		zones.append(door.zone)
	zones.sort()
	var keys: Array[StringName] = []
	for zone: StringName in arena.zone_spawns:
		if zone != Arena.START_ZONE:
			keys.append(zone)
	keys.sort()
	check(zones == keys, "Each zone except the Yard has exactly one door")
	await finish(arena)


func test_doors() -> void:
	var game: Game = start_game()
	game.player.teleport(Vector3(17.5, 0.0, 0.0), -PI * 0.5)
	await frames(3)
	check(prompt_text(game) == "E  Open Warehouse  1250" and game.hud.prompt_label.modulate == Hud.PROMPT_GRAY, "Facing the east door the prompt is \"E  Open Warehouse  1250\" in gray")
	game.player.intent.move = Vector2(0.0, 1.0)
	await frames(60)
	check(game.player.global_position.x < 20.0, "The player cannot walk through a closed door")
	game.player.intent.move = Vector2.ZERO
	game.player.teleport(Vector3(17.5, 0.0, 0.0), -PI * 0.5)
	await frames(3)
	check(not game.interact() and game.arena.spawns().size() == 8, "Without points a press does nothing and no zone opens")
	game.points.earn(1000)
	await frames(1)
	check(game.interact() and game.points.balance == 250 and game.arena.open_zones == [&"yard", &"warehouse"], "With 1500 points the press takes 1250 and opens the Warehouse")
	await frames(2)
	check(prompt_text(game) == "" and not game.interact(), "An open door shows no prompt and a press does nothing")
	game.player.teleport(Vector3(17.5, 0.0, 0.0), -PI * 0.5)
	await frames(1)
	game.player.intent.move = Vector2(0.0, 1.0)
	await frames(90)
	check(game.player.global_position.x > 24.0, "After the door opens the player walks into the Warehouse")
	game.player.intent.move = Vector2.ZERO
	var runner: Zombie = make_zombie(game.arena, Vector3(26.0, 0.0, -12.0), 150.0, 3.2, game.player)
	game.player.teleport(Vector3(8.0, 0.0, 0.0), 0.0)
	var reached: int = -1
	for tick: int in range(1, 1801):
		await physics_frame
		if runner.state == Zombie.State.ATTACK:
			reached = tick
			break
	measure("time for a Warehouse zombie to reach the Yard player", reached * TICK, "s")
	check(reached > 0 and reached * TICK < 30.0, "A zombie spawned in the Warehouse reaches a player in the Yard within 30 s")
	current_scene = null
	game.queue_free()
	await physics_frame
	var north: Game = start_game()
	north.player.teleport(Vector3(0.0, 0.0, -17.5), 0.0)
	north.points.earn(1500)
	await frames(3)
	check(prompt_text(north) == "E  Open Courtyard  1750" and north.points.balance == 2000 and north.interact() and north.arena.open_zones == [&"yard", &"courtyard"], "The north door costs 1750 and opens the Courtyard")
	current_scene = null
	north.queue_free()
	await physics_frame


func test_power() -> void:
	var game: Game = start_game()
	check(game.arena.machines.size() == 5 and game.arena.machines.all(func(machine: Machine) -> bool: return not machine.powered), "A new arena has 5 machines and no power")
	game.player.teleport(Vector3(8.0, 0.0, -18.45), 0.0)
	game.points.earn(2000)
	await frames(3)
	check(prompt_text(game) == "No power" and not game.interact() and game.points.balance == 2500, "Without power a machine says \"No power\" and a press does nothing")
	var switch: PowerSwitch = null
	for station: Station in game.arena.stations:
		if station is PowerSwitch:
			switch = station as PowerSwitch
	game.player.teleport(Vector3(58.0, 0.0, 0.0), -PI * 0.5)
	await frames(3)
	check(prompt_text(game) == "E  Turn on power" and game.interact() and switch.is_on, "The switch prompt is \"E  Turn on power\", and the press turns it on at no cost")
	await frames(2)
	check(game.points.balance == 2500 and prompt_text(game) == "Power is on" and not game.interact(), "The switch costs nothing and works one time")
	check(game.arena.machines.all(func(machine: Machine) -> bool: return machine.powered), "All 5 machines have power")
	game.player.teleport(Vector3(8.0, 0.0, -18.45), 0.0)
	await frames(3)
	check(prompt_text(game) == "E  Buy Mender  1500" and game.interact() and game.perks.has(Perks.Kind.MENDER), "With power the Mender machine sells")
	current_scene = null
	game.queue_free()
	await physics_frame


func test_secret() -> void:
	var game: Game = start_game()
	var secret: Secret = game.arena.get_node(^"Secret") as Secret
	var sigils: Array[Sigil] = []
	for node: Node in secret.find_children("*", "Sigil", false):
		sigils.append(node as Sigil)
	check(sigils.size() == 3 and not secret.cache.revealed, "The secret has 3 sigils and a hidden cache")
	game.player.teleport(Vector3(18.0, 0.0, -43.0), -PI * 0.5)
	await frames(3)
	check(prompt_text(game) == "" and not game.interact(), "In front of the closed panel there is no prompt, and a press does nothing")
	sigils[0].light()
	sigils[1].light()
	sigils[1].light()
	check(not secret.revealed and not secret.cache.revealed, "Two lit sigils do not reveal the cache")
	var third: Sigil = sigils[2]
	game.player.teleport(Vector3(third.position.x, 0.0, -57.0), 0.0)
	await frames(10)
	game.weapon.trigger_held = true
	await frames(3)
	game.weapon.trigger_held = false
	check(third.is_lit and secret.revealed and secret.cache.revealed, "A pistol shot at the third sigil lights it and reveals the cache")
	await frames(70)
	check(not is_instance_valid(secret.panel), "The panel sinks and frees itself")
	game.player.teleport(Vector3(18.0, 0.0, -43.0), -PI * 0.5)
	game.weapon.loadout.current().magazine = 1
	game.weapon.loadout.current().reserve = 3
	var before: int = game.points.balance
	await frames(3)
	check(prompt_text(game) == "E  Take the cache", "In the alcove the prompt is \"E  Take the cache\"")
	check(game.interact() and game.points.balance == before + 1500 and slot_text(game.weapon.current()) == "pistol 8/80", "The cache gives 1500 points and fills the weapon")
	await frames(2)
	check(not game.interact() and game.points.balance == before + 1500, "The cache works one time")
	current_scene = null
	game.queue_free()
	await physics_frame
