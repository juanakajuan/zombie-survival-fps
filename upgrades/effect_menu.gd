class_name EffectMenu
extends CanvasLayer
## Lists weapon effects and pauses the game tree while it shows. Player opens it after the second upgrade.
## The points are already spent, so the menu has no cancel: Esc does nothing, and a button emits `chosen`.

signal chosen(effect: WeaponEffect)

@export var button_size: Vector2 = Vector2(320.0, 64.0)
@export_range(8, 64, 1, "suffix:px") var font_size: int = 32

@onready var _list: VBoxContainer = %Effects

var _effects: Array[WeaponEffect] = []


func _ready() -> void:
	hide()


## Shows one button for each effect, takes the focus to the first one, and pauses the tree.
func open(effects: Array[WeaponEffect]) -> void:
	for old: Node in _list.get_children():
		_list.remove_child(old)
		old.queue_free()
	_effects = effects.duplicate()
	for effect: WeaponEffect in _effects:
		var button := Button.new()
		button.text = effect.display_name
		button.custom_minimum_size = button_size
		button.add_theme_font_size_override("font_size", font_size)
		button.add_theme_color_override("font_color", effect.color)
		button.add_theme_color_override("font_focus_color", effect.color)
		button.add_theme_color_override("font_hover_color", effect.color)
		button.pressed.connect(chosen.emit.bind(effect))
		_list.add_child(button)
	show()
	get_tree().paused = true
	(_list.get_child(0) as Button).grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


func is_open() -> bool:
	return visible


## The name on each button, in the order of the menu.
func effect_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for effect: WeaponEffect in _effects:
		labels.append(effect.display_name)
	return labels


## Selects the effect with this name, as a click on its button does.
func select(label: String) -> void:
	for effect: WeaponEffect in _effects:
		if effect.display_name == label:
			chosen.emit(effect)
			return
	push_error("EffectMenu: no effect named %s." % label)
