extends "res://tests/lib/test_case.gd"
## Skirmish.tscn stands the long map up from its data: everything the map lists
## is on the field, each side has its castle and nothing else (no barracks, no
## workers), the starting store, a baked floor -- and the landscape under it.

func begin() -> void:
	time_limit = 60 * 20
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	if not playing() or frame < 5:
		return false
	var field: MapBuilder = current_scene
	var map: MapData = field.map
	check(get_nodes_in_group("trees").size() == map.tree_positions.size(), "every tree is planted", get_nodes_in_group("trees").size())
	var ore := 0
	var gold := 0
	for vein in get_nodes_in_group("veins"):
		if vein.resource_kind == "gold": gold += 1
		else: ore += 1
		check(vein.rocks == (map.gold_rocks if vein.resource_kind == "gold" else map.ore_rocks), "seams are as rich as the map says")
	check(ore == map.vein_positions.size() and gold == map.gold_positions.size(), "every seam is there", "ore %d, gold %d" % [ore, gold])
	for team in [Team.Id.PLAYER, Team.Id.ENEMY]:
		var side: PlayerState = game().side(team)
		check(side != null, "side %d is registered" % team)
		check(side.base() != null and side.barracks() == null, "side %d has its castle and no barracks yet" % team)
		var towers := 0
		for b in side.buildings:
			if b is Tower: towers += 1
		check(towers == 0, "side %d starts without towers" % team, towers)
		check(side.workers().is_empty(), "side %d starts without workers" % team, side.workers().size())
		# the enemy's head may already have spent a little by now
		if team == Team.Id.PLAYER:
			check(side.economy.wood == 60 and side.economy.ore == 60, "we start with 60 wood and 60 ore", [side.economy.wood, side.economy.ore])
		else:
			check(side.economy.wood <= 60 and side.economy.ore <= 60, "the enemy starts with no more than that", [side.economy.wood, side.economy.ore])
	check((field.get_node("NavFloor") as NavFloor).navigation_polygon.get_polygon_count() > 0, "the floor is baked")
	check(field.has_node("Terrain"), "the land is laid under it")
	check(game().side(Team.Id.ENEMY).has_node("AIDirector") and not game().side(Team.Id.PLAYER).has_node("AIDirector"),
		"only the enemy has a head of its own")
	return true
