class_name Level
extends Node3D

@export var game_over: GameOver
@export var navigation: LevelNavigation
@export var player: Player
@export var round_manager: RoundManager


func _ready() -> void:
	player.hud.round_manager = round_manager
	game_over.restart_requested.connect(restart)


func restart() -> void:
	get_tree().reload_current_scene()
