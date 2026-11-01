class_name PointPopup
extends Label
## A "+10" or "-500" that drifts away from the points and fades. It frees itself at the end.


## Moves by `drift` and fades over `time` seconds. A fresh popup starts at full opacity, and it holds that for the first third of the time.
func play(drift: Vector2, time: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + drift, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, time * 0.66).set_delay(time * 0.34)
	tween.chain().tween_callback(queue_free)
