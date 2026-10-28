# Zombie Survival FPS verification map

This folder is the maintained source for proof of what a player can do in the game. Read this index before you drive the game. Then use the matching feature file as the recipe. [../SKILL.md](../SKILL.md) has the harness commands and state keys.

## Baseline preconditions

- Run `godot --headless --path . --import` once in the checkout.
- `.claude/skills/verify/scripts/doctor.sh` reports no `FAIL`.
- Each run starts from a new load of `res://levels/test_range.tscn`: round 1, 100 health, `12 / 12` ammo, the mouse captured, the player at `0.0 0.0 6.0` and looking toward -Z, 3 target dummies, and zombies that spawn one each second.
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

- [Movement and look](./movement-and-look.md) covers walking, mouse look, releasing the mouse with Esc, and the click that captures it again.
- [Weapon and targets](./weapon-and-targets.md) covers firing, ammo on the HUD, target dummies, and reload.
- [Rounds and HUD](./rounds-and-hud.md) covers zombie spawns, clearing a round, the BREAK label, and the next round.
- [Death, game over, and restart](./death-and-game-over.md) covers zombie attacks, player death, the game-over screen, and restart with Enter.
