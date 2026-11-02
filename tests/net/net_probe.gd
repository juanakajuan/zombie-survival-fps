class_name NetProbe
extends Node3D

var hits_received: int = 0


@rpc("any_peer", "call_local", "reliable")
func request_hit(amount: int) -> void:
	if multiplayer.is_server():
		hits_received += amount
