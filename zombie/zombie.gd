class_name Zombie
extends CharacterBody3D
## Melee zombie with the cartoon Shambler model (art_source/zombie.blend). It follows the navigation mesh to its target and hits it when close. The origin is at the feet.

enum State { CHASE, BREACH, ATTACK, DEAD }

@export_group("Attack")
@export_range(0.5, 5.0, 0.05, "suffix:m") var attack_range: float = 1.3
@export_range(0.0, 100.0, 1.0) var attack_damage: float = 10.0
@export_range(0.1, 10.0, 0.05, "suffix:s") var attack_interval: float = 1.0
## The zombie leaves ATTACK only when the target is this much farther than attack_range, so it does not flicker at the edge.
@export_range(0.0, 2.0, 0.05, "suffix:m") var attack_exit_margin: float = 0.3

@export_group("Barricade")
## The seconds that the zombie takes to pull off one board.
@export_range(0.1, 10.0, 0.1, "suffix:s") var board_pull_interval: float = 1.5

@export_group("Sound")
@export_range(0.5, 30.0, 0.5, "suffix:s") var groan_interval_min: float = 4.0
@export_range(0.5, 30.0, 0.5, "suffix:s") var groan_interval_max: float = 9.0

@export_group("Look")
@export_range(0.0, 50.0, 0.5, "suffix:1/s") var turn_rate: float = 10.0

@export_group("Drops")
## What the zombie may drop when it dies. Null means it drops nothing.
@export var drops: DropTable
@export var pickup_scene: PackedScene

## Set by configure(). Null means the zombie stands still.
var target: Node3D
## Set by configure(). RoundSettings owns the value for each round.
var move_speed: float
var state: State = State.CHASE
## Set by configure(). The barricade that the zombie walks through before it chases the target. It is cleared once the
## zombie is inside.
var entry: Barricade
## Set by the barricade zone that the zombie stands in. The zombie pulls its boards while it has any.
var blocker: Barricade

## Drawn over the model. HitFlash makes it opaque red during a hit.
var _tint := StandardMaterial3D.new()
var _attack_cooldown: float = 0.0
var _pull_cooldown: float = 0.0
var _groan_left: float
var _configured := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _health: Health = $Health
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var weak_spot: WeakSpot = $WeakSpot
@onready var _hit_flash: HitFlash = $HitFlash
@onready var animator: ZombieAnimator = $Animator
@onready var _model: Node3D = $Model
@onready var health_bar: HealthBar = $HealthBar
@onready var groan_sound: AudioStreamPlayer3D = $GroanSound
@onready var attack_sound: AudioStreamPlayer3D = $AttackSound
@onready var death_sound: AudioStreamPlayer3D = $DeathSound


func _ready() -> void:
	if not _configured:
		push_error("Zombie: call configure() before add_child(), so that RoundSettings sets its speed and health.")
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
	_groan_left = randf_range(groan_interval_min, groan_interval_max)


## The color drawn over the model: transparent, or the flash color during a hit.
func tint() -> Color:
	return _tint.albedo_color


## Whether the zombie is dead. A dead zombie stays in the tree while its body falls and sinks.
func is_dead() -> bool:
	return state == State.DEAD


## Sets the speed, health, and target of this zombie. Call it before the zombie enters the tree.
func configure(speed: float, max_health: float, chase: Node3D, through: Barricade = null) -> void:
	move_speed = speed
	target = chase
	entry = through
	Health.find_on(self).max_health = max_health
	_configured = true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		animator.advance_death(delta)
		if animator.death_finished():
			queue_free()
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	_groan_left -= delta
	if _groan_left <= 0.0:
		groan_sound.play()
		_groan_left = randf_range(groan_interval_min, groan_interval_max)

	var live_target := _live_target()
	var flat_offset := Vector3.ZERO
	if live_target != null:
		flat_offset = live_target.global_position - global_position
		flat_offset.y = 0.0
	var distance := flat_offset.length()

	_enter(_next_state(live_target, distance))

	var heading := Vector3.ZERO
	match state:
		State.CHASE:
			if live_target != null:
				_agent.target_position = _chase_goal(live_target)
				heading = _agent.get_next_path_position() - global_position
				heading.y = 0.0
				heading = heading.normalized()
		State.BREACH:
			heading = blocker.global_position - global_position
			heading.y = 0.0
			heading = heading.normalized()
			_pull_cooldown -= delta
			if _pull_cooldown <= 0.0:
				_pull_cooldown += board_pull_interval
				blocker.remove_board()
		State.ATTACK:
			heading = flat_offset.normalized()
			_attack_cooldown -= delta
			if _attack_cooldown <= 0.0:
				_attack_cooldown += attack_interval
				Health.find_on(live_target).damage(attack_damage)
				attack_sound.play()

	if heading != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-heading.x, -heading.z), minf(turn_rate * delta, 1.0))
	var move_dir := heading if state == State.CHASE else Vector3.ZERO
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
	move_and_slide()
	var real_velocity := get_real_velocity()
	var attack_progress := -1.0
	match state:
		State.ATTACK:
			attack_progress = 1.0 - _attack_cooldown / attack_interval
		State.BREACH:
			attack_progress = 1.0 - _pull_cooldown / board_pull_interval
	animator.advance(delta, Vector2(real_velocity.x, real_velocity.z).length(), attack_progress)


## ATTACK when the target is in reach (the exit margin keeps it from flickering at the edge), else BREACH while a
## barricade with boards blocks the zombie, else CHASE. At a barricade the reach is the barricade's repair range, so a
## player who repairs it always takes hits, and the zombie pulls no board while it hits.
func _next_state(live_target: Node3D, distance: float) -> State:
	var at_window := blocker != null and blocker.has_boards()
	if live_target != null:
		var margin := attack_exit_margin if state == State.ATTACK else 0.0
		var in_reach := blocker.in_reach(live_target.global_position, margin) if at_window else distance <= attack_range + margin
		if in_reach:
			return State.ATTACK
	if at_window:
		return State.BREACH
	return State.CHASE


func _enter(next: State) -> void:
	if next == state:
		return
	state = next
	match state:
		State.ATTACK:
			_attack_cooldown = attack_interval
		State.BREACH:
			_pull_cooldown = board_pull_interval


## The point that the path leads to: the entry barricade's inside point until the zombie is inside, then the target.
func _chase_goal(live_target: Node3D) -> Vector3:
	if entry != null and entry.is_inside(global_position):
		entry = null
	return live_target.global_position if entry == null else entry.inside_point()


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
	weak_spot.set_deferred("disabled", true)
	groan_sound.stop()
	death_sound.play()
	_drop_pickup()


func _drop_pickup() -> void:
	if drops == null:
		return
	var item := drops.roll()
	if item == null:
		return
	var pickup := pickup_scene.instantiate() as Pickup
	pickup.item = item
	pickup.lifetime = drops.lifetime
	pickup.position = position
	get_parent().add_child.call_deferred(pickup)
