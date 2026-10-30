class_name Door
extends Node3D
## A panel that closes a gap in a wall. The player buys it at its station, and it stays open. An open door has no
## collider, so the level can bake its navigation mesh again and zombies walk through the gap.

signal opened

const GROUP := &"door"

## The panel size. The origin is at the bottom center of the panel.
@export var size: Vector3 = Vector3(3.0, 3.0, 0.3)
## The height of the price label over the floor, because a tall panel has its top out of sight.
@export_range(0.5, 4.0, 0.05, "suffix:m") var label_height: float = 1.65

@onready var station: BuyStation = $Station

var _open := false


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	var panel: MeshInstance3D = station.get_node("MeshInstance3D")
	panel.mesh = mesh
	panel.position = Vector3(0.0, size.y / 2.0, 0.0)
	var collider: CollisionShape3D = station.get_node("CollisionShape3D")
	collider.shape = shape
	collider.position = panel.position
	var label: Label3D = station.get_node("Label")
	label.position = Vector3(0.0, label_height, size.z)
	station.purchased.connect(open)


func is_open() -> bool:
	return _open


## Opens the door for good. A second call does nothing.
func open() -> void:
	if _open:
		return
	_open = true
	station.collision_layer = 0
	station.hide()
	opened.emit()
