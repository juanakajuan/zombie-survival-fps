class_name NukeItem
extends BuyItem
## Kills every living zombie at once, with no points for the kills and no drops, and pays a fixed number of points.

@export_range(0, 10000) var points: int = 400


func can_apply(player: Player) -> bool:
	return not player.is_dead()


func apply(player: Player) -> void:
	for node: Node in player.get_tree().get_nodes_in_group(Zombie.GROUP):
		(node as Zombie).kill_quietly()
	player.wallet.add(points)
