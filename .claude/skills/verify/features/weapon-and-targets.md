# Weapon and targets

The player fires the pistol with the left mouse button and reloads with R. The HUD shows the rounds in the magazine and a RELOADING label. A target dummy flashes red when hit, goes away after 4 hits, and comes back after 2 s.

## Sub-features

- `fire` fires one hitscan shot and removes one round from the magazine.
- `fire-rate` allows one shot each 0.15 s.
- `dummy-hit` makes a dummy flash red, and 4 hits (25 damage each, 100 health) make it go away.
- `dummy-respawn` brings the dummy back after 2 s.
- `reload-key` refills the magazine to 12 in 1.2 s after R, with RELOADING on the HUD.
- `reload-empty` starts a reload when the player fires with an empty magazine.

## How to get to it (user POV)

- Start the game. The middle target dummy is straight ahead of the crosshair.
- Click the left mouse button to fire. Press R to reload.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.ammo` is `12 / 12` and `dummies.up` is `3`.

- **Fire once.** Run `tap fire`, `wait 12`. `expect hud.ammo 11 / 12` passes.
- **Remove a dummy.** Fire 3 more times with `wait 12` after each. `expect hud.ammo 8 / 12` and `expect dummies.up 2` pass. The screenshot shows no yellow dummy at the crosshair.
- **Respawn.** Run `until dummies.up 3 180`. It passes after about 2 s.
- **Reload.** Run `tap reload`, `wait 6`. `expect hud.reloading true` passes, and the screenshot shows the yellow RELOADING label. Then `until hud.reloading false 120` and `expect hud.ammo 12 / 12` pass.
- **Empty magazine.** Run `look 0 -400` to aim at the sky, so that no dummy is hit. Fire 12 times with `wait 12` after each, then `tap fire`. `expect hud.ammo 0 / 12` and `expect hud.reloading true` pass.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/weapon.steps`. It covers all the sub-features except the red flash. The flash lasts 0.1 s; take a `shot` 2 frames after a `tap fire` to see it.

## Gotchas

- Wait at least 9 frames between shots. A `tap fire` inside the 0.15 s cooldown does nothing.
- Zombies spawn from frame 0 and walk to the player. After about 8 s they can block the shot line or hurt the player. Keep weapon journeys short.
- There is no reserve ammo. A reload always gives 12 rounds.
