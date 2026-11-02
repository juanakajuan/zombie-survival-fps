class_name PlayerInput
extends Node
## The input of one player: the move vector, the look change, and a held and a just-pressed flag for each action.
## Player, its weapons, and GameOver read it, not Input. It fills itself from the devices of this machine only while
## its player is local. The input of a player that is not local stays empty.

## The gameplay actions. The lower-case name of each is its action in the Input Map.
enum Action { FIRE, AIM, RELOAD, JUMP, SPRINT, CROUCH, INTERACT, MELEE, GRENADE, WEAPON_1, WEAPON_2, WEAPON_NEXT, WEAPON_PREVIOUS, RESTART }

@export var player: Player

## The move input for this physics frame. -Y is forward and +X is right, as Input.get_vector() gives it.
var move := Vector2.ZERO

var _look := Vector2.ZERO
var _held: Array[bool] = []
var _just_pressed: Array[bool] = []
var _names: Array[StringName] = []


func _ready() -> void:
	# Player and its weapons read this node in their own physics frame, so it must fill first.
	process_physics_priority = -1
	for action_name: String in Action.keys():
		_names.append(StringName(action_name.to_lower()))
	_held.resize(_names.size())
	_just_pressed.resize(_names.size())


func _physics_process(_delta: float) -> void:
	var local := player.is_local()
	for i: int in _names.size():
		_held[i] = local and Input.is_action_pressed(_names[i])
		_just_pressed[i] = local and Input.is_action_just_pressed(_names[i])
	move = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if local else Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and player.is_local() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look += (event as InputEventMouseMotion).screen_relative


## True while the action is held in this physics frame.
func is_held(action: Action) -> bool:
	return _held[action]


## True in the first physics frame that the action is held.
func is_just_pressed(action: Action) -> bool:
	return _just_pressed[action]


## The mouse motion in pixels since the last call. The call clears it.
func take_look() -> Vector2:
	var taken := _look
	_look = Vector2.ZERO
	return taken
