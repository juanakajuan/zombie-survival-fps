# Economy

The player earns points by shooting zombies: 10 for each hit, and 60 more for the shot that kills, and 40 more when that killing shot hits the head. The HUD shows the points at the top right, and the ammo as `magazine / reserve` at the bottom right. The pistol has a reserve of 48 rounds, and a reload takes rounds from it. A buy station is a dark crate with a yellow label: AMMO, and 250 under it. When the player looks at it within 2.5 m, a prompt under the crosshair shows `E  BUY AMMO  250`. E spends 250 points and fills the reserve. Target dummies give no points.

A second crate, teal, is the weapon station. It sells the SMG for 1000 points (`E  BUY SMG  1000`), puts it in hand, and then sells its ammo for 300 (`E  BUY SMG AMMO  300`). The player holds at most two weapons, so a new weapon with two held replaces the one in hand.

## Sub-features

- `points-hit` adds 10 points for each shot that hits a living zombie, and 60 more for the killing shot. Round 1 has 4 zombies of 4 shots each, so clearing it gives 400 points.
- `points-headshot` adds the 40 headshot bonus on top of the 10 and the 60 when the killing shot hits a zombie's head. A headshot that does not kill pays the 10 only, and a punch never pays it. To prove it, run `until zombies.alive 4 300`, then shoot one zombie in the head with `aim_head`, `tap fire`, `wait 12` until it dies: `hud.points` is 10 + 10 + 60 + 40 = 120 when the first shot is a body shot and two head shots follow, so count the shots and read `hud.points` after each.
- `reserve` shows the reserve on the HUD. A reload takes only the rounds that the magazine lacks from it. With an empty reserve, R does nothing.
- `buy-prompt` shows `E  BUY AMMO  250` while the player looks at the station, and hides it when the player looks away.
- `buy-weapon` takes 1000 points at the weapon station and equips the SMG: `hud.weapon` is `SMG`, `hud.ammo` is `30 / 150`. Round 1 and round 2 give 1060 points in all, with no misses.
- `buy-weapon-ammo` takes 300 points and fills the SMG reserve, even while the pistol is in hand. It does nothing, and takes nothing, when that reserve is full.
- `buy-ammo` takes 250 points and fills the reserve to 48 on E. It does nothing, and takes nothing, when the points are too few, the reserve is full, or the player is dead.

## How to get to it (user POV)

- Start the game. Shoot zombies to earn points.
- Walk to the crate 4 m east of the start, in the test range. Look down at it. Press E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.points` is `0`, `hud.ammo` is `12 / 48`, `hud.prompt_visible` is `false`.

- **Earn points.** Run `until zombies.alive 4 300`, then `fight_until hud.break true 3600`. `expect hud.points 400` passes, and `expect_not hud.ammo 12 / 48` passes because reloads used the reserve. The screenshot shows POINTS 400 at the top right.
- **Face the station.** Run `face 0 0`, because the fight leaves the view toward the last zombie. `expect player.yaw_deg 0` passes. Then run `look 628 0` (the view turns right, toward +X), `hold move_forward`, `wait 30`, `release move_forward`, `wait 30`, `look 0 240` (the view tilts down to the crate top). `until hud.prompt_visible true 60` passes, and `expect hud.prompt E BUY AMMO 250` passes. The screenshot shows the yellow prompt under the crosshair.
- **Buy.** Run `tap reload` and `wait 90` to fill the magazine, then `tap interact`, `wait 5`. `expect hud.points 150` and `expect hud.ammo 12 / 48` pass.
- **Nothing to buy.** Run `tap interact`, `wait 5`. `expect hud.points 150` still passes: a full reserve buys nothing.
- **Look away.** Run `look 0 -400`, `wait 5`. `expect hud.prompt_visible false` passes.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/economy.steps`.

## Gotchas

- Points change only for living zombies. A shot at a dummy, a wall, or a zombie corpse adds none, so the point total of a cleared round 1 is exactly 400.
- The ammo station is in the test range at `4 0 6` and in the Compound at `8 0 16`. The weapon station is 3 m north of it, at `4 0 3` and `8 0 13`. The journeys are for the test range. To reach the weapon station from the start, run `face -53 0`, `hold move_forward`, `wait 30`, `release move_forward`, `wait 30`, `look 0 220`; `journeys/weapons.steps` does this after it earns 1060 points.
- Walk close first. The prompt needs the crate within 2.5 m of the head along the view line, and the view must point at the crate: the crate is 1.2 m high, lower than the eyes at 1.6 m.
- The prompt text is read with each run of spaces made one space (`E BUY AMMO 250`), because a steps line cannot keep a double space.
