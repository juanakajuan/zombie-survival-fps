class_name DebugMenu
extends CanvasLayer
## A table of play-test commands for a debug build. It pauses the game tree while it shows.
## Player opens it on the debug_menu action. Esc, F1, or the Close button emits close_requested, and Player closes it.

signal close_requested

@export var point_grants: Array[int] = [500, 5000]
## One "give weapon" command for each entry.
@export var weapons: Array[WeaponData] = []
@export var button_size: Vector2 = Vector2(220.0, 40.0)

## Player sets it. Every command acts on it.
var player: Player
## The level sets it. Without one, the round commands do nothing.
var round_manager: RoundManager

@onready var close_button: Button = %CloseButton
@onready var _grid: GridContainer = %Commands

var _commands: Dictionary[String, Callable] = {}
var _god_button: Button


func _ready() -> void:
	hide()
	close_button.pressed.connect(close_requested.emit)
	for grant: int in point_grants:
		_add_command("+%d POINTS" % grant, _give_points.bind(grant))
	for data: WeaponData in weapons:
		_add_command("GIVE " + data.display_name, _give_weapon.bind(data))
	_add_command("REFILL AMMO", _refill_ammo)
	_add_command("FULL HEALTH", _full_health)
	_god_button = _add_command("GOD MODE", _toggle_god_mode)
	_add_command("KILL ALL ZOMBIES", _kill_zombies)
	_add_command("SKIP BREAK", _skip_break)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("debug_menu")):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func open() -> void:
	_update_god_text()
	show()
	get_tree().paused = true
	close_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


func is_open() -> bool:
	return visible


## The label of each command, in the order of the menu.
func command_labels() -> PackedStringArray:
	return PackedStringArray(_commands.keys())


## Runs the command with this label, as a click on its button does.
func run_command(label: String) -> void:
	if not _commands.has(label):
		push_error("DebugMenu: no command named %s." % label)
		return
	var run: Callable = _commands[label]
	run.call()


## The text of the god mode button.
func god_mode_text() -> String:
	return _god_button.text


func _add_command(label: String, run: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = button_size
	button.pressed.connect(run_command.bind(label))
	_grid.add_child(button)
	_commands[label] = run
	return button


func _give_points(amount: int) -> void:
	player.wallet.add(amount)


func _give_weapon(data: WeaponData) -> void:
	player.weapon.equip(data)


func _refill_ammo() -> void:
	var weapon := player.weapon
	weapon.ammo = weapon.data.magazine_size
	weapon.reserve = weapon.data.max_reserve


func _full_health() -> void:
	player.health.reset()


func _toggle_god_mode() -> void:
	player.health.invulnerable = not player.health.invulnerable
	_update_god_text()


func _kill_zombies() -> void:
	if round_manager != null:
		round_manager.kill_all()


func _skip_break() -> void:
	if round_manager != null:
		round_manager.skip_break()


func _update_god_text() -> void:
	if player != null:
		_god_button.text = "GOD MODE: %s" % ("ON" if player.health.invulnerable else "OFF")
