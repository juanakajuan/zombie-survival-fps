class_name Level
extends Node3D
## Reloads the level when the game-over screen asks for a restart.

@export var game_over: GameOver


func _ready() -> void:
	game_over.restart_requested.connect(restart)


func restart() -> void:
	get_tree().reload_current_scene()
