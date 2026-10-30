# Doors and pickups

A door is a brown panel that closes a gap in a wall. It has a yellow label: DOOR, and 750 under it. When the player looks at it within 2.5 m, the prompt shows `E  BUY DOOR  750`. E spends 750 points, and the door vanishes for good: the gap is open, and zombies walk through it. A spawn point in the area behind the door spawns zombies only after that door is open. A pickup is a small spinning, bobbing cyan cube with the item name over it. Walking over it gives the item for free, and the pickup goes. A pickup that would do nothing stays on the ground. A dying zombie drops one by chance (10%): MAX AMMO fills the reserve of every held weapon, and HEALTH fills the health. A dropped pickup goes after 20 s.

## Sub-features

- `door-buy` takes 750 points and opens the door: `doors.open` goes from `0` to `1`. It does nothing, and takes nothing, with too few points. An open door shows no prompt.
- `door-navmesh` makes zombies path through the open gap. A zombie in a closed room cannot reach the player.
- `spawn-area` keeps the spawn point of a closed room silent until its door is open.
- `pickup-ammo` fills the reserve of every held weapon on a walk over it, when one of them is below its maximum.
- `pickup-health` fills the health on a walk over it, when the health is below its maximum.
- `pickup-drop` is the zombie drop and its expiry. Tests cover it: the 10% chance is not a thing to drive.

## How to get to it (user POV)

- Start the test range. The room is in the south-east corner, `x 12..20` and `z 12..20`. Its door is in the north wall at `16.5 0 12`. The placed MAX AMMO pickup is at `-3 0 10`.
- Get 750 points: shoot zombies, or open the debug menu with F1 and take `+500 POINTS` twice.
- Walk to the door from the north, look at it, and press E.

## Driving it with drive.sh

Preconditions:

- Baseline state: `doors.open` is `0`, `pickups` is `1`, `hud.points` is `0`, `hud.ammo` is `12 / 48`.

- **Use up some reserve.** Run `tap fire` three times with `wait 10` between them, then `tap reload`, `wait 150`. `expect hud.ammo 12 / 45` passes.
- **Get points and clear the zombies.** Run `key F1`, `key Tab`, `key Enter`, `key Enter` (the focus moves from CLOSE to `+500 POINTS`, and each Enter adds 500), then `key Tab` five times and `key Enter` (the focus reaches `KILL ALL ZOMBIES`), then `key F1`. `expect hud.points 1000` and `expect hud.break true` pass. The break gives 10 s with no zombies.
- **Pickup.** Run `face 143 0`, `hold move_forward`, `wait 70`, `release move_forward`. `until hud.ammo 12 / 48 60` passes, then `wait 3`, and `expect pickups 0` passes.
- **Door.** Run `face -90 0`, `hold move_forward`, `wait 255`, `release move_forward`, `face 180 0`. `until hud.prompt_visible true 60` passes, and `expect hud.prompt E BUY DOOR 750` passes. Run `tap interact`, `wait 10`. `expect hud.points 250` and `expect doors.open 1` pass.
- **Through the door.** Run `hold move_forward`, `wait 150`. The player ends in the room, at about `16 0 19.6`. The screenshot shows the room.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/doors.steps`.

## Gotchas

- The break is 10 s. The door steps need about 7 s of it. After the break, round 2 starts, and its zombies also spawn inside the room.
- A pickup leaves the tree one frame after it gives its item, so `wait 3` before `expect pickups 0`.
- The 10% drop has no driven proof, because it is random. `tests/pickups/test_drop_table.gd` proves it with a chance of 1 and 0.
- In the Compound, the warehouse and the office have doors: two for each (`WarehouseDoorSouth`, `WarehouseDoorEast`, `OfficeDoorNorth`, `OfficeDoorEast`). Buying either door of a building opens its spawn point. The journeys do not use the Compound.
- The door prompt text reads `E BUY DOOR 750` after the driver makes each run of spaces one space.
