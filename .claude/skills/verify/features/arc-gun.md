# Arc gun

The ARC GUN is the special weapon. Only the weapon box gives it, and no station sells it. It is a teal raygun with copper coils and a glowing tip. A shot is one ray. When the ray damages a living zombie, a cyan arc jumps from it to the nearest living zombie within 6 m that it can see, then from that one to the next, up to 4 jumps. Each jump deals 0.75 of the damage of the jump before it, and each zombie that an arc hits pays the 10 hit points. A wall stops an arc. The magazine is a glowing battery cell that the reload swaps. ARC GUN+ from the upgrade machine jumps 7 times, up to 8 m, with more damage and a magenta body.

## Sub-features

- `box-only` means that the weapon box can roll the ARC GUN, and that no wall buy or crate sells it.
- `give` takes the ARC GUN from the debug menu (`GIVE ARC GUN`) without the box: `hud.weapon` is `ARC GUN`, `hud.ammo` is `8 / 48`.
- `chain` sends arcs from the zombie that the shot hits to the zombies near it. One shot into a group of round 1 zombies pays 70 for the kill and 10 for each zombie that an arc hits, and every hit zombie flashes red and shows its health bar.
- `reload` drops the empty battery cell and the left hand pushes in a new one.

## How to get to it (user POV)

- Use the weapon box until it rolls the ARC GUN, and take it with E. Or, in a debug build, press F1 and click GIVE ARC GUN.
- Wait for zombies to bunch up, and shoot the nearest one.

## Driving it with drive.sh

Preconditions:

- Baseline state: `hud.weapon` is `PISTOL`, `hud.points` is `0`.

- **Take it.** Run `debug GOD MODE`, `debug GIVE ARC GUN`, `wait 5`. `expect hud.weapon ARC GUN` and `expect hud.ammo 8 / 48` pass.
- **Chain.** Run `until zombies.alive 4 300`, `wait 420` for the zombies to come close together, then `aim`, `tap fire`, and `shot` at once. The screenshot shows the cyan arcs and the hit zombies in red. `state` shows `hud.points` above 70 (the kill alone) when an arc hit another zombie. In the recorded run it was `100`: the kill and 3 arc hits.
- **Proof.** Run `.claude/skills/verify/scripts/drive.sh .claude/skills/verify/journeys/arc_gun.steps`.

## Gotchas

- The roll of the weapon box is random, so the journey takes the ARC GUN from the debug menu. `journeys/weapon_box.steps` proves the box.
- How many zombies an arc reaches depends on where they walk, so a run can show fewer arcs. `tests/weapons/test_arc_gun.gd` proves the jump order, the damage of each jump, and that a wall stops an arc.
- A zombie that the first ray kills still passes the arc on, because the arc starts at the point that the ray hit.
