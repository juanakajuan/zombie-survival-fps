# Rounds and HUD

Zombies come in rounds. The HUD shows the round number at the top center, and under it the zombies left in the round. When the last zombie of a round dies, a yellow BREAK label shows for 10 s with a NEXT ROUND IN countdown. Then the next round starts with 2 more zombies than the last, each with 20 more health and 0.25 m/s more speed (up to 5 m/s). A hurt zombie shows a red health bar over its head.

## Sub-features

- `round-start` starts round 1 when the level loads and spawns its 4 zombies, one each second.
- `round-clear` starts the break when the last zombie dies, and shows BREAK.
- `round-next` starts round 2 after 10 s, hides BREAK, and spawns 6 zombies.
- `hud-health` shows health as a number and a segmented bar, red at 30 or less.
- `hud-low-health` shows a red edge around the screen below 30 health. It gets stronger as health drops, and goes when health comes back.
- `health-regen` refills the player's health at 40 each second, 5 s after the last hit. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/health_regen.steps`. The `low` screenshot shows the red edge at `20 / 100`, and the `healed` screenshot shows `100 / 100` with no red edge.
- `hud-round` shows the round number, and `N LEFT` under it (zombies alive plus zombies still to spawn). In the break it shows `NEXT ROUND IN s`.
- `zombie-scaling` gives round n zombies `100 + 20 (n - 1)` health, so a round 2 zombie needs 5 pistol hits.
- `hud-fps` shows the frame rate (`60 FPS`) in the top-left corner while the SHOW FPS setting in the pause menu is on. It is off by default and saved with the other settings. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/fps_counter.steps`. The `menu` screenshot shows SHOW FPS on, and the `on` screenshot shows the counter.
- `zombie-health-bar` shows a red bar 2.2 m over a zombie after its first hit. It always faces the camera, empties as the zombie loses health, and hides at 0 health. An unhurt zombie has no bar.

## How to get to it (user POV)

- Start the game. Round 1 starts at once.
- Shoot all the zombies. Wait for the break to end.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.round` is `1` and `hud.break` is `false`.

- **Round 1 spawns.** Run `until zombies.alive 4 300`. It passes after about 3 s. `expect hud.objective 4 LEFT` and `expect zombies.bars 0` pass.
- **Health bar.** Run `aim`, `tap fire`. `expect zombies.bars 1` passes, and the screenshot shows a small red bar over the hurt zombie.
- **Clear round 1.** Run `fight_until hud.break true 3600`. `expect zombies.alive 0`, `expect hud.round 1`, and `expect hud.objective NEXT ROUND IN 10` pass. The screenshot shows ROUND 1 and the yellow BREAK label.
- **Round 2.** Run `until hud.break false 700`. `expect hud.round 2` passes. Then `until zombies.alive 6 400` passes, with `expect hud.objective 6 LEFT` and `expect zombies.bars 0`.
- **Low health color.** No journey drives it yet. Do not fire, run `until hud.health 30 1800` (each hit is 10, so the health reaches 30 exactly), then take a `shot`. The health number and bar show red.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/rounds.steps`.

## Gotchas

- `fight_until` aims with one mouse motion each shot. A crate between the player and the nearest zombie stops the shot. In round 1 the zombies come close fast, so this has not blocked a run.
- The break is 10 s (600 frames). Give `until hud.break false` a limit above 600.
- The round number stays the same during the break. It is the round that just ended.
