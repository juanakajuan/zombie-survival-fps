# Movement and look

The player walks with WASD, sprints with Shift, jumps with Space, and turns with the mouse. Esc releases the mouse. The left click that captures the mouse again does not fire a shot.

## Sub-features

- `move-walk` moves the player at 4.5 m/s with W, A, S, and D.
- `move-sprint` moves the player at 7 m/s with Shift and W held.
- `move-jump` lifts the player with Space when on the floor.
- `look-mouse` turns the view with mouse motion.
- `mouse-release` releases the mouse with Esc.
- `mouse-recapture` captures the mouse again on a left click, and that click does not fire.

## How to get to it (user POV)

- Start the game. The mouse is captured and the player can move at once.
- Press Esc to get the mouse cursor back. Click in the game window to play again.

## Driving it with drive.sh

Preconditions:

- Baseline state. The player is at `0.0 0.0 6.0` with yaw `0`.

- **Walk.** Hold W for 0.5 s. Run `hold move_forward`, `wait 30`, `release move_forward`, `wait 30`. `expect_not player.position 0.0 0.0 6.0` passes, and `z` is near `3.7` in `01-after-walk.json` (about 2.3 m).
- **Sprint.** Run `hold sprint`, `hold move_forward`, `wait 30`, then release both and `wait 30`. `z` in `02-after-sprint.json` is near `0.1` (about 3.6 m, more than the walk).
- **Jump.** Run `tap jump`, `wait 10`, `state 03-in-jump`. The `y` value of `player.position` is near `0.8`.
- **Look.** Run `look 200 0`. `expect player.yaw_deg -29` passes, and the screenshot shows the view turned to the right.
- **Release the mouse.** Run `key Escape`. `expect mouse.mode visible` passes.
- **Capture again without a shot.** Run `tap fire`. `expect mouse.mode captured` and `expect hud.ammo 12 / 12` pass.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/movement.steps`. It covers all the sub-features. Compare the `z` and `y` values in the JSON files by eye.

## Gotchas

- The run is real time, so the walk distance changes by a small amount between runs. Do not `expect` an exact position after movement.
- The walk and the sprint together take the player from `z = 6` to near `z = 0.1`. More forward movement hits the target dummy at `z = -3`.
- `look` uses the player's mouse sensitivity (0.0025 rad/px). If the human changes it in the Inspector, the expected yaw changes.
