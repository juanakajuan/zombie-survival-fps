# Wall buys

A wall buy is a dark board on a wall with a pale silhouette of a weapon on it and a yellow label: SHOTGUN, and 1200 under it. In the test range it is on the outer (west) wall of the room behind the door, at `11.75 0 15`. When the player looks at the board within 2.5 m, the prompt shows `E  BUY SHOTGUN  1200`. E spends 1200 points and puts the shotgun in hand, with `6 / 36` on the HUD. Then the board sells shotgun ammo for 500. The shotgun is semi-automatic, and each shot sends 8 pellets in a cone of 5 degrees, so one press shows a spray of tracers. A reload throws the shotgun away and draws a new one, as the pistol does.

A second wall buy, on the north wall of the same room at `13.4 0 11.75`, sells the RIFLE for 1500 (ammo 600). The rifle is semi-automatic, with 10 rounds and 70 damage a shot, so two body shots kill a round 1 zombie. Its reload keeps the gun in the hand and swaps the magazine, as the SMG does.

A third wall buy, on the east face of the large crate at `-4 0 -8`, sells the MACHINE GUN for 2500 (ammo 1000). It is automatic, with a 100-round magazine and a 300-round reserve, and its reload takes 4.5 s.

## Sub-features

- `wall-buy-prompt` shows `E  BUY SHOTGUN  1200` while the player looks at the board.
- `buy-shotgun` takes 1200 points and equips the shotgun: `hud.weapon` is `SHOTGUN`, `hud.ammo` is `6 / 36`. The prompt then is `E  BUY SHOTGUN AMMO  500`.
- `pellets` fires 8 rays for one shell: one press shows many tracers and `hud.ammo` drops by 1. Each pellet that hits a living zombie pays 10 points.
- `aim` puts the red bead in the notch of the rear sight at the screen centre.
- `reload` throws the gun away and takes the missing shells from the reserve.
- `buy-rifle` takes 1500 points and equips the rifle: `hud.weapon` is `RIFLE`, `hud.ammo` is `10 / 60`. A held fire button fires one shot.
- `rifle-aim` puts the red dot of the front post in the notch of the rear sight.
- `buy-machine-gun` takes 2500 points and equips the machine gun: `hud.weapon` is `MACHINE GUN`, `hud.ammo` is `100 / 300`. A held fire button keeps firing.
- `machine-gun-reload` shows RELOADING for 4.5 s and takes the missing rounds from the reserve.
- `machine-gun-upgrade` turns the machine gun into MACHINE GUN+: a green body, 50 damage a shot, `150 / 450` ammo, and a 3.5 s reload.
- `rifle-upgrade` turns the rifle into RIFLE+: an orange body, 150 damage a shot, and `15 / 90` ammo.
- `upgrade` at the upgrade machine (with power) turns the shotgun into SHOTGUN+: a blue body, 10 pellets of 32 damage, and `10 / 60` ammo.

## How to get to it (user POV)

- Start the game. Get 1200 points (shoot zombies, or the debug menu on F1 in a debug build).
- Turn right and back, toward the room in the south-east. Walk to the board on its west wall. Look at it. Press E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.points` is `0`, `hud.weapon` is `PISTOL`.

- **Points.** Run `debug +5000 POINTS`. `expect hud.points 5000` passes.
- **Walk to the board.** Run `face -127.4 -5`, `hold move_forward`, `until hud.prompt_visible true 900`, `release move_forward`. `expect hud.prompt E BUY SHOTGUN 1200` passes. The screenshot shows the board with the shotgun silhouette.
- **Buy.** Run `tap interact`, `wait 5`. `expect hud.points 3800`, `expect hud.weapon SHOTGUN`, and `expect hud.ammo 6 / 36` pass.
- **Fire.** Run `face 0 0`, `wait 10`, `tap fire`, then `shot` at once. The screenshot shows a spray of tracers. `expect hud.ammo 5 / 36` passes.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/shotgun.steps`.
- **Rifle.** Run `debug +5000 POINTS`, `face -113 -5`, `hold move_forward`, `until hud.prompt_visible true 900`, `release move_forward`. `expect hud.prompt E BUY RIFLE 1500` passes. `tap interact`, then `expect hud.weapon RIFLE` and `expect hud.ammo 10 / 60` pass. Hold fire for 30 frames: `expect hud.ammo 9 / 60` passes. The proof is `journeys/rifle.steps`.
- **Machine gun.** Run `debug +5000 POINTS`, `face 4.1 0`, `hold move_forward`, `wait 180`, `release move_forward`, `face 90 -5`, `hold move_forward`, `until hud.prompt_visible true 300`, `release move_forward`. `expect hud.prompt E BUY MACHINE GUN 2500` passes. The proof is `journeys/machine_gun.steps`.
- **Shotgun upgrade.** `journeys/shotgun_upgrade.steps` buys the shotgun, the room door, and the power with `walk_to`, then upgrades the shotgun: `expect hud.weapon SHOTGUN+` and `expect hud.ammo 10 / 60` pass.
- **Rifle upgrade.** `journeys/rifle_upgrade.steps` does the same with the rifle: `expect hud.weapon RIFLE+` and `expect hud.ammo 15 / 90` pass.
- **Machine gun upgrade.** `journeys/machine_gun_upgrade.steps` does the same with the machine gun: `expect hud.weapon MACHINE GUN+` and `expect hud.ammo 150 / 450` pass.

## Gotchas

- The `debug` command runs a debug menu button. It skips the earning of points, so this journey proves the wall buy and the shotgun, not the points from kills. `journeys/weapons.steps` proves the points.
- Zombies spawn during these journeys and can reach the player, so the health on the HUD can drop.
- The pellet spread is random, so the tracers are in a different place on each run.
- In the Compound, the shotgun wall buy is on the east end of the container south of the start, at `0 0 18.75`, the rifle wall buy is on the north side of the same container, at `-4 0 17.5`, and the machine gun wall buy is on the north side of the container by the south wall, at `10 0 25.5`.
