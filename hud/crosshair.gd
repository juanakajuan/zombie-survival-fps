@tool
class_name Crosshair
extends Control
## A center dot and four ticks. The ticks open on each shot and close again. A hit shows an X marker.

@export var color: Color = Color(1, 1, 1, 0.9)
@export var hit_color: Color = Color(1, 0.9, 0.0, 1)
@export_range(0.0, 40.0, 0.5, "suffix:px") var gap: float = 8.0
@export_range(0.0, 40.0, 0.5, "suffix:px") var tick_length: float = 7.0
@export_range(0.5, 6.0, 0.5, "suffix:px") var thickness: float = 2.0
@export_range(0.0, 40.0, 0.5, "suffix:px") var kick: float = 7.0
## Each second, the ticks close this many times the kick.
@export_range(0.1, 40.0, 0.1) var recover_speed: float = 10.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var hit_marker_time: float = 0.2

var _spread: float = 0.0
var _hit_left: float = 0.0


func shot() -> void:
	_spread = kick
	queue_redraw()


func hit() -> void:
	_hit_left = hit_marker_time
	queue_redraw()


func hit_marker_visible() -> bool:
	return _hit_left > 0.0


func _process(delta: float) -> void:
	if _spread <= 0.0 and _hit_left <= 0.0:
		return
	_spread = maxf(_spread - kick * recover_speed * delta, 0.0)
	_hit_left = maxf(_hit_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var g := gap + _spread
	draw_rect(Rect2(c - Vector2(thickness, thickness) / 2.0, Vector2(thickness, thickness)), color)
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + dir * g, c + dir * (g + tick_length), color, thickness)
	if _hit_left > 0.0:
		var marker := hit_color
		marker.a *= _hit_left / hit_marker_time
		for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var n := dir.normalized()
			draw_line(c + n * gap, c + n * (gap + tick_length), marker, thickness)
