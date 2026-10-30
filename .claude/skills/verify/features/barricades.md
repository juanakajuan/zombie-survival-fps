# Barricades

A barricade is a window with five brown boards, in the south-west yard of the test range. Zombies spawn in the yard and come through the window. A zombie stops outside the window and pulls off one board every 1.5 s. When no board is left, it walks through. The player stands within 1.5 m of the window and looks at it, and the prompt shows `HOLD E  REPAIR  4/5`. Holding E puts back one board each second, and each board gives 10 points, up to 50 points in a round. A zombie at the window hits a player within that same 1.5 m, through the boards, and pulls no board while it hits. A full window shows no prompt. The player cannot walk through the window, even with no boards. Zombies and shots pass it.

## Sub-features

- `barricade-breach` is the zombie that stops at the window and pulls a board at a time: `barricades.boards` goes down by one each 1.5 s while a zombie stands there. It crosses only when the value is `0`. Tests cover the crossing, the hits on a player who repairs, and two zombies that pull faster than one.
- `barricade-repair` is the hold on E: `barricades.boards` goes up by one for each second of hold, and `hud.points` goes up by 10 for each board.
- `barricade-prompt` is the HUD prompt `HOLD E REPAIR n/5` on a damaged window, and no prompt on a full one.
- `barricade-limit` is the limit of 50 repair points in each round, restored when a round starts. Tests cover it: the journey gives 10 points.
- `barricade-spawn` is the `SpawnYard` point: its zombies walk to the window before they chase the player.

## How to get to it (user POV)

- Start the test range. The yard is in the south-west corner, `x -20..-15` and `z 14..20`. The window is in its east wall at `-15 0 17`, and the spawn point is behind it at `-18 0 17`.
- The yard spawn point is not the first used. Clear round 1 (or take KILL ALL ZOMBIES in the F1 menu once all 4 zombies are out), and skip the break: the first zombie of round 2 spawns in the yard.
- Walk to about `-13.7 0 17.5` inside the arena, turn toward -X, and wait for a board to go. Hold E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `barricades.boards` is `5`, `hud.points` is `0`.

- **Clear the zombies safely.** Run `until zombies.alive 4 300`. Open the debug menu: `key F1`, `key Tab` five times, `key Enter` (GOD MODE), `key Tab`, `key Enter` (KILL ALL ZOMBIES), `key F1`. `expect hud.break true` passes.
- **Walk to the window.** Run `face 130 0`, `hold move_forward`, `wait 235`, `release move_forward`, `face 90 0`, `wait 20`. The player ends at about `-13.7 0 17.5`. `expect hud.prompt_visible false` passes: the window is full. Run `hold move_back`, `wait 15`, `release move_back`, `wait 10`. The player is at about `-12.4 0 17.5`, out of the 1.5 m repair range, so the zombie pulls boards and does not hit.
- **Start round 2.** Run `key F1`, `key Tab` seven times, `key Enter` (SKIP BREAK), `key F1`. The first zombie spawns in the yard.
- **A board goes.** Run `until barricades.boards 4 900`, `hold move_forward`, `until hud.prompt HOLD E REPAIR 4/5 60`, `release move_forward`. The prompt shows only within 1.5 m of the window. The screenshot shows four boards and the zombie behind them.
- **Repair.** Run `hold interact`, `until barricades.boards 5 180`, `release interact`. `expect hud.points 10` passes.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/barricades.steps`.

## Gotchas

- The board count is real time. After a repair, the zombie keeps pulling, so `barricades.boards` can fall again about 1.5 s after the last pull.
- With all zombies of round 2 out, others walk to the player at the window. The journey turns on GOD MODE so that they do not kill the player.
- A player within 1.5 m of the window takes the zombie's hits, and the zombie pulls no board while it hits. So the journey waits out of range for the first board. GOD MODE hides the damage: `tests/barricades/test_barricade.gd` proves it.
- A walk that is too long ends in the yard wall corner.
- The prompt text reads `HOLD E REPAIR 4/5` after the driver makes each run of spaces one space.
