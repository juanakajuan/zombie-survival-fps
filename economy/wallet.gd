class_name Wallet
extends Node
## The player's points. Zombie hits earn them, and buy stations spend them.

signal changed(points: int)

@export_range(0, 100000) var starting_points: int = 0
## Points for each shot that hits a zombie.
@export_range(0, 1000) var points_per_hit: int = 10
## Extra points for the shot that kills a zombie.
@export_range(0, 1000) var kill_bonus: int = 60

var points: int


func _ready() -> void:
	points = starting_points


func add(amount: int) -> void:
	points += amount
	changed.emit(points)


## Takes `cost` points and returns true, or returns false and changes nothing when there are too few points.
func spend(cost: int) -> bool:
	if cost > points:
		return false
	points -= cost
	changed.emit(points)
	return true


func reward_hit(killed: bool) -> void:
	add(points_per_hit + (kill_bonus if killed else 0))
