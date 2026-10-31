class_name RepairAllItem
extends BuyItem
## Puts the boards back on every barricade, and pays a fixed number of points.

@export_range(0, 10000) var points: int = 200


func can_apply(player: Player) -> bool:
	return not player.is_dead()


func apply(player: Player) -> void:
	for node: Node in player.get_tree().get_nodes_in_group(Barricade.GROUP):
		(node as Barricade).fill()
	player.wallet.add(points)
