class_name Level
extends Node3D

@export var game_over: GameOver
@export var navigation: LevelNavigation
@export var round_manager: RoundManager

## The players of this level. The scene's Player children join in `_ready()`. `add_player()` adds the others.
var players: Array[Player] = []


func _ready() -> void:
	for child: Node in get_children():
		if child is Player:
			add_player(child as Player)
	for node: Node in nodes_in_group(Door.GROUP, self):
		(node as Door).opened.connect(navigation.bake)
	for node: Node in nodes_in_group(WeaponBox.GROUP, self):
		(node as WeaponBox).moved.connect(navigation.bake)
	game_over.restart_requested.connect(restart)


## Makes `player` a target of the zombies, gives it the round state, and counts it for the game over. Adding the same
## player again does nothing.
func add_player(player: Player) -> void:
	if players.has(player):
		return
	players.append(player)
	player.hud.round_manager = round_manager
	player.debug_menu.round_manager = round_manager
	round_manager.round_started.connect(func(_round_number: int) -> void:
		player.wallet.start_round()
		player.grenades.start_round()
	)
	round_manager.targets.append(player)
	player.died.connect(_on_player_died)


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


func _on_player_died() -> void:
	if players.all(func(player: Player) -> bool: return player.is_dead()):
		game_over.open()
