extends TestCase

const COMPOUND_SCENE: PackedScene = preload("res://levels/compound.tscn")
## The foot and the top of each ramp, in level coordinates. Each ramp goes up toward -Z, the way the player looks at start.
const MEZZANINE_RAMP_FOOT := Vector3(-20.0, 0.0, 0.0)
const WATCHTOWER_RAMP_FOOT := Vector3(29.0, 0.0, -9.0)
const HIGH_FLOOR_HEIGHT := 4.0


func test_every_spawn_point_has_a_path_to_the_player_start() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var start := (level.get_node("Player") as Player).global_position
	var spawns := level.get_node("RoundManager").find_children("*", "Marker3D", false, false)
	assert_eq(spawns.size(), 4, "spawn points")
	for node: Node in spawns:
		var spawn := node as Marker3D
		assert_true(_path_reaches(level, spawn.global_position, start), "%s has no path to the player start" % spawn.name)


func test_the_player_walks_up_the_mezzanine_ramp_onto_the_mezzanine() -> void:
	await _assert_walks_up_the_ramp_from(MEZZANINE_RAMP_FOOT, "mezzanine")


func test_the_player_walks_up_the_watchtower_ramp_onto_the_watchtower() -> void:
	await _assert_walks_up_the_ramp_from(WATCHTOWER_RAMP_FOOT, "watchtower")


func test_round_1_starts_and_the_level_runs_for_5_seconds() -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	assert_eq((level.get_node("RoundManager") as RoundManager).round_number, 1, "round number")
	await run_seconds(5.0)


func _assert_walks_up_the_ramp_from(foot: Vector3, floor_name: String) -> void:
	var level := await spawn_level(null, COMPOUND_SCENE)
	var player := level.get_node("Player") as Player
	player.global_position = foot
	Input.action_press("move_forward")
	await run_seconds(5.0)
	assert_almost_eq(player.global_position.y, HIGH_FLOOR_HEIGHT, 0.1, "player height after walking up to the %s" % floor_name)


func _path_reaches(level: Level, from: Vector3, to: Vector3) -> bool:
	var map := level.navigation.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.0
