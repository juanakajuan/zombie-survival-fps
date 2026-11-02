class_name NetSession
extends Node

const CLIENT_ID := 2

var host_level: Level
var client_level: Level
var host_api: SceneMultiplayer
var client_api: SceneMultiplayer
var host_peer: LoopbackPeer
var client_peer: LoopbackPeer

var _scene: PackedScene
var _api_paths: Array[NodePath] = []


static func offline(scene: PackedScene) -> NetSession:
	var session := NetSession.new()
	session._scene = scene
	return session


static func loopback(scene: PackedScene) -> NetSession:
	var session := NetSession.offline(scene)
	session.host_peer = LoopbackPeer.new(1)
	session.client_peer = LoopbackPeer.new(CLIENT_ID)
	LoopbackPeer.link(session.host_peer, session.client_peer)
	return session


func _enter_tree() -> void:
	host_api = SceneMultiplayer.new()
	client_api = SceneMultiplayer.new()
	host_level = _add_branch("Host", host_api, host_peer)
	client_level = _add_branch("Client", client_api, client_peer)


func _exit_tree() -> void:
	for peer: LoopbackPeer in [host_peer, client_peer]:
		if peer != null:
			peer.close()
	for path: NodePath in _api_paths:
		get_tree().set_multiplayer(null, path)
	_api_paths.clear()


func _add_branch(branch_name: String, api: SceneMultiplayer, peer: LoopbackPeer) -> Level:
	var viewport := SubViewport.new()
	viewport.name = branch_name
	viewport.own_world_3d = true
	add_child(viewport)
	get_tree().set_multiplayer(api, viewport.get_path())
	_api_paths.append(viewport.get_path())
	api.multiplayer_peer = peer
	var level := _scene.instantiate() as Level
	viewport.add_child(level)
	return level
