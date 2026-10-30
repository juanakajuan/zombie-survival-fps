class_name Level
extends Node3D

@export var game_over: GameOver
@export var navigation: LevelNavigation
@export var player: Player
@export var round_manager: RoundManager


func _ready() -> void:
	player.hud.round_manager = round_manager
	player.debug_menu.round_manager = round_manager
	for node: Node in get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).opened.connect(navigation.bake)
	game_over.restart_requested.connect(restart)


func restart() -> void:
	get_tree().reload_current_scene()
