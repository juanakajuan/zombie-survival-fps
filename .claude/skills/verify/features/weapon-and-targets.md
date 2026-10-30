# Weapon and targets

The player fires the pistol with the left mouse button and reloads with R. The player sees a cartoon pistol held in the Scout's right hand that kicks back on each shot and draws a yellow tracer from the muzzle to the hit point, and on reload tosses the gun over the shoulder and draws a new one. The HUD shows the rounds in the magazine and in the reserve, and a RELOADING label. The player also buys an SMG (see [Economy](./economy.md)). It fires by itself while the left mouse button is held, and **1**, **2**, and the mouse wheel switch between it and the pistol. A target dummy flashes red when hit, goes away after 4 hits, and comes back after 2 s.

## Sub-features

- `fire` fires one hitscan shot and removes one round from the magazine. It does nothing while the player sprints.
- `tracer` draws a thin yellow streak from the muzzle at 120 m/s to the hit point, or 100 m out on a miss. It does no damage.
- `hit-marker` shows a marker on the crosshair for 0.2 s when a shot hits a zombie or a dummy.
- `fire-rate` allows one shot each 0.15 s.
- `dummy-hit` makes a dummy flash red, and 4 hits (25 damage each, 100 health) make it go away.
- `dummy-respawn` brings the dummy back after 2 s.
- `reload-key` refills the magazine to 12 from the reserve in 1.2 s after R, with RELOADING on the HUD. The HUD shows the magazine, then the reserve (`12 / 48` at the start).
- `view-model` shows the pistol in the player's hand at the bottom right of the view. It raises into view over 0.45 s at the start. It bobs while walking and drops out of view on death.
- `aim` holds the pistol up to the screen centre with its sights on the crosshair point, zooms the view, and hides the crosshair while the right mouse button is held.
- `reload-empty` starts a reload when the player fires with an empty magazine.
- `smg` fires every 0.08 s while fire is held, with a magazine of 30, a reserve of 150, and a reload of 1.6 s. Its model has a purple receiver with a red-dot sight on top, a barrel shroud, and a long magazine ahead of the grip. Its reload tilts the gun, drops the empty magazine as debris, and the left fist comes up from below and slaps a new one into the well. Then the hand pulls the charging handle.
- `switch` draws the other weapon on **1**, **2**, a wheel notch down (next), or a wheel notch up (previous). The HUD name and ammo follow, and the weapon that went away keeps its ammo. It does nothing with one weapon, and a reload in progress stops with no refill.

## How to get to it (user POV)

- The target dummies are only in the test range, which the driver loads. There, the middle dummy is straight ahead of the crosshair at the start. The main scene (the Compound) has none.
- Hold the right mouse button to aim down the sights.
- Click the left mouse button to fire. Press R to reload.
- Press 1 or 2, or turn the mouse wheel, to switch weapons once the SMG is bought.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.ammo` is `12 / 48` and `dummies.up` is `3`.

- **Fire once.** Run `wait 30` so that the gun has raised, then `tap fire`. `expect hud.hit_marker true` passes. After `wait 12`, `expect hud.ammo 11 / 48` passes.
- **Remove a dummy.** Fire 3 more times with `wait 12` after each. `expect hud.ammo 8 / 48` and `expect dummies.up 2` pass. The screenshot shows no yellow dummy at the crosshair.
- **Respawn.** Run `until dummies.up 3 180`. It passes after about 2 s.
- **Reload.** Run `tap reload`, `wait 6`. `expect hud.reloading true` passes, and the screenshot shows the yellow RELOADING label. Then `until hud.reloading false 120` and `expect hud.ammo 12 / 44` pass: the reload took the 4 spent rounds from the reserve.
- **Empty magazine.** Run `look 0 -400` to aim at the sky, so that no dummy is hit. Run `tap fire`. `expect tracers 1` and `expect hud.hit_marker false` pass, and the screenshot shows a short yellow streak near the crosshair. Fire 11 more times with `wait 12` after each, then `tap fire`. `expect hud.ammo 0 / 44` and `expect hud.reloading true` pass.
- **Aim.** Run `hold aim`, `wait 30`, then `shot`. The screenshot shows the pistol centred with its front sight at the screen centre, a narrower view, and no crosshair. `expect player.aiming true` and `expect hud.crosshair false` pass. Run `release aim`, `wait 10`, and `expect hud.crosshair true` passes.
- **SMG and switching.** Buy the SMG first (see [Economy](./economy.md)). `hud.weapon` is `SMG` and `hud.ammo` is `30 / 150`. Run `tap weapon_1`: `hud.weapon` is `PISTOL`. `tap weapon_2` and `tap weapon_next` and `tap weapon_previous` switch as well (the wheel actions are sent as wheel button events). Look at the sky with `look 0 -400`, then `hold fire`, `wait 30`: `hud.ammo` is not `29 / 150`, which proves automatic fire (the pistol would show one shot).
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/weapon.steps`. For the SMG and switching, run `journeys/weapons.steps`. The first journey covers all the sub-features except the SMG, switching, the fire rate, the red flash, the walk bob, and the drop on death. The screenshots show the view model. No state key reads its animation; `tests/weapons/test_view_model.gd` covers it. The flash lasts 0.1 s; take a `shot` 2 frames after a `tap fire` to see it.

## Gotchas

- Wait at least 10 frames between shots (0.15 s is 9 frames, and float rounding can make it 10). A `tap fire` inside the 0.15 s cooldown does nothing.
- A tracer to the dummy ahead lives only about 4 frames, and `tap` returns 3 frames after the shot. Take the tracer proof on a shot into the sky.
- Zombies spawn from frame 0 and walk to the player. After about 8 s they can block the shot line or hurt the player. Keep weapon journeys short.
- The reserve is 48 rounds and only a buy station refills it (see [Economy](./economy.md)). A reload takes only the rounds that the magazine lacks.
