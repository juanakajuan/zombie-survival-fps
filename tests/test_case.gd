class_name TestCase
extends RefCounted

const TICK: float = 1.0 / 60.0

var tree: SceneTree
var id: String = ""
var checks: int = 0
var failures: int = 0
var jumps: int = 0
var landings: Array[float] = []
var transitions: Array[String] = []
var _owned: Array[Node] = []


func ok(condition: bool, what: String) -> void:
	_record(condition, what, "")


func eq(actual: Variant, expected: Variant, what: String) -> void:
	var same: bool = actual == expected
	_record(same, what, "expected %s, got %s" % [expected, actual])


func near(actual: float, expected: float, tolerance: float, what: String) -> void:
	_record(absf(actual - expected) <= tolerance, what, "expected %.4f within %.4f, got %.4f" % [expected, tolerance, actual])


func between(actual: float, low: float, high: float, what: String) -> void:
	_record(actual >= low and actual <= high, what, "expected %.4f to %.4f, got %.4f" % [low, high, actual])


func measure(label: String, value: float, unit: String) -> void:
	print("MEASURE: %s = %.3f %s" % [label, value, unit])


func ticks(count: int) -> void:
	for i: int in range(count):
		await tree.physics_frame


func own(node: Node) -> Node:
	_owned.append(node)
	return node


func release() -> void:
	for node: Node in _owned:
		if is_instance_valid(node):
			node.free()
	_owned.clear()


func _record(passed: bool, what: String, detail: String) -> void:
	checks += 1
	if passed:
		print("PASS: " + what)
		return
	failures += 1
	push_error("FAIL: " + id + " " + what + ("" if detail.is_empty() else " (" + detail + ")"))


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
	tree.root.add_child(level)
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
	await tree.physics_frame
	clear_events()


func press_jump(player: Player) -> void:
	player.intent.jump_pressed = true
	player.intent.jump_held = true


func add_staircase(level: Node3D, x: float, riser: float, tread: float, count: int) -> void:
	for step: int in range(count):
		var height: float = riser * (step + 1)
		add_box(level, Vector3(3.0, height, tread), Vector3(x, height * 0.5, -3.0 - tread * (step + 0.5)))
	var top: float = riser * count
	add_box(level, Vector3(3.0, top, 6.0), Vector3(x, top * 0.5, -6.0 - tread * count))


func add_ledge(level: Node3D, x: float, height: float) -> void:
	add_box(level, Vector3(6.0, height, 10.0), Vector3(x, height * 0.5, -9.0))


func push_into_wall(player: Player) -> void:
	player.intent.move = Vector2(0.0, 1.0)
	await ticks(10)
	for tick: int in range(120):
		await tree.physics_frame
		if player.horizontal_speed() < 0.1:
			return


func slot_text(slot: Loadout.Slot) -> String:
	return "%s %d/%d" % [slot.def.id, slot.magazine, slot.reserve]


func loadout_text(loadout: Loadout) -> String:
	var parts: PackedStringArray = []
	for index: int in range(loadout.slots.size()):
		parts.append(("*" if index == loadout.active else "") + slot_text(loadout.slots[index]))
	return ", ".join(parts)


func offer_text(offer: Station.Offer) -> String:
	return "%s %d \"%s\" %s" % [Station.Offer.Kind.find_key(offer.kind), offer.cost, offer.label, offer.weapon.id if offer.weapon != null else &"-"]


## The navigation map syncs on a worker thread, and a path query alone can answer from the previous level's stale map.
## An owner query before the first sync is an engine error, so the loop waits for that sync first.
func make_arena() -> Arena:
	var arena: Arena = Game.ARENA_SCENE.instantiate() as Arena
	tree.root.add_child(arena)
	var map: RID = arena.get_world_3d().navigation_map
	var deadline: int = Time.get_ticks_msec() + 5000
	while NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point_owner(map, arena.player_spawn.origin) != arena.navigation.get_rid():
		if Time.get_ticks_msec() > deadline:
			push_error("make_arena: the navigation map did not take in the arena region in 5 s")
			break
		await tree.physics_frame
	return arena


func make_zombie(level: Node3D, at: Vector3, start_health: float, move_speed: float, target: Node3D) -> Zombie:
	var zombie: Zombie = Zombie.new()
	zombie.setup(start_health, move_speed, target)
	zombie.position = at
	level.add_child(zombie)
	return zombie


func make_still_zombie(level: Node3D, at: Vector3, start_health: float = 150.0) -> Zombie:
	var marker: Marker3D = Marker3D.new()
	marker.position = at
	level.add_child(marker)
	return make_zombie(level, at, start_health, 1.6, marker)


func steady(weapon: WeaponDef) -> WeaponDef:
	weapon.spread_degrees = 0.0
	return weapon


func wait_for_weapon_state(weapon: Weapon, state: Weapon.State, limit: int) -> int:
	for tick: int in range(1, limit + 1):
		await tree.physics_frame
		if weapon.state == state:
			return tick
	return -1


func ticks_in_state(weapon: Weapon, state: Weapon.State, limit: int) -> int:
	var count: int = 0
	while weapon.state == state and count < limit:
		await tree.physics_frame
		count += 1
	return count
