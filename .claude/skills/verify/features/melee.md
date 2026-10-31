# Melee

The player presses V to punch with the left hand. The player sees a cartoon fist come up at the lower left, jab straight out to the screen centre, and drop back out of view. The pistol dips down and rolls right during the swing. A zombie within about 1.8 m in front takes damage when the fist lands, and the player gets points as for a shot. The pistol cannot fire or reload during the swing.

## Sub-features

- `punch` starts a swing on V. A second press during the swing does nothing, and so does V during a reload or with a grenade in hand.
- `punch-hit` damages each living zombie in a short sphere in front of the head, once for each swing, at the end of the wind-up.
- `punch-points` gives the points of a hit, and the kill bonus for the killing punch. Target dummies give none.
- `punch-view` shows the left fist during the swing only, and dips the pistol.
- `punch-lock` stops fire and reload during the swing.

## How to get to it (user POV)

- Start the game. Wait for a zombie to walk close. Look at it and press V.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.points` is `0`.

- **Wait for a zombie.** `until zombies.alive 4 300`. A zombie reaches the player in about 8 s.
- **Punch it dead.** Run `punch_until hud.objective 3 LEFT 900`. It punches the nearest zombie as soon as it is in reach. A round 1 zombie has 100 health and a punch does 50, so two punches kill it before it hits the player. `expect hud.points 80` (10 for the hit, 10 + 60 for the kill) and `expect player.dead false` pass.
- **See the swing.** Run `aim`, `tap melee`, `wait 5`, `shot`. The screenshot shows the fist mid-swing.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/melee.steps`. No state key reads the swing; `tests/player/test_melee.gd` covers it.

## Gotchas

- The reach is short. A zombie that is more than about 2 m away is not hit, so `aim` first, then tap when the zombie is close.
- A tap is 2 frames, and a swing lasts about 0.3 s. Wait 40 frames between taps, or use `punch_until`.
- Do not wait for zombies with a fixed `wait`. A zombie does 40 damage each second, and four zombies kill the player in about 1 s. A punch after a long wait lands on a dead player.
- A shot taken within the swing does nothing. Do not mix `tap fire` into the swing.
