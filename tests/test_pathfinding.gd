extends "res://tests/lib/test_case.gd"
## Two units of one side swap places across a column of trees (NavTest.tscn).
## A straight line would walk them into the trunks and into each other; they
## should go round both and arrive.

var scene: Node
var closest := INF
var detour := 0.0

func begin() -> void:
	time_limit = 60 * 30
	scene = load("res://scenes/tests/NavTest.tscn").instantiate()
	root.add_child(scene)

func step() -> bool:
	var left: Unit = scene.get_node("Left")
	var right: Unit = scene.get_node("Right")
	for unit in [left, right]:
		detour = maxf(detour, absf(unit.global_position.y - 280.0))
		for tree in get_nodes_in_group("trees"):
			closest = minf(closest, unit.global_position.distance_to(tree.global_position))
	if frame == 3:
		check((scene.get_node("NavFloor") as NavFloor).navigation_polygon.get_polygon_count() > 0, "the floor baked a navigation mesh")
	if frame == 60 * 15:
		check(left.global_position.x > 650.0, "the left unit reached the right side", left.global_position.round())
		check(right.global_position.x < 250.0, "the right unit reached the left side", right.global_position.round())
		check(detour > 60.0, "they went round the trees", "%.0f px off the line" % detour)
		check(closest >= 26.0, "nobody walked into a trunk", "%.1f px from a trunk's middle" % closest)
		return true
	return false
