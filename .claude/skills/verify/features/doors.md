# Doors, power, and the secret

The Yard has two closed doors. The player buys a door to open a zone. A power switch turns on the machines. Three sigils hide a cache.

## Sub-features

- `door-prompt` shows `E  Open Warehouse  1250` at the east door and `E  Open Courtyard  1750` at the north door. The prompt is gray when the player cannot pay, and a press buys nothing.
- `door-open` takes the points, removes the blocker, label, and prompt, and adds the 3 zone spawn points. Proven by `test_doors` in `tests/test_runner.gd`. Round 1 gives about 1200 points with the pistol, so a player needs a part of round 2 for the east door.
- `power` is the switch at the far end of the Warehouse. Its prompt is `E  Turn on power`, then `Power is on`. It costs nothing and turns on all five machines. Proven by `test_power`.
- `secret` is three shots at the sigils on the north wall of the Courtyard, then the cache in the alcove (`E  Take the cache`: 1500 points and full ammunition for each weapon that the player has). Proven by `test_secret`.

## How to get to it (user POV)

| Thing | Position | Price |
|---|---|---|
| East door | east wall, z 0 | 1250 |
| North door | north wall, x 0 | 1750 |
| Power switch | Warehouse east wall, z 0 | 0 |
| Sigils | Courtyard north wall, x -8, 0, 8 | |
| Cache | alcove behind the Courtyard east wall, z -43 | 0 (gives 1500 points) |

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/doors.txt`. It takes about 30 seconds.

- The scenario proves `door-prompt` and the refusal with 500 points, with a screenshot of each door.
- It does not prove `door-open`, `power`, and `secret`. A driver command to set points would not be the real player path.
- The real path to `door-open` and `power` works, but it is not reliable with the pistol, so it is not a kept scenario. Clear round 1, walk to `17.5,0` in the intermission, `wait_until round == 2 15`, `wait_until nearest_zombie_m <= 15 30`, `fight 30 head`, then `face -90 0` and `tap E` with 1250 points or more. Then `press Shift` and walk `25,1.5`, `38,1.5`, `38,11`, `44,11`, `44,2`, `58.5,2`, `58.5,0`, and `face -90 0` at the switch. In 4 tries, the pistol died in round 2 two times, and one try got no switch prompt at `58.5,0`.
