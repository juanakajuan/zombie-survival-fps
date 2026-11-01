class_name RoundSettings
extends Resource
## How many zombies each round has, how strong they are, and how long the break between rounds is.
## The zombie count and health follow the solo Black Ops curve (zombacus.com/zombiecalculator, "Normal"). The speed
## and the runner part start at their round 1 value and go up by a step for each later round.

@export_group("Count")
## The zombie count of the first rounds. Round n has entry n - 1 while n is not more than the size of the table.
@export var early_round_counts: PackedInt32Array = [6, 8, 13, 18, 24, 27, 28, 28, 29]
## After the table, a round has `base_zombies` plus `zombies_per_round_squared` times the square of the round number.
@export_range(0, 200) var base_zombies: int = 24
@export_range(0.0, 1.0, 0.001) var zombies_per_round_squared: float = 0.09
## The most zombies alive at one time. The round spawns the rest of its count when others die.
@export_range(1, 100) var max_alive: int = 24

@export_group("Health")
@export_range(1.0, 10000.0, 1.0) var first_round_health: float = 150.0
## Rounds before `health_growth_round` add this much health each.
@export_range(0.0, 1000.0, 1.0) var health_per_round: float = 100.0
## From this round on, each round adds `health_growth` of the health of the round before, in place of `health_per_round`.
@export_range(2, 100) var health_growth_round: int = 10
@export_range(0.0, 1.0, 0.01) var health_growth: float = 0.1

@export_group("Speed")
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var first_round_speed: float = 2.5
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var speed_per_round: float = 0.25
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var max_speed: float = 5.0

@export_group("Runners")
## The first round that has runners. Earlier rounds have none.
@export_range(1, 100) var first_runner_round: int = 5
## The part of the round's zombies that run in the first runner round.
@export_range(0.0, 1.0, 0.01) var first_runner_fraction: float = 0.25
@export_range(0.0, 1.0, 0.01) var runner_fraction_per_round: float = 0.1
@export_range(0.0, 1.0, 0.01) var max_runner_fraction: float = 0.6
## Runners ignore the walking speed. Keep this above `max_speed`, so that a runner is always faster than a walker.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var runner_speed: float = 5.5

@export_group("Crawlers")
## The speed of a zombie that has lost its legs, in every round.
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var crawl_speed: float = 0.8

@export_group("Special rounds")
## The first special round. A special round has Mutts in place of zombies, and its last Mutt drops a free Max Ammo.
@export_range(1, 100) var first_special_round: int = 6
## A special round comes this many rounds after the one before.
@export_range(1, 20) var special_round_interval: int = 5
## The Mutts of a special round, as a part of the zombie count of that round.
@export_range(0.05, 2.0, 0.05) var special_count_scale: float = 0.6
## The health of a Mutt, as a part of the zombie health of that round.
@export_range(0.05, 1.0, 0.05) var special_health_scale: float = 0.4
## Mutts ignore the walking speed. Keep this above `runner_speed`, so that a Mutt is the fastest enemy.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var special_speed: float = 6.5

@export_group("Timing")
@export_range(0.0, 60.0, 0.5, "suffix:s") var break_time: float = 10.0
## Time between two spawns in a round. The first zombie spawns when the round starts.
@export_range(0.0, 10.0, 0.05, "suffix:s") var spawn_interval: float = 1.0

@export_group("Drops")
## The most pickups that zombies drop in one round.
@export_range(0, 20) var max_drops: int = 4


func zombie_count(round_number: int) -> int:
	if round_number <= early_round_counts.size():
		return early_round_counts[round_number - 1]
	return base_zombies + floori(zombies_per_round_squared * (round_number * round_number))


## Each growth step is cut to a whole number, so the health matches the reference curve.
func zombie_health(round_number: int) -> float:
	var health := first_round_health + health_per_round * (mini(round_number, health_growth_round - 1) - 1)
	for growth_round: int in range(health_growth_round, round_number + 1):
		health += floorf(health * health_growth)
	return health


func zombie_speed(round_number: int) -> float:
	return minf(first_round_speed + speed_per_round * (round_number - 1), max_speed)


## How many of the round's zombies run. It is 0 before `first_runner_round` and never more than the zombie count.
func runner_count(round_number: int) -> int:
	if round_number < first_runner_round:
		return 0
	var fraction := minf(first_runner_fraction + runner_fraction_per_round * (round_number - first_runner_round), max_runner_fraction)
	return mini(roundi(zombie_count(round_number) * fraction), zombie_count(round_number))


func is_special_round(round_number: int) -> bool:
	return round_number >= first_special_round and (round_number - first_special_round) % special_round_interval == 0


## The Mutts of a special round. It is at least 1.
func special_count(round_number: int) -> int:
	return maxi(roundi(zombie_count(round_number) * special_count_scale), 1)


func special_health(round_number: int) -> float:
	return zombie_health(round_number) * special_health_scale
