class_name Ink
extends RefCounted
## Cartoon outline helpers for the HUD controls that draw themselves.


## Draws `points` (a convex polygon) in `fill`, on top of the same shape grown by `outline_width` in `outline_color`. Call it from `_draw()` of `canvas`.
static func polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, outline_color: Color, outline_width: float) -> void:
	if outline_width > 0.0:
		var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(points, outline_width, Geometry2D.JOIN_ROUND)
		for ring: PackedVector2Array in grown:
			canvas.draw_colored_polygon(ring, outline_color)
	canvas.draw_colored_polygon(points, fill)


## Draws a circle in `fill`, on top of a larger circle in `outline_color`.
static func circle(canvas: CanvasItem, center: Vector2, radius: float, fill: Color, outline_color: Color, outline_width: float) -> void:
	if outline_width > 0.0:
		canvas.draw_circle(center, radius + outline_width, outline_color)
	canvas.draw_circle(center, radius, fill)
