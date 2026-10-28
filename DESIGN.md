# Zombie Survival FPS design

This file has the core loop, the decided game rules, what is done, and the steps to a minimal game. [CLAUDE.md](CLAUDE.md) has the commands and the code rules.

When you finish a step, move it to [What is done](#what-is-done) in the same commit.

## The core loop

You stand in an arena. Zombies come at you in rounds, and you shoot them before they reach you. When all zombies of a round are dead, a short break starts. Then a harder round starts. When your health gets to 0, the game ends and shows the round that you reached. You restart and try to reach a later round.

The game is minimal when a player can play the full loop from a fresh start, without the editor.

## Decided rules

- Zombies are box primitives built in code. Do not add imported or generated zombie models, and do not add rigged animation. A Blender-generated model with animation was tried and rejected.
- The game uses no external assets. Meshes and materials come from Godot primitives and code.
- Weapons are hitscan. A shot is one ray from the camera.
- A node that can take damage has a `Health` child (`health/health.gd`). Code that deals damage finds it with `Health.find_on(node)`.

## What is done

| Part | Files | Behavior |
|---|---|---|
| Player | `player/` | Walk at 4.5 m/s, sprint at 7 m/s, jump, and mouse look. 100 health. **Esc** releases the mouse. The click that captures the mouse again does not fire. |
| Weapon | `weapons/` | The pistol (`pistol.tres`) does 25 damage, fires every 0.15 s, holds 12 rounds, reloads in 1.2 s, and reaches 100 m. Left mouse fires and **R** reloads. A shot with an empty magazine starts a reload. There is no reserve ammo. |
| Health | `health/` | `damage()`, `reset()`, `is_dead()`, and the `damaged` and `died` signals. |
| Target dummy | `targets/` | 100 health. It flashes red when hit, goes away at 0 health, and comes back after 2 s. |
| Zombie | `zombie/` | 100 health. It follows the navmesh to the player at 2.5 m/s. Within 1.3 m it hits for 10 damage each 1 s. It is removed when it dies. It does not attack a dead player. |
| Test range | `levels/` | The greybox map and the main scene. It has 3 target dummies and 2 placed zombies. `level_navigation.gd` bakes the navmesh when the level starts. |
| Crosshair | `player/player.tscn` | A 4 px dot at the center of the screen. |

## Steps to a minimal game

The minimal game uses `levels/test_range.tscn` as its map. Each step is a GitHub issue that one agent can do.

Steps 1, 2, and 3 need no other step, so agents can do them at the same time. Step 4 needs steps 1 and 2. Step 5 needs steps 1 and 3.

| Step | Needs |
|---|---|
| 1. Add the round manager | Nothing |
| 2. Add the HUD for health and ammo | Nothing |
| 3. Add player death | Nothing |
| 4. Show the round number on the HUD | Steps 1 and 2 |
| 5. Add game over and restart | Steps 1 and 3 |

A step is done when all of these are true:

- `tools/check.sh` passes.
- A test covers each done-criterion that a test can see.
- A `tools/smoke.sh` screenshot shows each visible result.

### 1. Add the round manager

Rounds start, spawn zombies at spawn points, and get harder.

Put the round data in a `RoundSettings` resource in a `.tres` file. It gives the zombie count, the zombie health, and the zombie speed for each round, and the break time between rounds. Mark the spawn points with `Marker3D` nodes in the level.

Done when:

- Round 1 starts when the level loads.
- Round N spawns the number of zombies that `RoundSettings` gives for round N, at the spawn points.
- Zombie health and speed go up each round, as `RoundSettings` gives.
- When the last zombie of a round dies, the break starts. The next round starts when the break ends.
- Other code can read the round number, and it gets a signal when a round starts and when a round ends.
- The 2 placed zombies are gone from the test range. The round manager spawns all zombies.

### 2. Add the HUD for health and ammo

You see your health and ammo while you play.

Done when:

- The HUD shows the player's health and the rounds in the magazine.
- The HUD shows when the weapon reloads.
- Each value on the HUD changes when the value in the game changes.
- The HUD is easy to read in a smoke screenshot at 1280 × 720.

### 3. Add player death

The player stops when their health gets to 0.

Done when:

- At 0 health, the player cannot move, look, fire, or reload.
- The player emits a signal when they die. Other code uses it to start game over.
- Zombies stop attacking a dead player. This is true now, and a test keeps it true.

### 4. Show the round number on the HUD

Done when:

- The HUD shows the current round number.
- The HUD shows when a break between rounds is active.
- The values change when the round manager starts or ends a round.

### 5. Add game over and restart

The run ends when you die, and you can start again.

Done when:

- When the player dies, a game-over screen shows the round that they reached, and the mouse is released.
- A new `restart` input action reloads the level. The player starts round 1 again with full health and a full magazine, and the mouse is captured.

When the 5 steps are done, play one full loop by hand. Survive round 1, see round 2 start with more zombies, die, read the round on the game-over screen, and restart.

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
