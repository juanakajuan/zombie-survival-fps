extends SceneTree
## Verification driver. drive.sh runs it as the main loop: it loads the level, then plays a steps file line by line.
## Input goes through Input.parse_input_event with the events from the Input Map, so the game sees it as player input.
## Parsed events are flushed on the next frame, so every input command waits at least one frame after it sends.
## Args after `--`: --steps=<abs path> --out=<abs dir> [--scene=res://...]

const DEFAULT_SCENE := "res://levels/test_range.tscn"
const SECOND_WIND: PerkItem = preload("res://perks/second_wind.tres")

var _steps_path: String = ""
var _out_dir: String = ""
var _scene: String = DEFAULT_SCENE
var _failures: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--steps="):
			_steps_path = arg.trim_prefix("--steps=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_scene = arg.trim_prefix("--scene=")
	if _steps_path.is_empty() or _out_dir.is_empty():
		printerr("driver: pass --steps=<file> and --out=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# A fresh settings file, so that the human's saved sensitivity and field of view do not change the expected values.
	GameSettings.file_path = _out_dir.path_join("settings.cfg")
	DirAccess.remove_absolute(GameSettings.file_path)
	var err := change_scene_to_file(_scene)
	if err != OK:
		printerr("driver: cannot load %s: %s" % [_scene, error_string(err)])
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	# Ready means playable: the player is in the tree and the round panel shows a round. Only then do steps start.
	var waited := 0
	while _state().get("hud.round_visible", "false") != "true":
		if waited >= 600:
			printerr("driver: the level was not ready after 600 frames: %s" % str(_state()))
			quit(1)
			return
		await process_frame
		waited += 1
	print("driver: ready after %d frames" % waited)
	var lines := FileAccess.get_file_as_string(_steps_path).split("\n")
	for i: int in lines.size():
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		print("driver: [%d] %s" % [i + 1, line])
		var ok: bool = await _step(line)
		if not ok:
			_failures += 1
			printerr("driver: FAIL at line %d: %s" % [i + 1, line])
			if not line.begins_with("expect"):
				break
	_write_text("summary.txt", "failures=%d\n" % _failures)
	print("driver: done, %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _step(line: String) -> bool:
	var parts := line.split(" ", false)
	var command := parts[0]
	match command:
		"wait":
			await _wait_frames(parts[1].to_int())
		"hold", "release":
			if not _send_action(parts[1], command == "hold"):
				return false
			await _wait_frames(1)
		"tap":
			if not _send_action(parts[1], true):
				return false
			await _wait_frames(2)
			_send_action(parts[1], false)
			await _wait_frames(1)
		"key":
			return await _tap_key(parts[1])
		"look":
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(parts[1].to_float(), parts[2].to_float())
			motion.screen_relative = motion.relative
			Input.parse_input_event(motion)
			await _wait_flush()
		"shot":
			await RenderingServer.frame_post_draw
			var path := _out_dir.path_join(parts[1] + ".png")
			var err := root.get_texture().get_image().save_png(path)
			if err != OK:
				printerr("driver: cannot save %s: %s" % [path, error_string(err)])
				return false
		"state":
			_write_text(parts[1] + ".json", JSON.stringify(_state(), "  ") + "\n")
		"expect":
			return _expect(parts[1], " ".join(parts.slice(2)), true)
		"expect_not":
			return _expect(parts[1], " ".join(parts.slice(2)), false)
		"aim":
			return await _aim_nearest_zombie()
		"aim_head":
			return await _aim_nearest_zombie(true)
		"face":
			return await _face(deg_to_rad(parts[1].to_float()), deg_to_rad(parts[2].to_float()))
		"fight_until":
			return await _fight_until(parts[1], " ".join(parts.slice(2, parts.size() - 1)), parts[parts.size() - 1].to_int())
		"self_revive":
			_give_self_revive()
		"debug":
			return _run_debug_command(" ".join(parts.slice(1)))
		"until":
			return await _until(parts[1], " ".join(parts.slice(2, parts.size() - 1)), parts[parts.size() - 1].to_int())
		_:
			printerr("driver: unknown command %s" % command)
			return false
	return true


## Gives the player SECOND WIND without the power switch and the points, to show the downed state quickly.
func _give_self_revive() -> void:
	(get_first_node_in_group(Player.GROUP) as Player).perks.add(SECOND_WIND)


## Runs a debug menu command by its button label, as a click on the button does.
func _run_debug_command(label: String) -> bool:
	var menu := (get_first_node_in_group(Player.GROUP) as Player).debug_menu
	if not menu.command_labels().has(label):
		printerr("driver: no debug command %s in %s" % [label, menu.command_labels()])
		return false
	menu.run_command(label)
	return true


func _wait_frames(count: int) -> void:
	for i: int in count:
		await physics_frame


## Parsed input is flushed at the start of a main-loop iteration, and a slow frame can run more than one physics frame
## in one iteration. So wait for the end of this iteration, then one physics frame of the next.
func _wait_flush() -> void:
	await process_frame
	await physics_frame


func _send_action(action: StringName, pressed: bool) -> bool:
	if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
		printerr("driver: no Input Map event for action %s" % action)
		return false
	var event: InputEvent = InputMap.action_get_events(action)[0].duplicate()
	if event is InputEventKey:
		(event as InputEventKey).pressed = pressed
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		button.pressed = pressed
		button.position = root.get_visible_rect().size / 2.0
		button.global_position = button.position
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	return true


func _tap_key(key_name: String) -> bool:
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		printerr("driver: unknown key %s" % key_name)
		return false
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait_frames(2)
	return true


func _expect(key: String, want: String, equal: bool) -> bool:
	var got := str(_state().get(key, "<missing>"))
	var op := "==" if equal else "!="
	if (got == want) == equal:
		print("driver: ok %s %s %s (got %s)" % [key, op, want, got])
		return true
	printerr("driver: expected %s %s %s, got %s" % [key, op, want, got])
	return false


func _until(key: String, want: String, max_frames: int) -> bool:
	for i: int in max_frames:
		if str(_state().get(key, "<missing>")) == want:
			print("driver: ok %s == %s after %d frames" % [key, want, i])
			return true
		await physics_frame
	printerr("driver: %s never became %s in %d frames, last %s" % [key, want, max_frames, str(_state().get(key))])
	return false


## Turns the view to the nearest zombie's chest with one mouse-motion event, as a player would flick the mouse.
func _aim_nearest_zombie(head: bool = false) -> bool:
	var player := get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		printerr("driver: aim found no player")
		return false
	var nearest: Zombie = null
	for node: Node in current_scene.find_children("*", "", true, false):
		if node is Zombie and not (node as Zombie).is_dead() and (nearest == null or _dist(player, node as Zombie) < _dist(player, nearest)):
			nearest = node as Zombie
	if nearest == null:
		return true
	var point := nearest.weak_spot.global_position if head else nearest.global_position + Vector3.UP * 1.2
	await _turn(player.mouse_delta_to(point))
	return true


## Turns the view to an absolute yaw and pitch with one mouse-motion event.
func _face(yaw: float, pitch: float) -> bool:
	var player := get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		printerr("driver: face found no player")
		return false
	await _turn(player.mouse_delta_to_angles(yaw, pitch))
	return true


func _turn(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)
	await _wait_flush()


func _dist(a: Node3D, b: Node3D) -> float:
	return a.global_position.distance_to(b.global_position)


## Aims at the nearest zombie and fires, about 6 shots a second, until the state key has the value.
func _fight_until(key: String, want: String, max_frames: int) -> bool:
	var start := Engine.get_physics_frames()
	while Engine.get_physics_frames() - start < max_frames:
		if str(_state().get(key, "<missing>")) == want:
			print("driver: ok %s == %s after %d frames" % [key, want, Engine.get_physics_frames() - start])
			return true
		await _aim_nearest_zombie()
		if not _send_action(&"fire", true):
			return false
		await _wait_frames(2)
		_send_action(&"fire", false)
		await _wait_frames(7)
	printerr("driver: fight: %s never became %s in %d frames, last %s" % [key, want, max_frames, str(_state().get(key))])
	return false


## What the player can see or feel, as flat string values. `expect` and `until` compare against these.
func _state() -> Dictionary[String, String]:
	var s: Dictionary[String, String] = {}
	s["frame"] = str(Engine.get_physics_frames())
	s["mouse.mode"] = "captured" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "visible"
	s["game.paused"] = str(paused)
	var level := current_scene
	if level == null:
		return s
	var player := get_first_node_in_group(Player.GROUP) as Player
	if player != null:
		s["player.position"] = "%.1f %.1f %.1f" % [player.global_position.x, player.global_position.y, player.global_position.z]
		s["player.yaw_deg"] = "%.0f" % rad_to_deg(player.rotation.y)
		s["player.pitch_deg"] = "%.0f" % rad_to_deg(player.head.rotation.x)
		s["player.dead"] = str(player.is_dead())
		s["player.downed"] = str(player.is_downed())
		s["player.crouching"] = str(player.is_crouching())
		s["player.sliding"] = str(player.is_sliding())
		s["player.speed"] = "%.1f" % Vector2(player.velocity.x, player.velocity.z).length()
		s["player.aiming"] = str(player.is_aiming())
		s["player.third_person"] = str(player.is_third_person())
		s["pause_menu.open"] = str(player.pause_menu.is_open())
		var hud := player.hud.readout()
		s["hud.health"] = hud.health_text
		s["hud.ammo"] = hud.ammo_text
		s["hud.weapon"] = hud.weapon_name
		s["hud.points"] = hud.points_text
		s["hud.boost"] = hud.boost_text if hud.boost_visible else ""
		s["hud.prompt_visible"] = str(hud.prompt_visible)
		s["hud.prompt"] = " ".join(hud.prompt_text.split(" ", false)) if hud.prompt_visible else ""
		s["hud.reloading"] = str(hud.reloading)
		s["hud.round_visible"] = str(hud.round_visible)
		s["hud.round"] = hud.round_text
		s["hud.break"] = str(hud.in_break)
		s["hud.objective"] = hud.objective_text
		s["hud.crosshair"] = str(hud.crosshair_visible)
		s["hud.hit_marker"] = str(hud.hit_marker)
		s["hud.headshot_marker"] = str(hud.headshot_marker)
		s["hud.downed"] = hud.downed_text if hud.downed_visible else ""
		s["hud.revive"] = hud.revive_text if hud.revive_visible else ""
		s["hud.perks"] = " ".join(hud.perk_icons)
		s["hud.max_health"] = str(ceili(player.health.max_health))
	var zombies := 0
	var bars := 0
	var dummies_up := 0
	var doors_open := 0
	var pickups := 0
	var boards := 0
	for node: Node in level.find_children("*", "", true, false):
		if node is Zombie and not (node as Zombie).is_dead():
			zombies += 1
			if (node as Zombie).health_bar.visible:
				bars += 1
		elif node is TargetDummy and (node as TargetDummy).visible:
			dummies_up += 1
		elif node is Door and (node as Door).is_open():
			doors_open += 1
		elif node is Pickup:
			pickups += 1
		elif node is Barricade:
			boards += (node as Barricade).boards
	s["zombies.alive"] = str(zombies)
	s["zombies.bars"] = str(bars)
	s["tracers"] = str(get_nodes_in_group(Tracer.GROUP).size())
	s["dummies.up"] = str(dummies_up)
	s["doors.open"] = str(doors_open)
	s["pickups"] = str(pickups)
	s["barricades.boards"] = str(boards)
	var power := level.get_node_or_null("PowerSwitch") as PowerSwitch
	if power != null:
		s["power.on"] = str(power.is_on())
	var game_over := level.get_node_or_null("GameOver") as GameOver
	if game_over != null:
		s["game_over.visible"] = str(game_over.visible)
		s["game_over.text"] = game_over.round_text()
	return s


func _write_text(file_name: String, text: String) -> void:
	var file := FileAccess.open(_out_dir.path_join(file_name), FileAccess.WRITE)
	if file == null:
		printerr("driver: cannot write %s" % file_name)
		return
	file.store_string(text)
