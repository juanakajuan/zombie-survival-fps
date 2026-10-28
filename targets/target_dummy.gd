class_name TargetDummy
extends StaticBody3D
## Static shooting target. It flashes when hurt, vanishes when killed, and comes back later.

const FLASH_COLOR := Color(1.0, 0.15, 0.1)
const FLASH_SECONDS := 0.1

@export var base_color: Color = Color(0.85, 0.8, 0.2)
@export_range(0.1, 30.0, 0.1, "suffix:s") var respawn_delay: float = 2.0

var _material := StandardMaterial3D.new()

@onready var _health: Health = $Health
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_material.albedo_color = base_color
	_mesh.material_override = _material
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _on_damaged(_amount: float) -> void:
	_material.albedo_color = FLASH_COLOR
	get_tree().create_timer(FLASH_SECONDS).timeout.connect(_end_flash)


func _on_died() -> void:
	_set_active(false)
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _end_flash() -> void:
	_material.albedo_color = base_color


func _respawn() -> void:
	_health.reset()
	_material.albedo_color = base_color
	_set_active(true)


func _set_active(active: bool) -> void:
	visible = active
	_shape.disabled = not active
