# Sound sources

Every file in `sfx/` is Juan's voice, recorded with `tools/record_sfx.sh`. License: CC0.

| File | Source | License |
|---|---|---|
| `sfx/gunshot.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/dry_click.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/reload.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/hit.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/kill.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/zombie_groan_1.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/zombie_groan_2.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/zombie_groan_3.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/zombie_attack.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/zombie_death.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/player_hurt.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/round_start.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |
| `sfx/break_start.wav` | Juan's voice, recorded with tools/record_sfx.sh | CC0 |

Each `*.tres` next to this file is an `AudioStreamRandomizer`: one sound event, with its stream pool, random pitch, and random volume offset. The volume of the event is the `volume_db` of the player node that plays it.
