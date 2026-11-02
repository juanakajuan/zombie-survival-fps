# Rounds and HUD

Zombies come in rounds. The HUD shows the round in the bottom-left corner, as in Black Ops 2 Zombies: red tally marks for rounds 1 to 5 (the fifth mark crosses the first four), and a big red number from round 6 (purple in a Mutt round). The zombies left in the round show beside it. The counter pops and flashes white when a round starts. When the last zombie of a round dies, a yellow BREAK label shows by the counter for 10 s with a NEXT ROUND IN countdown. Then the next round starts with more zombies, each with more health and 0.25 m/s more speed (up to 5 m/s). The count and the health follow the solo Black Ops curve in `rounds/round_settings.tres`: 6, 8, 13, 18, and 24 zombies in rounds 1 to 5, and 150 health in round 1 with 100 more each round up to round 9. At most 24 zombies are alive at one time; the rest spawn when others die. A hurt zombie shows a red health bar over its head.

## Sub-features

- `round-start` starts round 1 when the level loads and spawns its 6 zombies, one each second.
- `round-clear` starts the break when the last zombie dies, and shows BREAK.
- `round-next` starts round 2 after 10 s, hides BREAK, and spawns 8 zombies.
- `hud-health` shows health as a number and a segmented bar, red at 30 or less.
- `hud-low-health` shows a red edge around the screen below 30 health. It gets stronger as health drops, and goes when health comes back.
- `health-regen` refills the player's health at 40 each second, 5 s after the last hit. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/health_regen.steps`. The `low` screenshot shows the red edge at `20 / 100`, and the `healed` screenshot shows `100 / 100` with no red edge.
- `hud-round` shows the round as tally marks (rounds 1 to 5) or a number (round 6 and later), and `N LEFT` beside it (zombies alive plus zombies still to spawn). In the break it shows `NEXT ROUND IN s`. The state keys `hud.round` (the number) and `hud.objective` read it.
- `hud-points` shows the points on a blood splat above the ammo, bottom right. Each change shows a `+N` (yellow) or `-N` (red) that drifts up-left and fades in about 1 s.
- `hud-layout` puts the perk icons, the health bar and the round counter in the bottom-left corner, from top to bottom, and the points, ammo and grenade icons in the bottom-right corner. Powerup timers show at the bottom center.
- `zombie-scaling` gives round n zombies `150 + 100 (n - 1)` health up to round 9, then 10% more each round. A round 1 zombie needs 6 pistol hits, and a round 2 zombie (250 health) needs 10.
- `hud-fps` shows the frame rate (`60 FPS`) in the top-left corner while the SHOW FPS setting in the pause menu is on. It is off by default and saved with the other settings. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/fps_counter.steps`. The `menu` screenshot shows SHOW FPS on, and the `on` screenshot shows the counter.
- `runners` makes part of each round's zombies run from round 5: 6 of the 24 in round 5. A runner wears a red shirt and grey pants, leans forward, and runs at 5.5 m/s. Round 4 and earlier have no runners. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/runners.steps`. The `00-round-four` screenshot shows only yellow shirts, and the `01-round-five` screenshot shows red runners among the walkers.
- `crawler` makes a zombie crawl at 0.8 m/s when one hit of 60 or more damage lands below 0.6 m and does not kill it, for example a grenade blast near its feet. Its health bar drops to 0.9 m. `tests/zombie/test_zombie.gd` covers it; no state key reads it.
- `mutt-round` makes round 6, and every fifth round after it, a special round: Mutts (dogs that run at 6.5 m/s, with 0.4 of the round's zombie health) in place of zombies, 0.6 of the round's zombie count (16 in round 6). The round counter turns purple, a `MUTT ROUND` banner shows, and the line beside it reads `N MUTTS LEFT`. The last Mutt drops a free Max Ammo. Mutts count in `zombies.alive`. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/mutt_round.steps`. The `01-mutt-round` screenshot shows the banner and `16 MUTTS LEFT`, and `02-mutts` shows the Mutts and the purple 6.
- `zombie-health-bar` shows a red bar 2.2 m over a zombie after its first hit. It always faces the camera, empties as the zombie loses health, and hides at 0 health. An unhurt zombie has no bar.

## How to get to it (user POV)

- Start the game. Round 1 starts at once.
- Shoot all the zombies. Wait for the break to end.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.round` is `1` and `hud.break` is `false`.

- **Round 1 spawns.** Run `until zombies.alive 6 400`. It passes after about 5 s. `expect hud.objective 6 LEFT` and `expect zombies.bars 0` pass.
- **Health bar.** Run `aim`, `tap fire`. `expect zombies.bars 1` passes, and the screenshot shows a small red bar over the hurt zombie.
- **Clear round 1.** Run `fight_until hud.break true 3600`. `expect zombies.alive 0`, `expect hud.round 1`, and `expect hud.objective NEXT ROUND IN 10` pass. The screenshot shows one red tally mark and the yellow BREAK label.
- **Round 2.** Run `until hud.break false 700`. `expect hud.round 2` passes. Then `until zombies.alive 8 500` passes, with `expect hud.objective 8 LEFT` and `expect zombies.bars 0`.
- **Low health color.** Each hit is 40, so the health goes 100, 60, 20. `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/health_regen.steps` kills four zombies with `fight_until hud.objective 2 LEFT`, reloads so the last fight has a full magazine, runs `until hud.health 20 1200`, turns on `debug GOD MODE` (it blocks hits, not regen), and saves `low.png`: the health number and bar show red, with the red edge around the screen. It then kills the zombie that hit the player with `fight_until hud.objective 1 LEFT` and waits for `hud.health 100`. It stops at 2 LEFT, not 1, because one round 1 zombie can stay behind the far dummy (see Gotchas), and the pistol has only a few rounds left by then.
- **Runners.** Turn on `debug GOD MODE`, then go to round 4 with `debug KILL ALL ZOMBIES`, `until hud.break true 60`, and `debug SKIP BREAK` for each round. `until zombies.alive 18 1200` passes, with `expect zombies.runners 0`. Go to round 5 the same way. `until zombies.alive 24 1600` passes, with `expect zombies.runners 6`. After `wait 60` and `aim`, the screenshot shows red runners close in among the yellow walkers. The debug buttons only set up the late round.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/rounds.steps`.

## Gotchas

- `fight_until` aims with one mouse motion each shot. A crate between the player and the nearest zombie stops the shot. In round 1 the zombies come close fast, so this has not blocked a run.
- In round 1 on the test range, one zombie can stand still behind the far target dummy at `2 0 -12` and not come to the player. `aim` turns the view to it. `fight_until` still kills it from the start, but a journey that waits for the last zombie to come close must not count on it.
- The break is 10 s (600 frames). Give `until hud.break false` a limit above 600.
- The round number stays the same during the break. It is the round that just ended.
- The run pose shows only while a runner moves. The zombies stand round the player when the runners journey takes its screenshots, so the run pose shows best in the tests of `ZombieAnimator`. The debug third-person view (`key F5`) does not help: the crowd hides the runners.
