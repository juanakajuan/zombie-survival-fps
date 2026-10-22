# Milestone 3 design: perks and upgrades

## Goal

Points buy lasting power, not only weapons. The player buys up to four perks at four perk machines. The player also pays one upgrade machine to make the weapon in their hands stronger. A player who survives long can earn all of them. A player who dies loses them.

Milestone 3 does not add power, doors, a bigger map, a second upgrade tier, a perk limit, or perks that need more than one player. Those belong to milestone 4, or to no milestone.

## Rules for the player

- To buy a perk, look at its machine from 2.5 m or less, and press **E**. The prompt and the price show on the HUD, as for a wall buy. If you cannot pay, the prompt is gray and the press does nothing.
- Each perk costs points one time. A machine of a perk that you have shows "Owned", and the press does nothing.
- You keep all perks until you die. A restart gives you none.
- The HUD shows one short name for each perk that you have, under the points.
- To upgrade, look at the upgrade machine and press **E**. It costs 4000 points. It upgrades the weapon in your hands. The weapon keeps its slot. Its magazine and reserve become full at the new sizes.
- A weapon can have one upgrade. The prompt for an upgraded weapon says "Already upgraded", and the press does nothing.
- A wall buy of an upgraded weapon sells ammunition at the usual half price. The box never takes an upgrade away: if the box offers a weapon that you already have, you only get a full refill.

## Perks

| Perk | Machine | Price | Effect |
|---|---|---|---|
| Mender | North wall | 1500 | Health regeneration starts after 1.5 s, not 4.0 s. It heals 100 for each second, not 50. |
| Rapid | East wall | 2000 | The time between shots is 0.75 times as long. |
| Quick Hands | South wall | 2500 | Reload and weapon change take half the time. |
| Tough | West wall | 3000 | Maximum health is 160, not 100. The player is at full health when they buy it. |

Tough means a zombie needs 4 hits, not 3, to kill the player (a hit is 40).

## Upgrade

`Arsenal.upgrade(def)` returns a new `WeaponDef` with these changes:

| Field | Change |
|---|---|
| `tier` | 1 |
| `display_name` | "Upgraded " followed by the old name |
| `damage` | times 2 |
| `magazine_size` | times 1.5, rounded down |
| `reserve_max` | times 1.5, rounded down |

Every other field, and the `id`, stay the same. Thus the code that compares weapons by `id` treats an upgraded pistol as a pistol. The view model gets a tint, so that the player sees the upgrade: `build_model` multiplies each part color by a gold color when `tier` is above 0.

The numbers are for game feel. The implementer may change them. Each change goes in the accepted deviations at the end of this document, and the tests assert the new literal values.

## Usage

```gdscript
# Perk state is plain data. Tests use it with no scene tree:
var perks: Perks = Perks.new()
perks.has(Perks.Kind.RAPID)              # false
perks.grant(Perks.Kind.RAPID)
Rules.fire_interval(Arsenal.smg(), perks)   # 0.075 * 0.75 = 0.05625

# The perk machine tells what a press buys. It does not change anything:
var machine: PerkMachine = PerkMachine.new()
machine.perk = Perks.Kind.TOUGH
machine.price = 3000
var offer: Station.Offer = machine.offer(loadout, perks)
offer.kind    # Station.Offer.Kind.PERK
offer.cost    # 3000
offer.label   # "Buy Tough"

# The upgrade machine reads the weapon in the hands:
var press: UpgradeMachine = UpgradeMachine.new()
press.offer(loadout, perks).label   # "Upgrade Pistol"

# Game takes the points and then lets the station act:
if points.spend(offer.cost):
	station.accept(offer, weapon, perks)
```

## Candidates

The main choice is how a perk changes the numbers.

| | A. Each perk changes the node it touches | B. A `Perks` set and `Rules` lookups |
|---|---|---|
| Shape | `accept()` on a machine sets a field on the player or on the weapon, for example `player.max_health = 160`. | `Perks` is a set of owned perks. `Rules` has one pure function for each number that a perk changes. Nodes call it where they used a constant. |
| Reader load | The current value of a number depends on which `accept()` ran. A reader must find every writer. | Each number has one function. A reader reads the function and sees all perks that touch it. |
| Tests | A test builds a machine, a player, and a weapon to check one number. | A test calls `Rules.fire_interval(def, perks)` with literal inputs. |
| Reset on death | Each node needs a reset. | A restart makes a new `Perks`. |

Choice: **B**. [DESIGN.md](../DESIGN.md) says that perks change numbers on `Rules` lookups. B is that shape, and the rules stay pure.

The upgrade is the reverse case. A perk changes a number that all weapons share. An upgrade changes one weapon, so it lives in the slot. A weapon is data, so `Slot.def` becomes the upgraded `WeaponDef`.

Two smaller choices:

- **Station arguments.** `offer()` and `accept()` receive `perks` as an extra argument. A `Kit` object that holds `loadout` and `perks` would hide the argument, but only these two stations read `perks`, and a new type for two fields is more than the change needs. Milestone 4 can introduce a `Kit` if doors need more state.
- **No perk slots limit.** Four perks exist and the player can have all four. A limit needs a second rule and a way to drop a perk, and the game gains nothing from it at this size.

## Files

New files:

- `game/perks.gd`. `class_name Perks extends RefCounted`. The owned set, the `Kind` enum, and the static name and color for each kind.
- `game/station/perk_machine.gd`. `class_name PerkMachine extends Station`. A `@tool` script, as `WallBuy` is. (Since the level-in-code change: no `@tool`, and `PerkMachine._init(perk, price)` takes both values.)
- `game/station/upgrade_machine.gd`. `class_name UpgradeMachine extends Station`. A `@tool` script (no `@tool` since the level-in-code change).

Changed files:

- `game/rules.gd`. Adds the upgrade price and the lookup functions.
- `game/weapon/weapon_def.gd`. Adds `tier`. `build_model` tints a model with `tier` above 0.
- `game/weapon/arsenal.gd`. Adds `upgrade(def)`.
- `game/weapon/loadout.gd`. Adds `Slot.upgrade()`. `Slot.fill()` uses `def`, so it fills to the new sizes.
- `game/weapon/weapon.gd`. Adds `perks`. Reads the fire interval, the reload time, and the change time from `Rules`. Adds `upgrade_current()`.
- `game/station/station.gd`. `Offer.Kind` adds `PERK` and `UPGRADE`. `offer()` and `accept()` take `perks`. `WallBuy` and `MysteryBox` take the new argument and ignore it.
- `game/player/player.gd`. Adds `perks`. Reads the maximum health and the regeneration numbers from `Rules`.
- `game/game.gd`. Owns one `Perks`, gives it to the player and the weapon, and passes it to `offer()` and `accept()`.
- `game/hud.gd`. Adds a perk row.
- `game/level/arena.tscn`. Holds the four perk machines and the upgrade machine. (Since the level-in-code change, `game/level/arena_layout.gd` holds them as `b.perk_machine(machines, name, perk, price, at)` calls on a `LevelBuilder`.)
- `tests/suites/perks_test.gd` and `test_game_perks` in `tests/suites/game_test.gd`. The tests in the verification plan.

## Data shapes

```gdscript
# Added to Rules:
const UPGRADE_PRICE: int = 4000
const PLAYER_TOUGH_HEALTH: float = 160.0
const MENDER_REGEN_DELAY: float = 1.5
const MENDER_REGEN_RATE: float = 100.0
const RAPID_INTERVAL_FACTOR: float = 0.75
const QUICK_HANDS_FACTOR: float = 0.5

static func max_health(perks: Perks) -> float
static func regen_delay(perks: Perks) -> float
static func regen_rate(perks: Perks) -> float
static func fire_interval(def: WeaponDef, perks: Perks) -> float
static func reload_seconds(def: WeaponDef, perks: Perks) -> float
static func switch_seconds(perks: Perks) -> float
```

```gdscript
class_name Perks extends RefCounted

enum Kind { MENDER, RAPID, QUICK_HANDS, TOUGH }

signal granted(kind: Kind)

var owned: Array[Kind] = []

func has(kind: Kind) -> bool
func grant(kind: Kind) -> void   # no change if owned

static func display_name(kind: Kind) -> String
static func color(kind: Kind) -> Color
```

The price belongs to the machine, as the price of a weapon belongs to its wall buy.

```gdscript
# Added to WeaponDef:
@export_range(0, 1, 1) var tier: int = 0

# Added to Arsenal:
static func upgrade(def: WeaponDef) -> WeaponDef   # a new def. Does not change its argument.

# Added to Loadout.Slot:
func upgrade() -> void   # def = Arsenal.upgrade(def), then fill()
```

```gdscript
# Station.Offer.Kind:
enum Kind { NONE, WEAPON, AMMO, BOX_ROLL, BOX_TAKE, PERK, UPGRADE }

func offer(loadout: Loadout, perks: Perks) -> Station.Offer
func accept(chosen: Station.Offer, weapon: Weapon, perks: Perks) -> void
```

```gdscript
class_name PerkMachine extends Station

@export var perk: Perks.Kind
@export var price: int
```

| The player | Offer |
|---|---|
| does not have the perk | PERK, `price`, "Buy Tough" |
| has the perk | NONE, 0, "Tough owned" |

`accept()` calls `perks.grant(perk)`. For TOUGH, `Game` also sets the player health to `Rules.max_health(perks)` on the `granted` signal.

```gdscript
class_name UpgradeMachine extends Station

# The price is Rules.UPGRADE_PRICE. One machine exists, so the price needs no export.
```

| The weapon in the hands | Offer |
|---|---|
| `tier` is 0 | UPGRADE, `Rules.UPGRADE_PRICE`, "Upgrade Pistol" |
| `tier` is 1 | NONE, 0, "Already upgraded" |

`accept()` calls `weapon.upgrade_current()`. That calls `Slot.upgrade()` on the active slot, emits `equipped` and `ammo_changed`, and does not start SWITCHING. The hands do not move, so the player can fire at once.

```gdscript
# Added to Weapon and Player:
var perks: Perks = Perks.new()   # Game sets it. The default is no perks, so tests need no setup.
```

The perk numbers enter at these places and nowhere else:

| Number | Place |
|---|---|
| Maximum health | `Player` health clamp and the `Hud` health bar |
| Regeneration delay and rate | `Player._regenerate` and `Player.take_damage` |
| Fire interval | `Weapon` when it starts COOLDOWN |
| Reload time | `Weapon` when it starts RELOADING |
| Change time | `Weapon` when it starts SWITCHING |

A reload or a change that is in progress when the player buys a perk keeps the old time. The new time applies from the next one. This keeps each timer a single number.

## Arena

The machines stand on the outer walls, 0.05 m off the wall, on the same plane as the wall buys. The upgrade machine stands beside the box.

| Station | Position | Faces |
|---|---|---|
| Mender, 1500 | (8, 1.5, -19.95) | +Z |
| Rapid, 2000 | (19.95, 1.5, 8) | -X |
| Quick Hands, 2500 | (0, 1.5, 19.95) | -Z |
| Tough, 3000 | (-19.95, 1.5, -8) | +X |
| Upgrade, 4000 | (-10, 0, 19.5) | -Z |

The implementer checks these positions against the zombie spawn markers, and moves a machine that stands on one. A perk machine is a tall slab with a glow in the color of its perk. The upgrade machine is a crate with a gold glow, like the box. All visuals come from `_ready()`, as for the milestone 2 stations, and show in the editor.

## HUD

The perk row is a `Label` under the points. It shows the short name of each owned perk, in the perk color, in the order of purchase. It connects to `Perks.granted` and does not poll.

## Boundaries

- `Perks.grant()` trusts its caller. `PerkMachine.offer()` is the only gate against a second purchase.
- `Rules` lookups take a `Perks` and never a null. `Player` and `Weapon` start with an empty `Perks`.
- `Game` still takes the points before `accept()`, so a machine never sees a failed spend.

## Verification plan

Headless tests with literal expected values:

- `Rules`: with no perks, `max_health` is 100, `regen_delay` is 4.0, `regen_rate` is 50, `fire_interval` of the SMG is 0.075, `reload_seconds` of the SMG is 2.0, and `switch_seconds` is 0.5. With each perk, the one number changes and the others do not: 160, 1.5 and 100, 0.05625, and 1.0 and 0.25.
- `Perks`: `grant` adds one entry, a second `grant` of the same kind adds nothing and emits no signal.
- `Arsenal.upgrade`: the pistol becomes damage 70, magazine 12, reserve 120, tier 1, name "Upgraded Pistol", and the same `id`. The argument is unchanged. The shotgun becomes magazine 9 and reserve 63.
- `Loadout`: `Slot.upgrade()` fills the slot to 12 and 120. `give(pistol)` after an upgrade fills the slot and keeps tier 1. `find(&"pistol")` still finds it.
- `PerkMachine.offer` for both rows of its table. `UpgradeMachine.offer` for both rows.
- `Weapon` in a real physics world: an upgraded pistol kills a zombie of 150 health in 3 shots, not 5. With Rapid, the SMG fires 5 shots in 0.28 s of ticks, and 4 without it in the same time. With Quick Hands, a pistol reload takes 42 ticks and a change takes 15. An upgrade during a reload does not stop the reload.
- `Player`: with Tough, 3 zombie hits leave 40 health and a fourth kills. With Mender, regeneration starts 1.5 s after a hit.
- `Game` with the real arena: with 1500 points the player buys Mender and the balance is 0. A second press does nothing. The perk row shows "Mender". With 4000 points the player upgrades the pistol and slot 1 has 12 and 120. A restart gives no perks.
- All milestone 1 and 2 tests still pass, on Jolt and on Godot Physics.
- `godot --headless --path . --quit-after 600` with no errors.
- `tests/visual_smoke.gd` captures a frame.
- The `verify` skill plays the real main scene: earn points, buy a perk, upgrade the pistol, and take a screenshot of the perk row and of the upgrade prompt.

## Accepted deviations

- The upgrade machine is a wall slab like the perk machines, at (-10, 1.5, 19.95) facing -Z, not a crate with a body beside the box. A slab needs no collision body or navigation change. `Machine` is the shared base of both machine kinds.
- Quick Hands stands at x 5 on the south wall, not x 0, because zombie spawn 6 is at (0, 0, 18).
- `Player.health_changed` has a second argument, the maximum health, so the HUD vignette scales with Tough. `Player.heal_to_max()` fills the health when the player buys Tough.
- `Weapon` stores the length of the reload or the change in progress (`_duration`), because perks change it and the view model animation reads it.
- The verify scenario `perks.txt` proves the prompts only. A pistol cannot clear round 2 here and 4000 points need many rounds. The paid buys are proven by `test_game_perks`.
