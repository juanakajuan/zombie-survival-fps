# Movement

The player walks at 7 m/s, sprints at 10.5 m/s, crouches at 3.5 m/s, slides from a sprint, jumps, and climbs ledges with a mantle. `docs/player.md` gives the full design.

## Sub-features

- `walk` with W, A, S, D.
- `sprint` with Shift held.
- `slide` when you press Ctrl or C on the ground at 8 m/s or more (sprint is 10.5 m/s), 0.6 s or more after the last slide. It adds 3.5 m/s, to 15 m/s at most. Landing with Ctrl or C held at 8 m/s or more also slides. Shift does not have to be held. The slide stops when you release the key or the speed goes below 4 m/s. Under 8 m/s, Ctrl or C crouches.
- `jump` with Space. The state goes `AIR`, then `GROUND` on landing.
- `mantle` when you press Space while you walk (W) into a ledge between 0.36 m and 1.2 m high, or when you fall against one with Space held. A walk into the ledge with no jump only stops you. The state goes `MANTLE` for 0.4 s, then `GROUND`, and you end on top. A ledge of 0.35 m or less is a step, and the state stays `GROUND`. A ledge above 1.2 m blocks you. In the air the reach is measured from the last floor, so a jump does not reach a ledge above 1.2 m. A low ceiling over the ledge refuses it, and a ceiling that only a crouched body fits under gives a crouch mantle. The Cover4 block at 12, -2 (3 m wide, 1.2 m high) is a ledge to mantle onto, from its +Z side. The cover block at z = -4 is 1.5 m high, so it blocks.
- `look` with mouse motion: 0.1 degree for each pixel.
- `stairs` on the platform at -10, -10 (stairs on its +Z side, a ramp on its +X side).

## How to get to it (user POV)

- Keyboard and mouse as above. Left stick, left stick press, B, A, and the right stick (look) on a gamepad.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/movement.txt`.

- **Turn.** `look 1800 0`, `wait 0.1`, `expect yaw_deg == -180`. The player now faces +Z, a clear lane.
- **Walk.** `press W`, `wait 0.5`, `expect speed >= 6.5`.
- **Sprint.** `press Shift`, `wait 0.6`, `expect speed >= 10`.
- **Slide.** `press C`, `wait 0.05`, `expect move_state == SLIDE`, `shot slide` (the camera is low).
- **Mantle.** Run `.claude/skills/verify/scenarios/mantle.txt`. It walks to 12, 1.5, faces -Z, holds W for 0.6 s, expects `GROUND` (no auto-mantle), taps Space, waits for `move_state == MANTLE`, takes a shot, waits for `GROUND`, and expects a y of 1.2 in `position`.
- **Jump.** Release all keys, `wait 1`, `tap Space`, `wait 0.1`, `expect move_state == AIR`, `wait 1`, `expect move_state == GROUND`.

## Gotchas

- Facing -Z from spawn, the cover block at z = -4 stops a sprint after about 1 s, and `speed` drops to 0.
- `press` holds a key until `release`. The driver releases held keys at the end of the run.
- Zombies can reach the player during long movement runs after round 1 starts at 3 s. The spawn point at `0,0,18` is in the +Z lane.
