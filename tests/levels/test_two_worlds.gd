extends TestCase

const NUKE: NukeItem = preload("res://pickups/nuke.tres")
const REPAIR_ALL: RepairAllItem = preload("res://pickups/repair_all.tres")


func test_nuke_stays_in_its_world() -> void:
	var session := await spawn_worlds()
	var host_zombie := spawn_zombie(Vector3(6.0, 0.0, -4.0))
	host_zombie.reparent(session.host_level, false)
	var client_zombie := spawn_zombie(Vector3(6.0, 0.0, -4.0))
	client_zombie.reparent(session.client_level, false)
	await physics_frames(1)
	NUKE.apply(session.host_level.players[0])
	await physics_frames(1)
	assert_true(host_zombie.is_dead(), "the nuke kills the zombie in its world")
	assert_true(not client_zombie.is_dead(), "the zombie in the other world lives")


func test_repair_all_stays_in_its_world() -> void:
	var session := await spawn_worlds()
	var host_barricade := session.host_level.get_node("YardBarricade") as Barricade
	var client_barricade := session.client_level.get_node("YardBarricade") as Barricade
	for barricade: Barricade in [host_barricade, client_barricade]:
		barricade.remove_board()
	REPAIR_ALL.apply(session.host_level.players[0])
	assert_true(host_barricade.is_full(), "repair all fills the barricade in its world")
	assert_true(not client_barricade.is_full(), "the barricade in the other world stays open")


func test_door_bakes_only_its_world() -> void:
	var session := await spawn_worlds()
	var bakes := {session.host_level: 0, session.client_level: 0}
	for level: Level in [session.host_level, session.client_level]:
		level.navigation.bake_finished.connect(func() -> void: bakes[level] += 1)
	(session.host_level.get_node("RoomDoor") as Door).open()
	assert_eq(bakes[session.host_level], 1, "bakes of the level whose door opened")
	assert_eq(bakes[session.client_level], 0, "bakes of the other level")
