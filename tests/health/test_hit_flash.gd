extends TestCase

const FLASH := Color(1.0, 0.15, 0.1)


func _body_color(zombie: Zombie) -> Color:
	return ((zombie.get_child(1).get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color


func test_zombie_flashes_red_then_returns_to_base_color() -> void:
	var zombie := spawn_zombie(Vector3(0.0, 0.0, 50.0))
	await physics_frames(1)
	var base := zombie.base_color
	Health.find_on(zombie).damage(1.0)
	assert_eq(_body_color(zombie), FLASH, "zombie flash color")
	await run_seconds(0.05)
	assert_eq(_body_color(zombie), FLASH, "zombie still flashing at 0.05 s")
	await run_seconds(0.1)
	assert_eq(_body_color(zombie), base, "zombie back to base color after 0.1 s")


func test_dummy_flashes_red_then_returns_to_base_color() -> void:
	var dummy := await spawn_dummy(Vector3.ZERO)
	var mesh := dummy.get_child(0) as MeshInstance3D
	var material := mesh.material_override as StandardMaterial3D
	Health.find_on(dummy).damage(1.0)
	assert_eq(material.albedo_color, FLASH, "dummy flash color")
	await run_seconds(0.05)
	assert_eq(material.albedo_color, FLASH, "dummy still flashing at 0.05 s")
	await run_seconds(0.1)
	assert_eq(material.albedo_color, dummy.base_color, "dummy back to base color after 0.1 s")


func test_second_hit_during_a_flash_still_restores_base_color() -> void:
	var dummy := await spawn_dummy(Vector3.ZERO)
	var material := (dummy.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	var health := Health.find_on(dummy)
	health.damage(1.0)
	await run_seconds(0.05)
	health.damage(1.0)
	await run_seconds(0.2)
	assert_eq(material.albedo_color, dummy.base_color, "base color after two hits")
