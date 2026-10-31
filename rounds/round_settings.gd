class_name RoundSettings
extends Resource
## How many zombies each round has, how strong they are, and how long the break between rounds is.
## Each value starts at its round 1 value and goes up by its per-round step for each later round.

@export_group("Count")
@export_range(1, 100) var first_round_zombies: int = 4
@export_range(0, 20) var zombies_per_round: int = 2
## The most zombies alive at one time. The round spawns the rest of its count when others die.
@export_range(1, 100) var max_alive: int = 24

@export_group("Health")
@export_range(1.0, 10000.0, 1.0) var first_round_health: float = 100.0
@export_range(0.0, 1000.0, 1.0) var health_per_round: float = 20.0

@export_group("Speed")
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var first_round_speed: float = 2.5
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var speed_per_round: float = 0.25
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var max_speed: float = 5.0

@export_group("Timing")
@export_range(0.0, 60.0, 0.5, "suffix:s") var break_time: float = 10.0
## Time between two spawns in a round. The first zombie spawns when the round starts.
@export_range(0.0, 10.0, 0.05, "suffix:s") var spawn_interval: float = 1.0

@export_group("Drops")
## The most pickups that zombies drop in one round.
@export_range(0, 20) var max_drops: int = 4


func zombie_count(round_number: int) -> int:
	return first_round_zombies + zombies_per_round * (round_number - 1)


func zombie_health(round_number: int) -> float:
	return first_round_health + health_per_round * (round_number - 1)


func zombie_speed(round_number: int) -> float:
	return minf(first_round_speed + speed_per_round * (round_number - 1), max_speed)
