@tool
class_name GrenadeIcons
extends Control
## One small cartoon grenade for each grenade the player holds.

@export_range(0, 12) var count: int = 2:
	set(v):
		count = v
		update_minimum_size()
		queue_redraw()
@export_range(8.0, 80.0, 1.0, "suffix:px") var icon_size: float = 48.0:
	set(v):
		icon_size = v
		update_minimum_size()
		queue_redraw()
@export_range(0.0, 20.0, 0.5, "suffix:px") var gap: float = 4.0:
	set(v):
		gap = v
		update_minimum_size()
		queue_redraw()
@export var body_color: Color = Color(0.4, 0.72, 0.2):
	set(v):
		body_color = v
		queue_redraw()
@export var band_color: Color = Color(0.22, 0.5, 0.14):
	set(v):
		band_color = v
		queue_redraw()
@export var lever_color: Color = Color(0.95, 0.85, 0.3):
	set(v):
		lever_color = v
		queue_redraw()
@export var cap_color: Color = Color(0.62, 0.64, 0.7):
	set(v):
		cap_color = v
		queue_redraw()
@export var outline_color: Color = Color(0.06, 0.04, 0.05):
	set(v):
		outline_color = v
		queue_redraw()
@export_range(0.0, 8.0, 0.5, "suffix:px") var outline_width: float = 2.5:
	set(v):
		outline_width = v
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(count * (icon_size + gap) - gap if count > 0 else 0.0, icon_size)


func _draw() -> void:
	for i in count:
		_draw_grenade(Vector2(i * (icon_size + gap), 0.0))


func _draw_grenade(origin: Vector2) -> void:
	var s := icon_size
	var center := origin + Vector2(s * 0.46, s * 0.62)
	var radius := s * 0.33
	Ink.circle(self, center, radius, body_color, outline_color, outline_width)
	draw_arc(center, radius * 0.7, deg_to_rad(200.0), deg_to_rad(340.0), 12, band_color, s * 0.07)
	draw_line(center + Vector2(-radius * 0.9, radius * 0.1), center + Vector2(radius * 0.9, radius * 0.1), band_color, s * 0.07)
	draw_circle(center + Vector2(-radius * 0.4, -radius * 0.3), radius * 0.2, Color(1, 1, 1, 0.45))
	var cap := PackedVector2Array([
		origin + Vector2(s * 0.34, s * 0.12),
		origin + Vector2(s * 0.58, s * 0.12),
		origin + Vector2(s * 0.56, s * 0.34),
		origin + Vector2(s * 0.36, s * 0.34),
	])
	Ink.polygon(self, cap, cap_color, outline_color, outline_width)
	var lever := PackedVector2Array([
		origin + Vector2(s * 0.56, s * 0.12),
		origin + Vector2(s * 0.92, s * 0.2),
		origin + Vector2(s * 0.9, s * 0.62),
		origin + Vector2(s * 0.8, s * 0.62),
		origin + Vector2(s * 0.8, s * 0.32),
		origin + Vector2(s * 0.56, s * 0.26),
	])
	Ink.polygon(self, lever, lever_color, outline_color, outline_width)
