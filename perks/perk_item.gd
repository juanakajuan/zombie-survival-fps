class_name PerkItem
extends BuyItem
## A perk that a perk machine sells. The player keeps it until 0 health. Each value changes one stat while the perk is
## held, and a value at its default changes nothing.

## The short text on the perk's HUD icon.
@export var icon_text: String = "?"
@export var icon_color: Color = Color(1, 1, 1, 1)
## Added to the player's max health, and to the current health when the perk is bought.
@export_range(0.0, 1000.0, 1.0) var max_health_bonus: float = 0.0
## Multiplies the reload time of every weapon.
@export_range(0.1, 1.0, 0.05) var reload_time_scale: float = 1.0
## Multiplies the time between shots of every weapon.
@export_range(0.1, 1.0, 0.05) var fire_interval_scale: float = 1.0
## Above 0, the player is downed at 0 health instead of dead, and stands up after this many seconds. Without such a
## perk, the player dies at once.
@export_range(0.0, 30.0, 0.5, "suffix:s") var self_revive_time: float = 0.0
## The fraction of max health that the self-revive stands the player up with.
@export_range(0.05, 1.0, 0.05) var self_revive_health: float = 0.5


func can_apply(player: Player) -> bool:
	return player.perks.can_add(self)


func apply(player: Player) -> void:
	player.perks.add(self)
