# Zombie Survival FPS verification map

This directory is the maintained source for verifying what a player can do in Zombie Survival FPS. Read this index before you drive the game, then use the matching feature file as the recipe.

## Baseline preconditions

- `.claude/skills/verify/doctor.sh` prints no `PROBLEM:` line.
- Each run starts a new game: round 0, phase `STARTING`, 500 points, 100 health, the pistol (`hud_weapon == Pistol`, `slots == *Pistol`) with `8 / 80` ammunition, player at `0,0,6` facing -Z.
- Round 1 starts 3 s after launch with 6 zombies of 150 health.

## Driving conventions

- Drive with `.claude/skills/verify/run.sh <scenario>` from the project root. `../SKILL.md` lists the scenario commands and state fields.
- Use keys, mouse buttons, and mouse motion only. Do not call game methods or set test hooks from a scenario.
- Wait for conditions with `wait_until`, not with long fixed waits. Spawns and spread are random.
- The keyboard and mouse entry points are drivable. The gamepad entry points are not driven yet: the driver sends no joypad events.

## Proof and skip reporting

- Proof is the evidence directory: `transcript.log` with `PASS` lines, and the PNG files. Look at the PNG files.
- Assert the HUD text and the game state behind it.
- Report each entry point that you did not drive (for example, the gamepad) as not verified, with the reason.

## Features

| Feature | File | Scenario | Code |
|---|---|---|---|
| Pistol: fire, hit, reload | [pistol.md](pistol.md) | `scenarios/pistol.txt` | `game/weapon/` |
| Knife attack | [melee.md](melee.md) | `scenarios/melee.txt` | `game/weapon/` |
| Rounds and intermission | [rounds.md](rounds.md) | `scenarios/rounds.txt` | `game/zombie/`, `game/round_director.gd`, `game/points.gd` |
| Death and play again | [death-restart.md](death-restart.md) | `scenarios/death-restart.txt` | `game/zombie/` |
| Pause and resume | [pause.md](pause.md) | `scenarios/pause.txt` | none |
| Movement: walk, sprint, slide, jump | [movement.md](movement.md) | `scenarios/movement.txt` | `game/player/`, `game/level/` |
| Buys: wall buys, ammo, weapon change, box | [buys.md](buys.md) | `scenarios/buys.txt` | `game/weapon/`, `game/station/`, `game/points.gd`, `game/level/` |
| Perks and upgrades: perk machines, upgrade machine | [perks.md](perks.md) | `scenarios/perks.txt` (`No power` prompts only) | `game/weapon/`, `game/station/`, `game/station/power_switch.gd`, `game/station/perk_machine.gd`, `game/station/upgrade_machine.gd`, `game/station/machine.gd`, `game/perks.gd`, `game/level/` |
| Doors, power, and the secret | [doors.md](doors.md) | `scenarios/doors.txt` (door prompts only) | `game/station/`, `game/station/door.gd`, `game/station/power_switch.gd`, `game/station/cache.gd`, `game/level/`, `game/level/secret.gd`, `game/level/sigil.gd` |
| Arena layout | [README.md](README.md) | none | `game/level/` |
| Shared code: any feature file or SKILL.md | [SKILL.md](../SKILL.md) | none | `game/hud.gd`, `game/game.gd`, `game/game_config.gd`, `game/rules.gd` |

The Code column is the map that rule L1 of `tools/lint.py` reads. A commit that changes a path in the column must change each feature file that lists the path, or carry a `Verify-map: unchanged (<reason>)` trailer. The longest matching path wins. Rule L1m fails when a table row cannot be read, when a path in the column does not exist, and when a file under `game/` has no Code path and is not in `L1_IGNORED` in `tools/lint.py`. Write a pipe inside a cell as `\|`.
