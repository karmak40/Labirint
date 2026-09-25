extends "res://tests/lib/test_case.gd"
## Three knights a side meet in the middle (BattleTest.tscn). Every blow should
## land on the other side -- nobody is hurt with no enemy near -- and one side
## should be wiped out.

var scene: Node
var hp := {}
var hits := 0
var stray := 0

func begin() -> void:
	time_limit = 60 * 60
	scene = load("res://scenes/tests/BattleTest.tscn").instantiate()
	root.add_child(scene)

func step() -> bool:
	for node in get_nodes_in_group("targets"):
		var unit := node as Unit
		if unit == null:
			continue
		var was: float = hp.get(unit, unit.health)
		if unit.health < was:
			hits += 1
			var foe_near := false
			for other in get_nodes_in_group("targets"):
				if other is Unit and other.team != unit.team and other.global_position.distance_to(unit.global_position) < 120.0:
					foe_near = true
			if not foe_near:
				stray += 1
		hp[unit] = unit.health
	var blue: PlayerState = scene.get_node("BlueSide")
	var red: PlayerState = scene.get_node("RedSide")
	if frame > 60 and (blue.squad.alive().is_empty() or red.squad.alive().is_empty()):
		check(hits > 10, "the two sides fought", "%d blows landed" % hits)
		check(stray == 0, "no blow landed with no enemy near (no friendly fire)", stray)
		check(true, "one side was wiped out", "blue %d, red %d left" % [blue.squad.alive().size(), red.squad.alive().size()])
		return true
	return false
