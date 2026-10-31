# Death, game over, and restart

Zombies hit the player for 40 damage each second when they are close, so three hits kill. Health comes back by itself: 5 s after the last hit, it refills at 40 each second. At 0 health the player dies and cannot move, look, fire, or reload. A GAME OVER screen shows the round that the player reached and releases the mouse. Enter starts the level again from round 1.

## Sub-features

- `zombie-attack` removes 40 health each second for each zombie within 1.3 m (flat distance). The first hit comes 1 s after the zombie gets close, and the zombie keeps hitting until the player is more than 1.6 m away.
- `player-death` stops all player input at 0 health.
- `game-over-screen` shows GAME OVER, `You reached round N`, and `Press Enter to restart`, and releases the mouse.
- `restart` reloads the level on Enter: round 1, 100 health, `12 / 48`, the mouse captured.
- `restart-before-death` does nothing when Enter is pressed before death.
- `downed` needs the SECOND WIND perk (driver command `self_revive` gives it). At 0 health the player is downed, not dead, and loses every perk: `player.downed true`, `hud.perks` empty, a low camera, `hud.downed` shows `DOWNED` and the seconds left, `hud.revive` shows `SECOND WIND  GETTING UP IN` and the seconds until the perk stands the player up, the pistol has a full magazine, and the zombies keep hitting. After 4 s the player stands up with half health. At the next 0 health, with no perk, the player dies and GAME OVER shows. Proof: `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/downed.steps`.

## How to get to it (user POV)

- Start the game and do not shoot. The zombies of round 1 reach the player and kill the player in about 12 s.
- On the GAME OVER screen, press Enter.

## Driving it with drive.sh

Preconditions:

- Baseline state. Do not fire, so that all 4 zombies of round 1 reach the player.

- **Die.** Run `until zombies.alive 4 300`, then `until game_over.visible true 3600`. It passes after a few seconds. `expect player.dead true` and `expect hud.health 0` pass.
- **Read the screen.** `expect game_over.text You reached round 1` and `expect mouse.mode visible` pass. The screenshot shows GAME OVER over a dim screen.
- **Dead input.** Run `tap move_forward` and `tap fire`. `expect hud.ammo 12 / 48` passes.
- **Restart.** Run `tap restart`, `wait 10`. `expect game_over.visible false`, `expect player.dead false`, `expect hud.health 100`, `expect hud.ammo 12 / 48`, `expect hud.round 1`, `expect player.position 0.0 0.0 6.0`, and `expect mouse.mode captured` pass.
- **Enter before death.** At the start, run `tap restart`, `wait 10`. `expect game_over.visible false` passes and `player.position` does not change.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/game_over.steps`. It covers all the sub-features, and Enter before death first.

## Gotchas

- To see the game-over text for a later round, the player must clear round 1 first. Use `fight_until hud.break true 3600`, then `until hud.round 2 700`, then stop firing.
- After the restart, the first new round 1 zombie spawns at once and the rest follow one each second. Take the restart proof within about 5 s.
- A reload that started before death still finishes after it.
