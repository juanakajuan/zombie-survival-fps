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
			weapon.effect_changed.disconnect(_update_effect)
		weapon = value
		weapon.fired.connect(_on_weapon_fired)
		weapon.ammo_changed.connect(_update_ammo)
		weapon.hit.connect(_on_weapon_hit)
		weapon.reload_started.connect(_update_ammo)
		weapon.reload_finished.connect(_update_ammo)
		weapon.damaged.connect(_on_damaged)
		weapon.effect_changed.connect(_update_effect)
		if is_node_ready():
			_show_weapon()
@export var melee: Melee
@export var grenades: Grenades
@export var wallet: Wallet
@export var perks: Perks
@export var powerups: Powerups
@export var health_color: Color = Color(1, 1, 1, 0.95)
@export var low_health_color: Color = Color(0.95, 0.2, 0.2)
@export_range(0.0, 1.0, 0.05) var low_health_fraction: float = 0.3
@export_group("Round counter")
## The color of the round counter.
@export var round_color: Color = Color(0.75, 0.05, 0.05)
## How big the counter gets at the start of a round, as a multiple of its size.
@export_range(1.0, 3.0, 0.05) var round_pop_scale: float = 1.45
## The seconds that the counter takes to bounce back to its size.
@export_range(0.05, 3.0, 0.05, "suffix:s") var round_pop_time: float = 0.6
## The seconds that the counter takes to fade from white back to its color.
@export_range(0.05, 3.0, 0.05, "suffix:s") var round_flash_time: float = 0.8
@export_group("Points")
@export var gain_color: Color = Color(1, 0.9, 0, 1)
@export var loss_color: Color = Color(0.95, 0.2, 0.2, 1)
## The seconds that a +10 or -500 takes to drift away and fade.
@export_range(0.1, 5.0, 0.1, "suffix:s") var popup_time: float = 1.2
## The way a popup drifts, in pixels.
@export var popup_drift: Vector2 = Vector2(-70, -50)
## Each new popup starts this many pixels lower than the one before it, for three popups. Then the row starts again.
@export_range(0.0, 60.0, 1.0, "suffix:px") var popup_spacing: float = 22.0
## How big the points get when the player earns some, as a multiple of their size.
@export_range(1.0, 2.0, 0.05) var points_bounce_scale: float = 1.25
@export_range(0.05, 2.0, 0.05, "suffix:s") var points_bounce_time: float = 0.35
@export_group("Special round")
## The color of the round number and the banner during a special round.
@export var special_color: Color = Color(0.72, 0.5, 0.95)
## The seconds that the banner shows at the start of a special round.
@export_range(0.0, 10.0, 0.1, "suffix:s") var special_banner_time: float = 3.0
@export_group("")

## Player sets it from the Show FPS setting.
@export var show_fps: bool = false

## The level sets it. Without one, the round panel stays hidden.
var round_manager: RoundManager:
	set(value):
		round_manager = value
		round_manager.round_started.connect(_update_round.unbind(1))
		round_manager.round_ended.connect(_update_round.unbind(1))
		round_manager.round_started.connect(_on_round_started.unbind(1))
		round_manager.round_ended.connect(break_sound.play.unbind(1))
		_update_round()

## What the HUD shows, as a player sees it. Tests and the verify driver read it.
class Readout extends RefCounted:
	var health_text: String
	var ammo_text: String
	## The number of grenades the icons show.
	var grenades_text: String
	## The seconds before the grenade in hand explodes, with one decimal. Empty when no grenade is in hand.
	var grenade_fuse_text: String
	var points_text: String
	## The text of each +N or -N on screen, oldest first.
	var point_popups: PackedStringArray
	## One entry for each running timed effect, in the order that they started: the name and the seconds left.
	var powerups: PackedStringArray
	var prompt_visible: bool
	var prompt_text: String
	var weapon_name: String
	## The name of the effect of the weapon in hand. Empty when it has none.
	var weapon_effect: String
	var reloading: bool
	var round_visible: bool
	var round_text: String
	## The number of tally marks that show in place of the round number. It is 0 when the number shows.
	var round_tally: int
	var round_color: Color
	var objective_text: String
	## The banner that names a special round as it starts.
	var special_banner_visible: bool
	var special_banner_text: String
	var in_break: bool
	var hit_marker: bool
	var headshot_marker: bool
	var crosshair_visible: bool
	var downed_visible: bool
	var downed_text: String
	## The opacity of the red edge that shows low health, from 0 (hidden) to 1 (at 0 health).
	var low_health_vignette: float
	var revive_visible: bool
	var revive_text: String
	## The icon text of each perk icon, in the order they show.
	var perk_icons: PackedStringArray
	var fps_visible: bool
	var fps_text: String


var _banner_left: float = 0.0
var _round_base_color: Color
var _shown_points: int = 0
var _popup_serial: int = 0
var _round_tween: Tween
var _points_tween: Tween

@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var kill_sound: AudioStreamPlayer = $KillSound
@onready var round_start_sound: AudioStreamPlayer = $RoundStartSound
@onready var special_round_sound: AudioStreamPlayer = $SpecialRoundSound
@onready var break_sound: AudioStreamPlayer = $BreakSound
@onready var _crosshair: Crosshair = %Crosshair
@onready var _health_value: Label = %HealthValue
@onready var _health_max: Label = %HealthMax
@onready var _health_bar: SegmentBar = %HealthBar
@onready var _low_health_vignette: TextureRect = %LowHealthVignette
@onready var _weapon_name: Label = %WeaponName
@onready var _weapon_effect: Label = %WeaponEffect
@onready var _ammo_value: Label = %AmmoValue
@onready var _grenade_icons: GrenadeIcons = %GrenadeIcons
@onready var _grenade_fuse: Label = %GrenadeFuse
@onready var _points_value: Label = %PointsValue
@onready var _powerup_label: Label = %PowerupLabel
@onready var _prompt: Label = %Prompt
@onready var _reload_label: Label = %ReloadLabel
@onready var _round_panel: Control = %RoundPanel
@onready var _round_value: Label = %RoundValue
@onready var _round_counter: Control = %RoundCounter
@onready var _round_tally: RoundTally = %RoundTally
@onready var _special_banner: Label = %SpecialBanner
@onready var _objective: Label = %Objective
@onready var _break_label: Label = %BreakLabel
@onready var _downed_label: Label = %DownedLabel
@onready var _revive_label: Label = %ReviveLabel
@onready var _perk_icons: HBoxContainer = %PerkIcons
@onready var _fps_label: Label = %FpsLabel
@onready var _perk_icon_template: PanelContainer = %PerkIcon
@onready var _popup_layer: Control = %PopupLayer
@onready var _popup_template: PointPopup = %PopupTemplate


func _ready() -> void:
	health.changed.connect(_on_health_changed)
	melee.damaged.connect(_on_damaged)
	grenades.damaged.connect(_on_damaged)
	grenades.changed.connect(_update_grenades)
	wallet.changed.connect(_on_points_changed)
	perks.changed.connect(_update_perks)
	_on_health_changed(health.current)
	_show_weapon()
	_update_grenades(grenades.count)
	_update_points()
	_update_round()


func _process(delta: float) -> void:
	_banner_left -= delta
	_special_banner.visible = _banner_left > 0.0
	_crosshair.visible = weapon.wielder == null or not weapon.wielder.is_aiming()
	_update_objective()
	_update_prompt()
	_update_powerups()
	_update_grenade_fuse()
	_update_fps()


func readout() -> Readout:
	var r := Readout.new()
	r.health_text = _health_value.text
	r.ammo_text = _ammo_value.text
	r.grenades_text = str(_grenade_icons.count)
	_update_grenade_fuse()
	r.grenade_fuse_text = _grenade_fuse.text if _grenade_fuse.visible else ""
	r.points_text = _points_value.text
	for popup: Node in _popup_layer.get_children():
		if popup != _popup_template and not popup.is_queued_for_deletion():
			r.point_popups.append((popup as PointPopup).text)
	_update_powerups()
	r.powerups = _powerup_lines()
	_update_prompt()
	r.prompt_visible = _prompt.visible
	r.prompt_text = _prompt.text
	r.weapon_name = _weapon_name.text
	r.weapon_effect = _weapon_effect.text if _weapon_effect.visible else ""
	r.reloading = _reload_label.is_visible_in_tree()
	r.round_visible = _round_panel.is_visible_in_tree()
	r.round_text = _round_value.text
	r.round_tally = _round_tally.count if _round_tally.visible else 0
	r.round_color = _round_base_color
	_update_objective()
	r.objective_text = _objective.text
	r.in_break = _break_label.is_visible_in_tree()
	r.special_banner_visible = _special_banner.is_visible_in_tree()
	r.special_banner_text = _special_banner.text
	r.hit_marker = _crosshair.hit_marker_visible()
	r.headshot_marker = _crosshair.headshot_marker_visible()
	r.crosshair_visible = _crosshair.is_visible_in_tree()
	r.downed_visible = _downed_label.is_visible_in_tree()
	r.downed_text = _downed_label.text
	r.low_health_vignette = _low_health_vignette.modulate.a if _low_health_vignette.visible else 0.0
	r.revive_visible = _revive_label.is_visible_in_tree()
	r.revive_text = _revive_label.text
	for icon: Node in _perk_icons.get_children():
		if icon != _perk_icon_template:
			r.perk_icons.append((icon.get_child(0) as Label).text)
	_update_fps()
	r.fps_visible = _fps_label.is_visible_in_tree()
	r.fps_text = _fps_label.text
	return r


## The scale of the round counter. It is above 1 while the counter pops at the start of a round.
func round_counter_scale() -> float:
	return _round_counter.scale.x


## The color that the round counter shows now. It is white at the start of a round and fades to its color.
func round_counter_color() -> Color:
	return _round_tally.color if _round_tally.visible else _round_value.get_theme_color("font_color")


## Shows the seconds that a downed player has left, and the seconds until `revive_name` stands the player up.
func show_downed(time_left: float, revive_name: String, revive_left: float) -> void:
	_downed_label.text = "DOWNED  %d" % ceili(time_left)
	_downed_label.visible = true
	_revive_label.text = "%s  GETTING UP IN %d" % [revive_name, ceili(revive_left)]
	_revive_label.visible = true


func hide_downed() -> void:
	_downed_label.visible = false
	_revive_label.visible = false


func _on_health_changed(current: float) -> void:
	_health_bar.max_value = health.max_health
	_health_max.text = "/ %d" % ceili(health.max_health)
	_health_value.text = str(ceili(current))
	_health_bar.value = current
	var low_health := health.max_health * low_health_fraction
	var color := low_health_color if current <= low_health else health_color
	_health_value.add_theme_color_override("font_color", color)
	_health_bar.fill_color = color
	_low_health_vignette.visible = current < low_health
	_low_health_vignette.modulate.a = clampf(1.0 - current / low_health, 0.0, 1.0)


func _show_weapon() -> void:
	_weapon_name.text = weapon.data.display_name
	_update_effect()
	_update_ammo()


func _update_effect() -> void:
	if not is_node_ready():
		return
	_weapon_effect.visible = weapon.effect != null
	if weapon.effect != null:
		_weapon_effect.text = weapon.effect.display_name
		_weapon_effect.add_theme_color_override("font_color", weapon.effect.color)


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


func _update_grenades(count: int) -> void:
	_grenade_icons.count = count


func _update_grenade_fuse() -> void:
	_grenade_fuse.visible = grenades.has_grenade_in_hand()
	_grenade_fuse.text = "%.1f" % grenades.fuse_left()


func _update_perks() -> void:
	for icon: Node in _perk_icons.get_children():
		if icon != _perk_icon_template:
			icon.free()
	for perk: PerkItem in perks.held:
		var icon := _perk_icon_template.duplicate() as PanelContainer
		icon.visible = true
		var style := icon.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.bg_color = perk.icon_color
		icon.add_theme_stylebox_override("panel", style)
		(icon.get_child(0) as Label).text = perk.icon_text
		_perk_icons.add_child(icon)


func _update_points() -> void:
	_shown_points = wallet.points
	_points_value.text = str(wallet.points)


func _on_points_changed(points: int) -> void:
	var change := points - _shown_points
	_update_points()
	if change == 0:
		return
	_spawn_popup(change)
	if change > 0:
		_bounce_points()


func _spawn_popup(change: int) -> void:
	var popup := _popup_template.duplicate() as PointPopup
	popup.visible = true
	popup.text = "%+d" % change
	popup.add_theme_color_override("font_color", gain_color if change > 0 else loss_color)
	popup.position += Vector2(0.0, (_popup_serial % 3) * popup_spacing)
	_popup_serial += 1
	_popup_layer.add_child(popup)
	popup.play(popup_drift, popup_time)


func _bounce_points() -> void:
	if _points_tween != null:
		_points_tween.kill()
	_points_value.scale = Vector2.ONE * points_bounce_scale
	_points_tween = create_tween()
	_points_tween.tween_property(_points_value, "scale", Vector2.ONE, points_bounce_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_powerups() -> void:
	var lines := _powerup_lines()
	_powerup_label.visible = not lines.is_empty()
	_powerup_label.text = "\n".join(lines)


func _powerup_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for item: TimedItem in powerups.running():
		lines.append("%s  %d" % [item.display_name, ceili(powerups.time_left(item))])
	return lines


func _update_fps() -> void:
	_fps_label.visible = show_fps
	if show_fps:
		_fps_label.text = "%d FPS" % roundi(Engine.get_frames_per_second())


func _update_prompt() -> void:
	var focused := weapon.wielder.focused() if weapon.wielder != null else null
	var text := focused.prompt_text(weapon.wielder) if focused != null else ""
	_prompt.visible = not text.is_empty()
	_prompt.text = text


func _update_round() -> void:
	_round_panel.visible = round_manager != null and round_manager.round_number > 0
	if not _round_panel.visible:
		return
	var number := round_manager.round_number
	_round_value.text = str(number)
	var tally_marks := number if number <= 5 else 0
	_round_tally.count = tally_marks
	_round_tally.visible = tally_marks > 0
	_round_value.visible = tally_marks == 0
	_round_base_color = special_color if round_manager.is_special_round() else round_color
	_paint_round(_round_base_color)
	_break_label.visible = round_manager.state == RoundManager.State.BREAK
	_update_objective()


func _paint_round(color: Color) -> void:
	_round_tally.color = color
	_round_value.add_theme_color_override("font_color", color)


## Flashes the counter white and pops it big, then lets both settle back.
func _pop_round() -> void:
	if _round_tween != null:
		_round_tween.kill()
	_round_counter.scale = Vector2.ONE * round_pop_scale
	_flash_round(1.0)
	_round_tween = create_tween()
	_round_tween.set_parallel(true)
	_round_tween.tween_property(_round_counter, "scale", Vector2.ONE, round_pop_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_round_tween.tween_method(_flash_round, 1.0, 0.0, round_flash_time)


func _flash_round(whiteness: float) -> void:
	_paint_round(_round_base_color.lerp(Color.WHITE, whiteness))


func _on_round_started() -> void:
	_pop_round()
	if not round_manager.is_special_round():
		round_start_sound.play()
		return
	special_round_sound.play()
	_banner_left = special_banner_time
	_special_banner.visible = special_banner_time > 0.0


func _update_objective() -> void:
	if round_manager == null or not _round_panel.visible:
		return
	if round_manager.state == RoundManager.State.BREAK:
		_objective.text = "NEXT ROUND IN %d" % ceili(round_manager.break_time_left())
	else:
		_objective.text = ("%d MUTTS LEFT" if round_manager.is_special_round() else "%d LEFT") % round_manager.zombies_left()
