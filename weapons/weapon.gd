class_name Weapon
extends Node3D
## Hitscan weapon. It shoots along its wielder's aim, or along its own -Z axis when it has no wielder. It ignores its wielder. A shot is
## `data.pellets` rays inside the `data.spread` cone, and each ray shows a tracer from the muzzle.

signal fired
signal reload_started
## Emitted when the trigger is pulled with no round in the magazine and none in the reserve.
signal dry_fired
signal reload_finished
signal reload_cancelled
signal hit(collider: Object, position: Vector3)
## Emitted when a ray of a shot damages a Health that is alive. `killed` is true when this ray took it to 0, and `headshot` is true when it hit a WeakSpot. A dead target takes no damage.
signal damaged(target: Node, killed: bool, headshot: bool)
## Emitted when the effect of the weapon damages a Health that is alive, such as a burn tick. `killed` is true when it took it to 0. It is not a ray hit, so `damaged` does not follow.
signal effect_damaged(target: Node, killed: bool)
## Emitted after `effect` changes.
signal effect_changed
## Emitted after `ammo` or `reserve` changes.
signal ammo_changed

enum State { READY, RELOADING }

@export var data: WeaponData
## Physics layers that a shot can hit. Debris, such as thrown guns, is not on them.
@export_flags_3d_physics var hit_mask: int = 1
## The player who holds the weapon. Shots never hit the wielder.
@export var wielder: Player

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
## The bonus from the second upgrade, or null. The weapon keeps it while it is holstered.
var effect: WeaponEffect:
	set(value):
		effect = value
		effect_changed.emit()
## The instance of data.view_model, or null when the data has none or its root is not a ViewModel.
var view_model: ViewModel

var _state: State = State.READY
var _shot_cooldown: float = 0.0
var _reload_left: float = 0.0


func _ready() -> void:
	ammo = data.magazine_size
	reserve = data.max_reserve
	if data.view_model != null:
		var model := data.view_model.instantiate()
		add_child(model)
		view_model = model as ViewModel


func _physics_process(delta: float) -> void:
	_shot_cooldown = maxf(_shot_cooldown - delta, 0.0)
	_reload_left = maxf(_reload_left - delta, 0.0)
	if _state == State.RELOADING and _reload_left == 0.0:
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


## Fires one shot. Returns false when the wielder sprints, punches, or has a grenade in hand, or the weapon is cooling down, reloading, or empty.
## Firing with an empty magazine starts a reload, or clicks dry when the reserve is empty too.
func try_fire() -> bool:
	if wielder != null and (wielder.is_sprinting() or wielder.is_meleeing() or wielder.is_throwing()):
		return false
	if _state != State.READY:
		return false
	if ammo == 0:
		if reserve > 0:
			start_reload()
		elif _shot_cooldown == 0.0:
			_shot_cooldown = fire_interval()
			dry_fired.emit()
			dry_sound.play()
		return false
	if _shot_cooldown > 0.0:
		return false
	ammo -= 1
	_shot_cooldown = fire_interval()
	fired.emit()
	shot_sound.play()
	_shoot()
	return true


## Does nothing when the magazine is full or the reserve is empty, or while the wielder punches or has a grenade in hand.
func start_reload() -> void:
	if wielder != null and (wielder.is_meleeing() or wielder.is_throwing()):
		return
	if _state == State.RELOADING or ammo == data.magazine_size or reserve == 0:
		return
	_state = State.RELOADING
	_reload_left = reload_time()
	reload_started.emit()
	reload_sound.play()


## Stops a reload and gives back nothing: the magazine and the reserve stay as they were.
func cancel_reload() -> void:
	var was_reloading := _state == State.RELOADING
	_state = State.READY
	_reload_left = 0.0
	_shot_cooldown = 0.0
	if was_reloading:
		reload_cancelled.emit()


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
	var spread := deg_to_rad(data.spread)
	for _pellet: int in data.pellets:
		var direction := _uniform_cone_direction(aim.basis, spread)
		_shoot_ray(aim.origin, direction)


func _uniform_cone_direction(aim: Basis, half_angle: float) -> Vector3:
	var forward := -aim.z
	return forward.rotated(aim.x, half_angle * sqrt(randf())).rotated(forward, randf() * TAU)


func _shoot_ray(from: Vector3, direction: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * data.max_range)
	if wielder != null:
		query.exclude = [wielder.get_rid()]
	query.collision_mask = hit_mask
	query.hit_from_inside = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_spawn_tracer(_muzzle(), query.to)
		return
	var collider: Object = result["collider"]
	var point: Vector3 = result["position"]
	var shape_index: int = result["shape"]
	_spawn_tracer(_muzzle(), point)
	hit.emit(collider, point)
	var weak_spot := WeakSpot.find_hit(collider, shape_index)
	if _try_damage(collider, data.damage * (weak_spot.damage_multiplier if weak_spot != null else 1.0), weak_spot != null, point) \
			and data.chain_targets > 0:
		_chain(collider as CollisionObject3D, point)


func _try_damage(collider: Object, amount: float, headshot: bool, point: Vector3) -> bool:
	if not collider is Node:
		return false
	var health := Health.find_on(collider as Node)
	if health == null or health.is_dead():
		return false
	if wielder != null:
		amount = wielder.powerups.hit_damage(collider as Node, health, amount)
	health.damage_at(amount, point)
	damaged.emit(collider, health.is_dead(), headshot)
	if effect != null and not health.is_dead():
		effect.on_hit(self, collider as Node)
	return true


func _chain(first: CollisionObject3D, from: Vector3) -> void:
	var struck: Array[RID] = [first.get_rid()]
	if wielder != null:
		struck.append(wielder.get_rid())
	var amount := data.damage
	for _jump: int in data.chain_targets:
		var next := _next_chain_target(from, struck)
		if next == null:
			return
		var to := next.global_position + Vector3.UP * data.chain_aim_height
		amount *= data.chain_damage_scale
		_spawn_tracer(from, to)
		hit.emit(next, to)
		_try_damage(next, amount, false, to)
		struck.append(next.get_rid())
		from = to


func _next_chain_target(from: Vector3, struck: Array[RID]) -> CollisionObject3D:
	var sphere := SphereShape3D.new()
	sphere.radius = data.chain_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.collision_mask = hit_mask
	query.exclude = struck
	var space := get_world_3d().direct_space_state
	var nearest: CollisionObject3D = null
	for found: Dictionary in space.intersect_shape(query, 64):
		var collider: Object = found["collider"]
		var body := collider as CollisionObject3D
		if body == null:
			continue
		var health := Health.find_on(body)
		if health == null or health.is_dead():
			continue
		var to := body.global_position + Vector3.UP * data.chain_aim_height
		if nearest != null and from.distance_to(to) >= from.distance_to(nearest.global_position + Vector3.UP * data.chain_aim_height):
			continue
		var sight := PhysicsRayQueryParameters3D.create(from, to, hit_mask, struck)
		var blocker: Dictionary = space.intersect_ray(sight)
		var seen: Object = blocker.get("collider")
		if seen == null or seen == body:
			nearest = body
	return nearest


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	if data.tracer == null:
		return
	var tracer := data.tracer.instantiate() as Tracer
	add_child(tracer)
	tracer.launch(from, to)


func _muzzle() -> Vector3:
	if view_model != null and view_model.muzzle != null:
		return view_model.muzzle.global_position
	return global_position
