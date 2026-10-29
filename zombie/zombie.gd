class_name Zombie
extends CharacterBody3D
## Melee zombie with the cartoon Shambler model (art_source/zombie.py). It follows the navigation mesh to its target and hits it when close. The origin is at the feet.

enum State { CHASE, ATTACK, DEAD }

@export_group("Attack")
@export_range(0.5, 5.0, 0.05, "suffix:m") var attack_range: float = 1.3
@export_range(0.0, 100.0, 1.0) var attack_damage: float = 10.0
@export_range(0.1, 10.0, 0.05, "suffix:s") var attack_interval: float = 1.0
## The zombie leaves ATTACK only when the target is this much farther than attack_range, so it does not flicker at the edge.
@export_range(0.0, 2.0, 0.05, "suffix:m") var attack_exit_margin: float = 0.3

@export_group("Look")
@export_range(0.0, 50.0, 0.5, "suffix:1/s") var turn_rate: float = 10.0

var target: Node3D
## Set by configure(). RoundSettings owns the value for each round.
var move_speed: float
var state: State = State.CHASE

## Drawn over the model. HitFlash makes it opaque red during a hit.
var _tint := StandardMaterial3D.new()
var _attack_cooldown: float = 0.0
var _configured := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _health: Health = $Health
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _hit_flash: HitFlash = $HitFlash
@onready var animator: ZombieAnimator = $Animator
@onready var _model: Node3D = $Model


func _ready() -> void:
	if not _configured:
		push_error("Zombie: call configure() before add_child(), so that RoundSettings sets its speed and health.")
	if target == null:
		target = get_tree().get_first_node_in_group(Player.GROUP) as Node3D
	_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint.albedo_color = Color.TRANSPARENT
	for mesh: Node in _model.find_children("*", "MeshInstance3D"):
		(mesh as MeshInstance3D).material_overlay = _tint
	# Baked navmesh surfaces float two cell heights above the floor, and the agent measures path distance in 3D, so
	# without this the zombie never reaches a path point that is above its feet.
	_agent.path_height_offset = 2.0 * NavigationServer3D.map_get_cell_height(_agent.get_navigation_map())
	_hit_flash.material = _tint
	animator.attach(_model)
	_health.died.connect(_on_died)


## The color drawn over the model: transparent, or the flash color during a hit.
func tint() -> Color:
	return _tint.albedo_color


## Whether the zombie is dead. A dead zombie stays in the tree while its body falls and sinks.
func is_dead() -> bool:
	return state == State.DEAD


## Sets the speed and health of this zombie. Call it before the zombie enters the tree.
func configure(speed: float, max_health: float) -> void:
	move_speed = speed
	Health.find_on(self).max_health = max_health
	_configured = true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		animator.advance_death(delta)
		if animator.death_finished():
			queue_free()
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	var live_target := _live_target()
	var flat_offset := Vector3.ZERO
	if live_target != null:
		flat_offset = live_target.global_position - global_position
		flat_offset.y = 0.0
	var distance := flat_offset.length()

	if live_target == null:
		state = State.CHASE
	elif state == State.CHASE and distance <= attack_range:
		state = State.ATTACK
		_attack_cooldown = attack_interval
	elif state == State.ATTACK and distance > attack_range + attack_exit_margin:
		state = State.CHASE

	var heading := Vector3.ZERO
	match state:
		State.CHASE:
			if live_target != null:
				_agent.target_position = live_target.global_position
				heading = _agent.get_next_path_position() - global_position
				heading.y = 0.0
				heading = heading.normalized()
		State.ATTACK:
			heading = flat_offset.normalized()
			_attack_cooldown -= delta
			if _attack_cooldown <= 0.0:
				_attack_cooldown += attack_interval
				Health.find_on(live_target).damage(attack_damage)

	if heading != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-heading.x, -heading.z), minf(turn_rate * delta, 1.0))
	var move_dir := heading if state == State.CHASE else Vector3.ZERO
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
	move_and_slide()
	var real_velocity := get_real_velocity()
	var attack_progress := 1.0 - _attack_cooldown / attack_interval if state == State.ATTACK else -1.0
	animator.advance(delta, Vector2(real_velocity.x, real_velocity.z).length(), attack_progress)


## The target, or null when there is none or it is dead.
func _live_target() -> Node3D:
	if target == null:
		return null
	var target_health := Health.find_on(target)
	if target_health == null or target_health.is_dead():
		return null
	return target


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_shape.set_deferred("disabled", true)
