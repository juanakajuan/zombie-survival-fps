@tool
class_name BloodSplat
extends Control
## A blob of blood with a few drips, drawn the same each time. It fills its rect.

@export var color: Color = Color(0.55, 0.02, 0.04):
	set(v):
		color = v
		queue_redraw()
@export var highlight_color: Color = Color(0.8, 0.12, 0.1, 0.8):
	set(v):
		highlight_color = v
		queue_redraw()
@export var outline_color: Color = Color(0.06, 0.04, 0.05):
	set(v):
		outline_color = v
		queue_redraw()
@export_range(0.0, 20.0, 0.5, "suffix:px") var outline_width: float = 5.0:
	set(v):
		outline_width = v
		queue_redraw()
## The smaller circles along the width, round the big one.
@export_range(0, 16) var lobes: int = 6:
	set(v):
		lobes = v
		queue_redraw()
@export_range(0, 8) var drips: int = 3:
	set(v):
		drips = v
		queue_redraw()


func _draw() -> void:
	var blobs := _blobs()
	for blob: Vector3 in blobs:
		draw_circle(Vector2(blob.x, blob.y), blob.z + outline_width, outline_color)
	var tails := _drips()
	for tail: Vector4 in tails:
		draw_line(Vector2(tail.x, tail.y), Vector2(tail.x, tail.y + tail.z), outline_color, tail.w + outline_width * 2.0)
		draw_circle(Vector2(tail.x, tail.y + tail.z), tail.w / 2.0 + outline_width, outline_color)
	for blob: Vector3 in blobs:
		draw_circle(Vector2(blob.x, blob.y), blob.z, color)
	for tail: Vector4 in tails:
		draw_line(Vector2(tail.x, tail.y), Vector2(tail.x, tail.y + tail.z), color, tail.w)
		draw_circle(Vector2(tail.x, tail.y + tail.z), tail.w / 2.0, color)
	var big := blobs[0]
	draw_circle(Vector2(big.x - big.z * 0.35, big.y - big.z * 0.35), big.z * 0.22, highlight_color)


## Each blob is x, y and radius. The first one is the big circle in the middle. The others run along the width.
func _blobs() -> Array[Vector3]:
	var middle := size / 2.0
	var big := size.y * 0.4
	var blobs: Array[Vector3] = [Vector3(middle.x, middle.y - size.y * 0.04, big)]
	for i in lobes:
		var radius := size.y * (0.2 + 0.1 * absf(sin(i * 2.3 + 0.5)))
		var along := float(i) / maxi(lobes - 1, 1)
		blobs.append(Vector3(
			lerpf(size.x * 0.18, size.x * 0.82, along),
			middle.y - size.y * 0.04 + sin(i * 2.9 + 0.7) * size.y * 0.14,
			radius,
		))
	return blobs


## Each drip is the x and top y of the line, its length, and its width.
func _drips() -> Array[Vector4]:
	var tails: Array[Vector4] = []
	var base := size.y * 0.62
	for i in drips:
		var x := size.x * (0.3 + 0.4 * (i + 0.5) / maxi(drips, 1)) + sin(i * 3.1) * size.x * 0.04
		var width := size.y * (0.08 + 0.04 * absf(sin(i * 1.3 + 1.0)))
		tails.append(Vector4(x, base, size.y * (0.22 + 0.1 * absf(sin(i * 2.1))), width))
	return tails
