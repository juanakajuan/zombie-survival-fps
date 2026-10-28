class_name ThrownGun
extends RigidBody3D
## A gun the player threw away. It tumbles as debris, then shrinks away after its lifetime.

@export_range(0.5, 120.0, 0.5, "suffix:s") var lifetime: float = 10.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var shrink_time: float = 0.4


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(lifetime)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, shrink_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
