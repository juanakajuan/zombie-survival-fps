---
name: verify
description: Drive the Zombie Survival FPS game (Godot 4.7, levels/test_range.tscn) as a player does, off-screen in gamescope, and capture screenshots and HUD state as proof. Use it to prove a gameplay change works in the running game (movement, weapon, zombies, rounds, HUD, game over, restart), not only in tests.
---

# Verify the Zombie Survival FPS

The surface is the 3D game itself: keyboard, mouse, and what the screen shows. A run plays a **steps file** against the real main scene. The driver sends input through the Input Map (the same events as a real keyboard and mouse), reads what the player can see (HUD label text, the game-over screen, the player position), and saves screenshots.

Each run is a separate, short-lived process with no shared data. Many runs can go side by side. A run never touches the editor or the game that the human starts from the editor.

`tools/check.sh` is still the gate for every change. This skill adds proof that the change works in the running game.

## Launch

From the repo root:

```bash
godot --headless --path . --import
.claude/skills/verify/scripts/doctor.sh
.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/weapon.steps
```

1. The import is necessary in a new checkout or worktree, and after a `class_name` is added. Without it the class cache is stale and the driver fails with `Could not find type "Hud"`.
2. `drive.sh <steps file> [run id]` starts `gamescope --backend headless` with `godot --path . -s res://.claude/skills/verify/scripts/driver.gd`. The driver loads `res://levels/test_range.tscn`.
3. Ready means playable: the driver waits until the HUD shows a round (the player is in the tree and round 1 started). The log shows `driver: ready after N frames`. Then the steps start.
4. The run is real time. 60 physics frames are 1 second. Exit 0 means all steps passed. Exit 1 means a step or an `expect` failed, the engine logged an `ERROR`, or the driver did not finish. Exit 2 means a bad argument or a run id that exists.
5. The run stops itself at the end of the steps (or after a 300 s timeout). There is no server to keep alive.

## Doctor

```bash
.claude/skills/verify/scripts/doctor.sh
```

Read-only. It checks that `godot` is 4.7.x, that `gamescope` is on `PATH`, that the project is imported, and that the class cache has `Player`, `Hud`, and `GameOver`. It also warns about runs that are still alive or left a stale pid file. Run it first, and again when a run fails in an unexpected way. On `FAIL class cache`, run the import command.

## Drive

Write a steps file (one command on each line, `#` starts a comment), or use one in `journeys/`. The feature map in `features/` gives the recipe and the proof for each feature.

| Command | Effect |
|---|---|
| `wait <frames>` | Wait for physics frames. |
| `hold <action>` / `release <action>` | Press or release an Input Map action: `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`, `fire`, `reload`, `restart`. |
| `tap <action>` | Press, hold 2 frames, release, wait 1 frame. |
| `key <name>` | Tap a physical key that is not an action, for example `key Escape` (releases the mouse). |
| `look <dx> <dy>` | One mouse-motion event in pixels. `look 200 0` turns right by 29 degrees. |
| `aim` | One mouse-motion event that turns the view to the nearest zombie's chest. |
| `fight_until <key> <value> <frames>` | Repeat `aim` and `tap fire` (about 6 shots a second) until the state key has the value. Fails at the frame limit. |
| `until <key> <value> <frames>` | Wait until the state key has the value. Fails at the frame limit. |
| `expect <key> <value>` / `expect_not <key> <value>` | Compare a state value now. A failed expect is recorded and the run continues. Any other failed command stops the run. |
| `state <name>` | Write the state to `<name>.json`. |
| `shot <name>` | Save the screen to `<name>.png` (1280x720). |

State keys (all values are strings, and booleans are `true` or `false`):

| Key | What the player sees |
|---|---|
| `hud.health`, `hud.ammo` | The HUD text, for example `100` and `11 / 12`. |
| `hud.reloading`, `hud.break`, `hud.round_visible` | Whether the RELOADING label, the BREAK label, and the round panel show. |
| `hud.round` | The round number on the HUD. |
| `game_over.visible`, `game_over.text` | The game-over screen, and its text, for example `You reached round 1`. |
| `mouse.mode` | `captured` or `visible`. |
| `player.position`, `player.yaw_deg`, `player.dead` | Feet position (`x y z`, 1 decimal), turn angle, and death. The player starts at `0.0 0.0 6.0`, yaw `0`, and looks toward -Z. |
| `zombies.alive`, `dummies.up` | Zombies in the level, and target dummies that show. |
| `frame` | The physics frame counter. |

To read state while you write a new journey, add `state probe` lines and read the JSON files.

## Evidence

Each run writes to `.smoke/verify/<run id>/` (git ignores `.smoke/`). The default run id is `<steps name>-<date>-<time>`. A run id that exists is refused, so evidence is never overwritten.

- `steps.txt`: the copy of the steps file that ran.
- `godot.log`: each step as it ran (`driver: [line] ...`), each `ok` and `FAIL`, and all engine output.
- `<name>.png` and `<name>.json`: the screenshots and state snapshots that the steps asked for.
- `summary.txt`: `failures=N`. It is missing when the driver did not finish.

Read the PNG files to look at the result. A proof has these properties:

- It uses the player's path: Input Map actions, keys, and the mouse. It does not call game methods or set fields. The driver reads state but never writes it.
- It captures the action and the state after it: a `state` or `shot` before and after, and an `expect` on the change, not only the last screen.
- It checks the result in two views when it can: the HUD text (`expect`) and the screenshot.
- It runs the full journey of the feature file. If a precondition is missing, report the failure. Do not make the journey weaker so that it passes.

## Cleanup

```bash
.claude/skills/verify/scripts/cleanup.sh
```

A normal run stops itself. After an interrupted run, `cleanup.sh` stops the process group in each `.smoke/verify/*/pid` file and removes the pid files. It never kills by process name, so it does not touch the editor or another session's game. It never deletes evidence. To remove old evidence, delete the run folders under `.smoke/verify/` yourself.

## Helpers

All are in `.claude/skills/verify/scripts/` and run from any directory.

- `drive.sh <steps file> [run id]`: runs one journey. See [Launch](#launch).
- `doctor.sh`: read-only checks. See [Doctor](#doctor).
- `cleanup.sh`: stops runs that this skill started. See [Cleanup](#cleanup).
- `driver.gd`: the SceneTree main loop that `drive.sh` runs. It is not under `tools/check.sh`, because that check skips hidden folders. A parse error shows as `SCRIPT ERROR` in `godot.log`.

## Other surfaces

- `tools/smoke.sh [scene] [frames] [out.png]`: one screenshot after N frames, with no input. Use it for a quick look at a scene.
- The `godot-ai` MCP server drives the game that the human runs from the editor. It shares the human's session. Use it only when the human asks, or to look at the open editor.

## Gotchas

- Do not add `--fixed-fps` to the run. With it, zombies do not follow the navmesh and stay at their spawn points.
- gamescope cannot turn off V-Sync. The log has `WARNING: The requested V-Sync mode Disabled is not available`. This is not an error.
- The run is real time, so frame counts in `until` are limits, not exact times. Values after movement can change by a small amount between runs. Use `expect_not` against the start value, or `until`, for movement.
- Input events are flushed on the next frame. Every input command waits at least one frame after it sends, so an `expect` after it sees the result.
