# Death and play again

A zombie hit removes 40 health. At 0 health the game ends and shows the death screen with the rounds survived and the points earned. Enter starts a new game.

## Sub-features

- `damage-vignette` shows a red vignette that gets stronger as health goes down. Health comes back at 50/s after 4 s without a hit (100/s after 1.5 s with Mender). Tough makes the maximum 160, and the vignette scales to it.
- `death-screen` shows `YOU DIED`, `You survived <n> rounds.` (`round` when n is 1), `You earned <n> points.` (points earned, not the balance), `Press Enter to play again.`, and frees the mouse. Esc does not pause it.
- `restart` reloads the scene with Enter: round 0, 500 points, 0 earned, 100 health, and the pistol only (`slots == *Pistol`). The scene reload also removes the perks (`hud_perks` empty) and the upgrades, closes the doors, turns off the power, and hides the cache.

## How to get to it (user POV)

- Stand still near zombies until they kill you.
- On the death screen, press Enter (or keypad Enter). Start on a gamepad.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/death-restart.txt`. It takes about 25 s.

- **Die.** `wait_until player_alive == false 180`. The player does nothing.
- **Death screen.** `expect phase == GAME_OVER`, `expect hud_death == true`, `expect hud_death_text contains You survived 0 rounds.`, `expect mouse_captured == false`, `shot death`.
- **Restart.** `tap Enter`, `wait 1`, then `expect phase == STARTING`, `expect hud_death == false`, `expect points == 500`, `expect earned == 0`, `expect health == 100`, `expect slots == *Pistol`.
- **Vignette (not in the scenario).** `wait_until health <= 60 60`, `shot hurt`. The PNG shows a red border.

## Gotchas

- Godot sometimes did not exit after a run with a restart. `run.sh` stops it 15 s after `VERIFY DONE` and prints a `NOTE:` line. That is not a failure of the feature.
- Round 1 is not survived if the player dies in it, so the text is `0 rounds`.
