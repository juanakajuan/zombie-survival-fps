class_name GameOver
extends CanvasLayer
## Hidden until the player dies. Then it shows the round that the player reached, releases the mouse, and emits
## restart_requested when the restart action is pressed.

## The level handles this signal and reloads itself. Tests can connect to it without a reload.
signal restart_requested

@export var player: Player
@export var round_manager: RoundManager

@onready var _round_label: Label = %RoundLabel


func _ready() -> void:
	hide()
	set_process(false)
	player.died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		set_process(false)
		restart_requested.emit()


func _on_player_died() -> void:
	_round_label.text = "You reached round %d" % round_manager.round_number
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(true)
