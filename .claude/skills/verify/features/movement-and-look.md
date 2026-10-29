# Movement and look

The player walks with WASD, sprints with Shift, jumps with Space, crouches with Ctrl, and turns with the mouse. The player speeds up and slows down with ground friction. Ctrl at sprint speed starts a slide: a speed boost, low friction, and a low camera. A jump out of a slide keeps the speed. Each jump needs a new press of Space, and steering in the air does not add speed, so there is no bunny hop. Esc pauses the game, opens the pause menu, and releases the mouse. Esc again resumes the game and captures the mouse.

## Sub-features

- `move-walk` moves the player at 4.5 m/s with W, A, S, and D.
- `move-sprint` moves the player at 7 m/s with Shift and W held.
- `move-jump` lifts the player with Space when on the floor. Holding Space hops only once.
- `move-air-control` turns the player in the air with the move keys, with no speed gain.
- `slide` starts with Ctrl at 5.5 m/s or faster (a sprint), adds 3 m/s (once each 1.5 s, up to 10 m/s), and ends at crouch speed, when Ctrl is released (a crouch, not a stand, under a roof), or when the player leaves the floor.
- `crouch` makes the player 1 m tall and moves the player at 2.5 m/s while Ctrl is held.
- `crouch-tunnel` lets a crouched player go through the crawl tunnel west of the spawn. The roof stops a standing player. Under the roof, the player stays crouched after Ctrl is released.
- `look-mouse` turns the view with mouse motion. The up-down angle stops at 89 degrees.
- `mouse-release` pauses with Esc, which releases the mouse, and resumes with Esc.
- `pause-settings` changes mouse sensitivity, field of view, master volume, and fullscreen in the pause menu. The game starts in a maximized window, and fullscreen off goes back to it. The menu also has a Quit button. `tests/pause_menu/test_pause_menu.gd` covers each setting and the save to disk.
- `third-person` (debug builds only) moves the camera 3 m behind the head and 0.6 m to the right with F5, and shows the player's body. F5 again goes back to first person.

## How to get to it (user POV)

- Start the game. The mouse is captured and the player can move at once. The game starts in the Compound map. The crawl tunnel is only in the test range, which the driver loads.
- In the test range, turn left from the spawn to see the crawl tunnel: a low roof between two walls, about 6 m away.
- Press Esc to pause and get the mouse cursor back. Press Esc again, or click Resume, to play again.

## Driving it with drive.sh

Preconditions:

- Baseline state. The player is at `0.0 0.0 6.0` with yaw `0`.

- **Walk.** Hold W for 0.5 s. Run `hold move_forward`, `wait 30`, `release move_forward`, `wait 30`. `expect_not player.position 0.0 0.0 6.0` passes, and `z` is near `3.5` in `01-after-walk.json` (about 2.5 m).
- **Sprint.** Run `hold sprint`, `hold move_forward`, `wait 30`, then release both and `wait 30`. `z` in `02-after-sprint.json` is near `-0.6` (about 4.1 m, more than the walk).
- **Jump.** Run `tap jump`, `wait 10`, `state 03-in-jump`. The `y` value of `player.position` is near `1.1`.
- **Look.** Run `look 200 0`. `expect player.yaw_deg -29` passes, and the screenshot shows the view turned to the right.
- **Pitch limit.** Run `look 0 -2000`. `expect player.pitch_deg 89` passes. Then `face 0 0` levels the view.
- **Third person.** Run `key F5`. `expect player.third_person true` passes, and the screenshot shows the Scout body from behind. `key F5` again goes back.
- **Pause.** Run `key Escape`. `expect mouse.mode visible`, `expect game.paused true`, and `expect pause_menu.open true` pass. `05-paused.png` shows the PAUSED panel with the settings.
- **Resume.** Run `key Escape` again. `expect game.paused false`, `expect mouse.mode captured`, and `expect hud.ammo 12 / 48` pass.
- **Crouch through the tunnel.** Run `look -628 0` to face -X (`expect player.yaw_deg 90`). Hold W for 3 s. The roof stops the player near `x = -5.6`. Run `hold crouch`, and `expect player.crouching true` passes. Hold W for 1 s, then release W and Ctrl. The player is near `x = -8.1`, and `expect player.crouching true` passes, because the roof is above. Hold W for 3 s. The player comes out at the far side and stands: `expect player.crouching false` passes.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/movement.steps` for walk, sprint, jump, look, the pitch limit, third person, and the mouse. Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/crouch.steps` for crouch and the tunnel. Compare the `x`, `y`, and `z` values in the JSON files by eye. Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/slide.steps` for the slide: `player.speed` goes from `7.0` to near `9.7` at the slide start, and `player.sliding` is `true` until Ctrl is released. No journey covers the air control or the held jump; `tests/player/test_player.gd` covers them.

## Gotchas

- The run is real time, so the walk distance changes by a small amount between runs. Do not `expect` an exact position after movement.
- The walk and the sprint together take the player from `z = 6` to near `z = -0.6`. More forward movement hits the target dummy at `z = -3`.
- `look` uses the player's mouse sensitivity (0.0025 rad/px). If the human changes it in the Inspector, the expected yaw changes. The driver uses its own settings file, so the human's pause-menu settings do not change it.
