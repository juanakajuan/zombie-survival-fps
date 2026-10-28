# Zombie Survival FPS design

This file has the core loop, the decided game rules, the parts that are done, and the work after the minimal game. [CLAUDE.md](CLAUDE.md) has the commands and the code rules.

Edit this file only when the core loop, a decided rule, or the list of parts changes. Tunable values, such as speeds, damage, and round sizes, are not in this file. They are `@export` values and `.tres` Resources, and the Inspector shows them. The verify skill's feature files in [.claude/skills/verify/features/](.claude/skills/verify/features/) show what a player can do with each part, and how to prove it.

## The core loop

You stand in an arena. Zombies come at you in rounds, and you shoot them before they reach you. When all zombies of a round are dead, a short break starts. Then a harder round starts. When your health gets to 0, the game ends and shows the round that you reached. You restart and try to reach a later round.

The minimal game is done: a player can play the full loop from a fresh start, without the editor. The verify skill plays it with `.claude/skills/verify/journeys/full_loop.steps`. That journey aims with the driver's `aim` command, so it does not test how hard aiming is. GitHub issues #1 to #5 and the git history have the steps that built it.

## Decided rules

- Zombies are box primitives built in code. Do not add imported or generated zombie models, and do not add rigged animation. A Blender-generated model with animation was tried and rejected.
- The level and the zombies use Godot primitives and code for meshes and materials. The only imported model is the pistol view model, `weapons/pistol.glb`. Its Blender source is `art_source/pistol.blend`.
- Weapons are hitscan. A shot is one ray from the camera.
- A node that can take damage has a `Health` child (`health/health.gd`). Code that deals damage finds it with `Health.find_on(node)`.
- `RoundSettings` (`rounds/round_settings.tres`) is the only source of zombie count, health, and speed for each round.

## What is done

Each part is a folder with its scenes, scripts, and data. The folder's tests in `tests/<folder>/` give the exact behavior.

| Part | Folder | What the player gets |
|---|---|---|
| Player | `player/` | Quake-style movement (ground friction, air strafing, jump held to hop again), sprint, crouch, mouse look, and death. **Esc** releases the mouse. Only `Player` writes the mouse mode. |
| Weapon | `weapons/` | The hitscan pistol (`pistol.tres`) with a magazine, a reload, and no reserve ammo. The animated view model (`view_model.gd`) and the thrown guns of a reload (debris on physics layer 2). |
| Health | `health/` | The `Health` node that takes damage, and `HitFlash`, which flashes a mesh red on a hit. |
| Target dummy | `targets/` | A dummy that flashes when hit, goes away at 0 health, and comes back. |
| Zombie | `zombie/` | A box zombie that follows the navmesh to the player and hits at close range. |
| Test range | `levels/` | The greybox map and the main scene, with target dummies, zombie spawn points, and a crawl tunnel west of the spawn. `level_navigation.gd` bakes the navmesh at start from the static colliders on physics layer 1. |
| Rounds | `rounds/` | `RoundManager` spawns each round's zombies from `RoundSettings`, then starts a break when the last zombie dies. |
| HUD | `hud/` | The crosshair, health, ammo, the RELOADING label, the round number, and the BREAK label. |
| Game over | `game_over/`, `levels/level.gd` | The GAME OVER screen with the round reached. **Enter** reloads the level. |

## After the minimal game

These parts wait until the loop works. The list is not complete, and its order is not a priority:

- Points for kills and hits.
- Buy stations for weapons and ammo.
- Reserve ammo.
- Doors that open new areas of the map.
- Pickups.
- Audio.
- More weapons.
- An arena map that replaces the test range.
