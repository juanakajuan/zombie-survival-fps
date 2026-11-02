class_name GameOver
extends CanvasLayer
## Hidden until Level calls `open()`, when every player is dead. Then it shows the round that the players reached and
## emits restart_requested when one of the players presses the restart action.

signal restart_requested

@export var round_manager: RoundManager

@onready var _round_label: Label = %RoundLabel

var _players: Array[Player] = []


func _ready() -> void:
	hide()
	set_physics_process(false)


func round_text() -> String:
	return _round_label.text


func open(players: Array[Player]) -> void:
	_players = players
	_round_label.text = "You reached round %d" % round_manager.round_number
	show()
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if _players.any(func(player: Player) -> bool: return player.input.is_just_pressed(PlayerInput.Action.RESTART)):
		set_physics_process(false)
		restart_requested.emit()
