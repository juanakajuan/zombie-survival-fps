# Perks and upgrades

The player buys four perks, each one time, at perk machines on the walls, and upgrades the weapon in the hands at the upgrade machine.

## Sub-features

- `perk-prompt` shows `E  Buy Mender  1500` at a perk machine. The prompt is gray when the player cannot pay. After the buy it says `Mender owned`.
- `perk-buy` takes the points and adds the perk name to the row under the points (`hud_perks`).
- `upgrade-buy` upgrades the pistol for 4000 points. The HUD weapon name becomes `Upgraded Pistol`, and the ammunition `12 / 120`. The prompt then says `Already upgraded`.

## How to get to it (user POV)

| Machine | Position | Price |
|---|---|---|
| Mender | north wall, x 8 | 1500 |
| Rapid | east wall, z 8 | 2000 |
| Quick Hands | south wall, x 5 | 2500 |
| Tough | west wall, z -8 | 3000 |
| Upgrade | south wall, x -10 | 4000 |

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/perks.txt`. It takes about 1 minute.

- The scenario proves `perk-prompt` and the refusal with too few points (1180 after round 1), and the `Upgrade Pistol  4000` prompt with a screenshot of each.
- It does not prove `perk-buy` and `upgrade-buy`. The pistol alone dies in round 2, and 4000 points need many rounds. `test_game_perks` in `tests/test_runner.gd` proves both through `Game.interact()`. A scenario that plays with the SMG for several rounds would prove them on the real path.
