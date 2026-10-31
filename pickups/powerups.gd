class_name Powerups
extends Node
## The timed effects that run on the player. It is the only owner of them: Wallet and the weapons ask it what is active.

## An effect started or ended.
signal changed

## The seconds left of each running effect, in the order that they started.
var _time_left: Dictionary[TimedItem, float] = {}


func _physics_process(delta: float) -> void:
	var ended := false
	for item: TimedItem in _time_left.keys():
		_time_left[item] -= delta
		if _time_left[item] <= 0.0:
			_time_left.erase(item)
			ended = true
	if ended:
		changed.emit()


## Starts the effect for its duration. An effect that already runs starts its time again.
func start(item: TimedItem) -> void:
	_time_left[item] = item.duration
	changed.emit()


## The seconds left of the effect, or 0 when it does not run.
func time_left(item: TimedItem) -> float:
	return _time_left[item] if item in _time_left else 0.0


## The running effects, in the order that they started.
func running() -> Array[TimedItem]:
	return _time_left.keys()


## What earned points are multiplied by: the highest multiplier of the running effects, or 1.
func points_multiplier() -> int:
	var best := 1
	for item: TimedItem in _time_left:
		best = maxi(best, item.points_multiplier())
	return best


## Whether a running effect makes each hit on a zombie a kill.
func kills_on_hit() -> bool:
	for item: TimedItem in _time_left:
		if item.kills_on_hit():
			return true
	return false

