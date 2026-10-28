class_name HitFlash
extends Node
## Tints a material while its sibling Health is hurt. Add it as a child of the thing that can be hurt, and set `material`.
## Each hit ends its own flash `flash_seconds` after the hit.

@export var flash_color: Color = Color(1.0, 0.15, 0.1)
@export_range(0.01, 2.0, 0.01, "suffix:s") var flash_seconds: float = 0.1

var material: StandardMaterial3D

var _base_color: Color


func _ready() -> void:
	Health.find_on(get_parent()).damaged.connect(_on_damaged)


func _on_damaged(_amount: float) -> void:
	if material.albedo_color != flash_color:
		_base_color = material.albedo_color
	material.albedo_color = flash_color
	get_tree().create_timer(flash_seconds).timeout.connect(_end_flash)


func _end_flash() -> void:
	material.albedo_color = _base_color
