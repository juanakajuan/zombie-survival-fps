# Milestone 4 design: map and secrets

## Goal

The map grows from one arena to three zones. The player starts in one zone, and buys doors to open the others. Zombies spawn only in open zones, so a door makes the game harder and gives more room. A power switch in the far zone turns on the perk machines and the upgrade machine. One secret hides a reward.

Milestone 4 does not add new weapons, new perks, new zombie types, a second secret, saved games, or doors that close again. Those belong to no milestone.

## Rules for the player

- The player starts in the **Yard**, the arena of milestones 1 to 3, with all wall buys, the box, and the machines. The Yard has two closed doors.
- To buy a door, look at it from 2.5 m or less and press **E**. The prompt shows the price. The door opens for the rest of the game.
- The east door costs 1250 and opens the **Warehouse**. The north door costs 1750 and opens the **Courtyard**.
- The perk machines and the upgrade machine have no light and say "No power" until the player turns on the power. The power switch is in the Warehouse. It is free, and it works one time.
- The Courtyard has three sigils (glowing marks on a wall). A shot at a sigil lights it. When all three are lit, a hidden panel in the Courtyard wall slides away, and a **cache** shows behind it. The cache is free and gives 1500 points and a full refill of both weapons. It works one time.
- Zombies spawn in the Yard from round 1, and also in every zone that the player has opened.
- A restart closes all doors, turns off the power, and hides the cache.

## Map

| Zone | Area (x, z in meters) | Opens with | Contents |
|---|---|---|---|
| Yard | -20 to 20, -20 to 20 | Always open | All of milestone 3. Doors in the east wall and the north wall. |
| Warehouse | 21 to 61, -15 to 15 | East door, 1250 | Cover blocks, one interior wall with a gap, the power switch at the far end, 3 zombie spawns. |
| Courtyard | -15 to 15, -61 to -21 | North door, 1750 | Three sigils, the hidden panel and cache, a few cover blocks, 3 zombie spawns. |

Each door fills a 4 m wide gap in a wall of the Yard. The zones form a **tree**: the only way from the Yard to a zone is its door, and no two zones touch. This rule makes the navigation work (see "Navigation").

## Usage

```gdscript
# A door is a Station. It tells what a press buys. It changes nothing until accept().
var door: Door = Door.new()
door.zone = &"warehouse"
door.price = 1250
var offer: Station.Offer = door.offer(loadout, perks)
offer.kind    # Station.Offer.Kind.DOOR
door.accept(offer, weapon, perks)    # the blocker is gone, and door.opened emits &"warehouse"

# Arena gives spawns of the open zones only:
arena.spawns()                       # the Yard spawns
arena.open_zone(&"warehouse")
arena.spawns()                       # the Yard spawns and the Warehouse spawns

# Power is a flag on each Machine, set by the switch through Game:
machine.offer(loadout, perks).label  # "No power"
machine.powered = true
machine.offer(loadout, perks).label  # the usual perk prompt
```

## Candidates

| Question | A | B |
|---|---|---|
| Doors and the navigation mesh | Bake once. The door blockers are outside the `Navigation` region, so the mesh is continuous through each gap. | Bake again at each door open, or use a `NavigationLink3D` for each door. |
| Shared state | Station-local flags. `Door` owns its open state. `Machine` owns `powered`. `Arena` owns the list of open zones. `Game` wires the signals. | A new `Kit` object with `loadout`, `perks`, `unlocks`, passed to every `offer()` and `accept()`. |
| Spawn choice in a big map | The farthest of 4 candidates (milestone 1), unchanged. | Nearest candidate that is at least 12 m from the player. |

Choices: **A**, **A**, **B**.

- Doors: a bake at run time is slow and asynchronous. With a tree of zones, a zombie never needs a path through a closed door, because the player is never beyond it. Zombies spawn only in open zones, and the player is in an open zone. So the mesh can be continuous. Test: a zombie in a closed zone is impossible by construction, and a test checks it (see "Verification plan").
- State: the milestone 3 document said that a `Kit` could come if doors need more state. They do not. A door needs only its own flag, and a machine needs one boolean. A `Kit` would change every `offer()` and `accept()` in six stations for no reader gain.
- Spawns: the farthest of 4 points was fine in a 40 m arena. In a 100 m map it makes zombies walk for a minute. The nearest candidate at least 12 m away keeps the zombie out of view at close range and keeps the fight close.

## Files

New:

- `game/station/door.gd`. `class_name Door extends Station`, `@tool`. Exports `zone` (`StringName`) and `price`. Builds a blocker (`StaticBody3D` on `Layers.WORLD`), a dark slab, and a price label, in `_ready()`. Signal `opened(zone: StringName)`. `accept()` frees the blocker and hides the slab.
- `game/station/power_switch.gd`. `class_name PowerSwitch extends Station`, `@tool`. Free. Signal `switched_on`. One use.
- `game/station/cache.gd`. `class_name Cache extends Station`, `@tool`. Free, one use. Hidden and not in the interact ray until `reveal()` is called.
- `game/level/sigil.gd`. `class_name Sigil extends StaticBody3D`, `@tool`. A glowing mark. `light()` turns it on. Signal `lit`.
- `game/level/secret.gd`. `class_name Secret extends Node3D`. Counts the lit sigils of its children, moves the panel away at 3, and calls `reveal()` on the cache.

Changed:

- `game/level/arena.tscn`. Adds the Warehouse and the Courtyard, the two doors, the power switch, the sigils, the panel, the cache, and the spawn markers. Spawn markers go under one `Node3D` for each zone (`ZombieSpawns/Yard`, `ZombieSpawns/Warehouse`, `ZombieSpawns/Courtyard`). Doors and the panel are outside `Navigation`.
- `game/level/arena.gd`. Reads spawns by zone. `open_zone(zone)` adds a zone. `spawns() -> Array[Vector3]` gives the open ones. Finds the doors, the power switch, and the secret.
- `game/station/machine.gd`. Adds `powered`. `offer()` returns NONE with the label "No power" when off, and calls the new abstract `_offer()` when on. The glow is dark when off. `PerkMachine` and `UpgradeMachine` rename `offer` to `_offer`.
- `game/station/station.gd`. Adds `Offer.Kind.DOOR`, `POWER`, and `CACHE`.
- `game/game.gd`. Connects `Door.opened` to `arena.open_zone`, `PowerSwitch.switched_on` to each machine, and the cache to `points.earn` and a refill. `_spawn_zombie()` uses `Rules.pick_spawn`.
- `game/weapon/weapon.gd`. When the hitscan ray ends on a `Sigil`, it calls `light()`. A sigil is a `StaticBody3D` on `Layers.WORLD`, so it also stops bullets.
- `game/rules.gd`. Adds `DOOR_PRICES` (by zone), `CACHE_POINTS`, `SPAWN_MIN_DISTANCE`, and `pick_spawn`.
- `game/hud.gd`. No change. The prompt path shows door prices and "No power".

## Data shapes

```gdscript
# Rules
const WAREHOUSE_DOOR_PRICE: int = 1250
const COURTYARD_DOOR_PRICE: int = 1750
const CACHE_POINTS: int = 1500
const SPAWN_CANDIDATES: int = 4          # moves from Game
const SPAWN_MIN_DISTANCE: float = 12.0

## Of the candidates, the nearest to the player that is at least SPAWN_MIN_DISTANCE away.
## If every candidate is closer, the farthest one. Candidates is never empty.
static func pick_spawn(candidates: Array[Vector3], player: Vector3) -> Vector3

# Door
@export var zone: StringName
@export var price: int
signal opened(zone: StringName)
var is_open: bool            # offer() is NONE with the label "" once true

# Machine
var powered: bool = false    # set by Game; Arena reads nothing from it

# Arena
var open_zones: Array[StringName] = [&"yard"]
func open_zone(zone: StringName) -> void     # no change if open already
func spawns() -> Array[Vector3]              # in marker order, open zones only
```

`pick_spawn` is a pure function: the caller draws the candidates from `Arena.spawns()` with its own random generator.

## Navigation

`Arena._ready()` bakes once, as in milestone 2. The doors and the panel are outside the `Navigation` region, so the baked mesh covers the gaps. A closed door is a physical blocker, not a navigation blocker. This is safe only because a zombie never has a target behind a closed door: the target is the player, the player is in an open zone, and an open zone connects to the others only through the tree. A test checks the rule that the zones are a tree (each zone has one door, and the Warehouse and the Courtyard share no wall).

The baked mesh is bigger, so the bake takes more time at load. The implementer measures it. If it is above 1 s, the arena bakes the Yard first and the other zones in the background.

## HUD

Door and power prompts use the existing prompt line. The cache and the switch show their label with no price ("Turn on power", "Take the cache"). No new HUD element.

## Boundaries

- A shot never opens a door. Only **E** buys.
- A zombie cannot open a door. The blocker has `Layers.WORLD`, and zombies collide with it.
- A sigil, a door blocker, and the panel are static. Nothing moves them except `Secret` and `Door`, one time each.
- Points can go down only through `points.spend()`, as before. The cache uses `points.earn()`.

## Verification plan

Headless tests (`tests/run_checks.sh`):

- `Rules.pick_spawn` takes the nearest candidate at or beyond 12 m, and the farthest if all are closer.
- `Arena.spawns()` has only Yard markers at first, and the Warehouse markers after `open_zone(&"warehouse")`.
- `Door.offer` gives DOOR with the price, then NONE after `accept`. The blocker is gone after `accept`.
- A player pushed into a closed door does not pass it. After `accept`, the player passes.
- `Machine.offer` says "No power" until `powered` is true. Each of the five machines has `powered == false` on a new arena.
- Three `light()` calls on the sigils of a `Secret` reveal the cache. Two calls do not.
- The cache gives 1500 points one time, and fills both weapons.
- A zombie spawned in the Warehouse after the door opens reaches a player in the Yard in 30 s.
- The zones form a tree (see "Navigation").
- All milestone 1 to 3 tests still pass, on Jolt and on Godot Physics.

Live checks with the `verify` skill: buy the east door and walk through, turn on the power and buy a perk, shoot three sigils and take the cache, and restart to see all closed. Add the new features to the feature map of the skill.

## Accepted deviations

None yet. The implementer lists each change to a number or a rule here.
