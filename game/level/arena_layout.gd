class_name ArenaLayout
extends RefCounted


static func build(b: LevelBuilder) -> void:
	var arena: Node3D = b.root
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = &"WorldEnvironment"
	var procedural_sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	procedural_sky_material.sky_top_color = Color(0.08, 0.1, 0.2, 1)
	procedural_sky_material.sky_horizon_color = Color(0.45, 0.3, 0.3, 1)
	procedural_sky_material.ground_bottom_color = Color(0.05, 0.05, 0.06, 1)
	procedural_sky_material.ground_horizon_color = Color(0.2, 0.16, 0.16, 1)
	var sky: Sky = Sky.new()
	sky.sky_material = procedural_sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.3, 0.26, 0.3, 1)
	environment.fog_density = 0.012
	world_environment.environment = environment
	b.add(arena, world_environment)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = &"Moon"
	moon.transform = Transform3D(Vector3(0.8660254, 0, -0.5), Vector3(-0.3213938, 0.76604444, -0.55667037), Vector3(0.38302222, 0.6427876, 0.66341394), Vector3(0, 0, 0))
	moon.light_color = Color(0.7, 0.75, 1, 1)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	b.add(arena, moon)
	var navigation: NavigationRegion3D = NavigationRegion3D.new()
	navigation.name = &"Navigation"
	var navigation_mesh: NavigationMesh = NavigationMesh.new()
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_collision_mask = Layers.WORLD
	navigation_mesh.cell_height = 0.1
	navigation_mesh.agent_height = 1.8
	navigation_mesh.agent_max_climb = 0.2
	navigation_mesh.agent_max_slope = 30.0
	navigation.navigation_mesh = navigation_mesh
	b.add(arena, navigation)
	b.block(navigation, &"Ground", Vector3(42, 1, 42), Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)), LevelBuilder.GROUND)
	b.block(navigation, &"NorthWall", Vector3(19, 3, 1), Transform3D(Basis.IDENTITY, Vector3(-11.5, 1.5, -20.5)), LevelBuilder.WALL)
	b.block(navigation, &"SouthWall", Vector3(42, 3, 1), Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 20.5)), LevelBuilder.WALL)
	b.block(navigation, &"WestWall", Vector3(1, 3, 40), Transform3D(Basis.IDENTITY, Vector3(-20.5, 1.5, 0)), LevelBuilder.WALL)
	b.block(navigation, &"EastWall", Vector3(1, 3, 18), Transform3D(Basis.IDENTITY, Vector3(20.5, 1.5, -11)), LevelBuilder.WALL)
	b.block(navigation, &"Cover1", Vector3(4, 1.5, 1), Transform3D(Basis.IDENTITY, Vector3(0, 0.75, -4)), LevelBuilder.COVER)
	b.block(navigation, &"Cover2", Vector3(2, 2, 2), Transform3D(Basis.IDENTITY, Vector3(8, 1, 4)), LevelBuilder.COVER)
	b.block(navigation, &"Cover3", Vector3(2, 2, 2), Transform3D(Basis.IDENTITY, Vector3(-8, 1, 6)), LevelBuilder.COVER)
	b.block(navigation, &"Cover4", Vector3(3, 1.2, 1), Transform3D(Basis.IDENTITY, Vector3(12, 0.6, -2)), LevelBuilder.COVER)
	b.block(navigation, &"Cover5", Vector3(1, 2.5, 4), Transform3D(Basis.IDENTITY, Vector3(5, 1.25, 12)), LevelBuilder.COVER)
	b.block(navigation, &"Cover6", Vector3(3, 2, 1), Transform3D(Basis.IDENTITY, Vector3(-13, 1, 10)), LevelBuilder.COVER)
	b.block(navigation, &"Cover7", Vector3(2, 2, 2), Transform3D(Basis.IDENTITY, Vector3(13, 1, 12)), LevelBuilder.COVER)
	b.block(navigation, &"Platform", Vector3(6, 1.5, 6), Transform3D(Basis.IDENTITY, Vector3(-10, 0.75, -10)), LevelBuilder.PLATFORM)
	b.block(navigation, &"Stair1", Vector3(3, 0.3, 0.4), Transform3D(Basis.IDENTITY, Vector3(-10, 0.15, -5.6)), LevelBuilder.PLATFORM)
	b.block(navigation, &"Stair2", Vector3(3, 0.6, 0.4), Transform3D(Basis.IDENTITY, Vector3(-10, 0.3, -6)), LevelBuilder.PLATFORM)
	b.block(navigation, &"Stair3", Vector3(3, 0.9, 0.4), Transform3D(Basis.IDENTITY, Vector3(-10, 0.45, -6.4)), LevelBuilder.PLATFORM)
	b.block(navigation, &"Stair4", Vector3(3, 1.2, 0.4), Transform3D(Basis.IDENTITY, Vector3(-10, 0.6, -6.8)), LevelBuilder.PLATFORM)
	b.block(navigation, &"Ramp", Vector3(5.2201533, 0.4, 4), Transform3D(Vector3(0.9578263, -0.28734788, 0), Vector3(0.28734788, 0.9578263, 0), Vector3(0, 0, 1), Vector3(-4.5574694, 0.5584347, -10)), LevelBuilder.PLATFORM)
	b.lamp(navigation, &"Lamp1", Vector3(-15, 0, -15))
	b.lamp(navigation, &"Lamp2", Vector3(15, 0, -15))
	b.lamp(navigation, &"Lamp3", Vector3(15, 0, 15))
	b.lamp(navigation, &"Lamp4", Vector3(-15, 0, 15))
	var box_crate: StaticBody3D = b.block(navigation, &"BoxCrate", Vector3(1.8, 0.9, 0.9), Transform3D(Vector3(-1, 0, 8.742278e-08), Vector3(0, 1, 0), Vector3(-8.742278e-08, 0, -1), Vector3(10, 0.45, 19.5)), LevelBuilder.CRATE)
	b.mystery_box(box_crate, &"MysteryBox")
	var wall_buys: Node3D = b.group(arena, &"WallBuys")
	b.wall_buy(wall_buys, &"SmgWallBuy", Arsenal.smg(), 1000, Transform3D(Basis.IDENTITY, Vector3(-8, 1.5, -19.95)))
	b.wall_buy(wall_buys, &"ShotgunWallBuy", Arsenal.shotgun(), 1200, Transform3D(Vector3(-4.371139e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.371139e-08), Vector3(19.95, 1.5, -8)))
	b.wall_buy(wall_buys, &"RifleWallBuy", Arsenal.rifle(), 1500, Transform3D(Vector3(-4.371139e-08, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, -4.371139e-08), Vector3(-19.95, 1.5, 8)))
	var machines: Node3D = b.group(arena, &"Machines")
	b.perk_machine(machines, &"MenderMachine", Perks.Kind.MENDER, 1500, Transform3D(Basis.IDENTITY, Vector3(8, 1.5, -19.95)))
	b.perk_machine(machines, &"RapidMachine", Perks.Kind.RAPID, 2000, Transform3D(Vector3(-4.371139e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.371139e-08), Vector3(19.95, 1.5, 8)))
	b.perk_machine(machines, &"QuickHandsMachine", Perks.Kind.QUICK_HANDS, 2500, Transform3D(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(5, 1.5, 19.95)))
	b.perk_machine(machines, &"ToughMachine", Perks.Kind.TOUGH, 3000, Transform3D(Vector3(-4.371139e-08, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, -4.371139e-08), Vector3(-19.95, 1.5, -8)))
	b.upgrade_machine(machines, &"UpgradeMachine", Transform3D(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-10, 1.5, 19.95)))
	b.marker(arena, &"PlayerSpawn", Vector3(0, 0, 6))
	var zombie_spawns: Node3D = b.group(arena, &"ZombieSpawns")
	var yard: Node3D = b.spawn_group(zombie_spawns, LevelBuilder.Zone.YARD)
	b.marker(yard, &"ZombieSpawn1", Vector3(-17, 0, -17))
	b.marker(yard, &"ZombieSpawn2", Vector3(0, 0, -18))
	b.marker(yard, &"ZombieSpawn3", Vector3(17, 0, -17))
	b.marker(yard, &"ZombieSpawn4", Vector3(18, 0, 0))
	b.marker(yard, &"ZombieSpawn5", Vector3(17, 0, 17))
	b.marker(yard, &"ZombieSpawn6", Vector3(0, 0, 18))
	b.marker(yard, &"ZombieSpawn7", Vector3(-17, 0, 17))
	b.marker(yard, &"ZombieSpawn8", Vector3(-18, 0, 0))
	b.block(navigation, &"EastWallB", Vector3(1, 3, 18), Transform3D(Basis.IDENTITY, Vector3(20.5, 1.5, 11)), LevelBuilder.WALL)
	b.block(navigation, &"NorthWallB", Vector3(19, 3, 1), Transform3D(Basis.IDENTITY, Vector3(11.5, 1.5, -20.5)), LevelBuilder.WALL)
	b.block(navigation, &"WarehouseGround", Vector3(40, 1, 30), Transform3D(Basis.IDENTITY, Vector3(41, -0.5, 0)), LevelBuilder.GROUND)
	b.block(navigation, &"WarehouseNorthWall", Vector3(42, 3, 1), Transform3D(Basis.IDENTITY, Vector3(41, 1.5, -15.5)), LevelBuilder.WALL)
	b.block(navigation, &"WarehouseSouthWall", Vector3(42, 3, 1), Transform3D(Basis.IDENTITY, Vector3(41, 1.5, 15.5)), LevelBuilder.WALL)
	b.block(navigation, &"WarehouseEastWall", Vector3(1, 3, 32), Transform3D(Basis.IDENTITY, Vector3(61.5, 1.5, 0)), LevelBuilder.WALL)
	b.block(navigation, &"WarehouseDivider", Vector3(1, 3, 20), Transform3D(Basis.IDENTITY, Vector3(41, 1.5, -5)), LevelBuilder.WALL)
	b.block(navigation, &"WarehouseCover1", Vector3(2, 2, 2), Transform3D(Basis.IDENTITY, Vector3(30, 1, -8)), LevelBuilder.COVER)
	b.block(navigation, &"WarehouseCover2", Vector3(4, 1.5, 1), Transform3D(Basis.IDENTITY, Vector3(32, 0.75, 9)), LevelBuilder.COVER)
	b.block(navigation, &"WarehouseCover3", Vector3(2, 2, 2), Transform3D(Basis.IDENTITY, Vector3(50, 1, -9)), LevelBuilder.COVER)
	b.block(navigation, &"WarehouseCover4", Vector3(4, 1.5, 1), Transform3D(Basis.IDENTITY, Vector3(52, 0.75, 9)), LevelBuilder.COVER)
	b.block(navigation, &"CourtyardGround", Vector3(30, 1, 40), Transform3D(Basis.IDENTITY, Vector3(0, -0.5, -41)), LevelBuilder.GROUND)
	b.block(navigation, &"CourtyardWestWall", Vector3(1, 3, 42), Transform3D(Basis.IDENTITY, Vector3(-15.5, 1.5, -41)), LevelBuilder.WALL)
	b.block(navigation, &"CourtyardEastWallA", Vector3(1, 3, 17), Transform3D(Basis.IDENTITY, Vector3(15.5, 1.5, -53.5)), LevelBuilder.WALL)
	b.block(navigation, &"CourtyardEastWallB", Vector3(1, 3, 21), Transform3D(Basis.IDENTITY, Vector3(15.5, 1.5, -30.5)), LevelBuilder.WALL)
	b.block(navigation, &"CourtyardNorthWall", Vector3(32, 3, 1), Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -61.5)), LevelBuilder.WALL)
	b.block(navigation, &"CourtyardCover1", Vector3(2, 2, 2), Transform3D(Basis.IDENTITY, Vector3(-8, 1, -35)), LevelBuilder.COVER)
	b.block(navigation, &"CourtyardCover2", Vector3(4, 1.5, 1), Transform3D(Basis.IDENTITY, Vector3(8, 0.75, -48)), LevelBuilder.COVER)
	b.block(navigation, &"CourtyardCover3", Vector3(4, 1.5, 1), Transform3D(Basis.IDENTITY, Vector3(-6, 0.75, -52)), LevelBuilder.COVER)
	b.block(navigation, &"AlcoveGround", Vector3(6, 1, 4), Transform3D(Basis.IDENTITY, Vector3(18.5, -0.5, -43)), LevelBuilder.GROUND)
	b.block(navigation, &"AlcoveNorthWall", Vector3(7, 3, 1), Transform3D(Basis.IDENTITY, Vector3(18.5, 1.5, -45.5)), LevelBuilder.WALL)
	b.block(navigation, &"AlcoveSouthWall", Vector3(7, 3, 1), Transform3D(Basis.IDENTITY, Vector3(18.5, 1.5, -40.5)), LevelBuilder.WALL)
	b.block(navigation, &"AlcoveEastWall", Vector3(1, 3, 6), Transform3D(Basis.IDENTITY, Vector3(21.5, 1.5, -43)), LevelBuilder.WALL)
	b.lamp(navigation, &"Lamp5", Vector3(30, 0, 0))
	b.lamp(navigation, &"Lamp6", Vector3(52, 0, 0))
	b.lamp(navigation, &"Lamp7", Vector3(-10, 0, -28))
	b.lamp(navigation, &"Lamp8", Vector3(10, 0, -55))
	var doors: Node3D = b.group(arena, &"Doors")
	b.door(doors, &"EastDoor", LevelBuilder.Zone.WAREHOUSE, 1250, Transform3D(Vector3(-4.371139e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.371139e-08), Vector3(20.5, 1.5, 0)))
	b.door(doors, &"NorthDoor", LevelBuilder.Zone.COURTYARD, 1750, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -20.5)))
	var switches: Node3D = b.group(arena, &"Switches")
	b.power_switch(switches, &"PowerSwitch", Transform3D(Vector3(-4.371139e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.371139e-08), Vector3(60.98, 1.4, 0)))
	var secret: Secret = b.secret(arena, &"Secret")
	b.sigil(secret, &"Sigil1", Vector3(-8, 1.8, -60.99))
	b.sigil(secret, &"Sigil2", Vector3(0, 1.8, -60.99))
	b.sigil(secret, &"Sigil3", Vector3(8, 1.8, -60.99))
	b.block(secret, &"Panel", Vector3(1, 3, 4), Transform3D(Basis.IDENTITY, Vector3(15.5, 1.5, -43)), LevelBuilder.WALL)
	b.cache(secret, &"Cache", Transform3D(Vector3(-4.371139e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.371139e-08), Vector3(20.98, 1.2, -43)))
	var warehouse: Node3D = b.spawn_group(zombie_spawns, LevelBuilder.Zone.WAREHOUSE)
	b.marker(warehouse, &"WarehouseSpawn1", Vector3(26, 0, -12))
	b.marker(warehouse, &"WarehouseSpawn2", Vector3(56, 0, -10))
	b.marker(warehouse, &"WarehouseSpawn3", Vector3(56, 0, 10))
	var courtyard: Node3D = b.spawn_group(zombie_spawns, LevelBuilder.Zone.COURTYARD)
	b.marker(courtyard, &"CourtyardSpawn1", Vector3(-12, 0, -58))
	b.marker(courtyard, &"CourtyardSpawn2", Vector3(12, 0, -58))
	b.marker(courtyard, &"CourtyardSpawn3", Vector3(0, 0, -30))
