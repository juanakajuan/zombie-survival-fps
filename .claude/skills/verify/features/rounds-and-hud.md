# Rounds and HUD

Zombies come in rounds. The HUD shows the round number at the top center. When the last zombie of a round dies, a blue BREAK label shows for 10 s. Then the next round starts with 2 more zombies than the last.

## Sub-features

- `round-start` starts round 1 when the level loads and spawns its 4 zombies, one each second.
- `round-clear` starts the break when the last zombie dies, and shows BREAK.
- `round-next` starts round 2 after 10 s, hides BREAK, and spawns 6 zombies.
- `hud-health` shows health as a number and a bar, red at 30 or less.
- `hud-round` shows the round number.

## How to get to it (user POV)

- Start the game. Round 1 starts at once.
- Shoot all the zombies. Wait for the break to end.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.round` is `1` and `hud.break` is `false`.

- **Round 1 spawns.** Run `until zombies.alive 4 300`. It passes after about 3 s.
- **Clear round 1.** Run `fight_until hud.break true 3600`. `expect zombies.alive 0` and `expect hud.round 1` pass. The screenshot shows ROUND 1 and the blue BREAK label.
- **Round 2.** Run `until hud.break false 700`. `expect hud.round 2` passes. Then `until zombies.alive 6 400` passes.
- **Low health color.** No journey drives it yet. Let zombies hit the player to 30 health or less, then take a `shot`. The health number and bar show red.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/rounds.steps`.

## Gotchas

- `fight_until` aims with one mouse motion each shot. A crate between the player and the nearest zombie stops the shot. In round 1 the zombies come close fast, so this has not blocked a run.
- The break is 10 s (600 frames). Give `until hud.break false` a limit above 600.
- The round number stays the same during the break. It is the round that just ended.
