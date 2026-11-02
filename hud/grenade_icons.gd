@tool
class_name GrenadeIcons
extends Control
## One small flat grenade for each grenade the player holds.

@export_range(0, 12) var count: int = 2:
	set(v):
		count = v
		update_minimum_size()
		queue_redraw()
@export_range(8.0, 80.0, 1.0, "suffix:px") var icon_size: float = 36.0:
	set(v):
		icon_size = v
		update_minimum_size()
		queue_redraw()
@export_range(0.0, 20.0, 0.5, "suffix:px") var gap: float = 4.0:
	set(v):
		gap = v
		update_minimum_size()
		queue_redraw()
@export var body_color: Color = Color(0.92, 0.886, 0.792):
	set(v):
		body_color = v
		queue_redraw()
@export var band_color: Color = Color(0.459, 0.42, 0.369):
	set(v):
		band_color = v
		queue_redraw()
@export var lever_color: Color = Color(0.92, 0.886, 0.792):
	set(v):
		lever_color = v
		queue_redraw()
@export var cap_color: Color = Color(0.459, 0.42, 0.369):
	set(v):
		cap_color = v
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
	draw_circle(center, radius, body_color)
	draw_arc(center, radius * 0.7, deg_to_rad(200.0), deg_to_rad(340.0), 12, band_color, s * 0.07)
	draw_line(center + Vector2(-radius * 0.9, radius * 0.1), center + Vector2(radius * 0.9, radius * 0.1), band_color, s * 0.07)
	var cap := PackedVector2Array([
		origin + Vector2(s * 0.34, s * 0.12),
		origin + Vector2(s * 0.58, s * 0.12),
		origin + Vector2(s * 0.56, s * 0.34),
		origin + Vector2(s * 0.36, s * 0.34),
	])
	draw_colored_polygon(cap, cap_color)
	var lever := PackedVector2Array([
		origin + Vector2(s * 0.56, s * 0.12),
		origin + Vector2(s * 0.92, s * 0.2),
		origin + Vector2(s * 0.9, s * 0.62),
		origin + Vector2(s * 0.8, s * 0.62),
		origin + Vector2(s * 0.8, s * 0.32),
		origin + Vector2(s * 0.56, s * 0.26),
	])
	draw_colored_polygon(lever, lever_color)
