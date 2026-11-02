# Economy

The player earns points by shooting zombies: 10 for each hit, and 60 more for the shot that kills, and 40 more when that killing shot hits the head. The HUD shows the points in gold on a dark panel at the bottom right, and under them the ammo panel with the magazine big and the reserve small beside it. The pistol has a reserve of 48 rounds, and a reload takes rounds from it. A buy station is a dark crate with a yellow label: AMMO, and 250 under it. When the player looks at it within 2.5 m, a prompt under the crosshair shows `E  BUY AMMO  250`. E spends 250 points and fills the reserve. Target dummies give no points.

A second crate, teal, is the weapon station. It sells the SMG for 1000 points (`E  BUY SMG  1000`), puts it in hand, and then sells its ammo for 300 (`E  BUY SMG AMMO  300`). The player holds at most two weapons, so a new weapon with two held replaces the one in hand.

## Sub-features

- `points-hit` adds 10 points for each shot that hits a living zombie, and 60 more for the killing shot. Round 1 has 6 zombies of 150 health, 6 pistol hits each, so clearing it gives 720 points.
- `points-headshot` adds the 40 headshot bonus on top of the 10 and the 60 when the killing shot hits a zombie's head. A headshot that does not kill pays the 10 only, and a punch never pays it. To prove it, run `until zombies.alive 4 300`, then shoot one zombie in the head with `aim_head`, `tap fire`, `wait 12` until it dies: a head shot does 50, so a body shot and three head shots kill it. The body shot pays 10, the first two head shots 10 each, and the killing head shot 10 + 60 + 40, so `hud.points` is 140. Count the shots and read `hud.points` after each.
- `reserve` shows the reserve on the HUD. A reload takes only the rounds that the magazine lacks from it. With an empty reserve, R does nothing.
- `buy-prompt` shows `E  BUY AMMO  250` while the player looks at the station, and hides it when the player looks away.
- `buy-weapon` takes 1000 points at the weapon station and equips the SMG: `hud.weapon` is `SMG`, `hud.ammo` is `30 / 150`. `journeys/weapons.steps` takes the points from the debug menu.
- `buy-weapon-ammo` takes 300 points and fills the SMG reserve, even while the pistol is in hand. It does nothing, and takes nothing, when that reserve is full.
- `buy-ammo` takes 250 points and fills the reserve to 48 on E. It does nothing, and takes nothing, when the points are too few, the reserve is full, or the player is dead.

## How to get to it (user POV)

- Start the game. Shoot zombies to earn points.
- Walk to the crate 4 m east of the start, in the test range. Look down at it. Press E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.points` is `0`, `hud.ammo` is `12 / 48`, `hud.prompt_visible` is `false`.

- **Earn points.** Run `until zombies.alive 6 400`, then `fight_until hud.break true 3600`. `expect hud.points 720` passes, and `expect_not hud.ammo 12 / 48` passes because reloads used the reserve. The screenshot shows 720 in gold at the bottom right, above the ammo.
- **Face the station.** Run `face 0 0`, because the fight leaves the view toward the last zombie. `expect player.yaw_deg 0` passes. Then run `look 628 0` (the view turns right, toward +X), `hold move_forward`, `wait 30`, `release move_forward`, `wait 30`, `look 0 240` (the view tilts down to the crate top). `until hud.prompt_visible true 60` passes, and `expect hud.prompt E BUY AMMO 250` passes. The screenshot shows the prompt under the crosshair.
- **Buy.** Round 1 can leave the reserve empty. Run `tap interact`, `wait 5`: `expect hud.points 470` passes. Run `tap reload`, `wait 90` to fill the magazine from the new reserve, then `tap interact`, `wait 5` again. `expect hud.points 220` and `expect hud.ammo 12 / 48` pass.
- **Nothing to buy.** Run `tap interact`, `wait 5`. `expect hud.points 220` still passes: a full reserve buys nothing.
- **Look away.** Run `look 0 -400`, `wait 5`. `expect hud.prompt_visible false` passes.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/economy.steps`.

## Gotchas

- Points change only for living zombies. A shot at a dummy, a wall, or a zombie corpse adds none, so the point total of a cleared round 1 is exactly 720.
- Clearing round 1 with the pistol uses most of its 60 rounds: about 55 in a recorded run. A run that misses more can empty the gun before the round is clear.
- The ammo station is in the test range at `4 0 6`, and the weapon station is 3 m north of it, at `4 0 3`. In Pumpkin Hollow (the main scene) the ammo station is at `-3.5 0 11` and the weapon station at `3.5 0 11`. The journeys are for the test range. To reach the weapon station from the start, run `face -53 0`, `hold move_forward`, `wait 30`, `release move_forward`, `wait 30`, `look 0 220`; `journeys/weapons.steps` does this after it takes 1500 points from the debug menu.
- Walk close first. The prompt needs the crate within 2.5 m of the head along the view line, and the view must point at the crate: the crate is 1.2 m high, lower than the eyes at 1.6 m.
- The prompt text is read with each run of spaces made one space (`E BUY AMMO 250`), because a steps line cannot keep a double space.
