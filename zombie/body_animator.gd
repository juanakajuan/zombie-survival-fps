@abstract
class_name BodyAnimator
extends Node
## Poses the model of a Zombie in code. Each body (the Shambler, the Mutt) has its own subclass for its own parts.

## The gait to pose. Set it before attach().
var gait: Zombie.Gait = Zombie.Gait.WALK


## Finds the parts in the model. Call it before the first advance().
@abstract func attach(model: Node3D) -> void


## Moves the pose on by one step. `attack_progress` goes from 0 just after a hit to 1 at the next hit, and is
## negative when the zombie is not attacking.
@abstract func advance(delta: float, speed: float, attack_progress: float) -> void


## Moves the death pose on by one step. Call it each physics frame after the zombie dies, until death_finished().
@abstract func advance_death(delta: float) -> void


## The time from death until the zombie goes.
@abstract func death_length() -> float


## Whether the death pose has played to the end, so the zombie can go.
@abstract func death_finished() -> bool


## Whether the model shows its legs.
func has_legs() -> bool:
	return true
