# Zombie Survival FPS design

This file has the core loop, the decided game rules, what is done, and the steps to a minimal game. [CLAUDE.md](CLAUDE.md) has the commands and the code rules.

When you finish a step, move it to [What is done](#what-is-done) in the same commit.

## The core loop

You stand in an arena. Zombies come at you in rounds, and you shoot them before they reach you. When all zombies of a round are dead, a short break starts. Then a harder round starts. When your health gets to 0, the game ends and shows the round that you reached. You restart and try to reach a later round.

The game is minimal when a player can play the full loop from a fresh start, without the editor. The minimal game is done.

## Decided rules

- Zombies are box primitives built in code. Do not add imported or generated zombie models, and do not add rigged animation. A Blender-generated model with animation was tried and rejected.
- The game uses no external assets. Meshes and materials come from Godot primitives and code.
- Weapons are hitscan. A shot is one ray from the camera.
- A node that can take damage has a `Health` child (`health/health.gd`). Code that deals damage finds it with `Health.find_on(node)`.

## What is done

| Part | Files | Behavior |
|---|---|---|
| Player | `player/` | Walk at 4.5 m/s, sprint at 7 m/s, jump, and mouse look. 100 health. **Esc** releases the mouse. The click that captures the mouse again does not fire. At 0 health the player emits `died` and cannot move, jump, look, fire, or reload, but still falls under gravity. |
| Weapon | `weapons/` | The pistol (`pistol.tres`) does 25 damage, fires every 0.15 s, holds 12 rounds, reloads in 1.2 s, and reaches 100 m. Left mouse fires and **R** reloads. A shot with an empty magazine starts a reload. There is no reserve ammo. |
| Health | `health/` | `damage()`, `reset()`, `is_dead()`, and the `damaged`, `died`, and `changed` signals. |
| Target dummy | `targets/` | 100 health. It flashes red when hit, goes away at 0 health, and comes back after 2 s. |
| Zombie | `zombie/` | 100 health. It follows the navmesh to the player at 2.5 m/s. Within 1.3 m it hits for 10 damage each 1 s. It is removed when it dies. It does not attack a dead player. |
| Test range | `levels/` | The greybox map and the main scene. It has 3 target dummies and 4 zombie spawn points. `level_navigation.gd` bakes the navmesh when the level starts. |
| Game over | `game_over/`, `levels/level.gd` | When the player dies, a screen shows GAME OVER and the round that the player reached, and the mouse is released. **Enter** (the `restart` action) then makes the screen emit `restart_requested`, and `Level` reloads the level: round 1, full health, a full magazine, and the mouse captured. Before death, `restart` does nothing. |
| Rounds | `rounds/` | `RoundManager` starts round 1 when the level loads. Each round spawns its zombies one each 1 s, in turn at the `Marker3D` children of the manager. `round_settings.tres` gives 4 zombies in round 1 and 2 more each round, 100 health and 20 more each round, and 2.5 m/s and 0.25 m/s more each round up to 5 m/s. When the last zombie dies, a 10 s break starts, then the next round. Other code reads `round_number` and `state` (`BREAK` or `ACTIVE`) and connects to `round_started` and `round_ended`. |
| HUD | `hud/` | An instance in `player/player.tscn`. A 4 px crosshair dot at the center. Bottom left: health as a number and a bar, red at 30% or less. Bottom right: rounds in the magazine (`11 / 12`) and a yellow RELOADING label during a reload. Top center: the round number and a blue BREAK label during the break between rounds. The HUD finds the `RoundManager` through its `round_manager` group, and hides the round panel when there is none. The values change on the `Health`, `Weapon`, and `RoundManager` signals. |

## Steps to a minimal game

The minimal game uses `levels/test_range.tscn` as its map. Each step is a GitHub issue that one agent can do. The `ready` label marks an issue that an agent can start now. The `blocked` label marks an issue that waits on other issues. When an issue closes, move the `ready` label to each issue that it unblocked.

Steps 1, 2, and 3 need no other step, so agents can do them at the same time. Step 4 needs steps 1 and 2. Step 5 needs steps 1 and 3.

| Step | Issue | Needs |
|---|---|---|
| 1. Add the round manager (done) | [#1](https://github.com/juanakajuan/zombie-survival-fps/issues/1) | Nothing |
| 2. Add the HUD for health and ammo (done) | [#2](https://github.com/juanakajuan/zombie-survival-fps/issues/2) | Nothing |
| 3. Add player death (done) | [#3](https://github.com/juanakajuan/zombie-survival-fps/issues/3) | Nothing |
| 4. Show the round number on the HUD (done) | [#4](https://github.com/juanakajuan/zombie-survival-fps/issues/4) | Steps 1 and 2 |
| 5. Add game over and restart (done) | [#5](https://github.com/juanakajuan/zombie-survival-fps/issues/5) | Steps 1 and 3 |

A step is done when all of these are true:

- `tools/check.sh` passes.
- A test covers each done-criterion that a test can see.
- A `tools/smoke.sh` screenshot shows each visible result.

When the 5 steps are done, play one full loop by hand. Survive round 1, see round 2 start with more zombies, die, read the round on the game-over screen, and restart.

The 5 steps are done, and the full loop passes. The verify skill plays it with `.claude/skills/verify/journeys/full_loop.steps`, and the run has 0 failures. The run aims with the driver's `aim` command, so it does not test how hard aiming is.

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
