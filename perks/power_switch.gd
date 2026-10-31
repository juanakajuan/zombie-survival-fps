class_name PowerSwitch
extends Interactable
## The switch that turns on the power. The player turns it on once with the interact action, and it stays on. A
## BuyStation that names it sells only while it is on.

signal turned_on

@export var off_color: Color = Color(0.8, 0.1, 0.1, 1)
@export var on_color: Color = Color(0.2, 1.0, 0.3, 1)
## The lever turns by this angle about its pivot when the power goes on.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var lever_on_angle: float = 180.0

@onready var _lever: Node3D = $Lever
@onready var _lamp: MeshInstance3D = $Lamp

var _on := false


func _ready() -> void:
	_show()


func is_on() -> bool:
	return _on


## Turns the power on for good. A second call does nothing.
func turn_on() -> void:
	if _on:
		return
	_on = true
	_show()
	turned_on.emit()


func prompt_text(_player: Player) -> String:
	return "" if _on else "E  TURN ON POWER"


func press(_player: Player) -> void:
	turn_on()


func _show() -> void:
	_lever.rotation.x = deg_to_rad(lever_on_angle) if _on else 0.0
	var material := StandardMaterial3D.new()
	material.albedo_color = on_color if _on else off_color
	material.emission_enabled = true
	material.emission = material.albedo_color
	_lamp.material_override = material
