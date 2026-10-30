class_name MagazineViewModel
extends ViewModel
## A view model whose reload keeps the gun in the hand and swaps only the magazine. The gun tilts, the empty
## magazine drops out as debris, the left hand pushes a new one up into the well, and the right hand pulls the slide.

## The magazine, a child of the model with its origin at the top of the magazine well.
@export var magazine: Node3D
## The left hand, a child of the model. It shows only while it brings the new magazine.
@export var left_hand: Node3D
## The empty magazine that drops out. With none, it only goes out of view.
@export var dropped_magazine_scene: PackedScene
## The speed of the empty magazine out of the well, in m/s. The player's own velocity is added.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var magazine_drop_speed: float = 1.0
## Where the new magazine starts, relative to its rest place in the model, before the left hand pushes it in.
@export var magazine_insert_offset: Vector3 = Vector3(0.0, -0.25, 0.05)

@export_group("Magazine reload")
## The gun tilts by these angles in degrees (pitch, yaw, roll) so the well faces the left hand.
@export var tilt_angles: Vector3 = Vector3(12.0, 0.0, -40.0)
@export var tilt_offset: Vector3 = Vector3(-0.05, 0.05, 0.02)
## The left hand holds the magazine at this place, relative to the magazine.
@export var left_hand_offset: Vector3 = Vector3(0.0, -0.11, 0.0)
## The left hand's angles in degrees (pitch, yaw, roll) relative to the view, not the tilted gun, so the forearm
## stays on its way to the shoulder.
@export var left_hand_angles: Vector3 = Vector3(50.0, 0.0, 0.0)
## After the slap, the left hand drops this far, relative to the model, and goes out of view.
@export var left_hand_exit_offset: Vector3 = Vector3(0.0, -0.3, 0.0)
## The slap pushes the gun up this far, and it comes back.
@export_range(0.0, 0.1, 0.005, "suffix:m") var slap_bump: float = 0.02
## Each phase lasts this fraction of the weapon's reload time. When the sum is above 1, every phase shrinks by
## the same factor.
@export_range(0.0, 1.0, 0.01) var tilt_fraction: float = 0.12
@export_range(0.0, 1.0, 0.01) var empty_well_fraction: float = 0.15
@export_range(0.0, 1.0, 0.01) var insert_fraction: float = 0.25
@export_range(0.0, 1.0, 0.01) var slap_fraction: float = 0.08
@export_range(0.0, 1.0, 0.01) var untilt_fraction: float = 0.15

var _magazine_rest: Transform3D
var _tilted: Transform3D


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
	var phases := tilt_fraction + empty_well_fraction + insert_fraction + slap_fraction + untilt_fraction \
		+ slide_pull_fraction + slide_release_fraction
	var time := weapon.data.reload_time / maxf(phases, 1.0)
	var tilt := tilt_angles * (PI / 180.0)
	_tilted = _model_rest.translated_local(tilt_offset) * Transform3D(Basis.from_euler(tilt), Vector3.ZERO)
	slide.position = _slide_rest
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(model, "transform", _tilted, time * tilt_fraction)
	_tween.tween_callback(_drop_magazine)
	_tween.tween_interval(time * empty_well_fraction)
	_tween.tween_method(_insert_step, 0.0, 1.0, time * insert_fraction)
	_tween.tween_property(model, "transform", _tilted.translated_local(Vector3.UP * slap_bump), time * slap_fraction * 0.4)
	_tween.tween_property(model, "transform", _tilted, time * slap_fraction * 0.6)
	_tween.tween_property(model, "transform", _model_rest, time * untilt_fraction).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(left_hand, "position", _left_hand_grip().origin + left_hand_exit_offset, time * untilt_fraction)
	_tween.tween_callback(left_hand.hide)
	_tween.tween_property(slide, "position", _slide_rest + Vector3(0.0, 0.0, slide_travel), time * slide_pull_fraction)
	_tween.tween_property(slide, "position", _slide_rest, time * slide_release_fraction).set_trans(Tween.TRANS_BACK)


func _drop_magazine() -> void:
	magazine.hide()
	if dropped_magazine_scene == null or _player == null:
		return
	var dropped := dropped_magazine_scene.instantiate() as RigidBody3D
	var copy := magazine.duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	copy.show()
	dropped.add_child(copy)
	_player.get_parent().add_child(dropped)
	dropped.global_transform = magazine.global_transform
	dropped.add_collision_exception_with(_player)
	dropped.linear_velocity = _player.velocity - magazine.global_basis.y * magazine_drop_speed


func _insert_step(progress: float) -> void:
	magazine.transform = _magazine_rest.translated_local(magazine_insert_offset * (1.0 - progress))
	magazine.show()
	left_hand.transform = _left_hand_grip()
	left_hand.show()


## The left hand's transform in the model while it holds the magazine where the magazine is now.
func _left_hand_grip() -> Transform3D:
	var angles := left_hand_angles * (PI / 180.0)
	var grip := magazine.transform.translated_local(left_hand_offset).origin
	return Transform3D(model.transform.basis.inverse() * Basis.from_euler(angles), grip)


func _settle() -> void:
	if not _lowered:
		_seat_magazine()
	super()


func _seat_magazine() -> void:
	magazine.transform = _magazine_rest
	magazine.show()
	left_hand.hide()
