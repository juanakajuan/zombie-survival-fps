class_name Grenade
extends RigidBody3D
## A thrown grenade. It bounces, and after fuse_time it explodes once. The blast damages every living Health in a
## sphere, once each, and less with the distance from the centre. Walls do not shield from it.

## Emitted once, when the grenade explodes and after it has damaged its targets.
signal exploded
## Emitted for each living Health that the blast damages. `killed` is true when it took that Health to 0.
## `headshot` is always false. The signal has the shape of Weapon.damaged, so one handler serves both.
signal damaged(target: Node, killed: bool, headshot: bool)

@export_range(0.1, 10.0, 0.1, "suffix:s") var fuse_time: float = 2.5
@export_range(0.5, 20.0, 0.1, "suffix:m") var blast_radius: float = 5.0
## The damage at the centre.
@export_range(1.0, 10000.0, 1.0) var max_damage: float = 250.0
## The damage at the edge of the blast. The damage falls off in a line between the two.
@export_range(0.0, 10000.0, 1.0) var min_damage: float = 20.0
## What the blast does to the thrower, as a fraction of the damage a zombie takes. 0 never hurts the thrower.
@export_range(0.0, 1.0, 0.05) var player_damage_scale: float = 0.25
@export_flags_3d_physics var hit_mask: int = 1

@export_group("Flash")
@export_range(0.05, 2.0, 0.05, "suffix:s") var flash_time: float = 0.25
@export_range(0.5, 20.0, 0.1, "suffix:m") var flash_diameter: float = 2.5

## The player who threw it. The grenade does not collide with the thrower, and the blast hurts the thrower
## by player_damage_scale. Grenades sets it.
var thrower: Player

## Seconds until the blast. The owner may set it before the grenade enters the tree, for a grenade that has burned
## already. NAN, the default, starts the full fuse_time. 0 or less explodes the grenade on its first physics tick.
var fuse_left: float = NAN

var _flash_left: float = 0.0
var _flash_energy: float
var _exploded: bool = false

@onready var _model: Node3D = $Model
@onready var _flash: MeshInstance3D = $Flash
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	if is_nan(fuse_left):
		fuse_left = fuse_time
	_flash_energy = _light.light_energy
	if thrower != null:
		add_collision_exception_with(thrower)


func _physics_process(delta: float) -> void:
	if _exploded:
		_fade_flash(delta)
		return
	fuse_left -= delta
	if fuse_left <= 0.0:
		_explode()


## The blast has gone off. The grenade stays in the tree until its flash has faded.
func has_exploded() -> bool:
	return _exploded


func _explode() -> void:
	_exploded = true
	freeze = true
	_model.visible = false
	_flash.visible = true
	_light.visible = true
	_flash_left = flash_time
	var shape := SphereShape3D.new()
	shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = hit_mask
	var struck: Array[Health] = []
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var collider: Node = result["collider"]
		var health := Health.find_on(collider)
		if health == null or health.is_dead() or health in struck:
			continue
		struck.append(health)
		var target := collider as Node3D
		var amount := lerpf(max_damage, min_damage, clampf(global_position.distance_to(target.global_position) / blast_radius, 0.0, 1.0))
		if collider == thrower:
			health.damage(amount * player_damage_scale)
			continue
		if amount <= 0.0:
			continue
		if thrower != null:
			amount = thrower.powerups.hit_damage(collider, health, amount)
		health.damage_at(amount, global_position)
		damaged.emit(collider, health.is_dead(), false)
	exploded.emit()


func _fade_flash(delta: float) -> void:
	_flash_left -= delta
	if _flash_left <= 0.0:
		queue_free()
		return
	var progress := 1.0 - _flash_left / flash_time
	_flash.scale = Vector3.ONE * flash_diameter * lerpf(0.3, 1.0, progress)
	_flash.transparency = progress
	_light.light_energy = _flash_energy * (1.0 - progress)
