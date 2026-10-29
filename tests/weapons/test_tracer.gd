extends TestCase

const SETTLE_FRAMES := 60
const TARGET_DISTANCE := 20.0


func test_shot_sends_a_tracer_from_the_muzzle_toward_the_hit_point() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var dummy := await spawn_dummy(Vector3(0.0, 0.0, -TARGET_DISTANCE))
	look_at_point(player, dummy.global_position + Vector3.UP)
	await physics_frames(SETTLE_FRAMES)
	var hits: Array[Vector3] = []
	player.weapon.hit.connect(func(_collider: Object, point: Vector3) -> void: hits.append(point))
	assert_true(player.weapon.try_fire(), "shot fires")
	var muzzle := player.weapon.view_model.muzzle.global_position
	assert_eq(hits.size(), 1, "the shot hits the dummy")
	var tracers := _tracers()
	assert_eq(tracers.size(), 1, "one tracer flies")
	await physics_frames(1)
	var head := tracers[0].head()
	var path := hits[0] - muzzle
	assert_true((head - muzzle).length() > 0.0, "the tracer moved away from the muzzle")
	assert_true((head - muzzle).cross(path.normalized()).length() < 0.01, "the tracer is on the line from the muzzle to the hit")
	assert_true((head - muzzle).dot(path) > 0.0 and (head - muzzle).length() < path.length(), "the tracer is between the muzzle and the hit")
	await run_seconds(path.length() / tracers[0].speed + 0.1)
	assert_eq(_tracers().size(), 0, "the tracer is gone after it reaches the hit")


func test_missed_shot_sends_a_tracer_that_ends_at_max_range() -> void:
	var player := await spawn_player(Vector3.ZERO, SETTLE_FRAMES)
	var weapon := player.weapon
	look_at_point(player, player.camera.global_position + Vector3(0.0, 10.0, -1.0))
	await physics_frames(1)
	assert_true(weapon.try_fire(), "shot fires")
	var tracers := _tracers()
	assert_eq(tracers.size(), 1, "a missed shot also shows a tracer")
	var seconds := weapon.data.max_range / tracers[0].speed
	await run_seconds(seconds * 0.5)
	assert_eq(_tracers().size(), 1, "the tracer still flies halfway to max range")
	await run_seconds(seconds * 0.5 + 0.1)
	assert_eq(_tracers().size(), 0, "the tracer is gone at max range")


func _tracers() -> Array[Tracer]:
	var tracers: Array[Tracer] = []
	for node: Node in get_tree().get_nodes_in_group(Tracer.GROUP):
		if not node.is_queued_for_deletion():
			tracers.append(node as Tracer)
	return tracers
