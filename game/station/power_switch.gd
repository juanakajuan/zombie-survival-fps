class_name PowerSwitch
extends Station
## A lever on a wall that turns on the power one time. Its origin is on the wall face, and its +Z axis points out of the wall.

signal switched_on

const PANEL_SIZE: Vector3 = Vector3(0.9, 1.4, 0.2)
const AREA_DEPTH: float = 0.7
const OFF_COLOR: Color = Color(0.9, 0.2, 0.15)
const ON_COLOR: Color = Color(0.3, 1.0, 0.45)

var is_on: bool = false

var _lamp_material: StandardMaterial3D
var _glow: OmniLight3D


func _ready() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(PANEL_SIZE.x, PANEL_SIZE.y, AREA_DEPTH)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.0, AREA_DEPTH * 0.5)
	add_child(collision)
	var panel_mesh: BoxMesh = BoxMesh.new()
	panel_mesh.size = PANEL_SIZE
	var panel_material: StandardMaterial3D = StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.07, 0.07, 0.08)
	panel_material.metallic = 0.5
	panel_material.roughness = 0.6
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.mesh = panel_mesh
	panel.material_override = panel_material
	panel.position = Vector3(0.0, 0.0, PANEL_SIZE.z * 0.5)
	add_child(panel)
	var lamp_mesh: BoxMesh = BoxMesh.new()
	lamp_mesh.size = Vector3(0.5, 0.25, 0.02)
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lamp: MeshInstance3D = MeshInstance3D.new()
	lamp.mesh = lamp_mesh
	lamp.material_override = _lamp_material
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.position = Vector3(0.0, 0.3, PANEL_SIZE.z + 0.011)
	add_child(lamp)
	_glow = OmniLight3D.new()
	_glow.light_energy = 1.2
	_glow.omni_range = 4.0
	_glow.position = Vector3(0.0, 0.3, PANEL_SIZE.z + 0.6)
	add_child(_glow)
	_show_state()


func offer(_loadout: Loadout, _perks: Perks) -> Station.Offer:
	if is_on:
		return Station.Offer.new(Station.Offer.Kind.NONE, 0, "Power is on")
	return Station.Offer.new(Station.Offer.Kind.POWER, 0, "Turn on power")


func accept(chosen: Station.Offer, _weapon: Weapon, _perks: Perks) -> void:
	if chosen.kind != Station.Offer.Kind.POWER or is_on:
		return
	is_on = true
	_show_state()
	switched_on.emit()


func _show_state() -> void:
	var color: Color = ON_COLOR if is_on else OFF_COLOR
	_lamp_material.albedo_color = color
	_glow.light_color = color
