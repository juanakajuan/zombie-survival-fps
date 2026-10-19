class_name Secret
extends Node3D
## The sigils, the panel, and the cache of one secret. Its children are the Sigil nodes, a StaticBody3D named Panel, and a Cache named Cache.
## When every sigil is lit, the panel sinks and the cache shows.

const PANEL_SINK_SECONDS: float = 1.0
const PANEL_SINK_DEPTH: float = 3.2

var revealed: bool = false

@onready var panel: StaticBody3D = $Panel
@onready var cache: Cache = $Cache
var _sigils: Array[Sigil] = []


func _ready() -> void:
	for node: Node in find_children("*", "Sigil", false):
		var sigil: Sigil = node as Sigil
		_sigils.append(sigil)
		sigil.lit.connect(_on_sigil_lit)


func _on_sigil_lit() -> void:
	if revealed:
		return
	for sigil: Sigil in _sigils:
		if not sigil.is_lit:
			return
	revealed = true
	cache.reveal()
	panel.collision_layer = 0
	var tween: Tween = create_tween()
	tween.tween_property(panel, "position:y", panel.position.y - PANEL_SINK_DEPTH, PANEL_SINK_SECONDS)
	tween.tween_callback(panel.queue_free)
