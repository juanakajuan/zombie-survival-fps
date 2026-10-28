extends TestCase

const DUMMY_SCENE: PackedScene = preload("res://targets/target_dummy.tscn")


func test_killed_dummy_disappears_then_respawns_with_full_health() -> void:
	var dummy := DUMMY_SCENE.instantiate() as TargetDummy
	dummy.respawn_delay = 0.3
	add_child(dummy)
	var health := Health.find_on(dummy)
	var shape := dummy.get_node("CollisionShape3D") as CollisionShape3D
	await physics_frames(1)
	health.damage(health.max_health)
	assert_true(not dummy.visible, "hidden when dead")
	assert_true(shape.disabled, "collision disabled when dead")
	await physics_frames(roundi(0.15 * Engine.physics_ticks_per_second))
	assert_true(not dummy.visible, "still hidden before the respawn delay")
	await physics_frames(roundi(0.3 * Engine.physics_ticks_per_second))
	assert_true(dummy.visible, "visible after respawn")
	assert_true(not shape.disabled, "collision enabled after respawn")
	assert_almost_eq(health.current, health.max_health, 0.001, "health restored")


func test_dummy_freed_while_dead_or_flashing_logs_no_error() -> void:
	var dummy := DUMMY_SCENE.instantiate() as TargetDummy
	dummy.respawn_delay = 0.2
	add_child(dummy)
	await physics_frames(1)
	Health.find_on(dummy).damage(1000.0)
	dummy.free()
	await physics_frames(roundi(0.4 * Engine.physics_ticks_per_second))
