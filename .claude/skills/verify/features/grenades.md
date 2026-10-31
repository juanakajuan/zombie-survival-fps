# Grenades

The player presses G to pull the pin: the left hand comes up with a small green grenade, and the fuse starts at the press. Releasing G swings the hand forward, and the grenade leaves it along the aim, arcs, and bounces on the ground. A tap throws with nearly the whole fuse, and holding G cooks the grenade, so it explodes sooner after the throw. About 2.5 s after the press it explodes in an orange flash, or in the hand when G is held that long. Every living zombie within about 5 m takes damage, more the closer it is, and the player gets points as for a hit, with the kill bonus for a zombie that dies. The blast also hurts the player, at half the damage. The HUD shows the count under the ammo (`G GRENADES 2`). The player starts with 2, each new round adds 2, and the most the player holds is 4.

## Sub-features

- `cook` takes one grenade when G goes down, raises the hand with the grenade, and starts the fuse. The HUD shows the fuse left in orange next to the count (`hud.grenade_fuse`, for example `2.1`). With none left, or while downed or dead, G does nothing.
- `throw` plays the swing when G comes up. The grenade leaves the hand 0.12 s later along the aim, with the fuse that is left, and the hand drops out of view. A press during the cook or the swing does nothing.
- `busy` stops the gun (no fire, no reload) and the punch from the pin pull until the swing ends. The gun dips out of the hand's way.
- `fuse` explodes the grenade once, `Grenade.fuse_time` after the press, then shows the flash for a moment. A grenade held that long explodes in the hand, at the head.
- `drop` lets a player who goes down or dies while cooking drop the grenade at the feet. It still explodes.
- `blast` damages each living zombie in the radius once, with less damage the farther it stands from the centre. A wall does not stop it.
- `blast-points` gives the points of a hit for each zombie that the blast damages, and the kill bonus for each that dies. It never counts as a headshot.
- `blast-self` hurts the player by `Grenade.player_damage_scale` of the damage a zombie would take. It pays nothing.
- `hud-count` shows the count and follows each throw and each refill.
- `refill` adds `Grenades.per_round` at the start of each round after the first, up to `Grenades.max_count`.

## How to get to it (user POV)

- Start the game. Look at the ground a few metres ahead of the zombies and press G. Step back and watch the blast.
- To cook, hold G for a second, watch the orange fuse count down next to the grenade count, and release.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.grenades` is `2` and `hud.points` is `0`.

- **Wait for the zombies.** `until zombies.alive 4 300`, then `wait 40` and `aim`. The nearest zombie is about 13 m away and walks at 2.5 m/s.
- **Aim at the ground ahead.** `look 0 220` turns the view about 33 degrees down from the zombie, so that the grenade lands about 4 m ahead and rolls on toward the zombies.
- **Throw.** `tap grenade`, then `expect hud.grenades 1`. A `shot` 30 frames later shows the grenade on the ground. `look 0 -190` first turns the view back up to the zombies.
- **Blast.** The grenade explodes 150 frames after the throw. A `shot` at about frame 153 shows the flash. `expect_not hud.points 0` and `expect_not zombies.alive 4` pass after it.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/grenade.steps`. The fuse, the falloff, the points of a kill, the self damage, and the refill are in `tests/grenades/test_grenade.gd`.
- **Cook.** `hold grenade`, then a `shot` about 25 frames later shows the raised hand with the grenade, and `hud.grenade_fuse` is below `2.5`. `release grenade`, `wait 12`, and `look 0 -190` turn the view back up after the grenade has left the hand. `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/grenade_cook.steps` holds for 60 frames, so the blast comes 150 frames after the press, and checks it has happened 120 frames after the release, which a full fuse after the release would not allow. The timing, the gun and fist lock, the hand, the drop and the HUD are in `tests/grenades/test_grenade_cook.gd`.

## Gotchas

- Throw early. A grenade that hits a zombie in the air bounces back at the player. Thrown at the ground a few metres ahead while the zombies are still far, it is already in their path when it explodes.
- The blast hurts the player. A grenade that lands at the player's feet takes about half of what a zombie would take, so keep the throw out past 3 m.
- The swing takes 0.12 s, which is 7 frames, and a `shot` takes real time, so a `shot` after `release grenade` shows the start of the swing or the thrown grenade, not a fixed frame. To look at the middle of the swing, set `Grenades.throw_wind_time` to about 0.8 while you tune, and put it back.
- The run is real time, so the exact landing spot and the frame of the blast move a little between runs. `expect_not` against the start value is the safe check.
