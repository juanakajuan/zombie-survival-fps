extends TestCase

const PROBE_NAME := "Probe"
const WAIT_FRAMES := 30

var _client_copy: NetProbe


func test_client_connects_in_one_frame() -> void:
	var session := NetSession.loopback(LEVEL_SCENE)
	add_child(session)
	# The tree polls the multiplayer APIs just before it emits process_frame. A physics frame can come before that poll.
	await get_tree().process_frame
	assert_true(session.host_api.get_peers().has(NetSession.CLIENT_ID), "the host sees the client")
	assert_true(session.client_api.get_peers().has(1), "the client sees the host")
	assert_eq(session.client_api.get_unique_id(), NetSession.CLIENT_ID, "client id")
	await await_navmesh(session.host_level)
	await await_navmesh(session.client_level)


func test_rpc_reaches_host() -> void:
	var session := await spawn_session()
	var host_probe := _add_probe(session.host_level)
	var client_probe := _add_probe(session.client_level)
	var sent_before := session.client_peer.bytes_sent
	client_probe.request_hit.rpc_id(1, 5)
	await physics_frames(1)
	assert_eq(host_probe.hits_received, 5, "hits the host received after 1 frame")
	assert_eq(client_probe.hits_received, 0, "hits the client counted")
	assert_true(session.client_peer.bytes_sent > sent_before, "the client sent bytes")


func test_synchronizer_copies_owner_position() -> void:
	var session := await spawn_session()
	var host_spawner := _add_spawner(session.host_level)
	var client_spawner := _add_spawner(session.client_level)
	client_spawner.spawned.connect(func(node: Node) -> void: _client_copy = node as NetProbe)
	var host_copy := host_spawner.spawn(NetSession.CLIENT_ID) as NetProbe
	for _i: int in WAIT_FRAMES:
		if _client_copy != null:
			break
		await physics_frames(1)
	assert_true(_client_copy != null, "the client received the spawn")
	if _client_copy == null:
		return
	assert_true(_client_copy.is_multiplayer_authority(), "the client owns its copy")
	_client_copy.position = Vector3(3.0, 0.5, -2.0)
	for _i: int in WAIT_FRAMES:
		if host_copy.position.is_equal_approx(_client_copy.position):
			break
		await physics_frames(1)
	assert_true(host_copy.position.is_equal_approx(_client_copy.position), "the host copy has position %s, got %s" % [_client_copy.position, host_copy.position])


func test_worlds_do_not_share_physics() -> void:
	var session := await spawn_worlds()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.0, 4.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, 100.0, 0.0)
	session.host_level.add_child(body)
	await physics_frames(2)
	var from := Vector3(0.0, 110.0, 0.0)
	var to := Vector3(0.0, 90.0, 0.0)
	var in_host := session.host_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	var in_client := session.client_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	assert_true(not in_host.is_empty(), "the ray in the host world hits the body")
	assert_true(in_client.is_empty(), "the ray in the client world misses the body")
	assert_true(session.host_level.navigation.get_navigation_map() != session.client_level.navigation.get_navigation_map(), "the worlds have two navigation maps")


func _add_probe(level: Level) -> NetProbe:
	var probe := NetProbe.new()
	probe.name = PROBE_NAME
	level.add_child(probe)
	return probe


func _add_spawner(level: Level) -> MultiplayerSpawner:
	var players := Node3D.new()
	players.name = "Players"
	level.add_child(players)
	var spawner := MultiplayerSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_function = _make_probe
	level.add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players)
	return spawner


func _make_probe(owner_id: Variant) -> Node:
	var id: int = owner_id
	var probe := NetProbe.new()
	probe.name = "%s%d" % [PROBE_NAME, id]
	var synchronizer := MultiplayerSynchronizer.new()
	synchronizer.name = "Sync"
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	synchronizer.replication_config = config
	probe.add_child(synchronizer)
	probe.set_multiplayer_authority(id)
	return probe
