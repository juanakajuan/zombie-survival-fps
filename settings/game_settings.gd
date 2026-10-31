class_name GameSettings
extends RefCounted
## The settings that the player changes in the pause menu. They are saved to `file_path` between runs.

const SECTION := "settings"

static var file_path: String = "user://settings.cfg"

var mouse_sensitivity_scale: float = 1.0
var field_of_view: float = 80.0
## Linear volume of the master bus, from 0 to 1.
var master_volume: float = 1.0
var fullscreen: bool = false
var show_fps: bool = false


## The saved settings. A missing file, or a value of the wrong type, gives the default for that value.
static func load_saved() -> GameSettings:
	var settings := GameSettings.new()
	var file := ConfigFile.new()
	if file.load(file_path) != OK:
		return settings
	settings.mouse_sensitivity_scale = _read_float(file, "mouse_sensitivity_scale", settings.mouse_sensitivity_scale)
	settings.field_of_view = _read_float(file, "field_of_view", settings.field_of_view)
	settings.master_volume = clampf(_read_float(file, "master_volume", settings.master_volume), 0.0, 1.0)
	var fullscreen_value: Variant = file.get_value(SECTION, "fullscreen", settings.fullscreen)
	if fullscreen_value is bool:
		settings.fullscreen = fullscreen_value
	var show_fps_value: Variant = file.get_value(SECTION, "show_fps", settings.show_fps)
	if show_fps_value is bool:
		settings.show_fps = show_fps_value
	return settings


func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "mouse_sensitivity_scale", mouse_sensitivity_scale)
	file.set_value(SECTION, "field_of_view", field_of_view)
	file.set_value(SECTION, "master_volume", master_volume)
	file.set_value(SECTION, "fullscreen", fullscreen)
	file.set_value(SECTION, "show_fps", show_fps)
	var err := file.save(file_path)
	if err != OK:
		push_warning("GameSettings: cannot save %s: %s" % [file_path, error_string(err)])


## Applies the settings that belong to the engine, not to the player: the volume and the window mode.
func apply_to_engine() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED)


static func _read_float(file: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = file.get_value(SECTION, key, fallback)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var number: float = value
	return number
