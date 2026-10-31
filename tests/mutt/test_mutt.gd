extends TestCase

const WEAPON_SCENE: PackedScene = preload("res://weapons/weapon.tscn")
const RIFLE: WeaponData = preload("res://weapons/rifle.tres")
const FRAME_MARGIN := 3


func test_mutt_trots_to_the_player_at_the_special_speed_with_its_legs_swinging() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3.ZERO, 3)
	var mutt := spawn_mutt(Vector3(0.0, 0.0, -20.0), player)
	await run_seconds(0.5)
	var start := _flat_distance(mutt, player)
	var seconds := 1.0
	var pitches := await sample_range(func() -> float: return _mutt(mutt).front_leg_pitch(), seconds)
	var speed := (start - _flat_distance(mutt, player)) / seconds
	assert_true(speed > ROUND_SETTINGS.special_speed * 0.8 and speed < ROUND_SETTINGS.special_speed * 1.05,
		"Mutt moves at %s m/s, settings say %s m/s" % [speed, ROUND_SETTINGS.special_speed])
	var swing := deg_to_rad(_mutt(mutt).leg_swing) * 0.5
	assert_true(pitches.y > swing and pitches.x < -swing, "front leg swings %s to %s rad" % [pitches.x, pitches.y])


func test_mutt_in_range_bites_the_player_with_a_head_snap() -> void:
	await spawn_nav_world()
	var player := await spawn_player(Vector3.ZERO, 3)
	var mutt := spawn_mutt(Vector3(0.0, 0.0, -1.0), player)
	var health := Health.find_on(player)
	var pitches := await sample_range(func() -> float: return _mutt(mutt).head_pitch(), mutt.attack_interval * 2.0 + FRAME_MARGIN / 60.0)
	assert_almost_eq(health.current, health.max_health - 2.0 * mutt.attack_damage, 0.001, "two bites in two intervals")
	assert_true(pitches.x < -deg_to_rad(_mutt(mutt).bite_angle) * 0.5, "head snaps down, min %s rad" % pitches.x)


func test_mutt_takes_a_headshot_and_never_loses_its_legs() -> void:
	var mutt := spawn_mutt(Vector3.ZERO)
	var health := Health.find_on(mutt)
	health.max_health = 10000.0
	health.reset()
	var weapon := WEAPON_SCENE.instantiate() as Weapon
	weapon.data = RIFLE
	weapon.position = Vector3(0.0, 0.9, -5.0)
	add_child(weapon)
	var reports: Array[bool] = []
	weapon.damaged.connect(func(_target: Node, _killed: bool, headshot: bool) -> void: reports.append(headshot))
	await physics_frames(FRAME_MARGIN)
	weapon.look_at(mutt.global_position + Vector3(0.0, 0.2, 0.0))
	assert_true(weapon.try_fire(), "leg shot fires")
	await run_seconds(RIFLE.fire_interval + FRAME_MARGIN / 60.0)
	weapon.look_at(mutt.weak_spot.global_position)
	assert_true(weapon.try_fire(), "head shot fires")
	assert_eq(reports, [false, true] as Array[bool], "only the second shot is a headshot")
	assert_eq(mutt.gait, Zombie.Gait.WALK, "gait after a strong leg shot")
	assert_true(mutt.animator.has_legs(), "the legs are on")


func test_dying_mutt_falls_on_its_side_and_goes() -> void:
	var mutt := spawn_mutt(Vector3.ZERO)
	await physics_frames(2)
	Health.find_on(mutt).damage(1.0e6)
	var animator := _mutt(mutt)
	await run_seconds(animator.fall_time + 0.1)
	assert_almost_eq(animator.side_tilt(), deg_to_rad(animator.fall_angle), 0.05, "the Mutt lies on its side")
	await run_seconds(animator.death_length() + FRAME_MARGIN / 60.0)
	assert_true(not is_instance_valid(mutt) or not mutt.is_inside_tree(), "the Mutt left the tree after its death")


func _mutt(mutt: Zombie) -> MuttAnimator:
	return mutt.animator as MuttAnimator


func _flat_distance(a: Node3D, b: Node3D) -> float:
	var offset := a.global_position - b.global_position
	offset.y = 0.0
	return offset.length()
