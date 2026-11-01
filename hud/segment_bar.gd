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
@export var outline_color: Color = Color(0.06, 0.04, 0.05):
	set(v):
		outline_color = v
		queue_redraw()
## The ink line round each segment. It sits inside the rect of the control.
@export_range(0.0, 10.0, 0.5, "suffix:px") var outline_width: float = 0.0:
	set(v):
		outline_width = v
		queue_redraw()


func _draw() -> void:
	var count := maxi(ceili(max_value / segment_value), 1)
	var width := (size.x - slant - gap * (count - 1) - outline_width * 2.0) / count
	for i in count:
		var x := outline_width + i * (width + gap)
		var fraction := clampf((value - i * segment_value) / segment_value, 0.0, 1.0)
		Ink.polygon(self, _segment_points(x, width), empty_color, outline_color, outline_width)
		if fraction > 0.0:
			draw_colored_polygon(_segment_points(x, width * fraction), fill_color)


func _segment_points(x: float, width: float) -> PackedVector2Array:
	var top := outline_width
	var bottom := size.y - outline_width
	return PackedVector2Array([
		Vector2(x + slant, top),
		Vector2(x + width + slant, top),
		Vector2(x + width, bottom),
		Vector2(x, bottom),
	])
