extends TestCase

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const FRAME_MARGIN := 2


func test_shows_full_health_and_magazine_at_start() -> void:
	var player := await _spawn_player()
	var weapon := _weapon(player)
	assert_eq(_label(player, "HealthValue").text, "100", "health text")
	assert_eq(_label(player, "AmmoValue").text, "%d / %d" % [weapon.data.magazine_size, weapon.data.magazine_size], "ammo text")
	assert_true(not _label(player, "ReloadLabel").is_visible_in_tree(), "reload label hidden")


func test_health_text_follows_damage_and_reset() -> void:
	var player := await _spawn_player()
	var health := Health.find_on(player)
	health.damage(25.0)
	assert_eq(_label(player, "HealthValue").text, "75", "health after damage")
	health.damage(0.5)
	assert_eq(_label(player, "HealthValue").text, "75", "fractional health rounds up")
	health.reset()
	assert_eq(_label(player, "HealthValue").text, "100", "health after reset")


func test_ammo_text_follows_shots() -> void:
	var player := await _spawn_player()
	var weapon := _weapon(player)
	assert_true(weapon.try_fire(), "shot fires")
	assert_eq(_label(player, "AmmoValue").text, "%d / %d" % [weapon.data.magazine_size - 1, weapon.data.magazine_size], "ammo after one shot")


func test_reload_label_shows_during_reload_and_ammo_refills() -> void:
	var player := await _spawn_player()
	var weapon := _weapon(player)
	weapon.try_fire()
	weapon.start_reload()
	assert_true(_label(player, "ReloadLabel").is_visible_in_tree(), "reload label shown while reloading")
	await physics_frames(roundi(weapon.data.reload_time * Engine.physics_ticks_per_second) + FRAME_MARGIN)
	assert_true(not weapon.is_reloading(), "reload finished")
	assert_true(not _label(player, "ReloadLabel").is_visible_in_tree(), "reload label hidden after reload")
	assert_eq(_label(player, "AmmoValue").text, "%d / %d" % [weapon.data.magazine_size, weapon.data.magazine_size], "ammo refilled")


func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await physics_frames(1)
	return player


func _weapon(player: Player) -> Weapon:
	return player.get_node("Head/Camera3D/Weapon") as Weapon


func _label(player: Player, unique_name: String) -> Label:
	return player.get_node("Hud").get_node("%" + unique_name) as Label
