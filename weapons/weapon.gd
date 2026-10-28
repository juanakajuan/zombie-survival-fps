class_name Weapon
extends Node3D
## Hitscan weapon. It shoots along its own -Z axis and ignores the body it is mounted on.

signal fired
signal reload_started
signal reload_finished
signal hit(collider: Object, position: Vector3)

enum State { READY, RELOADING }

@export var data: WeaponData
## Physics layers that a shot can hit. Debris, such as thrown guns, is not on them.
@export_flags_3d_physics var hit_mask: int = 1

var ammo: int
## When false, the fire and reload actions do nothing. The owner turns it off while the mouse is released.
var trigger_enabled: bool = true
## The instance of data.view_model, or null when the data has none or its root is not a ViewModel.
var view_model: ViewModel
## The player who holds the weapon. Shots never hit the wielder. Player sets it.
var wielder: Player

var _state: State = State.READY
## Seconds until the next shot while READY, or until the reload ends while RELOADING.
var _cooldown: float = 0.0


func _ready() -> void:
	ammo = data.magazine_size
	if data.view_model != null:
		var model := data.view_model.instantiate()
		add_child(model)
		view_model = model as ViewModel


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _state == State.RELOADING and _cooldown == 0.0:
		_state = State.READY
		ammo = data.magazine_size
		reload_finished.emit()

	if not trigger_enabled:
		return
	var fire_pressed := Input.is_action_pressed("fire") if data.automatic else Input.is_action_just_pressed("fire")
	if fire_pressed:
		try_fire()
	if Input.is_action_just_pressed("reload"):
		start_reload()


## Fires one shot. Returns false when the weapon is cooling down, reloading, or empty.
## Firing with an empty magazine starts a reload.
func try_fire() -> bool:
	if _state != State.READY:
		return false
	if ammo == 0:
		start_reload()
		return false
	if _cooldown > 0.0:
		return false
	ammo -= 1
	_cooldown = data.fire_interval
	fired.emit()
	_shoot()
	return true


func start_reload() -> void:
	if _state == State.RELOADING or ammo == data.magazine_size:
		return
	_state = State.RELOADING
	_cooldown = data.reload_time
	reload_started.emit()


func is_reloading() -> bool:
	return _state == State.RELOADING


func _shoot() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position - global_basis.z * data.max_range)
	if wielder != null:
		query.exclude = [wielder.get_rid()]
	query.collision_mask = hit_mask
	query.hit_from_inside = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result["collider"]
	var point: Vector3 = result["position"]
	hit.emit(collider, point)
	if collider is Node:
		var health := Health.find_on(collider as Node)
		if health != null:
			health.damage(data.damage)
