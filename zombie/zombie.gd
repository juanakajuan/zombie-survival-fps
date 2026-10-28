class_name Zombie
extends CharacterBody3D
## Melee zombie. It follows the navigation mesh to its target and hits it when close. The origin is at the feet.

enum State { CHASE, ATTACK, DEAD }

const FLASH_COLOR := Color(1.0, 0.15, 0.1)
const FLASH_SECONDS := 0.1
## The zombie leaves ATTACK only when the target is this much farther than attack_range, so it does not flicker at the edge.
const ATTACK_EXIT_MARGIN := 0.3
const TURN_RATE := 10.0

@export_group("Movement")
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var move_speed: float = 2.5

@export_group("Attack")
@export_range(0.5, 5.0, 0.05, "suffix:m") var attack_range: float = 1.3
@export_range(0.0, 100.0, 1.0) var attack_damage: float = 10.0
@export_range(0.1, 10.0, 0.05, "suffix:s") var attack_interval: float = 1.0

@export_group("Look")
@export var base_color: Color = Color(0.35, 0.55, 0.3)

var target: Node3D
var state: State = State.CHASE

var _material := StandardMaterial3D.new()
var _attack_cooldown: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _health: Health = $Health
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group(Player.GROUP) as Node3D
	_material.albedo_color = base_color
	for child: Node in $Body.get_children():
		(child as MeshInstance3D).material_override = _material
	# Baked navmesh surfaces float two cell heights above the floor, and the agent measures path distance in 3D, so
	# without this the zombie never reaches a path point that is above its feet.
	_agent.path_height_offset = 2.0 * NavigationServer3D.map_get_cell_height(_agent.get_navigation_map())
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
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
	elif state == State.ATTACK and distance > attack_range + ATTACK_EXIT_MARGIN:
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
		rotation.y = lerp_angle(rotation.y, atan2(-heading.x, -heading.z), minf(TURN_RATE * delta, 1.0))
	var move_dir := heading if state == State.CHASE else Vector3.ZERO
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
	move_and_slide()


## The target, or null when there is none or it is dead.
func _live_target() -> Node3D:
	if target == null:
		return null
	var target_health := Health.find_on(target)
	if target_health == null or target_health.is_dead():
		return null
	return target


func _on_damaged(_amount: float) -> void:
	_material.albedo_color = FLASH_COLOR
	get_tree().create_timer(FLASH_SECONDS).timeout.connect(_end_flash)


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_shape.set_deferred("disabled", true)
	queue_free()


func _end_flash() -> void:
	_material.albedo_color = base_color
