# Zombie animation

Each zombie is a skinned PS1-style model. A chasing zombie plays a shambling walk: the left arm reaches forward, the right leg drags, and the head lolls. The walk plays faster for a faster zombie. A zombie in reach of the player swings both arms down on each attack. A dead zombie stops its animation and sinks.

## Sub-features

- `walk` plays while the zombie chases. The stride rate follows the ground speed (1x at 1.6 m/s).
- `attack` plays once on each attack, every 1.2 s, while the player is in reach.
- `dead` stops the animation.

## How to get to it (user POV)

- Start the game, wait for round 1, and look at a zombie that walks to you. Stay still until it attacks.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/zombie-animation.txt`. It takes about 20 s.

- **Walk.** `wait_until nearest_zombie_m < 9 30`, then `aim_nearest body` and `shot walk-1` to `walk-3`, 0.25 s apart. Each shot must show the legs at a different point in the stride.
- **Attack.** `wait_until health < 100 20` catches the first attack. Then `shot attack-rise` (both arms go up) and `shot attack-strike` (the body bends forward, the arms are down).

## Gotchas

- The scenario does not fire. Only the screenshots prove the poses: look at each PNG.
- The `dead` sub-feature has a headless check in `tests/test_runner.gd` (`test_zombie`), not a scenario step.
