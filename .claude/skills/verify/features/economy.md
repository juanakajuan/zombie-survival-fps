# Economy

The player earns points by shooting zombies: 10 for each hit, and 60 more for the shot that kills. The HUD shows the points at the top right, and the ammo as `magazine / reserve` at the bottom right. The pistol has a reserve of 48 rounds, and a reload takes rounds from it. A buy station is a dark crate with a yellow AMMO label. When the player looks at it within 2.5 m, a prompt under the crosshair shows `E  BUY AMMO  250`. E spends 250 points and fills the reserve. Target dummies give no points.

## Sub-features

- `points-hit` adds 10 points for each shot that hits a living zombie, and 60 more for the killing shot. Round 1 has 4 zombies of 4 shots each, so clearing it gives 400 points.
- `reserve` shows the reserve on the HUD. A reload takes only the rounds that the magazine lacks from it. With an empty reserve, R does nothing.
- `buy-prompt` shows `E  BUY AMMO  250` while the player looks at the station, and hides it when the player looks away.
- `buy-ammo` takes 250 points and fills the reserve to 48 on E. It does nothing, and takes nothing, when the points are too few or the reserve is full.

## How to get to it (user POV)

- Start the game. Shoot zombies to earn points.
- Walk to the crate 4 m east of the start, in the test range. Look down at it. Press E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.points` is `0`, `hud.ammo` is `12 / 48`, `hud.prompt_visible` is `false`.

- **Earn points.** Run `until zombies.alive 4 300`, then `fight_until hud.break true 3600`. `expect hud.points 400` passes, and `expect_not hud.ammo 12 / 48` passes because reloads used the reserve. The screenshot shows POINTS 400 at the top right.
- **Face the station.** Run `look 628 0` (the view turns right, toward +X), `hold move_forward`, `wait 30`, `release move_forward`, `wait 30`, `look 0 240` (the view tilts down to the crate top). `until hud.prompt_visible true 60` passes, and `expect hud.prompt E BUY AMMO 250` passes. The screenshot shows the yellow prompt under the crosshair.
- **Buy.** Run `tap reload` and `wait 90` to fill the magazine, then `tap interact`, `wait 5`. `expect hud.points 150` and `expect hud.ammo 12 / 48` pass.
- **Nothing to buy.** Run `tap interact`, `wait 5`. `expect hud.points 150` still passes: a full reserve buys nothing.
- **Look away.** Run `look 0 -400`, `wait 5`. `expect hud.prompt_visible false` passes.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/economy.steps`.

## Gotchas

- Points change only for living zombies. A shot at a dummy, a wall, or a zombie corpse adds none, so the point total of a cleared round 1 is exactly 400.
- The station is in the test range at `4 0 6` and in the Compound at `8 0 16`. The journey is for the test range.
- Walk close first. The prompt needs the crate within 2.5 m of the head along the view line, and the view must point at the crate: the crate is 1.2 m high, lower than the eyes at 1.6 m.
- The prompt text is read with each run of spaces made one space (`E BUY AMMO 250`), because a steps line cannot keep a double space.
