class_name WeaponBox
extends Interactable
## A box that gives a random weapon for a price. The weapon shows over the box for a short time, and the player takes it
## with the interact action. A use can instead give the points back and move the box to another of its places.

## A use refunded the price and the box went to a new place.
signal moved

const GROUP := &"weapon_box"

enum State { READY, OFFERING }

@export var table: WeaponBoxTable
@export_range(0, 100000) var cost: int = 950
## The seconds that a rolled weapon stays over the box. Then it is gone and the points are not given back.
@export_range(1.0, 60.0, 0.5, "suffix:s") var offer_time: float = 8.0
## The chance that a use moves the box instead of giving a weapon.
@export_range(0.0, 1.0, 0.01) var move_chance: float = 0.15
## The uses at a place before the box can move from it.
@export_range(0, 100) var safe_uses: int = 3
## The places that the box can stand at. Include the place where the box starts.
@export var places: Array[Node3D]

var _state := State.READY
var _offer: WeaponItem
var _offer_left := 0.0
var _uses_here := 0

@onready var _label: Label3D = $Label
@onready var _offer_label: Label3D = $OfferLabel


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_label.text = "WEAPON BOX\n%d" % cost
	_show_offer()


func _physics_process(delta: float) -> void:
	if _state != State.OFFERING:
		return
	_offer_left -= delta
	if _offer_left <= 0.0:
		_end_offer()


## The weapon over the box that the player can take, or null.
func offer() -> WeaponItem:
	return _offer


## Takes the cost and rolls. Returns false, and takes no points, while a weapon is over the box, when the table has no
## weapon that the player does not hold, or when the player cannot pay.
func use(player: Player) -> bool:
	if _state != State.READY or table.available(player).is_empty() or not player.wallet.spend(cost):
		return false
	_uses_here += 1
	if _uses_here > safe_uses and randf() < move_chance:
		player.wallet.add(cost)
		_move()
		return true
	_offer = table.roll(player)
	_offer_left = offer_time
	_state = State.OFFERING
	_show_offer()
	return true


## Gives the weapon over the box to the player. Returns false when there is none.
func take(player: Player) -> bool:
	if _state != State.OFFERING:
		return false
	_offer.apply(player)
	_end_offer()
	return true


func prompt_text(player: Player) -> String:
	if _state == State.OFFERING:
		return "E  TAKE %s" % _offer.display_name
	if table.available(player).is_empty():
		return "NO NEW WEAPONS"
	return "E  WEAPON BOX  %d" % cost


func press(player: Player) -> void:
	if _state == State.OFFERING:
		take(player)
	else:
		use(player)


## The text over the box: the rolled weapon's name while it is there, or an empty string.
func offer_text() -> String:
	return _offer_label.text if _offer_label.visible else ""


func _end_offer() -> void:
	_state = State.READY
	_offer = null
	_show_offer()


func _show_offer() -> void:
	_offer_label.visible = _offer != null
	_offer_label.text = _offer.display_name if _offer != null else ""


func _move() -> void:
	var others := places.filter(func(place: Node3D) -> bool: return not place.global_position.is_equal_approx(global_position))
	_uses_here = 0
	if others.is_empty():
		return
	var place: Node3D = others.pick_random()
	global_transform = place.global_transform
	moved.emit()
