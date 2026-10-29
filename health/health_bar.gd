class_name HealthBar
extends MeshInstance3D
## A bar over a thing that can be hurt, filled by the Health of its parent. It shows after the first hit and hides at 0 health
## and at full health, so a crowd of unhurt zombies has no bars.

var _fill: float = 1.0


func _ready() -> void:
	visible = false
	var health := Health.find_on(get_parent())
	health.changed.connect(_on_changed.bind(health))


## The part of the bar that is full, from 0 to 1.
func fill() -> float:
	return _fill


func _on_changed(current: float, health: Health) -> void:
	_fill = current / health.max_health
	set_instance_shader_parameter("fill", _fill)
	visible = current > 0.0 and current < health.max_health
