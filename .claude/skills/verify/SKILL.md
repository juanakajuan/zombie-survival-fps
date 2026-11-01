---
name: verify
description: Drive the Zombie Survival FPS game (Godot 4.7, levels/test_range.tscn) as a player does, off-screen in gamescope, and capture screenshots and HUD state as proof. Use it to prove a gameplay change works in the running game (movement, weapon, zombies, rounds, HUD, game over, restart), not only in tests.
---

# Verify the Zombie Survival FPS

The surface is the 3D game itself: keyboard, mouse, and what the screen shows. A run plays a **steps file** against the greybox test range (`levels/test_range.tscn`), not the main scene (`levels/compound.tscn`). The driver sends input through the Input Map (the same events as a real keyboard and mouse), reads what the player can see (HUD label text, the game-over screen, the player position), and saves screenshots.

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
| `hold <action>` / `release <action>` | Press or release an Input Map action: `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`, `crouch`, `fire`, `aim`, `reload`, `interact`, `melee`, `grenade`, `restart`, `weapon_1`, `weapon_2`, `weapon_next`, `weapon_previous`, `third_person`, `debug_menu`. |
| `tap <action>` | Press, wait until the game has applied the press and one more physics frame has run, then release and wait until the game has applied the release. |
| `key <name>` | Tap a physical key, for example `key Escape` (opens or closes the pause menu), `key F5` (the debug third-person view), or `key F1` (the debug menu). |
| `look <dx> <dy>` | One mouse-motion event in pixels. `look 200 0` turns right by 29 degrees. |
| `aim` | One mouse-motion event that turns the view to the nearest zombie's chest. It is not the `aim` action: use `hold aim` to aim down the sights. |
| `aim_head` | Like `aim`, but turns the view to the nearest zombie's head. |
| `face <yaw> <pitch>` | One mouse-motion event that turns the view to an absolute yaw and pitch in degrees. `face 0 0` looks level toward -Z, as at the start. Use it after `aim` or `fight_until`, which leave the view toward the last zombie. |
| `fight_until <key> <value> <frames>` | Repeat `aim` and `tap fire` (about 6 shots a second) until the state key has the value. Fails at the frame limit. |
| `punch_until <key> <value> <frames>` | Repeat `aim` and `tap melee` (one punch about every 22 frames, after the swing ends) until the state key has the value. Fails at the frame limit. A punch out of reach does nothing, so it can start before a zombie is close. |
| `until <key> <value> <frames>` | Wait until the state key has the value. Fails at the frame limit. |
| `walk_to <x> <z> <frames>` | Turn the view level toward the ground point and hold `move_forward` until the feet are within 0.4 m of it, turning again every 5 frames. It does not path around walls, so give it a point in a straight line. Fails at the frame limit. |
| `debug <label>` | Run the debug menu command with this button label, as a click on it does, for example `debug +5000 POINTS`. The labels are `+500 POINTS`, `+5000 POINTS`, `REFILL AMMO`, `FULL HEALTH`, `GOD MODE`, `KILL ALL ZOMBIES`, `SKIP BREAK`, a `GIVE <weapon>` for each weapon that can be bought or rolled: `GIVE SMG`, `GIVE SHOTGUN`, `GIVE RIFLE`, `GIVE MACHINE GUN`, and `GIVE ARC GUN`, and a `GIVE <drop>` that applies a zombie drop as its pickup does: `GIVE DOUBLE POINTS`, `GIVE INSTA-KILL`, `GIVE NUKE`, and `GIVE REPAIR ALL`. |
| `self_revive` | Give the player SECOND WIND (HUD icon `S`) without the power and the points, so that 0 health downs the player. |
| `expect <key> <value>` / `expect_not <key> <value>` | Compare a state value now. A failed expect is recorded and the run continues. Any other failed command stops the run. |
| `state <name>` | Write the state to `<name>.json`. |
| `shot <name>` | Save the screen to `<name>.png` (1280x720). |

State keys (all values are strings, and booleans are `true` or `false`):

| Key | What the player sees |
|---|---|
| `hud.health`, `hud.ammo`, `hud.weapon` | The HUD text, for example `100`, `11 / 48` (rounds in the magazine, then in the reserve), and `PISTOL` (the weapon in hand). |
| `hud.weapon_effect`, `effect_menu.open` | The effect of the weapon in hand on the HUD, for example `FIRE` (empty when it has none), and whether the SELECT AN EFFECT menu shows. |
| `hud.grenades`, `hud.grenade_fuse` | The grenade count on the HUD, for example `2`, and the seconds left on the grenade in hand, for example `1.8` (empty when none is in hand). |
| `hud.points`, `hud.prompt_visible`, `hud.prompt` | The points on the HUD, whether the buy prompt shows, and its text with each run of spaces made one space, for example `E BUY AMMO 250` (empty when hidden). |
| `hud.powerups` | The timed effects at the bottom center, one entry for each in the order they started, each with its runs of spaces made one space and joined with ` \| `, for example `DOUBLE POINTS 23 \| INSTA-KILL 30` (empty when none runs). |
| `hud.reloading`, `hud.break`, `hud.round_visible` | Whether the RELOADING label, the BREAK label, and the round panel show. |
| `hud.round`, `hud.objective` | The round number on the HUD, and the line beside it: `4 LEFT` during a round (zombies alive plus zombies still to spawn), `NEXT ROUND IN 10` during the break. |
| `hud.crosshair`, `hud.hit_marker`, `hud.headshot_marker` | Whether the crosshair shows (hidden while aiming), whether the hit marker shows (0.2 s after a shot hits a zombie or a dummy), and whether it shows in the headshot color (0.2 s after a shot hits a zombie's head). |
| `game_over.visible`, `game_over.text` | The game-over screen, and its text, for example `You reached round 1`. |
| `mouse.mode` | `captured` or `visible`. |
| `player.position`, `player.yaw_deg`, `player.pitch_deg`, `player.dead`, `player.downed`, `player.crouching`, `player.sliding`, `player.speed` | Feet position (`x y z`, 1 decimal), turn angle, up-down angle (`89` is straight up), death, crouch (true while sliding too), slide, and horizontal speed in m/s (1 decimal). The player starts at `0.0 0.0 6.0`, yaw `0`, pitch `0`, and looks toward -Z. |
| `player.aiming`, `player.third_person` | Whether the player aims down the sights, and whether the debug third-person camera is on. |
| `game.paused`, `pause_menu.open` | Whether the game tree is paused, and whether the pause menu shows. Esc toggles both. |
| `zombies.alive`, `zombies.bars`, `zombies.runners`, `zombies.burning`, `dummies.up` | Zombies in the level, living zombies whose health bar shows, living runners (the red shirts that run), living zombies on fire, and target dummies that show. |
| `doors.open`, `pickups` | Doors that are open, and pickups on the ground in the level (a placed one counts too). |
| `power.on`, `hud.perks`, `hud.max_health`, `hud.downed` | Whether the power switch is on, the text of each perk icon on the HUD in order with one space between them (empty with no perk), the max health under the health number, and the downed timer text on the HUD (for example `DOWNED  7`, empty when hidden). |
| `hud.fps` | The frame counter in the top-left corner, for example `60 FPS` (empty while the SHOW FPS setting is off). |
| `hud.revive` | The self-revive line under the downed timer, for example `SECOND WIND  GETTING UP IN 3` (empty when hidden). |
| `barricades.boards` | The boards left on all barricades in the level, added up. The test range has one barricade with 5 boards, so it starts at `5`. |
| `box.position`, `box.offer` | Where the weapon box stands (`x y z`, 1 decimal; it starts at `0.0 0.0 9.5`), and the weapon name over it (empty with none). |
| `tracers` | Shot tracers in flight. A tracer into the sky lives about 50 frames; one to the dummy ahead lives about 4. |
| `frame` | The physics frame counter. |

To read state while you write a new journey, add `state probe` lines and read the JSON files.

## Evidence

Each run writes to `.smoke/verify/<run id>/` (git ignores `.smoke/`). The default run id is `<steps name>-<date>-<time>`. A run id that exists is refused, so evidence is never overwritten.

- `steps.txt`: the copy of the steps file that ran.
- `godot.log`: each step as it ran (`driver: [line] ...`), each `ok` and `FAIL`, and all engine output.
- `<name>.png` and `<name>.json`: the screenshots and state snapshots that the steps asked for.
- `summary.txt`: `failures=N`. It is missing when the driver did not finish.

Read the PNG files to look at the result. A proof has these properties:

- It uses the player's path: Input Map actions, keys, and the mouse. It does not call game methods or set fields. The driver reads state but never writes it, with two exceptions for setup:
  - `debug <label>` calls `DebugMenu.run_command()`, the method that the button's `pressed` signal calls, so the result is the same as a click. The debug menu is a test tool, not a feature that a journey proves.
  - `self_revive` calls `player.perks.add()`. The buy station needs the power on and the points, and the journeys that use it prove the downed state and the revive, not the buy.

  Use these two only to set up a precondition. Do not use them for the action that the journey proves.
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
- `driver.gd`: the SceneTree main loop that `drive.sh` runs. `tools/check.sh` lints and type-checks it (it is in `tools/hidden_scripts.gd`). At run time, a parse error shows as `SCRIPT ERROR` in `godot.log`.

## Other surfaces

- `tools/smoke.sh [scene] [frames] [out.png]`: one screenshot after N frames, with no input. Use it for a quick look at a scene.
- The `godot-ai` MCP server drives the game that the human runs from the editor. It shares the human's session. Use it only when the human asks, or to look at the open editor.

## Gotchas

- gamescope cannot turn off V-Sync. The log has `WARNING: The requested V-Sync mode Disabled is not available`. This is not an error.
- The run is real time, so frame counts in `until` are limits, not exact times. Values after movement can change by a small amount between runs. Use `expect_not` against the start value, or `until`, for movement.
- Input events are flushed at the start of the next main-loop iteration, and a slow frame can run several physics frames in one iteration. Every input command waits for that flush, so an `expect` after it sees the result. A press and its release never land in the same flush, so the game sees every `tap` and `key`.
- Because a slow frame runs several physics frames, a `tap fire` or a timed `hold fire` with an automatic weapon fires a varying number of rounds. Check that the ammo changed with `expect_not`, or fire until the magazine is empty for an exact count, as `journeys/machine_gun.steps` does.
