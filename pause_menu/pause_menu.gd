class_name PauseMenu
extends CanvasLayer
## Pauses the game tree while it shows, and edits a GameSettings. Player opens it on Esc.
## Esc or the Resume button emits resume_requested. Player then closes it and takes the mouse back.

signal resume_requested
## Emitted each time the player changes a value. The settings are saved when the menu closes.
signal settings_changed

@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var fov_slider: HSlider = %FovSlider
@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var resume_button: Button = %ResumeButton
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _fov_value: Label = %FovValue
@onready var _volume_value: Label = %VolumeValue
@onready var _quit_button: Button = %QuitButton

var _settings: GameSettings


func _ready() -> void:
	hide()
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	fov_slider.value_changed.connect(_on_fov_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	resume_button.pressed.connect(resume_requested.emit)
	_quit_button.pressed.connect(get_tree().quit)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


## Shows the menu with the values of `settings` and pauses the tree. The menu changes `settings` in place.
func open(settings: GameSettings) -> void:
	_settings = settings
	sensitivity_slider.set_value_no_signal(settings.mouse_sensitivity_scale)
	fov_slider.set_value_no_signal(settings.field_of_view)
	volume_slider.set_value_no_signal(settings.master_volume)
	fullscreen_toggle.set_pressed_no_signal(settings.fullscreen)
	_update_value_labels()
	show()
	get_tree().paused = true
	resume_button.grab_focus()


## Hides the menu, saves the settings, and resumes the tree.
func close() -> void:
	hide()
	get_tree().paused = false
	_settings.save()


func is_open() -> bool:
	return visible


func _on_sensitivity_changed(value: float) -> void:
	_settings.mouse_sensitivity_scale = value
	_changed()


func _on_fov_changed(value: float) -> void:
	_settings.field_of_view = value
	_changed()


func _on_volume_changed(value: float) -> void:
	_settings.master_volume = value
	_changed()


func _on_fullscreen_toggled(on: bool) -> void:
	_settings.fullscreen = on
	_changed()


func _changed() -> void:
	_update_value_labels()
	settings_changed.emit()


func _update_value_labels() -> void:
	_sensitivity_value.text = "%.2fx" % sensitivity_slider.value
	_fov_value.text = "%d°" % roundi(fov_slider.value)
	_volume_value.text = "%d%%" % roundi(volume_slider.value * 100.0)
