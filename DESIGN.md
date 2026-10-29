# Zombie Survival FPS design

This file has the core loop, the decided game rules, the parts that are done, and the work after the minimal game. [CLAUDE.md](CLAUDE.md) has the commands and the code rules.

Edit this file only when the core loop, a decided rule, or the list of parts changes. Tunable values, such as speeds, damage, and round sizes, are not in this file. They are `@export` values and `.tres` Resources, and the Inspector shows them. The verify skill's feature files in [.claude/skills/verify/features/](.claude/skills/verify/features/) show what a player can do with each part, and how to prove it.

## The core loop

You stand in an arena. Zombies come at you in rounds, and you shoot them before they reach you. When all zombies of a round are dead, a short break starts. Then a harder round starts. When your health gets to 0, the game ends and shows the round that you reached. You restart and try to reach a later round.

The minimal game is done: a player can play the full loop from a fresh start, without the editor. The verify skill plays it with `.claude/skills/verify/journeys/full_loop.steps`. That journey aims with the driver's `aim` command, so it does not test how hard aiming is. GitHub issues #1 to #5 and the git history have the steps that built it.

## Decided rules

- The zombie is the cartoon Shambler model, `zombie/zombie_model.glb`, in the same style as the pistol: beveled primitives, flat colors, and an ink outline. Its source is `art_source/zombie.blend`. Edit the `.blend` in Blender (through the Blender MCP or by hand), then export the `.glb` from it. Do not add a build script. The model has six parts with no rig: `LegL`, `LegR`, and `Torso`, with `Head`, `ArmL`, and `ArmR` under `Torso`. Each part has its origin on its joint. Keep these names and origins, and `ZombieAnimator` (`zombie/zombie_animator.gd`) animates them in code, as `view_model.gd` animates the pistol. A PS1-style generated model with rigged animation was tried and rejected.
- The player's body is the cartoon Scout model, `player/player_model.glb`, in the same style. Its source is `art_source/player.blend`, edited and exported like the zombie. Its parts are `LegL` and `LegR`, each with a shin (`ShinL`, `ShinR`) that has a foot (`FootL`, `FootR`), and `Torso`, with `Head`, `ArmL`, and `ArmR` under `Torso`. Each part has its origin on its joint, and L and R are the model's own left and right. `PlayerAnimator` (`player/player_animator.gd`) poses them in code: a walk that follows the speed, a stride in the air and on a slide, bent knees with flat feet while crouched, a right arm that holds the gun where the player looks, and both arms up while aiming. In first person the body draws only its shadow, so the player sees their own shadow. In a debug build, **F5** (the `third_person` action) puts the camera behind the player and shows the body.
- In first person, the Scout's right hand holds the pistol. It is `player/player_hand.glb`, from the `ViewArm` scene in `art_source/player.blend`. A `RemoteTransform3D` on the gun moves it, so it kicks with the gun. During a reload it follows the thrown gun without the spin, and comes back with the new gun. The gun and hand neither cast nor receive shadows, because they float in front of the camera.
- The level uses Godot primitives and code for meshes and materials. The only imported models are the pistol view model, `weapons/pistol.glb` (Blender source `art_source/pistol.blend`), the zombie, and the player.
- Weapons are hitscan. A shot is one ray from the camera.
- The player cannot shoot while sprinting.
- The slide is the fast way to move. There is no bunny hop: each jump needs a new press of jump, and air control never takes the speed above the speed at takeoff or the target speed.
- A node that can take damage has a `Health` child (`health/health.gd`). Code that deals damage finds it with `Health.find_on(node)`.
- `RoundSettings` (`rounds/round_settings.tres`) is the only source of zombie count, health, and speed for each round.
- Points come from shots and slaps that hit a living zombie (`Wallet.points_per_hit`) and from the killing blow (`Wallet.kill_bonus`). Target dummies and corpses give none. The `Wallet` on the player is the only owner of the balance.
- The reserve is per weapon (`WeaponData.max_reserve`). A reload moves rounds from the reserve into the magazine, and with an empty reserve there is no reload.
- A `BuyStation` sells one `BuyItem` resource (`economy/`). A subclass of `BuyItem` says when the item can be bought and what it gives (`AmmoItem` fills the reserve). A new thing to buy, such as a weapon or a door, is a new `BuyItem` subclass and a `.tres`, not a new station.

## What is done

Each part is a folder with its scenes, scripts, and data. The folder's tests in `tests/<folder>/` give the exact behavior.

| Part | Folder | What the player gets |
|---|---|---|
| Player | `player/` | Movement with ground friction, sprint, crouch, a slide (crouch while sprinting: a speed boost, low friction, and a jump that keeps the speed), limited air control, aim down the sights (hold the right mouse button: zoom, slow walk, no sprint), mouse look, using a buy station with **E**, a backhand slap with the left hand (**V**: damage at short reach, and the pistol cannot fire or reload during it), and death. **Esc** opens the pause menu. Only `Player` writes the mouse mode. |
| Weapon | `weapons/` | The hitscan pistol (`pistol.tres`) with a magazine, a reserve of 48 rounds that a reload draws from, and a reload that needs a reserve. The animated view model (`view_model.gd`), the thrown guns of a reload (debris on physics layer 2), and a tracer (`tracer.gd`) that flies from the muzzle to where each shot ended. It shows the shot and does no damage. |
| Health | `health/` | The `Health` node that takes damage, `HitFlash`, which flashes a material red on a hit, and `HealthBar`, a cartoon bar over a zombie that shows after its first hit and hides when it dies. |
| Target dummy | `targets/` | A dummy that flashes when hit, goes away at 0 health, and comes back. |
| Zombie | `zombie/` | A cartoon zombie with a shambling walk, an arm-slam attack, and a fall onto its back when it dies, that follows the navmesh to the player and hits at close range. |
| Test range | `levels/` | The greybox test map for tests and the verify skill, with target dummies, zombie spawn points, and a crawl tunnel west of the spawn. `level_navigation.gd` bakes the navmesh at start from the static colliders on physics layer 1. |
| Compound | `levels/compound.tscn` | A 72 m walled compound: a warehouse with a mezzanine, a loading dock, an office, a watchtower, and shipping containers in the yard. Zombies come in through three gates in the outer wall. It is the main scene. |
| Rounds | `rounds/` | `RoundManager` spawns each round's zombies from `RoundSettings`, then starts a break when the last zombie dies. |
| HUD | `hud/` | A slanted, yellow-accent HUD in the style of The Finals (`hud_theme.tres`): the crosshair with a hit marker, segmented health, the points, the weapon name and the ammo as magazine and reserve, the RELOADING label, the buy prompt, the round number, the zombies left, and the BREAK label with a countdown. |
| Economy | `economy/` | Points on a `Wallet` on the player: 10 for each zombie hit and 60 more for a kill. A buy station is a crate that sells one `BuyItem`. The player looks at it within 2.5 m, sees the prompt, and presses **E** to buy. The ammo station costs 250 points and fills the reserve. The test range and the Compound each have one. |
| Pause menu | `pause_menu/`, `settings/` | **Esc** pauses the game and shows mouse sensitivity, field of view, master volume, and fullscreen. **Esc** or **Resume** goes back to the game. `GameSettings` saves the settings to `user://settings.cfg`. |
| Game over | `game_over/`, `levels/level.gd` | The GAME OVER screen with the round reached. **Enter** reloads the level. |

## After the minimal game

These parts come after the minimal game. The list is not complete, and its order is not a priority:

- Doors that open new areas of the map.
- Pickups.
- Audio.
- More weapons.
