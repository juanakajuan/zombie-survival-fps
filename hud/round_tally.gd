@tool
class_name RoundTally
extends Control
## Hand-painted tally marks for the first five rounds. Four slanted strokes make four rounds, and the fifth stroke crosses them. The strokes keep their slots, so the tally does not shift when it grows.

## How many marks show, from 0 to 5.
@export_range(0, 5) var count: int = 1:
	set(v):
		count = clampi(v, 0, 5)
		update_minimum_size()
		queue_redraw()
@export var color: Color = Color(0.75, 0.05, 0.05):
	set(v):
		color = v
		queue_redraw()
@export var outline_color: Color = Color(0.06, 0.04, 0.05):
	set(v):
		outline_color = v
		queue_redraw()
@export_range(0.0, 20.0, 0.5, "suffix:px") var outline_width: float = 5.0:
	set(v):
		outline_width = v
		queue_redraw()
@export_range(2.0, 60.0, 0.5, "suffix:px") var stroke_width: float = 16.0:
	set(v):
		stroke_width = v
		queue_redraw()
## The distance between the centers of two strokes.
@export_range(4.0, 120.0, 0.5, "suffix:px") var slot_width: float = 38.0:
	set(v):
		slot_width = v
		update_minimum_size()
		queue_redraw()
## How far the top of each stroke sits right of its bottom.
@export_range(0.0, 60.0, 0.5, "suffix:px") var slant: float = 14.0:
	set(v):
		slant = v
		update_minimum_size()
		queue_redraw()
## How much the brush wobbles: the width, the length and the place of each stroke.
@export_range(0.0, 1.0, 0.05) var wobble: float = 0.3:
	set(v):
		wobble = v
		queue_redraw()


func _get_minimum_size() -> Vector2:
	if count == 0:
		return Vector2.ZERO
	return Vector2(outline_width * 2.0 + stroke_width + slant + slot_width * (mini(count, 4) - 1), 0.0)


func _draw() -> void:
	for i in mini(count, 4):
		_draw_stroke(i)
	if count == 5:
		_draw_cross_stroke()


func _wobble_of(index: int, salt: float) -> float:
	return sin(index * 2.7 + salt) * wobble


func _stroke_area() -> Rect2:
	var pad := outline_width
	return Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)


func _draw_stroke(index: int) -> void:
	var area := _stroke_area()
	var top_x := area.position.x + stroke_width / 2.0 + slant + slot_width * index + _wobble_of(index, 0.4) * slot_width * 0.15
	var bottom_x := top_x - slant
	var top_y := area.position.y + _wobble_of(index, 1.9) * area.size.y * 0.06
	var bottom_y := area.end.y - maxf(_wobble_of(index, 3.1), 0.0) * area.size.y * 0.08
	var top_half := stroke_width * (0.5 - _wobble_of(index, 5.3) * 0.15)
	var bottom_half := stroke_width * (0.5 + _wobble_of(index, 6.7) * 0.15)
	var points := PackedVector2Array([
		Vector2(top_x - top_half, top_y),
		Vector2(top_x + top_half, top_y),
		Vector2(bottom_x + bottom_half, bottom_y),
		Vector2(bottom_x - bottom_half, bottom_y),
	])
	Ink.polygon(self, points, color, outline_color, outline_width)


func _draw_cross_stroke() -> void:
	var area := _stroke_area()
	var from := Vector2(area.position.x + stroke_width * 0.5, area.end.y - area.size.y * 0.18)
	var to := Vector2(area.end.x - stroke_width * 0.5, area.position.y + area.size.y * 0.16)
	var across := (to - from).normalized().orthogonal() * stroke_width * 0.5
	var points := PackedVector2Array([from - across, to - across * 0.8, to + across * 0.8, from + across])
	Ink.polygon(self, points, color, outline_color, outline_width)
