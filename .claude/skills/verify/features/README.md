# Zombie Survival FPS verification map

This folder is the maintained source for proof of what a player can do in the game. Read this index before you drive the game. Then use the matching feature file as the recipe. [../SKILL.md](../SKILL.md) has the harness commands and state keys.

## Baseline preconditions

- Run `godot --headless --path . --import` once in the checkout.
- `.claude/skills/verify/scripts/doctor.sh` reports no `FAIL`.
- Each run starts from a new load of `res://levels/test_range.tscn` (not the main scene, `levels/compound.tscn`): round 1, 100 health, `12 / 48` ammo, the mouse captured, the player at `0.0 0.0 6.0` and looking toward -Z, 3 target dummies, and zombies that spawn one each second.
- Never drive the game that the human runs from the editor.

## Driving conventions

- Run every journey with `.claude/skills/verify/scripts/drive.sh <steps file> [run id]`.
- Send input only with the steps commands (`hold`, `release`, `tap`, `key`, `look`, `aim`, `fight_until`). Do not call game methods.
- Use the Input Map action names and the state keys as they are written.
- A ready journey file is in `../journeys/<feature>.steps`. Copy it and add steps for a new check.

## Proof and skip reporting

- Capture the action and the state after it: `state` and `shot` before and after, and an `expect` on the change.
- The proof for each run is in `.smoke/verify/<run id>/`. Give the run id and the feature file with the result.
- Report the exit code of `drive.sh` and every `FAIL` line from `godot.log`.
- When a precondition is missing, report the failure with the step and the reason. Do not report a path that you did not drive as verified.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph about the behavior that the player sees. Then it has four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with drive.sh`, and `Gotchas`.

## Features

- [Movement and look](./movement-and-look.md) covers walking, jumps, the slide, crouch and the crawl tunnel, mouse look and its pitch limit, the debug third-person view, and the Esc pause menu that releases the mouse and captures it again on resume.
- [Weapon and targets](./weapon-and-targets.md) covers firing, the tracer and the hit marker, the pistol in the player's hand, aim down the sights, ammo on the HUD, target dummies, and reload.
- [Melee](./melee.md) covers the punch on V: the left hand animation, the damage at short reach, and the points from a punch.
- [Economy](./economy.md) covers points from zombie hits and kills, the reserve ammo, and the buy station that sells ammo with E.
- [Doors and pickups](./doors-and-pickups.md) covers the door that points buy, the spawn point that waits for it, and the max ammo and double points pickups that a walk over them give.
- [Barricades](./barricades.md) covers the boarded window that a zombie breaks and the player repairs with a hold on E, and the points that each board gives.
- [Power and perks](./power-and-perks.md) covers the power switch in the room behind the door, the perk machines that sell only with power, and the perk icons on the HUD.
- [Rounds and HUD](./rounds-and-hud.md) covers zombie spawns, the zombie health bar, the zombies-left line, clearing a round, the BREAK label, and the next round with stronger zombies.
- [Death, game over, and restart](./death-and-game-over.md) covers zombie attacks, player death, the game-over screen, and restart with Enter.

## Full loop

`../journeys/full_loop.steps` plays the core loop of [DESIGN.md](../../../../DESIGN.md) in one run: clear round 1, see the break and round 2 with 6 zombies, die in round 2, read `You reached round 2`, and restart to round 1. Run it after a change to rounds, death, or restart. The run takes about 30 s.
