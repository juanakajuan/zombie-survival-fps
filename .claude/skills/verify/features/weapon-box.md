# Weapon box

A purple box with a yellow lid stands 3.5 m behind the start, with the label WEAPON BOX and 950 over it. Looking at it shows `E  WEAPON BOX  950`. E takes 950 points and shows a random weapon name over the box, from `weapon_box/weapon_box_table.tres`, never one that the player holds. The prompt then shows `E  TAKE <weapon>`, for example `E  TAKE SHOTGUN`, and E puts the weapon in hand (with two held, it replaces the weapon in hand). An offer that the player does not take goes away after 8 s, with no refund. After 3 uses at a place, each use has a 15 % chance to give no weapon: the points come back and the box moves to another place.

## Sub-features

- `box-prompt` shows `E  WEAPON BOX  950`, or `NO NEW WEAPONS` when the player holds every weapon in the table. Then E takes nothing.
- `box-use` takes 950 points and shows the weapon name over the box (`box.offer`).
- `box-take` gives the offered weapon on a second E. `box.offer` is empty again.
- `box-move` refunds and moves the box to one of its places (`box.position` changes). The tests prove it with a move chance of 1, because the run cannot force the chance.

## How to get to it (user POV)

- Earn 950 points (rounds 1 and 2 give 1060).
- Turn around from the start, walk to the box, look down at it, and press E. Press E again to take the weapon.

## Driving it with drive.sh

Preconditions:

- Baseline state: `box.position` is `0.0 0.0 9.5`, `box.offer` is empty.

- **Earn points.** Clear rounds 1 and 2 as in `journeys/weapons.steps`. `expect hud.points 1060` passes.
- **Face the box.** Run `face 180 0`, `hold move_forward`, `wait 25`, `release move_forward`, `wait 30`, `look 0 260`. `expect hud.prompt E WEAPON BOX 950` passes.
- **Use.** Run `tap interact`, `wait 5`. `expect hud.points 110` passes, and `expect_not box.offer` (empty) passes because a weapon name is over the box. The roll is random: any weapon in the table except the pistol, which the player holds. The screenshot shows the name over the box.
- **Take.** Run `tap interact`, `wait 5`. `expect_not hud.weapon PISTOL` and `expect box.offer` (empty) pass, and the prompt is `E  WEAPON BOX  950` again. `tests/weapon_box/test_weapon_box.gd` proves `NO NEW WEAPONS` with a table of two weapons.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/weapon_box.steps`.

## Gotchas

- In the Compound, the box starts in the yard at `-6 0 21.5`, south of the container near the start. Its other places are in the warehouse, by the watchtower, and in the east yard. The journeys are for the test range.
- The first 3 uses at a place never move the box (`WeaponBox.safe_uses`), so a journey with one use is deterministic.
- The offer shows over the box, so look up after the use to see it in a screenshot.
