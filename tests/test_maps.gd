extends "res://tests/lib/test_case.gd"
## The new skirmish maps: «Озёрный лес» (a great lake in the middle, only the
## south shore open) and «У моста» (a river across the valley and one bridge).
## Water is ground nobody can cross: a soldier sent from one castle to the other
## gets there without ever standing in it, round the lake or over the bridge,
## and nothing can be built in it.

const MAPS := [
	["res://resources/maps/skirmish_lake.tres", "Озёрный лес", 1],
	["res://resources/maps/skirmish_bridge.tres", "У моста", 2],
]

var index := 0
var stage := 0
var walker: Unit
var wet_steps := 0
var through_bridge := false

func begin() -> void:
	time_limit = 60 * 240
	game().map = load(MAPS[0][0])
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _in_water(point: Vector2) -> bool:
	for node in get_nodes_in_group("waters"):
		if (node as Water).covers(point):
			return true
	return false

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing() or current_scene.map.title != MAPS[index][1] or frame < 10:
				return false
			silence(Team.Id.ENEMY)
			var waters := get_nodes_in_group("waters").size()
			check(waters == MAPS[index][2], "%s has its water" % MAPS[index][1], waters)
			check((current_scene.get_node("NavFloor") as NavFloor).navigation_polygon.get_polygon_count() > 0, "the floor baked")
			var pool := get_nodes_in_group("waters")[0] as Water
			var centre := Vector2.ZERO
			for p in pool.outline:
				centre += p / float(pool.outline.size())
			check(pool.covers(centre) and pool.reaches(Rect2(centre - Vector2(23, 15), Vector2(46, 26))), "a house would stand in the water", centre)
			check(not pool.reaches(Rect2(400, 280, 46, 26)), "and the dry land is still open")
			check((get_nodes_in_group("bridges").size() == 1) == (index == 1), "a bridge only on the river map")
			# every mine and tree is on dry ground, where a man can go
			var stranded := 0
			for group in ["trees", "veins"]:
				for node in get_nodes_in_group(group):
					if _in_water((node as Node2D).global_position):
						stranded += 1
			check(stranded == 0, "no tree or seam stands in the water", stranded)
			walker = (load("res://scenes/warrior/Warrior.tscn") as PackedScene).instantiate()
			walker.team = Team.Id.PLAYER
			walker.loadout = "warrior"
			walker.position = Vector2(700, 300)
			current_scene.add_child(walker)
			walker.set_attack_move(Vector2(2300, 300))
			wet_steps = 0
			through_bridge = false
			stage = 1
			frame = 0
		1:
			if walker.is_alive() and _in_water(walker.global_position):
				wet_steps += 1
			if index == 1 and absf(walker.global_position.x - 1500.0) < 40.0:
				through_bridge = true
			if walker.global_position.x > 2250.0:
				check(wet_steps == 0, "he crossed without standing in water", wet_steps)
				if index == 1:
					check(through_bridge, "and went over the bridge")
				check(frame < 60 * 70, "in reasonable time", "%.0f s" % (frame / 60.0))
				index += 1
				if index >= MAPS.size():
					return true
				gs.map = load(MAPS[index][0])
				gs.restart_match()
				stage = 0
				frame = 0
			elif frame > 60 * 110:
				check(false, "he got across", walker.global_position.round())
				return true
	return false
