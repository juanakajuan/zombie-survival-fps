extends TestCase

const SFX_BUS := &"SFX"
const FRAME_MARGIN := 3


func _tap_melee() -> void:
	Input.action_press("melee")
	await physics_frames(2)
	Input.action_release("melee")


func _every_sound_player(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	found.append_array(root.find_children("*", "AudioStreamPlayer", true, false))
	found.append_array(root.find_children("*", "AudioStreamPlayer3D", true, false))
	return found


func test_the_sfx_bus_sends_to_master() -> void:
	var index := AudioServer.get_bus_index(SFX_BUS)
	assert_true(index > 0, "SFX bus exists below Master")
	assert_eq(AudioServer.get_bus_send(index), &"Master", "SFX sends to Master")


func test_every_sound_player_uses_the_sfx_bus() -> void:
	var player := await spawn_player()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -10.0))
	var players := _every_sound_player(player)
	players.append_array(_every_sound_player(zombie))
	assert_true(players.size() >= 11, "found the sound players, got %d" % players.size())
	for node: Node in players:
		assert_eq(node.get("bus"), SFX_BUS, "bus of %s" % node.name)
		assert_true(node.get("stream") != null, "stream of %s" % node.name)


func test_a_shot_plays_the_shot_sound() -> void:
	var player := await spawn_player()
	assert_true(not player.weapon.shot_sound.playing, "silent before the shot")
	assert_true(player.weapon.try_fire(), "shot fires")
	assert_true(player.weapon.shot_sound.playing, "shot sound plays")


func test_a_reload_plays_the_reload_sound() -> void:
	var player := await spawn_player()
	player.weapon.try_fire()
	player.weapon.start_reload()
	assert_true(player.weapon.reload_sound.playing, "reload sound plays")


func test_an_empty_gun_clicks_once_per_fire_interval() -> void:
	var player := await spawn_player()
	var weapon := player.weapon
	weapon.ammo = 0
	weapon.reserve = 0
	var clicks := [0]
	weapon.dry_fired.connect(func() -> void: clicks[0] += 1)
	assert_true(not weapon.try_fire(), "no shot")
	assert_eq(clicks[0], 1, "one click")
	assert_true(weapon.dry_sound.playing, "dry sound plays")
	assert_true(not weapon.shot_sound.playing, "no shot sound")
	weapon.try_fire()
	assert_eq(clicks[0], 1, "no second click in the same interval")
	await run_seconds(weapon.data.fire_interval + FRAME_MARGIN / 60.0)
	weapon.try_fire()
	assert_eq(clicks[0], 2, "a click after the interval")


func test_an_empty_magazine_with_a_reserve_reloads_and_does_not_click() -> void:
	var player := await spawn_player()
	player.weapon.ammo = 0
	var clicks := [0]
	player.weapon.dry_fired.connect(func() -> void: clicks[0] += 1)
	player.weapon.try_fire()
	assert_eq(clicks[0], 0, "no click")
	assert_true(player.weapon.reload_sound.playing, "reload sound plays")


func test_a_hit_plays_the_hit_sound_and_a_kill_plays_the_kill_sound() -> void:
	var player := await spawn_player()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -4.0))
	await physics_frames(2)
	var hud := player.hud
	var health := Health.find_on(zombie)
	health.max_health = player.weapon.data.damage * 2.0
	health.reset()
	assert_true(player.weapon.try_fire(), "first shot fires")
	assert_true(hud.hit_sound.playing, "hit sound plays")
	assert_true(not hud.kill_sound.playing, "no kill sound on a hit")
	await run_seconds(player.weapon.data.fire_interval + FRAME_MARGIN / 60.0)
	hud.hit_sound.stop()
	assert_true(player.weapon.try_fire(), "second shot fires")
	assert_true(zombie.is_dead(), "zombie died")
	assert_true(hud.kill_sound.playing, "kill sound plays")
	assert_true(not hud.hit_sound.playing, "no hit sound on a kill")


func test_a_punch_plays_the_hit_sound() -> void:
	var player := await spawn_player()
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -(player.melee.reach * 0.5)))
	await physics_frames(2)
	await _tap_melee()
	await run_seconds(player.melee.wind_up_time + FRAME_MARGIN / 60.0)
	assert_true(Health.find_on(zombie).current < Health.find_on(zombie).max_health, "the punch hit")
	assert_true(player.hud.hit_sound.playing or player.hud.kill_sound.playing, "a hit marker sound plays")


func test_the_zombie_dying_plays_its_death_sound_and_stops_groaning() -> void:
	var zombie := spawn_zombie(Vector3.ZERO)
	zombie.groan_interval_min = 0.5
	zombie.groan_interval_max = 0.5
	await physics_frames(2)
	zombie.groan_sound.play()
	assert_true(not zombie.death_sound.playing, "silent before the death")
	Health.find_on(zombie).damage(1.0e6)
	assert_true(zombie.death_sound.playing, "death sound plays")
	assert_true(not zombie.groan_sound.playing, "groan stops")
	zombie.groan_sound.stop()
	await run_seconds(zombie.groan_interval_max + FRAME_MARGIN / 60.0)
	assert_true(zombie.animator.death_length() > zombie.groan_interval_max + FRAME_MARGIN / 60.0, "the body is still in the tree")
	assert_true(not zombie.groan_sound.playing, "no groan after death")


func test_a_living_zombie_groans_within_the_longest_interval() -> void:
	var zombie := ZOMBIE_SCENE.instantiate() as Zombie
	zombie.configure(0.0, 100.0, null)
	zombie.groan_interval_min = 0.5
	zombie.groan_interval_max = 1.0
	add_child(zombie)
	assert_true(not zombie.groan_sound.playing, "silent at the start")
	var groaned := false
	for _i: int in roundi((zombie.groan_interval_max + 0.2) * Engine.physics_ticks_per_second):
		await physics_frames(1)
		if zombie.groan_sound.playing:
			groaned = true
			break
	assert_true(groaned, "the zombie groaned")


func test_a_zombie_slam_plays_the_attack_sound() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3.ZERO, 3)
	var zombie := spawn_zombie(Vector3(0.0, 0.0, -1.0), player)
	zombie.attack_interval = 0.3
	assert_true(not zombie.attack_sound.playing, "silent before the slam")
	await run_seconds(zombie.attack_interval + FRAME_MARGIN / 60.0)
	assert_true(Health.find_on(player).current < Health.find_on(player).max_health, "the slam hit")
	assert_true(zombie.attack_sound.playing, "attack sound plays")


func test_damage_plays_the_hurt_sound() -> void:
	var player := await spawn_player()
	assert_true(not player.hurt_sound.playing, "silent before the damage")
	Health.find_on(player).damage(10.0)
	assert_true(player.hurt_sound.playing, "hurt sound plays")


func test_round_start_and_break_play_their_sounds() -> void:
	var settings := RoundSettings.new()
	settings.first_round_zombies = 1
	settings.first_round_speed = 0.0
	settings.break_time = 0.5
	var manager := RoundManager.new()
	manager.settings = settings
	var marker := SpawnPoint.new()
	marker.position = Vector3(0.0, 0.0, -6.0)
	manager.add_child(marker)
	add_child(manager)
	var player := await spawn_player()
	player.hud.round_manager = manager
	assert_true(not player.hud.break_sound.playing, "no break sound yet")
	for child: Node in manager.get_children():
		if child is Zombie:
			Health.find_on(child).damage(1.0e6)
	await physics_frames(2)
	assert_true(player.hud.break_sound.playing, "break sound plays when the break starts")
	assert_true(not player.hud.round_start_sound.playing, "no round start sound in the break")
	await run_seconds(settings.break_time + FRAME_MARGIN / 60.0)
	assert_eq(manager.round_number, 2, "round 2 started")
	assert_true(player.hud.round_start_sound.playing, "round start sound plays")
