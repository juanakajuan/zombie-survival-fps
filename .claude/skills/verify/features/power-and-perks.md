# Power and perks

The power switch is a dark cabinet with a red lamp and a yellow lever up, labeled POWER, in the room behind the door. When the player looks at it within 2.5 m, the prompt shows `E  TURN ON POWER`. E turns the power on for good: the lamp goes green, the lever swings down, and the switch shows no prompt after. The four perk machines are tall purple boxes in a row at `x -5`. Without power, each one shows `NO POWER` under its name, and its prompt is `NEEDS POWER`. With power, it shows its cost, and E buys the perk: IRON GUT (2500) adds 50 max health, QUICK HANDS (3000) halves the reload time, HAIR TRIGGER (2000) makes the time between shots 0.65 times as long, and SECOND WIND (1500) downs the player at 0 health and stands the player up after 4 s. Each buy of SECOND WIND raises its price by 1500 (the prompt and the label show 3000, then 4500), and after 3 buys in a run its prompt and label show `SOLD OUT`. Tests cover the price and the limit, because three downs take a long drive. Each held perk shows a colored icon over the health bar: `H` red, `R` green, `F` orange, `S` blue. The player holds one of each, at most 4, and loses all of them at 0 health.

## Sub-features

- `power-switch` turns on once with E. `power.on` goes from `false` to `true`.
- `perk-no-power` refuses a sale and takes no points while the power is off.
- `perk-buy` takes the cost and adds the perk icon: `hud.perks` goes from empty to `F`.
- `perk-effects` changes max health, reload time, and fire rate. `tests/perks/test_perks.gd` proves each one. With IRON GUT, `hud.max_health` reads `150`.
- `perk-limit` refuses a held perk and a perk over `Perks.max_held`. Tests cover it.

## How to get to it (user POV)

- Start the test range. The switch is at `18 0 18.6` in the room (`x 12..20`, `z 12..20`). The room door is at `16.5 0 12` and costs 750.
- The machines face east: IRON GUT at `-5 0 0`, QUICK HANDS at `-5 0 -2.5`, HAIR TRIGGER at `-5 0 -5`, SECOND WIND at `-5 0 2.5`.
- Get points from the debug menu (F1, `+5000 POINTS`), buy the door, turn on the switch, walk to a machine, and press E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `power.on` is `false`, `hud.perks` is empty, `hud.max_health` is `100`.

- **Points and a clear arena.** Run `key F1`, `key Tab` twice, `key Enter` (+5000), `key Tab` four times, `key Enter` (KILL ALL ZOMBIES), `key F1`. `expect hud.points 5000` passes.
- **Door.** Walk the path of [doors-and-pickups.md](./doors-and-pickups.md): `face 143 0` and 70 frames forward, then `face -90 0` and 255 frames forward, `face 180 0`, `tap interact`. `expect doors.open 1` passes.
- **Switch.** Run `hold move_forward`, `wait 150`, `release move_forward`. The player stops at about `16.1 0 19.6`. Run `face -59 -9`. `expect hud.prompt E TURN ON POWER` passes. `tap interact`, and `expect power.on true` passes.
- **Back to the machines.** Run `until hud.break false 600` and clear round 2 with KILL ALL ZOMBIES (`key Tab` six times from CLOSE), so its zombies do not block the walk. Run `face 0 0` and 150 frames forward, `face 90 0` and 255 frames forward, `face 0 0` and 175 frames forward. The player stops at about `-3.3 0 -5.3`.
- **Perk.** Run `face 90 -15`. `expect hud.prompt E BUY HAIR TRIGGER 2000` passes. `tap interact`, then `expect hud.points 2250` and `expect hud.perks F` pass. The screenshot shows the orange `F` icon over the health bar.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/perks.steps`.

## Gotchas

- The journey needs a break for each walk. Round 2 starts while the player is in the room, and its zombies block the walk back unless it is cleared.
- A machine still shows its buy prompt for a held perk, as the ammo station does with a full reserve. E does nothing and takes no points.
- In the Compound, the power switch is on the west wall of the office, and the perk machines stand along the south wall of the warehouse, outside it.
