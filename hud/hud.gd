class_name Hud
extends CanvasLayer
## Shows the player's health, the rounds in the magazine, and when the weapon reloads.

@export var health: Health
@export var weapon: Weapon
@export var health_color: Color = Color(0.35, 0.85, 0.4)
@export var low_health_color: Color = Color(0.95, 0.25, 0.2)
@export_range(0.0, 1.0, 0.05) var low_health_fraction: float = 0.3

@onready var _health_value: Label = %HealthValue
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _ammo_value: Label = %AmmoValue
@onready var _reload_label: Label = %ReloadLabel


func _ready() -> void:
	health.changed.connect(_on_health_changed)
	weapon.fired.connect(_update_ammo)
	weapon.reload_started.connect(_update_ammo)
	weapon.reload_finished.connect(_update_ammo)
	_health_bar.max_value = health.max_health
	_on_health_changed(health.current)
	_update_ammo()


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
