class_name GameOver
extends CanvasLayer
## Hidden until Level calls `open()`, when every player is dead. Then it shows the round that the players reached and
## emits restart_requested when the restart action is pressed.

signal restart_requested

@export var round_manager: RoundManager

@onready var _round_label: Label = %RoundLabel


func _ready() -> void:
	hide()
	set_process(false)


func round_text() -> String:
	return _round_label.text


func open() -> void:
	_round_label.text = "You reached round %d" % round_manager.round_number
	show()
	set_process(true)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		set_process(false)
		restart_requested.emit()
