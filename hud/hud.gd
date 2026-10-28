class_name Hud
extends CanvasLayer
## Shows the player's health, the rounds in the magazine, when the weapon reloads, the round, and the break between rounds.

@export var health: Health
@export var weapon: Weapon
## If it is empty, the HUD uses the first RoundManager in the tree. Without one, the round panel stays hidden.
@export var round_manager: RoundManager
@export var health_color: Color = Color(0.35, 0.85, 0.4)
@export var low_health_color: Color = Color(0.95, 0.25, 0.2)
@export_range(0.0, 1.0, 0.05) var low_health_fraction: float = 0.3

## What the HUD shows, as a player sees it. Tests and the verify driver read it.
class Readout extends RefCounted:
	var health_text: String
	var ammo_text: String
	var reloading: bool
	var round_visible: bool
	var round_text: String
	var in_break: bool


@onready var _health_value: Label = %HealthValue
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _ammo_value: Label = %AmmoValue
@onready var _reload_label: Label = %ReloadLabel
@onready var _round_panel: Control = %RoundPanel
@onready var _round_value: Label = %RoundValue
@onready var _break_label: Label = %BreakLabel


func _ready() -> void:
	health.changed.connect(_on_health_changed)
	weapon.fired.connect(_update_ammo)
	weapon.reload_started.connect(_update_ammo)
	weapon.reload_finished.connect(_update_ammo)
	_health_bar.max_value = health.max_health
	_on_health_changed(health.current)
	_update_ammo()
	if round_manager == null:
		round_manager = get_tree().get_first_node_in_group(RoundManager.GROUP) as RoundManager
	if round_manager != null:
		round_manager.round_started.connect(_update_round.unbind(1))
		round_manager.round_ended.connect(_update_round.unbind(1))
	_update_round()


func readout() -> Readout:
	var r := Readout.new()
	r.health_text = _health_value.text
	r.ammo_text = _ammo_value.text
	r.reloading = _reload_label.is_visible_in_tree()
	r.round_visible = _round_panel.is_visible_in_tree()
	r.round_text = _round_value.text
	r.in_break = _break_label.is_visible_in_tree()
	return r


func _on_health_changed(current: float) -> void:
	_health_value.text = str(ceili(current))
	_health_bar.value = current
	var color := low_health_color if current <= health.max_health * low_health_fraction else health_color
	_health_value.add_theme_color_override("font_color", color)
	var fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = color


func _update_ammo() -> void:
	_ammo_value.text = "%d / %d" % [weapon.ammo, weapon.data.magazine_size]
	_reload_label.visible = weapon.is_reloading()


func _update_round() -> void:
	_round_panel.visible = round_manager != null and round_manager.round_number > 0
	if not _round_panel.visible:
		return
	_round_value.text = str(round_manager.round_number)
	_break_label.visible = round_manager.state == RoundManager.State.BREAK
