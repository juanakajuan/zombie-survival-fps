class_name SpinViewModel
extends ViewModel
## A view model whose reload spins the gun once around the trigger finger. Halfway round, the empty magazine flies
## out as debris, and a new one slides into the well before the spin ends. Then the hand pulls the slide.

## The magazine, a child of the model with its origin at the top of the magazine well.
@export var magazine: Node3D
## The point in the model that the gun spins around, where the trigger finger is.
@export var spin_pivot: Vector3 = Vector3(0.0, 0.02, -0.044)
## The empty magazine that flies out. With none, it only goes out of view.
@export var thrown_magazine_scene: PackedScene
## The speed of the empty magazine out of the well, in m/s. The player's own velocity is added.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var magazine_eject_speed: float = 2.5
## Where the new magazine starts, relative to its rest place in the model, before it slides into the well.
@export var magazine_insert_offset: Vector3 = Vector3(0.0, -0.14, 0.0)

@export_group("Spin reload")
## Each phase lasts this fraction of the weapon's reload time. When the sum is above 1, every phase shrinks by
## the same factor.
@export_range(0.0, 1.0, 0.01) var spin_wind_up_fraction: float = 0.12
@export_range(0.0, 1.0, 0.01) var spin_fraction: float = 0.5
## Of the spin, the share after which the empty magazine flies out, and the share after which the new one starts
## to slide in.
@export_range(0.0, 1.0, 0.01) var eject_at: float = 0.45
@export_range(0.0, 1.0, 0.01) var insert_at: float = 0.6
@export_range(0.0, 1.0, 0.01) var spin_pause_fraction: float = 0.08

var _magazine_rest: Transform3D
var _ejected := false


func _ready() -> void:
	_magazine_rest = magazine.transform
	super()


func draw() -> void:
	_seat_magazine()
	super()


func _on_reload_started(weapon: Weapon) -> void:
	if _lowered:
		return
	_restart_tween()
	var phases := spin_wind_up_fraction + spin_fraction + spin_pause_fraction + slide_pull_fraction + slide_release_fraction
	var time := weapon.data.reload_time / maxf(phases, 1.0)
	_ejected = false
	slide.position = _slide_rest
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(model, "transform", _model_rest.translated_local(wind_up_offset), time * spin_wind_up_fraction)
	_tween.tween_callback(_freeze_hand.bind(true))
	_tween.tween_method(_spin_step, 0.0, 1.0, time * spin_fraction).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_freeze_hand.bind(false))
	_tween.tween_property(model, "transform", _model_rest, time * spin_pause_fraction).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(slide, "position", _slide_rest + Vector3(0.0, 0.0, slide_travel), time * slide_pull_fraction)
	_tween.tween_property(slide, "position", _slide_rest, time * slide_release_fraction).set_trans(Tween.TRANS_BACK)


func _spin_step(progress: float) -> void:
	var start := _model_rest.translated_local(wind_up_offset)
	model.transform = start.translated_local(spin_pivot).rotated_local(Vector3.RIGHT, TAU * progress).translated_local(-spin_pivot)
	if progress >= eject_at and not _ejected:
		_eject_magazine()
	if progress >= insert_at:
		var slide_in := ease(inverse_lerp(insert_at, 1.0, progress), 0.4)
		magazine.transform = _magazine_rest.translated_local(magazine_insert_offset * (1.0 - slide_in))
		magazine.show()


func _eject_magazine() -> void:
	_ejected = true
	magazine.hide()
	if thrown_magazine_scene == null or _player == null:
		return
	var thrown := thrown_magazine_scene.instantiate() as RigidBody3D
	var copy := magazine.duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	copy.show()
	thrown.add_child(copy)
	_player.get_parent().add_child(thrown)
	thrown.global_transform = magazine.global_transform
	thrown.add_collision_exception_with(_player)
	thrown.linear_velocity = _player.velocity - magazine.global_basis.y * magazine_eject_speed


## While the gun spins, the hand stays where it was, so the gun turns in the fingers.
func _freeze_hand(frozen: bool) -> void:
	if hand_anchor != null:
		hand_anchor.update_position = not frozen
		hand_anchor.update_rotation = not frozen


func _settle() -> void:
	if not _lowered:
		_seat_magazine()
	super()


func _seat_magazine() -> void:
	magazine.transform = _magazine_rest
	magazine.show()
	_freeze_hand(false)
