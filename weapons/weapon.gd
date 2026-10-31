class_name Weapon
extends Node3D
## Hitscan weapon. It shoots along its wielder's aim, or along its own -Z axis when it has no wielder. It ignores its wielder. Each shot shows a tracer from the muzzle.

signal fired
signal reload_started
## Emitted when the trigger is pulled with no round in the magazine and none in the reserve.
signal dry_fired
signal reload_finished
signal hit(collider: Object, position: Vector3)
## Emitted when a shot damages a Health that is alive. `killed` is true when this shot took it to 0, and `headshot` is true when it hit a WeakSpot. A dead target takes no damage.
signal damaged(target: Node, killed: bool, headshot: bool)
## Emitted after `ammo` or `reserve` changes.
signal ammo_changed

enum State { READY, RELOADING }

@export var data: WeaponData
## Physics layers that a shot can hit. Debris, such as thrown guns, is not on them.
@export_flags_3d_physics var hit_mask: int = 1

@export_group("Sounds")
@export var shot_sound: AudioStreamPlayer
@export var dry_sound: AudioStreamPlayer
@export var reload_sound: AudioStreamPlayer

var ammo: int:
	set(value):
		ammo = value
		ammo_changed.emit()
## Rounds outside the magazine. A reload moves them into the magazine.
var reserve: int:
	set(value):
		reserve = value
		ammo_changed.emit()
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
	reserve = data.max_reserve
	if data.view_model != null:
		var model := data.view_model.instantiate()
		add_child(model)
		view_model = model as ViewModel


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _state == State.RELOADING and _cooldown == 0.0:
		_state = State.READY
		var taken := mini(data.magazine_size - ammo, reserve)
		reserve -= taken
		ammo += taken
		reload_finished.emit()

	if not trigger_enabled:
		return
	var fire_pressed := Input.is_action_pressed("fire") if data.automatic else Input.is_action_just_pressed("fire")
	if fire_pressed:
		try_fire()
	if Input.is_action_just_pressed("reload"):
		start_reload()


## Fires one shot. Returns false when the wielder sprints or punches, or the weapon is cooling down, reloading, or empty.
## Firing with an empty magazine starts a reload, or clicks dry when the reserve is empty too.
func try_fire() -> bool:
	if wielder != null and (wielder.is_sprinting() or wielder.is_meleeing()):
		return false
	if _state != State.READY:
		return false
	if ammo == 0:
		if reserve > 0:
			start_reload()
		elif _cooldown == 0.0:
			_cooldown = fire_interval()
			dry_fired.emit()
			dry_sound.play()
		return false
	if _cooldown > 0.0:
		return false
	ammo -= 1
	_cooldown = fire_interval()
	fired.emit()
	shot_sound.play()
	_shoot()
	return true


## Does nothing when the magazine is full or the reserve is empty, or while the wielder punches.
func start_reload() -> void:
	if wielder != null and wielder.is_meleeing():
		return
	if _state == State.RELOADING or ammo == data.magazine_size or reserve == 0:
		return
	_state = State.RELOADING
	_cooldown = reload_time()
	reload_started.emit()
	reload_sound.play()


## Stops a reload and gives back nothing: the magazine and the reserve stay as they were.
func cancel_reload() -> void:
	_state = State.READY
	_cooldown = 0.0


## Fills the reserve. Returns false when it was already full.
func refill_reserve() -> bool:
	if reserve >= data.max_reserve:
		return false
	reserve = data.max_reserve
	return true


## The reload time of the data, changed by the wielder's perks.
func reload_time() -> float:
	return data.reload_time * (wielder.perks.reload_time_scale() if wielder != null else 1.0)


## The time between shots of the data, changed by the wielder's perks.
func fire_interval() -> float:
	return data.fire_interval * (wielder.perks.fire_interval_scale() if wielder != null else 1.0)


func is_reloading() -> bool:
	return _state == State.RELOADING


func _shoot() -> void:
	var aim := wielder.aim_transform() if wielder != null else global_transform
	var query := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin - aim.basis.z * data.max_range)
	if wielder != null:
		query.exclude = [wielder.get_rid()]
	query.collision_mask = hit_mask
	query.hit_from_inside = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_spawn_tracer(query.to)
		return
	var collider: Object = result["collider"]
	var point: Vector3 = result["position"]
	var shape_index: int = result["shape"]
	_spawn_tracer(point)
	hit.emit(collider, point)
	if collider is Node:
		var health := Health.find_on(collider as Node)
		if health != null:
			if health.is_dead():
				return
			var weak_spot := WeakSpot.find_hit(collider, shape_index)
			health.damage(data.damage * (weak_spot.damage_multiplier if weak_spot != null else 1.0))
			damaged.emit(collider, health.is_dead(), weak_spot != null)


func _spawn_tracer(to: Vector3) -> void:
	if data.tracer == null:
		return
	var tracer := data.tracer.instantiate() as Tracer
	add_child(tracer)
	var from := global_position
	if view_model != null and view_model.muzzle != null:
		from = view_model.muzzle.global_position
	tracer.launch(from, to)
