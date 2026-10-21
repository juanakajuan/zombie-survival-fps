class_name Perks
extends RefCounted

enum Kind { MENDER, RAPID, QUICK_HANDS, TOUGH }

signal granted(kind: Kind)

var owned: Array[Kind] = []


func has(kind: Kind) -> bool:
	return owned.has(kind)


func grant(kind: Kind) -> void:
	if has(kind):
		return
	owned.append(kind)
	granted.emit(kind)


static func display_name(kind: Kind) -> String:
	match kind:
		Kind.MENDER:
			return "Mender"
		Kind.RAPID:
			return "Rapid"
		Kind.QUICK_HANDS:
			return "Quick Hands"
	return "Tough"


static func color(kind: Kind) -> Color:
	match kind:
		Kind.MENDER:
			return Color(0.35, 0.9, 0.45)
		Kind.RAPID:
			return Color(1.0, 0.55, 0.2)
		Kind.QUICK_HANDS:
			return Color(0.35, 0.7, 1.0)
	return Color(0.9, 0.25, 0.3)
