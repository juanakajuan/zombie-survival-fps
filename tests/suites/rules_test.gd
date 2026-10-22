extends TestCase


func test_rules() -> void:
	ok([Rules.zombie_count(1), Rules.zombie_count(2), Rules.zombie_count(5), Rules.zombie_count(6), Rules.zombie_count(10), Rules.zombie_count(20)] == [6, 9, 18, 27, 53, 153], "Zombie counts for rounds 1, 2, 5, 6, 10, 20 are 6, 9, 18, 27, 53, 153")
	ok([Rules.zombie_health(1), Rules.zombie_health(2), Rules.zombie_health(5), Rules.zombie_health(9)] == [150.0, 250.0, 550.0, 950.0], "Zombie health for rounds 1, 2, 5, 9 is 150, 250, 550, 950")
	ok(is_equal_approx(Rules.zombie_health(10), 1045.0) and absf(Rules.zombie_health(20) - 2710.46) < 0.01, "Zombie health grows 10% per round after round 9: 1045 at round 10 and 2710.46 at round 20")
	ok([Rules.spawn_interval(1), Rules.spawn_interval(2), Rules.spawn_interval(5), Rules.spawn_interval(20)] == [2.0, 1.85, 1.4, 0.5] and is_equal_approx(Rules.spawn_interval(10), 0.65), "Spawn intervals for rounds 1, 2, 5, 10, 20 are 2.0, 1.85, 1.4, 0.65, 0.5 s")
	var rolls: Array[float] = [0.0, 0.1, 0.3, 0.5, 0.9, 0.99]
	var round_one: Array[float] = []
	var round_five: Array[float] = []
	var round_ten: Array[float] = []
	for roll: float in rolls:
		round_one.append(Rules.zombie_speed(1, roll))
		round_five.append(Rules.zombie_speed(5, roll))
		round_ten.append(Rules.zombie_speed(10, roll))
	ok(round_one == [1.6, 1.6, 1.6, 1.6, 1.6, 1.6], "Round 1 has only walkers at 1.6 m/s")
	ok(round_five == [5.0, 5.0, 3.2, 3.2, 1.6, 1.6], "Round 5 has 24% runners, 60% joggers, and 16% walkers")
	ok(round_ten == [5.0, 5.0, 5.0, 5.0, 3.2, 3.2], "Round 10 has 80% runners and 20% joggers")
	var kinds: Array[Rules.HitKind] = [Rules.HitKind.BODY, Rules.HitKind.HEAD, Rules.HitKind.MELEE]
	var hit_points: Array[int] = []
	var kill_points: Array[int] = []
	for kind: Rules.HitKind in kinds:
		hit_points.append(Rules.points_for_hit(false, kind))
		kill_points.append(Rules.points_for_hit(true, kind))
	ok(hit_points == [10, 10, 10] and kill_points == [60, 100, 130], "A hit of any kind earns 10. A body kill earns 60, a headshot kill 100, and a melee kill 130")
	ok([Rules.ammo_price(1000), Rules.ammo_price(1200), Rules.ammo_price(1500)] == [500, 600, 750], "Ammo for the 1000, 1200, and 1500 weapons costs 500, 600, and 750")


func clear_round(director: RoundDirector) -> void:
	while director.phase == RoundDirector.Phase.ACTIVE:
		director.tick(0.25)
		for zombie: int in range(director.alive):
			director.zombie_died()


func test_round_director_start() -> void:
	var director: RoundDirector = RoundDirector.new()
	var events: Array[String] = []
	director.round_started.connect(func(number: int) -> void: events.append("started %d" % number))
	director.round_cleared.connect(func(number: int) -> void: events.append("cleared %d" % number))
	var early: int = director.tick(2.5)
	ok(early == 0 and director.phase == RoundDirector.Phase.STARTING and director.rounds_survived() == 0, "2.5 s after the start the director is STARTING, spawns nothing, and has 0 rounds survived")
	var first: int = director.tick(0.5)
	ok(first == 1 and director.phase == RoundDirector.Phase.ACTIVE and director.round_number == 1 and director.to_spawn == 5 and director.alive == 1, "At 3.0 s round 1 starts and spawns its first zombie, with 5 left to spawn")
	var spawned: Array[int] = []
	for step: int in range(4):
		spawned.append(director.tick(0.5))
	ok(spawned == [0, 0, 0, 1], "The next zombie comes 2.0 s later")
	director.tick(10.0)
	ok(director.to_spawn == 0 and director.alive == 6, "A 10 s tick spawns the rest of round 1, so 6 zombies are alive")
	for zombie: int in range(5):
		director.zombie_died()
	ok(director.phase == RoundDirector.Phase.ACTIVE and director.rounds_survived() == 0, "With one zombie alive round 1 is still ACTIVE and 0 rounds are survived")
	director.zombie_died()
	ok(director.phase == RoundDirector.Phase.INTERMISSION and director.rounds_survived() == 1, "The last death clears round 1 into INTERMISSION with 1 round survived")
	ok(director.tick(9.5) == 0 and director.phase == RoundDirector.Phase.INTERMISSION, "9.5 s into the intermission there is no new round")
	ok(director.tick(0.5) == 1 and director.round_number == 2 and director.to_spawn == 8, "10 s after the clear round 2 starts with 9 zombies")
	ok(director.rounds_survived() == 1, "During round 2, 1 round is survived")
	ok(events == ["started 1", "cleared 1", "started 2"], "Signals are round_started 1, round_cleared 1, round_started 2")


func test_round_director_spawn_cap() -> void:
	var director: RoundDirector = RoundDirector.new()
	director.tick(3.0)
	for number: int in range(1, 7):
		clear_round(director)
		director.tick(10.0)
	ok(director.round_number == 7 and director.to_spawn + director.alive == 33, "After six cleared rounds round 7 has 33 zombies")
	var most_alive: int = 0
	var total: int = director.alive
	for step: int in range(2400):
		total += director.tick(1.0 / 60.0)
		most_alive = maxi(most_alive, director.alive)
	ok(most_alive == 24 and director.alive == 24 and director.to_spawn == 9 and total == 24, "With no deaths in round 7, spawns stop at 24 alive and 9 wait")
	director.zombie_died()
	director.zombie_died()
	var at_once: int = director.tick(1.0 / 60.0)
	var later: int = 0
	for step: int in range(70):
		later += director.tick(1.0 / 60.0)
	ok(at_once == 1 and later == 1 and director.alive == 24 and director.to_spawn == 7, "After two deaths at the cap, one zombie spawns on the next tick and one 1.1 s later")


func test_round_director_game_over() -> void:
	var director: RoundDirector = RoundDirector.new()
	var results: Array[int] = []
	director.game_over.connect(func(survived: int) -> void: results.append(survived))
	director.tick(3.0)
	clear_round(director)
	director.tick(10.0)
	director.tick(5.0)
	director.player_died()
	director.player_died()
	ok(director.phase == RoundDirector.Phase.GAME_OVER and results == [1], "A death in round 2 ends the game once with 1 round survived")
	ok(director.tick(30.0) == 0 and director.round_number == 2, "After GAME_OVER, tick spawns nothing and no round starts")
	var in_break: RoundDirector = RoundDirector.new()
	var break_results: Array[int] = []
	in_break.game_over.connect(func(survived: int) -> void: break_results.append(survived))
	in_break.tick(3.0)
	clear_round(in_break)
	in_break.player_died()
	ok(break_results == [1], "A death in the intermission after round 1 reports 1 round survived")
	var at_start: RoundDirector = RoundDirector.new()
	at_start.player_died()
	ok(at_start.rounds_survived() == 0 and at_start.phase == RoundDirector.Phase.GAME_OVER, "A death before round 1 reports 0 rounds survived")


func test_points() -> void:
	var points: Points = Points.new()
	var balances: Array[int] = []
	points.changed.connect(func(balance: int) -> void: balances.append(balance))
	points.earn(60)
	points.earn(10)
	ok(points.balance == 570 and points.earned == 70, "Earning 60 and 10 from 500 gives a balance of 570 and 70 earned")
	ok(points.spend(400) and points.balance == 170 and points.earned == 70, "Spending 400 of 570 succeeds and leaves 170, and earned stays 70")
	ok(not points.spend(171) and points.balance == 170, "Spending 171 of 170 fails and leaves the balance at 170")
	ok(balances == [560, 570, 170], "changed reports 560, 570, 170 and nothing for the failed spend")


func test_pick_spawn() -> void:
	var player: Vector3 = Vector3.ZERO
	var spawns: Array[Vector3] = [Vector3(30.0, 0.0, 0.0), Vector3(15.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)]
	ok(Rules.pick_spawn(spawns, player) == Vector3(15.0, 0.0, 0.0), "pick_spawn takes the nearest candidate that is 12 m or more away")
	spawns = [Vector3(5.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)]
	ok(Rules.pick_spawn(spawns, player) == Vector3(8.0, 0.0, 0.0), "pick_spawn takes the farthest candidate if all are closer than 12 m")
	spawns = [Vector3(12.0, 0.0, 0.0), Vector3(11.9, 0.0, 0.0)]
	ok(Rules.pick_spawn(spawns, player) == Vector3(12.0, 0.0, 0.0), "A candidate at exactly 12 m counts as far")
