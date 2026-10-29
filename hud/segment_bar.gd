@tool
class_name SegmentBar
extends Control
## A bar cut into slanted segments. Each segment holds segment_value. The last segment fills in part.

@export var max_value: float = 100.0:
	set(v):
		max_value = v
		queue_redraw()
@export var value: float = 100.0:
	set(v):
		value = v
		queue_redraw()
@export_range(1.0, 1000.0, 1.0) var segment_value: float = 25.0:
	set(v):
		segment_value = v
		queue_redraw()
@export_range(0.0, 20.0, 0.5, "suffix:px") var gap: float = 4.0:
	set(v):
		gap = v
		queue_redraw()
## How far the top edge of each segment moves right of the bottom edge.
@export_range(0.0, 20.0, 0.5, "suffix:px") var slant: float = 5.0:
	set(v):
		slant = v
		queue_redraw()
@export var fill_color: Color = Color(1, 1, 1, 0.95):
	set(v):
		fill_color = v
		queue_redraw()
@export var empty_color: Color = Color(0, 0, 0, 0.45):
	set(v):
		empty_color = v
		queue_redraw()


func _draw() -> void:
	var count := maxi(ceili(max_value / segment_value), 1)
	var width := (size.x - slant - gap * (count - 1)) / count
	for i in count:
		var x := i * (width + gap)
		var fraction := clampf((value - i * segment_value) / segment_value, 0.0, 1.0)
		_draw_segment(x, width, empty_color)
		if fraction > 0.0:
			_draw_segment(x, width * fraction, fill_color)


func _draw_segment(x: float, width: float, color: Color) -> void:
	var points := PackedVector2Array([
		Vector2(x + slant, 0.0),
		Vector2(x + width + slant, 0.0),
		Vector2(x + width, size.y),
		Vector2(x, size.y),
	])
	draw_colored_polygon(points, color)
