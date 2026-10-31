class_name Wallet
extends Node
## The player's points. Zombie hits earn them, and buy stations spend them.

signal changed(points: int)
## A boost started or ended.
signal boost_changed

@export_range(0, 100000) var starting_points: int = 0
@export_range(0, 1000) var points_per_hit: int = 10
## Extra points for the shot that kills a zombie.
@export_range(0, 1000) var kill_bonus: int = 60
## Extra points when the killing blow is a headshot.
@export_range(0, 1000) var headshot_bonus: int = 40
## Points for each board that the player repairs.
@export_range(0, 1000) var points_per_board: int = 10
## The most points that repairs give in one round, so that the player cannot farm a barricade.
@export_range(0, 10000) var board_points_per_round: int = 50

var points: int
## What earned points are multiplied by. It is 1 when no boost runs.
var multiplier: int = 1

var _board_points_this_round: int = 0
var _boost_left: float = 0.0


func _ready() -> void:
	points = starting_points


func _physics_process(delta: float) -> void:
	if _boost_left <= 0.0:
		return
	_boost_left -= delta
	if _boost_left <= 0.0:
		multiplier = 1
		boost_changed.emit()


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


func reward_hit(killed: bool, headshot: bool) -> void:
	var bonus := 0
	if killed:
		bonus = kill_bonus + (headshot_bonus if headshot else 0)
	add((points_per_hit + bonus) * multiplier)


## Gives the points for one repaired board, up to board_points_per_round in the round. After that it gives none. The limit counts the points before a boost.
func reward_board() -> void:
	var amount := mini(points_per_board, board_points_per_round - _board_points_this_round)
	if amount <= 0:
		return
	_board_points_this_round += amount
	add(amount * multiplier)


## Multiplies earned points by `factor` for `seconds`. A new boost replaces the one that runs.
func boost(factor: int, seconds: float) -> void:
	multiplier = factor
	_boost_left = seconds
	boost_changed.emit()


func boost_time_left() -> float:
	return maxf(_boost_left, 0.0)


## Starts the point limit for repairs again. The level calls it when a round starts.
func start_round() -> void:
	_board_points_this_round = 0
