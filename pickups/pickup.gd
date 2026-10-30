class_name Pickup
extends Area3D
## An item on the ground. A player who walks over it gets the item for free, unless it would do nothing. Then it stays.

## The item that the pickup gives.
@export var item: BuyItem
## The seconds until the pickup disappears. 0 means it never does.
@export_range(0.0, 120.0, 1.0, "suffix:s") var lifetime: float = 0.0
@export_group("Look")
@export_range(0.0, 10.0, 0.1, "suffix:rad/s") var spin_speed: float = 2.0
@export_range(0.0, 1.0, 0.01, "suffix:m") var bob_height: float = 0.12
@export_range(0.0, 10.0, 0.1, "suffix:rad/s") var bob_speed: float = 3.0

var _age: float = 0.0
var _rest_height: float

@onready var _visual: Node3D = $Visual
@onready var _label: Label3D = $Label


func _ready() -> void:
	_label.text = item.display_name
	_rest_height = _visual.position.y


func _process(delta: float) -> void:
	_visual.rotate_y(spin_speed * delta)
	_visual.position.y = _rest_height + sin(_age * bob_speed) * bob_height


func _physics_process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()
		return
	for body: Node3D in get_overlapping_bodies():
		var player := body as Player
		if player != null and item.can_apply(player):
			item.apply(player)
			queue_free()
			return


## The text of the label over the pickup.
func label_text() -> String:
	return _label.text
