# Weapon upgrade

The upgrade machine is a wide, low yellow box labeled UPGRADE with its cost, 5000. It needs the power switch. Without power, it shows `NO POWER` and its prompt is `NEEDS POWER`. With power, its prompt names the weapon in hand, for example `E  BUY UPGRADE PISTOL  5000`. E takes the points and swaps the weapon in hand for its upgrade in the same slot, with a full magazine and reserve: the PISTOL becomes PISTOL+ (`18 / 108`, 60 damage), and the SMG becomes SMG+ (`45 / 270`, 32 damage). The upgraded gun shows new colors (the pistol slide purple, the SMG body red, and the accents cyan) and keeps its ink outline. An upgraded weapon cannot be upgraded again: the prompt reads `PISTOL+ CANNOT BE UPGRADED`, and E takes no points. The SMG wall station sells SMG+ ammo, not a new SMG.

## Sub-features

- `upgrade-buy` takes 5000 points and swaps the weapon: `hud.weapon` goes from `PISTOL` to `PISTOL+`, and `hud.ammo` from `12 / 48` to `18 / 108`.
- `upgrade-once` refuses a second upgrade and takes no points.
- `upgrade-no-power` refuses a sale while the power is off. `tests/upgrades/test_upgrade.gd` proves it.
- `upgrade-damage` and `upgrade-look` are proved by the same test file. The screenshot shows the new colors.

## How to get to it (user POV)

- Start the test range. The machine is at `4 0 0`, north of the weapon station. The switch is in the room behind the door, as in [power-and-perks.md](./power-and-perks.md).
- Get 10000 points from the debug menu, buy the door, turn on the switch, walk to the west side of the machine, look at it, and press E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `power.on` is `false`, `hud.weapon` is `PISTOL`, `hud.ammo` is `12 / 48`.

- **Points and a clear arena.** Run `key F1`, `key Tab` twice, `key Enter` twice (+10000), `key Tab` four times, `key Enter` (KILL ALL ZOMBIES), `key F1`. `expect hud.points 10000` passes.
- **Door and switch.** Walk the path of [power-and-perks.md](./power-and-perks.md) and turn on the switch.
- **Back to the machine.** Run `until hud.break false 600` and clear round 2 with KILL ALL ZOMBIES. Run `face 0 0` and 150 frames forward, `face 90 0` and 190 frames forward, `face 0 0` and 110 frames forward. The player stops at about `1.5 0 -0.4`.
- **Upgrade.** Run `face -90 -15`. `expect hud.prompt E BUY UPGRADE PISTOL 5000` passes. `tap interact`, then `expect hud.points 4250`, `expect hud.weapon PISTOL+`, `expect hud.ammo 18 / 108`, and `expect hud.prompt PISTOL+ CANNOT BE UPGRADED` pass. A second `tap interact` leaves `hud.points` at `4250`.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/upgrade.steps`. `02-upgraded.png` shows the purple pistol.

## Gotchas

- The run can end with `ERROR: 2 resources still in use at exit` from the break sound after the mid-round kill-all, as in the perks journey (#62).
- The machine sells to the weapon in hand. To upgrade the SMG, hold it when you press E.
- In the Compound, the upgrade machine stands at the east end of the perk machines, along the south wall of the warehouse.
