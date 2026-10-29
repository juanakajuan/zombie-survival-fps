# Melee

The player presses V to slap with the left hand. The player sees an open cartoon glove come up from the lower right, whip across the screen to the left with the back of the hand leading, and drop out of view at the lower left. The pistol dips down and rolls right during the swing. A zombie within about 1.8 m in front takes damage when the hand lands, and the player gets points as for a shot. The pistol cannot fire or reload during the swing.

## Sub-features

- `slap` starts a swing on V. A second press during the swing does nothing.
- `slap-hit` damages each living zombie in a short sphere in front of the head, once for each swing, at the end of the wind-up.
- `slap-points` gives the points of a hit, and the kill bonus for the killing slap. Target dummies give none.
- `slap-view` shows the left glove during the swing only, and dips the pistol.
- `slap-lock` stops fire and reload during the swing.

## How to get to it (user POV)

- Start the game. Wait for a zombie to walk close. Look at it and press V.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.points` is `0`.

- **Wait for a zombie.** `until zombies.alive 4 300`, then `wait 420` and `aim`. A zombie reaches the player in about 8 s.
- **Slap.** Run `tap melee`, `wait 12`, with a `shot` 5 frames after the tap. The screenshot shows the glove mid-swing. `expect_not hud.points 0` passes once the zombie is in reach.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/melee.steps`. No state key reads the swing; `tests/player/test_melee.gd` covers it.

## Gotchas

- The reach is short. A zombie that is more than about 2 m away is not hit, so `aim` first, then tap when the zombie is close.
- A tap is 2 frames, and a swing lasts about 0.5 s. Wait 40 frames between taps.
- A shot taken within the swing does nothing. Do not mix `tap fire` into the swing.
