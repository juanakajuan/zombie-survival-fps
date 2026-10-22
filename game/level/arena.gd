class_name Arena
extends Node3D

const START_ZONE: StringName = &"yard"

## Every static body under it is walkable or is an obstacle for the bake. The door blockers and the secret panel are outside it, so the mesh is continuous through each door gap.
@onready var navigation: NavigationRegion3D = $Navigation
@onready var player_spawn: Transform3D = ($PlayerSpawn as Marker3D).transform

## The spawn points of each zone, by zone id. The id is the lower case name of the marker group.
var zone_spawns: Dictionary[StringName, Array] = {}
var open_zones: Array[StringName] = [START_ZONE]
var stations: Array[Station] = []
var machines: Array[Machine] = []
var box: MysteryBox = null


static func create() -> Arena:
	var arena: Arena = Arena.new()
	arena.name = &"Arena"
	ArenaLayout.build(LevelBuilder.new(arena))
	return arena


func _ready() -> void:
	for group: Node in $ZombieSpawns.get_children():
		var points: Array[Vector3] = []
		for marker: Node in group.get_children():
			points.append((marker as Marker3D).position)
		zone_spawns[StringName(group.name.to_lower())] = points
	for node: Node in find_children("*", "Area3D"):
		var station: Station = node as Station
		if station == null:
			continue
		stations.append(station)
		if station is MysteryBox:
			box = station as MysteryBox
		elif station is Machine:
			machines.append(station as Machine)
		elif station is Door:
			(station as Door).opened.connect(open_zone)
		elif station is PowerSwitch:
			(station as PowerSwitch).switched_on.connect(_power_on)
	navigation.bake_navigation_mesh(false)
	if navigation.navigation_mesh.get_polygon_count() == 0:
		push_error("Arena: the navigation bake gave an empty mesh. Zombies cannot find a path.")


func open_zone(zone: StringName) -> void:
	if not zone_spawns.has(zone):
		push_error("Arena: no zone has the id \"%s\"." % zone)
		return
	if not open_zones.has(zone):
		open_zones.append(zone)


func spawns() -> Array[Vector3]:
	var found: Array[Vector3] = []
	for zone: StringName in open_zones:
		found.append_array(zone_spawns[zone])
	return found


func _power_on() -> void:
	for machine: Machine in machines:
		machine.powered = true
