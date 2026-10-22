extends TestCase


func test_camera_on_mantle() -> void:
	var level: Node3D = make_level()
	add_ledge(level, 0.0, 1.0)
	var values: PlayerSettings = tuning()
	values.head_bob_enabled = false
	var player: Player = spawn(level, values, Vector3(0.0, 0.0, 0.0), 0.0)
	await ticks(5)
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
		await tree.process_frame
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
	ok(absf(player.global_position.y - 1.0) < 0.02 and transitions.has("GROUND>MANTLE"), "The camera test body mantles onto the 1.0 m ledge")
	ok(samples > 100, "At a 240 FPS cap more frames render than physics ticks run")
	ok(worst_drop <= 0.01, "During a mantle no rendered frame moves the camera down by more than 0.01 m")
	ok(worst_rise <= worst_body_rise + 0.01, "During a mantle no rendered frame moves the camera up by more than the body moves in one tick")
	await finish(level)


func test_camera_on_stairs() -> void:
	var level: Node3D = make_level()
	add_staircase(level, 0.0, 0.3, 0.6, 20)
	var values: PlayerSettings = tuning()
	# The head bob moves the camera down on purpose, so it is off to isolate the step.
	values.head_bob_enabled = false
	var player: Player = spawn(level, values, Vector3.ZERO, 0.0)
	await ticks(5)
	var previous_max_fps: int = Engine.max_fps
	Engine.max_fps = 240
	player.intent.move = Vector2(0.0, 1.0)
	var start_tick: int = Engine.get_physics_frames()
	var last_y: float = player.camera.global_position.y
	var worst_drop: float = 0.0
	var samples: int = 0
	while player.global_position.z > -16.5 and Engine.get_physics_frames() - start_tick < 240:
		await tree.process_frame
		var y: float = player.camera.global_position.y
		worst_drop = maxf(worst_drop, last_y - y)
		last_y = y
		samples += 1
	var ticks: int = Engine.get_physics_frames() - start_tick
	Engine.max_fps = previous_max_fps
	measure("rendered frames while climbing twenty 0.3 m steps", samples, "frames")
	measure("physics ticks while climbing twenty 0.3 m steps", ticks, "ticks")
	measure("worst camera drop in one frame while climbing", worst_drop, "m")
	ok(absf(player.global_position.y - 6.0) < 0.02, "Walking up twenty 0.3 m steps with 0.6 m treads reaches the 6.0 m top")
	ok(samples > ticks, "At a 240 FPS cap more frames render than physics ticks run, so frames fall between ticks")
	ok(worst_drop <= 0.01, "While the body climbs, no rendered frame moves the camera down by more than 0.01 m")
	await finish(level)
