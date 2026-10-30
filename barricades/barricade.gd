class_name Barricade
extends Interactable
## Boards over a window or a gate. Zombies come through it from the +Z side, and the -Z axis points into the play area.
## A zombie that stands in the zone pulls the boards off one at a time, and walks through when none are left. The player
## holds the interact action to put them back. The body is on physics layer 3, so only the player collides with it:
## zombies and shots pass the plane.

signal boards_changed(boards: int)

const GROUP := &"barricade"

## The opening: width, height, and depth. The origin is at the bottom center.
@export var size: Vector3 = Vector3(2.0, 2.5, 0.5)
@export_range(1, 10) var max_boards: int = 5
## The seconds of holding interact for each board.
@export_range(0.1, 10.0, 0.1, "suffix:s") var repair_time: float = 1.0
## The depth of the zone outside the opening in which a zombie stops to pull boards.
@export_range(0.1, 3.0, 0.05, "suffix:m") var zone_depth: float = 0.6
@export var board_material: Material

var boards: int

var _repair_progress: float = 0.0

@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _boards_root: Node3D = $Boards
@onready var _zone: Area3D = $Zone
@onready var _zone_shape: CollisionShape3D = $Zone/CollisionShape3D


func _ready() -> void:
	boards = max_boards
	var shape := BoxShape3D.new()
	shape.size = size
	_collider.shape = shape
	_collider.position = Vector3(0.0, size.y / 2.0, 0.0)
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(size.x, size.y, zone_depth)
	_zone_shape.shape = zone_box
	_zone_shape.position = Vector3(0.0, size.y / 2.0, size.z / 2.0 + zone_depth / 2.0)
	_build_boards()
	_zone.body_entered.connect(_on_zone_body_entered)
	_zone.body_exited.connect(_on_zone_body_exited)


func is_full() -> bool:
	return boards >= max_boards


func has_boards() -> bool:
	return boards > 0


## Pulls one board off. Does nothing with no boards left.
func remove_board() -> void:
	if boards > 0:
		_set_boards(boards - 1)


## Whether the point is on the -Z side of the opening, the side of the play area.
func is_inside(point: Vector3) -> bool:
	return (point - global_position).dot(-global_basis.z) > 0.0


## A point 1 m inside the opening, on the floor. A zombie that walks here has passed the barricade.
func inside_point() -> Vector3:
	return global_position - global_basis.z


func prompt_text(_player: Player) -> String:
	if is_full():
		return ""
	return "HOLD E  REPAIR  %d/%d" % [boards, max_boards]


## Adds up the time of the hold. Each repair_time puts back one board and pays for it.
func hold(player: Player, delta: float) -> void:
	if is_full():
		_repair_progress = 0.0
		return
	_repair_progress += delta
	if _repair_progress < repair_time:
		return
	_repair_progress -= repair_time
	_set_boards(boards + 1)
	player.wallet.reward_board()
	if is_full():
		_repair_progress = 0.0


func _set_boards(count: int) -> void:
	boards = count
	for i: int in _boards_root.get_child_count():
		(_boards_root.get_child(i) as Node3D).visible = i < boards
	boards_changed.emit(boards)


func _build_boards() -> void:
	var plank_height := size.y / max_boards * 0.7
	for i: int in max_boards:
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x, plank_height, size.z * 0.5)
		plank.mesh = mesh
		plank.material_override = board_material
		plank.position = Vector3(0.0, size.y * (i + 0.5) / max_boards, 0.0)
		_boards_root.add_child(plank)


func _on_zone_body_entered(body: Node3D) -> void:
	if body is Zombie:
		(body as Zombie).blocker = self


func _on_zone_body_exited(body: Node3D) -> void:
	if body is Zombie and (body as Zombie).blocker == self:
		(body as Zombie).blocker = null
