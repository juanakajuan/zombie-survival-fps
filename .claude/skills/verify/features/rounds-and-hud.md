# Rounds and HUD

Zombies come in rounds. The HUD shows the round in the bottom-left corner, as in Black Ops 2 Zombies: red tally marks for rounds 1 to 5 (the fifth mark crosses the first four), and a big red number from round 6. The zombies left in the round show beside it. The counter pops and flashes white when a round starts. When the last zombie of a round dies, a yellow BREAK label shows by the counter for 10 s with a NEXT ROUND IN countdown. Then the next round starts with 2 more zombies than the last, each with 20 more health and 0.25 m/s more speed (up to 5 m/s). A hurt zombie shows a red health bar over its head.

## Sub-features

- `round-start` starts round 1 when the level loads and spawns its 4 zombies, one each second.
- `round-clear` starts the break when the last zombie dies, and shows BREAK.
- `round-next` starts round 2 after 10 s, hides BREAK, and spawns 6 zombies.
- `hud-health` shows health as a number and a segmented bar, red at 30 or less.
- `hud-low-health` shows a red edge around the screen below 30 health. It gets stronger as health drops, and goes when health comes back.
- `health-regen` refills the player's health at 40 each second, 5 s after the last hit. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/health_regen.steps`. The `low` screenshot shows the red edge at `20 / 100`, and the `healed` screenshot shows `100 / 100` with no red edge.
- `hud-round` shows the round as tally marks (rounds 1 to 5) or a number (round 6 and later), and `N LEFT` beside it (zombies alive plus zombies still to spawn). In the break it shows `NEXT ROUND IN s`. The state keys `hud.round` (the number) and `hud.objective` read it.
- `hud-points` shows the points on a blood splat above the ammo, bottom right. Each change shows a `+N` (yellow) or `-N` (red) that drifts up-left and fades in about 1 s.
- `hud-layout` puts the perk icons, the health bar and the round counter in the bottom-left corner, from top to bottom, and the points, ammo and grenade icons in the bottom-right corner. Powerup timers show at the bottom center.
- `zombie-scaling` gives round n zombies `100 + 20 (n - 1)` health, so a round 2 zombie needs 5 pistol hits.
- `hud-fps` shows the frame rate (`60 FPS`) in the top-left corner while the SHOW FPS setting in the pause menu is on. It is off by default and saved with the other settings. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/fps_counter.steps`. The `menu` screenshot shows SHOW FPS on, and the `on` screenshot shows the counter.
- `runners` makes part of each round's zombies run from round 5: 3 of the 12 in round 5. A runner wears a red shirt and grey pants, leans forward, and runs at 5.5 m/s. Round 4 and earlier have no runners. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/runners.steps`. The `00-round-four` screenshot shows only yellow shirts, and the `01-round-five` screenshot shows red runners among the walkers.
- `zombie-health-bar` shows a red bar 2.2 m over a zombie after its first hit. It always faces the camera, empties as the zombie loses health, and hides at 0 health. An unhurt zombie has no bar.

## How to get to it (user POV)

- Start the game. Round 1 starts at once.
- Shoot all the zombies. Wait for the break to end.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.round` is `1` and `hud.break` is `false`.

- **Round 1 spawns.** Run `until zombies.alive 4 300`. It passes after about 3 s. `expect hud.objective 4 LEFT` and `expect zombies.bars 0` pass.
- **Health bar.** Run `aim`, `tap fire`. `expect zombies.bars 1` passes, and the screenshot shows a small red bar over the hurt zombie.
- **Clear round 1.** Run `fight_until hud.break true 3600`. `expect zombies.alive 0`, `expect hud.round 1`, and `expect hud.objective NEXT ROUND IN 10` pass. The screenshot shows one red tally mark and the yellow BREAK label.
- **Round 2.** Run `until hud.break false 700`. `expect hud.round 2` passes. Then `until zombies.alive 6 400` passes, with `expect hud.objective 6 LEFT` and `expect zombies.bars 0`.
- **Low health color.** Each hit is 40, so the health goes 100, 60, 20. `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/health_regen.steps` leaves one zombie, reloads so the last fight has a full magazine, runs `until hud.health 20 1200`, and saves `low.png`: the health number and bar show red, with the red edge around the screen. It then kills the zombie and waits for `hud.health 100`.
- **Runners.** Turn on `debug GOD MODE`, then go to round 4 with `debug KILL ALL ZOMBIES`, `until hud.break true 60`, and `debug SKIP BREAK` for each round. `until zombies.alive 10 900` passes, with `expect zombies.runners 0`. Go to round 5 the same way. `until zombies.alive 12 900` passes, with `expect zombies.runners 3`. After `wait 60` and `aim`, the screenshot shows red runners close in among the yellow walkers. The debug buttons only set up the late round.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/rounds.steps`.

## Gotchas

- `fight_until` aims with one mouse motion each shot. A crate between the player and the nearest zombie stops the shot. In round 1 the zombies come close fast, so this has not blocked a run.
- The break is 10 s (600 frames). Give `until hud.break false` a limit above 600.
- The round number stays the same during the break. It is the round that just ended.
- The run pose shows only while a runner moves. The zombies stand round the player when the runners journey takes its screenshots, so the run pose shows best in the tests of `ZombieAnimator`. The debug third-person view (`key F5`) does not help: the crowd hides the runners.
