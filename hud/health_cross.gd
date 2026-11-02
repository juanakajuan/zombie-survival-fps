@tool
class_name HealthCross
extends Control
## A plus-shaped cross on a rounded square, as a health icon. It fills its rect. While `low` is set, the cross is in `low_color` and pulses.

@export var low: bool = false:
	set(v):
		low = v
		queue_redraw()
@export var backing_color: Color = Color(0.15, 0.135, 0.125, 0.85):
	set(v):
		backing_color = v
		queue_redraw()
@export var cross_color: Color = Color(0.92, 0.886, 0.792):
	set(v):
		cross_color = v
		queue_redraw()
@export var low_color: Color = Color(0.722, 0.22, 0.231):
	set(v):
		low_color = v
		queue_redraw()
## The thickness of each arm, as a part of the width.
@export_range(0.1, 0.9, 0.01) var arm_width: float = 0.38:
	set(v):
		arm_width = v
		queue_redraw()
## The space between the ends of the arms and the edge, as a part of the width.
@export_range(0.0, 0.4, 0.01) var inset: float = 0.11:
	set(v):
		inset = v
		queue_redraw()
@export_range(0.0, 64.0, 1.0, "suffix:px") var corner_radius: float = 12.0:
	set(v):
		corner_radius = v
		queue_redraw()
@export_range(0.0, 32.0, 1.0, "suffix:px") var arm_radius: float = 5.0:
	set(v):
		arm_radius = v
		queue_redraw()
## How many times each second the low cross gets bright.
@export_range(0.1, 10.0, 0.1) var pulse_rate: float = 1.5
## How much the low cross gets brighter at the top of a pulse, from 0 (no pulse) to 1 (white).
@export_range(0.0, 1.0, 0.05) var pulse_amount: float = 0.35

var _time: float = 0.0


func _process(delta: float) -> void:
	if not low:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = backing_color
	backing.set_corner_radius_all(roundi(corner_radius))
	draw_style_box(backing, Rect2(Vector2.ZERO, size))
	var arm := StyleBoxFlat.new()
	arm.bg_color = _cross_color_now()
	arm.set_corner_radius_all(roundi(arm_radius))
	var thickness := size * arm_width
	var length := size * (1.0 - inset * 2.0)
	var center := size / 2.0
	draw_style_box(arm, Rect2(center - Vector2(thickness.x, length.y) / 2.0, Vector2(thickness.x, length.y)))
	draw_style_box(arm, Rect2(center - Vector2(length.x, thickness.y) / 2.0, Vector2(length.x, thickness.y)))


func _cross_color_now() -> Color:
	if not low:
		return cross_color
	var brightness := (sin(_time * pulse_rate * TAU) * 0.5 + 0.5) * pulse_amount
	return low_color.lerp(Color.WHITE, brightness)
