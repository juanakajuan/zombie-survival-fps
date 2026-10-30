# Zombie Survival FPS design

This file has the core loop and the decided game rules: the decisions that the code does not show. [CLAUDE.md](CLAUDE.md) has the commands and the code rules.

Edit this file only when the core loop or a decided rule changes. Do not list the parts of the game or the tunable values here. Each feature folder and its tests in `tests/<folder>/` give the exact behavior. The `@export` values and `.tres` Resources hold the tunable values, and the Inspector shows them. The verify skill's feature files in [.claude/skills/verify/features/](.claude/skills/verify/features/) show what a player can do with each part, and how to prove it. GitHub issues hold the work that is not done.

## The core loop

You stand in an arena. Zombies come at you in rounds, and you shoot them before they reach you. When all zombies of a round are dead, a short break starts. Then a harder round starts. When your health gets to 0, the game ends and shows the round that you reached. You restart and try to reach a later round.

## Decided rules

- The zombie is the cartoon Shambler model, `zombie/zombie_model.glb`, in the same style as the pistol: beveled primitives, flat colors, and an ink outline. Its source is `art_source/zombie.blend`. Edit the `.blend` in Blender (through the Blender MCP or by hand), then export the `.glb` from it. Do not add a build script. The model has six parts with no rig: `LegL`, `LegR`, and `Torso`, with `Head`, `ArmL`, and `ArmR` under `Torso`. Each part has its origin on its joint. Keep these names and origins, and `ZombieAnimator` (`zombie/zombie_animator.gd`) animates them in code, as `view_model.gd` animates the pistol. A PS1-style generated model with rigged animation was tried and rejected.
- The player's body is the cartoon Scout model, `player/player_model.glb`, in the same style. Its source is `art_source/player.blend`, edited and exported like the zombie. Its parts are `LegL` and `LegR`, each with a shin (`ShinL`, `ShinR`) that has a foot (`FootL`, `FootR`), and `Torso`, with `Head`, `ArmL`, and `ArmR` under `Torso`. Each part has its origin on its joint, and L and R are the model's own left and right. `PlayerAnimator` (`player/player_animator.gd`) poses them in code: a walk that follows the speed, a stride in the air and on a slide, bent knees with flat feet while crouched, a right arm that holds the gun where the player looks, and both arms up while aiming. In first person the body draws only its shadow, so the player sees their own shadow. In a debug build, **F5** (the `third_person` action) puts the camera behind the player and shows the body.
- In first person, the Scout's right hand holds the pistol. It is `player/player_hand.glb`, from the `ViewArm` scene in `art_source/player.blend`. A `RemoteTransform3D` on the gun moves it, so it kicks with the gun. During a reload it follows the thrown gun without the spin, and comes back with the new gun. The SMG (`MagazineViewModel`) keeps the gun in the hand instead: its reload tilts the gun, drops the empty magazine as debris, and the left fist pushes a new one up into the well. The gun and hand neither cast nor receive shadows, because they float in front of the camera.
- The level uses Godot primitives and code for meshes and materials. The only imported models are the weapon view models, `weapons/pistol.glb` and `weapons/smg.glb` (Blender sources `art_source/pistol.blend` and `art_source/smg.blend`), the zombie, and the player.
- Weapons are hitscan. A shot is one ray from the camera.
- The player cannot shoot while sprinting.
- The slide is the fast way to move. There is no bunny hop: each jump needs a new press of jump, and air control never takes the speed above the speed at takeoff or the target speed.
- A node that can take damage has a `Health` child (`health/health.gd`). Code that deals damage finds it with `Health.find_on(node)`.
- `RoundSettings` (`rounds/round_settings.tres`) is the only source of zombie count, health, and speed for each round.
- Points come from shots and punches that hit a living zombie (`Wallet.points_per_hit`) and from the killing blow (`Wallet.kill_bonus`). Target dummies and corpses give none. The `Wallet` on the player is the only owner of the balance.
- The player holds at most two weapons (`Player.max_weapons`) and switches with **1**, **2**, and the mouse wheel. Buying a new weapon while two are held replaces the weapon in hand. A holstered weapon does not fire, and its reload stops with no refill.
- A weapon station is a `BuyStation` with a `WeaponItem`. It sells the weapon, and once the player holds it, that weapon's ammo.
- The reserve is per weapon (`WeaponData.max_reserve`). A reload moves rounds from the reserve into the magazine, and with an empty reserve there is no reload.
- A `BuyStation` sells one `BuyItem` resource (`economy/`). A subclass of `BuyItem` says when the item can be bought and what it gives (`AmmoItem` fills the reserve). A new thing to buy, such as a weapon or a door, is a new `BuyItem` subclass and a `.tres`, not a new station.
