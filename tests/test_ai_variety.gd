extends "res://tests/lib/test_case.gd"
## No two heads of the same strategy play alike: each rolls its own habits --
## where it puts each kind of building, the order of its studies, how much it
## favours each soldier -- but within what its strategy allows: the same
## studies and soldiers, prerequisites always before what needs them, and a
## turtle still a turtle for towers.

func begin() -> void:
	time_limit = 60 * 20
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _head(strategy: String) -> AIDirector:
	var head := AIDirector.new()
	head.strategy = strategy
	head.difficulty = "normal"
	current_scene.add_child(head)
	return head

func step() -> bool:
	if not playing():
		return false
	silence(Team.Id.ENEMY)
	var base := AIProfile.make("balanced", "normal")
	var layouts := {}
	var orders := {}
	var mixes := {}
	for i in 8:
		var head := _head("balanced")
		layouts[str(head.sites)] = true
		orders[str(head.plan["studies"])] = true
		mixes[str(head.plan["mix"])] = true
		var studies: Array = head.plan["studies"]
		var same := studies.duplicate()
		same.sort()
		var wanted: Array = (base["studies"] as Array).duplicate()
		wanted.sort()
		if same != wanted or not AIDirector._in_order(studies) or head.plan["mix"].keys() != base["mix"].keys():
			check(false, "a head keeps to its strategy's studies and soldiers", studies)
		head.free()
	check(layouts.size() >= 4, "heads put their buildings in different places", "%d layouts of 8" % layouts.size())
	check(orders.size() >= 3, "and take their studies in different orders", "%d orders of 8" % orders.size())
	check(mixes.size() == 8, "and favour their soldiers differently")
	check(true, "every order keeps prerequisites first and the same studies")
	for i in 6:
		var turtle := _head("turtle")
		if int(turtle.plan["towers"]) < 3 or not bool(turtle.plan["towers_early"]):
			check(false, "a turtle is still a turtle for towers", turtle.plan["towers"])
		turtle.free()
	check(true, "turtles keep at least three towers, early")
	return true
