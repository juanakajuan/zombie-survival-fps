class_name Level
extends Node3D

@export var game_over: GameOver
@export var navigation: LevelNavigation


func _ready() -> void:
	game_over.restart_requested.connect(restart)


func restart() -> void:
	get_tree().reload_current_scene()
