class_name TargetDummy
extends StaticBody3D

@export var base_color: Color = Color(0.85, 0.8, 0.2)
@export_range(0.1, 30.0, 0.1, "suffix:s") var respawn_delay: float = 2.0

var _material := StandardMaterial3D.new()

@onready var _health: Health = $Health
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _hit_flash: HitFlash = $HitFlash


func _ready() -> void:
	_material.albedo_color = base_color
	_mesh.material_override = _material
	_hit_flash.material = _material
	_health.died.connect(_on_died)


func _on_died() -> void:
	_set_active(false)
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	_health.reset()
	_material.albedo_color = base_color
	_set_active(true)


func _set_active(active: bool) -> void:
	visible = active
	_shape.disabled = not active
