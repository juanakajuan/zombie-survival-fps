# Doors, power, and the secret

The Yard has two closed doors. The player buys a door to open a zone. A power switch turns on the machines. Three sigils hide a cache.

## Sub-features

- `door-prompt` shows `E  Open Warehouse  1250` at the east door and `E  Open Courtyard  1750` at the north door. The prompt is gray when the player cannot pay, and a press buys nothing.
- `door-open` takes the points, removes the blocker, and adds the zone spawn points. Proven by `test_doors` in `tests/test_runner.gd`, not by a scenario (the player cannot earn 1250 points with the pistol in round 1).
- `power` is the switch at the far end of the Warehouse. Proven by `test_power`.
- `secret` is three shots at the sigils on the north wall of the Courtyard, then the cache in the alcove. Proven by `test_secret`.

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
- It does not prove `door-open`, `power`, and `secret`. They need more points than round 1 gives, and a driver command to set points would not be the real player path.
