class_name Hud
extends CanvasLayer

@export var health: Health
## The weapon whose name and ammo show. Player sets it on each switch.
@export var weapon: Weapon:
	set(value):
		if weapon != null:
			weapon.fired.disconnect(_on_weapon_fired)
			weapon.ammo_changed.disconnect(_update_ammo)
			weapon.hit.disconnect(_on_weapon_hit)
			weapon.reload_started.disconnect(_update_ammo)
			weapon.reload_finished.disconnect(_update_ammo)
			weapon.damaged.disconnect(_on_damaged)
		weapon = value
		weapon.fired.connect(_on_weapon_fired)
		weapon.ammo_changed.connect(_update_ammo)
		weapon.hit.connect(_on_weapon_hit)
		weapon.reload_started.connect(_update_ammo)
		weapon.reload_finished.connect(_update_ammo)
		weapon.damaged.connect(_on_damaged)
		if is_node_ready():
			_show_weapon()
@export var melee: Melee
@export var wallet: Wallet
@export var health_color: Color = Color(1, 1, 1, 0.95)
@export var low_health_color: Color = Color(0.95, 0.2, 0.2)
@export_range(0.0, 1.0, 0.05) var low_health_fraction: float = 0.3

## The level sets it. Without one, the round panel stays hidden.
var round_manager: RoundManager:
	set(value):
		round_manager = value
		round_manager.round_started.connect(_update_round.unbind(1))
		round_manager.round_ended.connect(_update_round.unbind(1))
		round_manager.round_started.connect(round_start_sound.play.unbind(1))
		round_manager.round_ended.connect(break_sound.play.unbind(1))
		_update_round()

## What the HUD shows, as a player sees it. Tests and the verify driver read it.
class Readout extends RefCounted:
	var health_text: String
	var ammo_text: String
	var points_text: String
	var prompt_visible: bool
	var prompt_text: String
	var weapon_name: String
	var reloading: bool
	var round_visible: bool
	var round_text: String
	var objective_text: String
	var in_break: bool
	var hit_marker: bool
	var headshot_marker: bool
	var crosshair_visible: bool


@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var kill_sound: AudioStreamPlayer = $KillSound
@onready var round_start_sound: AudioStreamPlayer = $RoundStartSound
@onready var break_sound: AudioStreamPlayer = $BreakSound
@onready var _crosshair: Crosshair = %Crosshair
@onready var _health_value: Label = %HealthValue
@onready var _health_max: Label = %HealthMax
@onready var _health_bar: SegmentBar = %HealthBar
@onready var _weapon_name: Label = %WeaponName
@onready var _ammo_value: Label = %AmmoValue
@onready var _points_value: Label = %PointsValue
@onready var _prompt: Label = %Prompt
@onready var _reload_label: Label = %ReloadLabel
@onready var _round_panel: Control = %RoundPanel
@onready var _round_value: Label = %RoundValue
@onready var _objective: Label = %Objective
@onready var _break_label: Label = %BreakLabel


func _ready() -> void:
	health.changed.connect(_on_health_changed)
	melee.damaged.connect(_on_damaged)
	wallet.changed.connect(_update_points.unbind(1))
	_health_bar.max_value = health.max_health
	_health_max.text = "/ %d" % ceili(health.max_health)
	_on_health_changed(health.current)
	_show_weapon()
	_update_points()
	_update_round()


func _process(_delta: float) -> void:
	_crosshair.visible = weapon.wielder == null or not weapon.wielder.is_aiming()
	_update_objective()
	_update_prompt()


func readout() -> Readout:
	var r := Readout.new()
	r.health_text = _health_value.text
	r.ammo_text = _ammo_value.text
	r.points_text = _points_value.text
	_update_prompt()
	r.prompt_visible = _prompt.visible
	r.prompt_text = _prompt.text
	r.weapon_name = _weapon_name.text
	r.reloading = _reload_label.is_visible_in_tree()
	r.round_visible = _round_panel.is_visible_in_tree()
	r.round_text = _round_value.text
	_update_objective()
	r.objective_text = _objective.text
	r.in_break = _break_label.is_visible_in_tree()
	r.hit_marker = _crosshair.hit_marker_visible()
	r.headshot_marker = _crosshair.headshot_marker_visible()
	r.crosshair_visible = _crosshair.is_visible_in_tree()
	return r


func _on_health_changed(current: float) -> void:
	_health_value.text = str(ceili(current))
	_health_bar.value = current
	var color := low_health_color if current <= health.max_health * low_health_fraction else health_color
	_health_value.add_theme_color_override("font_color", color)
	_health_bar.fill_color = color


func _show_weapon() -> void:
	_weapon_name.text = weapon.data.display_name
	_update_ammo()


func _on_weapon_fired() -> void:
	_crosshair.shot()


func _on_weapon_hit(collider: Object, _position: Vector3) -> void:
	var node := collider as Node
	if node != null and Health.find_on(node) != null:
		_crosshair.hit()


func _on_damaged(_target: Node, killed: bool, headshot: bool) -> void:
	if headshot:
		_crosshair.hit(true)
	(kill_sound if killed else hit_sound).play()


func _update_ammo() -> void:
	if not is_node_ready():
		return
	_ammo_value.text = "%d / %d" % [weapon.ammo, weapon.reserve]
	_reload_label.visible = weapon.is_reloading()


func _update_points() -> void:
	_points_value.text = str(wallet.points)


func _update_prompt() -> void:
	var focused := weapon.wielder.focused() if weapon.wielder != null else null
	var text := focused.prompt_text(weapon.wielder) if focused != null else ""
	_prompt.visible = not text.is_empty()
	_prompt.text = text


func _update_round() -> void:
	_round_panel.visible = round_manager != null and round_manager.round_number > 0
	if not _round_panel.visible:
		return
	_round_value.text = str(round_manager.round_number)
	_break_label.visible = round_manager.state == RoundManager.State.BREAK
	_update_objective()


func _update_objective() -> void:
	if round_manager == null or not _round_panel.visible:
		return
	if round_manager.state == RoundManager.State.BREAK:
		_objective.text = "NEXT ROUND IN %d" % ceili(round_manager.break_time_left())
	else:
		_objective.text = "%d LEFT" % round_manager.zombies_left()
