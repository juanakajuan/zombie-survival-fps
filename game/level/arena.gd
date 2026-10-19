class_name Arena
extends Node3D
## The script of game/level/arena.tscn. The scene holds the geometry, the lights, the stations, and the spawn markers.
## This script reads the markers and bakes the navigation mesh from the scene geometry.

const START_ZONE: StringName = &"yard"

## Every static body under it is walkable or is an obstacle for the bake. The door blockers and the secret panel are outside it, so the mesh is continuous through each door gap.
@onready var navigation: NavigationRegion3D = $Navigation
## The origin is the player feet. The player faces the -Z axis of the marker.
@onready var player_spawn: Transform3D = ($PlayerSpawn as Marker3D).transform

## The spawn points of each zone, by zone id. The id is the lower case name of the marker group.
var zone_spawns: Dictionary[StringName, Array] = {}
var open_zones: Array[StringName] = [START_ZONE]
## In scene tree order.
var stations: Array[Station] = []
var machines: Array[Machine] = []
var box: MysteryBox = null


## Bakes at once, so zombies can path on the first physics tick. The children are ready, so the box crate is in the bake.
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


## No change if the zone is open.
func open_zone(zone: StringName) -> void:
	if not zone_spawns.has(zone):
		push_error("Arena: no zone has the id \"%s\"." % zone)
		return
	if not open_zones.has(zone):
		open_zones.append(zone)


## The spawn points of the open zones, in zone order of opening and then marker order.
func spawns() -> Array[Vector3]:
	var found: Array[Vector3] = []
	for zone: StringName in open_zones:
		found.append_array(zone_spawns[zone])
	return found


func _power_on() -> void:
	for machine: Machine in machines:
		machine.powered = true
