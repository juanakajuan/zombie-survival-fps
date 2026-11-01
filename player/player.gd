class_name Player
extends CharacterBody3D
## First-person controller. The origin is at the feet. Yaw is on this body, pitch is on Head.

## Emitted once when the Health child gets to 0 and the player goes down, which needs a self-revive perk.
signal downed

## Emitted once when the player dies: the downed time ends, or the Health child gets to 0 without a self-revive perk.
## After it, the player ignores all input.
signal died

## Emitted when another weapon becomes the current one, and when a bought weapon is equipped.
signal weapon_changed(weapon: Weapon)

## The group that player.tscn puts the player in. Other features find the player with it.
const GROUP := &"player"

@export_group("Movement")
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var walk_speed: float = 4.5
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var sprint_speed: float = 7.0
## Each second on the floor, the player gains up to this many times the target speed.
@export_range(0.0, 50.0, 0.5) var ground_acceleration: float = 10.0
## Each second in the air, the player can steer up to this many times the target speed. Steering in the air
## never takes the speed above the larger of the target speed and the speed at takeoff.
@export_range(0.0, 50.0, 0.5) var air_acceleration: float = 2.0
## Each second on the floor, the player loses this many times its speed.
@export_range(0.0, 20.0, 0.1) var friction: float = 6.0
## Below this speed, friction acts as if the player moves at this speed, so the player comes to a full stop quickly.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var stop_speed: float = 2.5
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var jump_velocity: float = 8.0
@export_range(0.0, 60.0, 0.1, "suffix:m/s²") var gravity: float = 25.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var aim_speed: float = 3.0

@export_group("Crouch")
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var crouch_speed: float = 2.5
## Collision height while crouched. Standing height comes from the capsule in the scene.
@export_range(0.7, 1.8, 0.05, "suffix:m") var crouch_height: float = 1.0
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var crouch_camera_speed: float = 6.0

@export_group("Slide")
## Pressing crouch on the floor at this speed or faster starts a slide instead of a crouch.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var slide_min_speed: float = 5.5
## Speed added at the start of a slide, when the slide cooldown is over.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var slide_boost: float = 3.0
## The boost does not take the speed above this value.
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var slide_max_speed: float = 10.0
## Time after a boost before the next slide gets a boost.
@export_range(0.0, 10.0, 0.05, "suffix:s") var slide_cooldown: float = 1.5
## Each second of a slide, the player loses this many times its speed. The slide ends at crouch speed.
@export_range(0.0, 10.0, 0.05) var slide_friction: float = 0.6

@export_group("Downed")
## With a self-revive perk, the player is downed at 0 health. The perk stands the player up after its time, and if
## this time ends first, the player dies.
@export_range(0.5, 60.0, 0.5, "suffix:s") var downed_time: float = 10.0
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var downed_speed: float = 1.0
## The height of the head above the feet while downed.
@export_range(0.1, 1.0, 0.05, "suffix:m") var downed_head_height: float = 0.5
## The only weapon that a downed player fires. It always has a full magazine.
@export var downed_weapon: WeaponData

@export_group("Look")
@export_range(0.0001, 0.02, 0.0001, "suffix:rad/px") var mouse_sensitivity: float = 0.0025
@export_range(0.0, 90.0, 0.5, "suffix:°") var max_pitch_degrees: float = 89.0

@export_group("Aim")
## The field of view while fully aimed, as a fraction of the field of view in the settings.
@export_range(0.3, 1.0, 0.01) var aim_fov_scale: float = 0.8
## Each second, the zoom closes this much of the gap to its target. Higher is snappier.
@export_range(0.1, 40.0, 0.1) var aim_sharpness: float = 14.0

@export_group("Interact")
@export_range(0.5, 10.0, 0.1, "suffix:m") var interact_range: float = 2.5

@export_group("Weapons")
## How many weapons the player holds. Buying another with all held replaces the current one.
@export_range(1, 4) var max_weapons: int = 2
## The scene that give_weapon instances for each weapon.
@export var weapon_scene: PackedScene

@export_group("Third person (debug)")
## In a debug build, the third_person action moves the camera behind the player so the body shows.
## The camera sits this far behind the head, and stops short of walls.
@export_range(0.5, 10.0, 0.1, "suffix:m") var third_person_distance: float = 3.0
## The camera moves this far to the right of the head, over the shoulder.
@export_range(-2.0, 2.0, 0.05, "suffix:m") var third_person_shoulder: float = 0.6

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hud: Hud = $Hud
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var debug_menu: DebugMenu = $DebugMenu
@onready var body: Node3D = $Body
@onready var animator: PlayerAnimator = $Animator
@onready var wallet: Wallet = $Wallet
@onready var perks: Perks = $Perks
@onready var powerups: Powerups = $Powerups
@onready var hurt_sound: AudioStreamPlayer = $HurtSound
@onready var health: Health = $Health
@onready var _collision: CollisionShape3D = $CollisionShape3D

## The weapon in hand: one of `weapons`, or the loaner pistol of a downed player who holds no pistol.
@onready var weapon: Weapon = $Head/Camera3D/Weapon
## The weapons the player holds, in slot order. Only `weapon` fires; the others are holstered.
@onready var weapons: Array[Weapon] = [weapon]
@onready var melee: Melee = $Melee
@onready var grenades: Grenades = $Grenades
@onready var punch_view: PunchView = $Head/Camera3D/PunchView
@onready var grenade_view: GrenadeView = $Head/Camera3D/GrenadeView
var settings: GameSettings

enum Stance { STANDING, CROUCHED, SLIDING }
enum Life { ALIVE, DOWNED, DEAD }

var _stance := Stance.STANDING
var _life := Life.ALIVE
var _downed_left := 0.0
var _self_revive_left := 0.0
var _self_revive: PerkItem
var _weapon_before_down: Weapon
var _loaner_pistol: Weapon
var _slide_cooldown_left := 0.0
var _aim_blend := 0.0
var _shape: CapsuleShape3D
var _stand_height: float
var _stand_head_height: float
var _third_person := false
var _focused: Interactable


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health.died.connect(_on_health_died)
	health.changed.connect(_on_health_changed)
	health.damaged.connect(hurt_sound.play.unbind(1))
	weapon.damaged.connect(_on_damaged)
	weapon.effect_damaged.connect(_on_effect_damaged)
	melee.damaged.connect(_on_damaged)
	grenades.damaged.connect(_on_damaged)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.settings_changed.connect(_apply_settings)
	debug_menu.player = self
	debug_menu.close_requested.connect(_close_debug_menu)
	settings = GameSettings.load_saved()
	_apply_settings()
	# Every Player instance shares the scene's capsule, so crouching must resize a copy.
	_shape = _collision.shape.duplicate() as CapsuleShape3D
	_collision.shape = _shape
	animator.attach(body)
	animator.melee = melee
	_set_third_person(false)
	_stand_height = _shape.height
	_stand_head_height = head.position.y
	# Physics moves the body 60 times a second. On a faster screen the camera would hold still for some frames
	# and then jump, which looks like blur. So the camera follows the interpolated head, but it takes the look
	# angles as they are, because interpolating them would make the mouse lag by one physics tick.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_place_camera(head.global_position)


func _process(delta: float) -> void:
	_aim_blend = lerpf(_aim_blend, 1.0 if is_aiming() else 0.0, 1.0 - exp(-aim_sharpness * delta))
	_apply_field_of_view()
	_place_camera(head.get_global_transform_interpolated().origin)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("third_person") and OS.is_debug_build():
		_set_third_person(not _third_person)
	elif event.is_action_pressed("weapon_1"):
		switch_to(0)
	elif event.is_action_pressed("weapon_2"):
		switch_to(1)
	elif event.is_action_pressed("weapon_next"):
		switch_to(posmod(weapons.find(weapon) + 1, weapons.size()))
	elif event.is_action_pressed("weapon_previous"):
		switch_to(posmod(weapons.find(weapon) - 1, weapons.size()))
	elif event.is_action_pressed("debug_menu") and OS.is_debug_build():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		debug_menu.open()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu.open(settings)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if is_downed():
		_downed_left -= delta
		_self_revive_left -= delta
		hud.show_downed(_downed_left, _self_revive.display_name, _self_revive_left)
		if _self_revive_left <= 0.0:
			revive(_self_revive.self_revive_health)
		elif _downed_left <= 0.0:
			_die()
	_update_focus()
	if _focused != null and weapon.trigger_enabled:
		if Input.is_action_just_pressed("interact"):
			_focused.press(self)
		if Input.is_action_pressed("interact"):
			_focused.hold(self, delta)
	if weapon.trigger_enabled and not weapon.is_reloading() and not is_throwing() and Input.is_action_just_pressed("melee"):
		melee.try_swing()
	if weapon.trigger_enabled and not is_meleeing() and Input.is_action_just_pressed("grenade"):
		grenades.start_cook()
	if grenades.is_cooking() and not Input.is_action_pressed("grenade"):
		grenades.release()
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)
	_update_stance(on_floor, delta)
	var jumping := on_floor and Input.is_action_just_pressed("jump") and not is_dead() and not is_downed()
	if jumping:
		velocity.y = jump_velocity
	elif on_floor:
		velocity.y = 0.0
		if _stance == Stance.SLIDING:
			_apply_friction(slide_friction, 0.0, delta)
		else:
			_apply_friction(friction, minf(stop_speed, downed_speed) if is_downed() else stop_speed, delta)
	else:
		velocity.y -= gravity * delta

	var move_input := _move_input()
	var wish_dir := (global_basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
	var target_speed := (downed_speed if is_downed() else crouch_speed if is_crouching() else aim_speed if is_aiming() else sprint_speed if is_sprinting() else walk_speed) * move_input.length()
	if not on_floor:
		_air_accelerate(wish_dir, target_speed, delta)
	elif _stance != Stance.SLIDING:
		_accelerate(wish_dir, target_speed, ground_acceleration, delta)
	move_and_slide()
	animator.advance(delta, _horizontal_speed(), not is_on_floor() or is_sliding(), is_crouching(), is_aiming(), head.rotation.x, melee.progress())


## Applies a mouse delta in pixels. Moving the mouse right turns right, and moving it up looks up.
## A dead player does not look.
func look(relative: Vector2) -> void:
	if is_dead():
		return
	var sensitivity := mouse_sensitivity * settings.mouse_sensitivity_scale
	rotation.y -= relative.x * sensitivity
	var max_pitch := deg_to_rad(max_pitch_degrees)
	head.rotation.x = clampf(head.rotation.x - relative.y * sensitivity, -max_pitch, max_pitch)
	camera.global_basis = _look_basis()



## The mouse delta in pixels that turns the view to `point` when it goes to look().
func mouse_delta_to(point: Vector3) -> Vector2:
	var to_point := point - head.global_position
	return mouse_delta_to_angles(atan2(-to_point.x, -to_point.z), atan2(to_point.y, Vector2(to_point.x, to_point.z).length()))


## The mouse delta in pixels that turns the view to an absolute yaw and pitch, in radians, when it goes to look().
func mouse_delta_to_angles(yaw: float, pitch: float) -> Vector2:
	var sensitivity := mouse_sensitivity * settings.mouse_sensitivity_scale
	return Vector2(-wrapf(yaw - rotation.y, -PI, PI), -(pitch - head.rotation.x)) / sensitivity


## Adds a weapon with this data and takes it in hand. When the player already holds `max_weapons`, it replaces
## the weapon in hand. Returns the new weapon.
func give_weapon(data: WeaponData) -> Weapon:
	var given := _make_weapon(data)
	_holster(weapon)
	if weapons.size() >= max_weapons:
		var replaced := weapon
		weapons[weapons.find(replaced)] = given
		replaced.queue_free()
	else:
		weapons.append(given)
	_equip(given)
	return given


## Replaces the weapon in hand with its `WeaponData.upgrade`, with a full magazine and reserve. Returns the new weapon,
## or null when the weapon in hand has no upgrade.
func upgrade_weapon() -> Weapon:
	if weapon.data.upgrade == null:
		return null
	var upgraded := _make_weapon(weapon.data.upgrade)
	var replaced := weapon
	_holster(replaced)
	weapons[weapons.find(replaced)] = upgraded
	replaced.queue_free()
	_equip(upgraded)
	return upgraded


## The held weapon that has this data or its upgrade, or null.
func weapon_holding(data: WeaponData) -> Weapon:
	for held: Weapon in weapons:
		if held.data == data or (data.upgrade != null and held.data == data.upgrade):
			return held
	return null


## Takes the weapon in this slot in hand. It does nothing for the slot in hand, a slot with no weapon, or a downed or dead player.
## The weapon that goes away loses its reload in progress.
func switch_to(index: int) -> void:
	if is_dead() or is_downed() or index < 0 or index >= weapons.size() or weapons[index] == weapon:
		return
	_holster(weapon)
	_equip(weapons[index])


## The interactable within interact_range that the player looks at, or null. A downed or dead player has none.
func focused() -> Interactable:
	return _focused


## True while the aim action is held. A dead player does not aim.
func is_aiming() -> bool:
	return Input.is_action_pressed("aim") and not is_dead()


## True while on the floor, not crouched, not aiming, with the sprint action held and the move input pointing forward.
func is_sprinting() -> bool:
	return is_on_floor() and _stance == Stance.STANDING and not is_aiming() and Input.is_action_pressed("sprint") and _move_input().y < -0.5


## True while the player is low: crouched or sliding. The player stays low after the crouch action is released
## until there is room to stand.
func is_crouching() -> bool:
	return _stance != Stance.STANDING


## True while the player slides: crouch was pressed on the floor at slide_min_speed or faster, and the speed
## is still above crouch_speed.
func is_sliding() -> bool:
	return _stance == Stance.SLIDING


## True from the start to the end of a punch. The weapon cannot fire or reload during it.
func is_meleeing() -> bool:
	return melee.is_swinging()


## True from the pin pull of a grenade until the end of its throw. The weapon cannot fire or reload, and the player
## cannot punch, during it.
func is_throwing() -> bool:
	return grenades.is_busy()


## True from 0 health without a self-revive perk, or from the end of the downed time.
func is_dead() -> bool:
	return _life == Life.DEAD


## True from 0 health until the downed time ends or a revive stands the player up.
func is_downed() -> bool:
	return _life == Life.DOWNED


## Stands a downed player up with `health_fraction` of max_health, at least 1 hp. It does nothing for a player who is not downed.
func revive(health_fraction: float) -> void:
	if not is_downed():
		return
	health.heal(maxf(health.max_health * health_fraction, 1.0))


func _update_focus() -> void:
	_focused = null
	if is_dead() or is_downed():
		return
	var aim := aim_transform()
	var query := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin - aim.basis.z * interact_range, collision_mask, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider: Object = result["collider"]
		_focused = collider as Interactable


func _on_health_died() -> void:
	var self_revive := perks.self_revive()
	perks.lose_all()
	if self_revive != null:
		_go_down(self_revive)
	else:
		_die()


func _on_health_changed(current: float) -> void:
	if is_downed() and current > 0.0:
		_stand_up()


func _go_down(self_revive: PerkItem) -> void:
	_life = Life.DOWNED
	grenades.drop()
	_downed_left = downed_time
	_self_revive_left = self_revive.self_revive_time
	_self_revive = self_revive
	_weapon_before_down = weapon
	_set_stance(Stance.CROUCHED)
	var pistol := weapon_holding(downed_weapon)
	if pistol == null:
		pistol = _make_weapon(downed_weapon)
		_loaner_pistol = pistol
	if pistol != weapon:
		_holster(weapon)
		_equip(pistol)
	pistol.ammo = pistol.data.magazine_size
	hud.show_downed(_downed_left, _self_revive.display_name, _self_revive_left)
	downed.emit()


func _stand_up() -> void:
	_life = Life.ALIVE
	hud.hide_downed()
	if weapon != _weapon_before_down:
		_holster(weapon)
		_equip(_weapon_before_down)
	if _loaner_pistol != null:
		_loaner_pistol.queue_free()
		_loaner_pistol = null
	_self_revive = null


func _die() -> void:
	_life = Life.DEAD
	grenades.drop()
	_set_stance(Stance.CROUCHED)
	hud.hide_downed()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for held: Weapon in weapons:
		held.trigger_enabled = false
	weapon.trigger_enabled = false
	died.emit()


func _make_weapon(data: WeaponData) -> Weapon:
	var made := weapon_scene.instantiate() as Weapon
	made.data = data
	made.wielder = self
	made.trigger_enabled = weapon.trigger_enabled
	camera.add_child(made)
	made.damaged.connect(_on_damaged)
	made.effect_damaged.connect(_on_effect_damaged)
	return made


func _holster(held: Weapon) -> void:
	held.cancel_reload()
	held.visible = false
	held.process_mode = Node.PROCESS_MODE_DISABLED


func _equip(next: Weapon) -> void:
	weapon = next
	next.visible = true
	next.process_mode = Node.PROCESS_MODE_INHERIT
	if next.view_model != null:
		next.view_model.visible = not _third_person
		next.view_model.draw()
	hud.weapon = next
	weapon_changed.emit(next)


func _on_damaged(target: Node, killed: bool, headshot: bool) -> void:
	if target is Zombie:
		wallet.reward_hit(killed, headshot)


func _on_effect_damaged(target: Node, killed: bool) -> void:
	_on_damaged(target, killed, false)


func _resume() -> void:
	pause_menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _close_debug_menu() -> void:
	debug_menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_settings() -> void:
	_apply_field_of_view()
	settings.apply_to_engine()
	hud.show_fps = settings.show_fps


func _apply_field_of_view() -> void:
	camera.fov = settings.field_of_view * lerpf(1.0, aim_fov_scale, _aim_blend)


func _place_camera(origin: Vector3) -> void:
	var basis := _look_basis()
	if _third_person:
		var target := origin + basis * Vector3(third_person_shoulder, 0.0, third_person_distance)
		var query := PhysicsRayQueryParameters3D.create(origin, target, collision_mask, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var wall: Vector3 = hit["position"]
			target = wall + (origin - target).normalized() * 0.2
		origin = target
	camera.global_transform = Transform3D(basis, origin)


## Whether the camera is behind the player, from the debug third_person action.
func is_third_person() -> bool:
	return _third_person


func _set_third_person(on: bool) -> void:
	_third_person = on
	# In first person the body draws only its shadow, so it does not block the view. A camera cull mask would hide
	# the shadow too.
	var casting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = casting
	var shown: Array[Weapon] = weapons.duplicate()
	if _loaner_pistol != null:
		shown.append(_loaner_pistol)
	for held: Weapon in shown:
		if held.view_model != null:
			held.view_model.visible = not on
	punch_view.visible = not on
	grenade_view.visible = not on


## The head position with the look rotation. Shots, punches, and the buy-station check start here and point along -Z.
func aim_transform() -> Transform3D:
	return Transform3D(_look_basis(), head.global_position)


func _look_basis() -> Basis:
	return Basis.from_euler(Vector3(head.rotation.x, rotation.y, 0.0))


func _move_input() -> Vector2:
	if is_dead():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _apply_friction(amount: float, min_speed: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	if speed == 0.0:
		return
	var new_speed := maxf(speed - maxf(speed, min_speed) * amount * delta, 0.0)
	horizontal *= new_speed / speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _accelerate(wish_dir: Vector3, target_speed: float, acceleration: float, delta: float) -> void:
	var add_speed := target_speed - velocity.dot(wish_dir)
	if add_speed <= 0.0:
		return
	velocity += wish_dir * minf(acceleration * target_speed * delta, add_speed)


func _air_accelerate(wish_dir: Vector3, target_speed: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var limit := maxf(horizontal.length(), target_speed)
	horizontal = (horizontal + wish_dir * air_acceleration * target_speed * delta).limit_length(limit)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _update_stance(on_floor: bool, delta: float) -> void:
	if not is_dead() and not is_downed():
		_choose_stance(on_floor)
	var head_height := downed_head_height if is_dead() or is_downed() else _stand_head_height - (_stand_height - crouch_height if is_crouching() else 0.0)
	head.position.y = move_toward(head.position.y, head_height, crouch_camera_speed * delta)


func _choose_stance(on_floor: bool) -> void:
	var crouch_held := Input.is_action_pressed("crouch")
	if not crouch_held:
		if _stance != Stance.STANDING and _has_room_to_stand():
			_set_stance(Stance.STANDING)
		elif _stance == Stance.SLIDING:
			_set_stance(Stance.CROUCHED)
	elif _stance == Stance.SLIDING:
		if not on_floor or _horizontal_speed() <= crouch_speed:
			_set_stance(Stance.CROUCHED)
	elif on_floor and _horizontal_speed() >= slide_min_speed:
		_start_slide()
	else:
		_set_stance(Stance.CROUCHED)


func _start_slide() -> void:
	_set_stance(Stance.SLIDING)
	if _slide_cooldown_left > 0.0:
		return
	_slide_cooldown_left = slide_cooldown
	var speed := _horizontal_speed()
	var boosted := maxf(speed, minf(speed + slide_boost, slide_max_speed))
	velocity.x *= boosted / speed
	velocity.z *= boosted / speed


func _set_stance(stance: Stance) -> void:
	_stance = stance
	_shape.height = crouch_height if is_crouching() else _stand_height
	_collision.position.y = _shape.height / 2.0


func _has_room_to_stand() -> bool:
	var standing := CapsuleShape3D.new()
	standing.radius = _shape.radius
	standing.height = _stand_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	var floor_clearance := 0.05
	query.transform = global_transform.translated(Vector3.UP * (_stand_height / 2.0 + floor_clearance))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
