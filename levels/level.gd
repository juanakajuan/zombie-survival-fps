class_name Level
extends Node3D

@export var game_over: GameOver
@export var navigation: LevelNavigation
@export var player: Player
@export var round_manager: RoundManager


func _ready() -> void:
	player.hud.round_manager = round_manager
	player.debug_menu.round_manager = round_manager
	for node: Node in nodes_in_group(Door.GROUP, self):
		(node as Door).opened.connect(navigation.bake)
	for node: Node in nodes_in_group(WeaponBox.GROUP, self):
		(node as WeaponBox).moved.connect(navigation.bake)
	round_manager.round_started.connect(func(_round_number: int) -> void:
		player.wallet.start_round()
		player.grenades.start_round()
	)
	game_over.restart_requested.connect(restart)


## The members of `group` in the 3D world of `near`. The scene tree can hold more than one world, as in a network test.
static func nodes_in_group(group: StringName, near: Node) -> Array[Node]:
	var world := near.get_viewport().find_world_3d()
	var found: Array[Node] = []
	for node: Node in near.get_tree().get_nodes_in_group(group):
		if node.get_viewport().find_world_3d() == world:
			found.append(node)
	return found


func restart() -> void:
	get_tree().reload_current_scene()
