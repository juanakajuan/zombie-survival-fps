class_name LoopbackPeer
extends MultiplayerPeerExtension

class Packet:
	var data: PackedByteArray
	var from: int
	var channel: int
	var mode: MultiplayerPeer.TransferMode

var bytes_sent: int = 0

var _id: int
var _remote_id: int = 0
var _inbox: Array[Packet] = []
var _outbox: Array[Packet] = []
var _target: int = 0
var _channel: int = 0
var _mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _status: MultiplayerPeer.ConnectionStatus = MultiplayerPeer.CONNECTION_CONNECTING
var _announced := false


func _init(id: int) -> void:
	_id = id


static func link(host: LoopbackPeer, client: LoopbackPeer) -> void:
	host._remote_id = client._id
	client._remote_id = host._id
	host._outbox = client._inbox
	client._outbox = host._inbox


func _poll() -> void:
	if not _announced and _status == MultiplayerPeer.CONNECTION_CONNECTING and _remote_id != 0:
		_announced = true
		_status = MultiplayerPeer.CONNECTION_CONNECTED
		peer_connected.emit(_remote_id)


func _get_available_packet_count() -> int:
	return _inbox.size()


func _get_packet_peer() -> int:
	return _inbox[0].from


func _get_packet_channel() -> int:
	return _inbox[0].channel


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return _inbox[0].mode


func _get_packet_script() -> PackedByteArray:
	return _inbox.pop_front().data


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_CONNECTION_ERROR
	bytes_sent += buffer.size()
	var reaches_remote := _target == 0 or _target == _remote_id or (_target < 0 and -_target != _remote_id)
	if reaches_remote:
		var packet := Packet.new()
		packet.data = buffer
		packet.from = _id
		packet.channel = _channel
		packet.mode = _mode
		_outbox.append(packet)
	return OK


func _get_max_packet_size() -> int:
	return 1 << 24


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _id == 1


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _close() -> void:
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _disconnect_peer(_peer: int, _force: bool) -> void:
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(_enable: bool) -> void:
	pass


func _is_refusing_new_connections() -> bool:
	return false
