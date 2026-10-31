# Grenades

The player presses G to throw a grenade. A small green grenade leaves the head along the aim, arcs, and bounces on the ground. About 2.5 s after the throw it explodes in an orange flash. Every living zombie within about 5 m takes damage, more the closer it is, and the player gets points as for a hit, with the kill bonus for a zombie that dies. The blast also hurts the player, at half the damage. The HUD shows the count under the ammo (`G GRENADES 2`). The player starts with 2, each new round adds 2, and the most the player holds is 4.

## Sub-features

- `throw` takes one grenade on G and sends it along the aim. With none left, or while downed or dead, G does nothing. A second press within half a second does nothing.
- `fuse` explodes the grenade once, `Grenade.fuse_time` after the throw, then shows the flash for a moment.
- `blast` damages each living zombie in the radius once, with less damage the farther it stands from the centre. A wall does not stop it.
- `blast-points` gives the points of a hit for each zombie that the blast damages, and the kill bonus for each that dies. It never counts as a headshot.
- `blast-self` hurts the player by `Grenade.player_damage_scale` of the damage a zombie would take. It pays nothing.
- `hud-count` shows the count and follows each throw and each refill.
- `refill` adds `Grenades.per_round` at the start of each round after the first, up to `Grenades.max_count`.

## How to get to it (user POV)

- Start the game. Look at the ground a few metres ahead of the zombies and press G. Step back and watch the blast.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.grenades` is `2` and `hud.points` is `0`.

- **Wait for the zombies.** `until zombies.alive 4 300`, then `wait 40` and `aim`. The nearest zombie is about 13 m away and walks at 2.5 m/s.
- **Aim at the ground ahead.** `look 0 220` turns the view about 33 degrees down from the zombie, so that the grenade lands about 4 m ahead and rolls on toward the zombies.
- **Throw.** `tap grenade`, then `expect hud.grenades 1`. A `shot` 30 frames later shows the grenade on the ground. `look 0 -190` first turns the view back up to the zombies.
- **Blast.** The grenade explodes 150 frames after the throw. A `shot` at about frame 153 shows the flash. `expect_not hud.points 0` and `expect_not zombies.alive 4` pass after it.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/grenade.steps`. The fuse, the falloff, the points of a kill, the self damage, and the refill are in `tests/grenades/test_grenade.gd`.

## Gotchas

- Throw early. A grenade that hits a zombie in the air bounces back at the player. Thrown at the ground a few metres ahead while the zombies are still far, it is already in their path when it explodes.
- The blast hurts the player. A grenade that lands at the player's feet takes about half of what a zombie would take, so keep the throw out past 3 m.
- The run is real time, so the exact landing spot and the frame of the blast move a little between runs. `expect_not` against the start value is the safe check.
