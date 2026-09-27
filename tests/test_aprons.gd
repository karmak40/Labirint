extends "res://tests/lib/test_case.gd"
## The ground in front of a door or an anvil stays open. A forge may not be
## put right under the barracks door (the user's jam: it stood on the rally
## point, and every new soldier shoved at it for ever); and a rally point on a
## building or on that open ground puts soldiers just clear of it instead, so
## they keep to where they were sent rather than milling round it.

var stage := 0
var barracks: ProductionBuilding
var smithy: Forge
var soldiers: Array[Unit] = []

func begin() -> void:
	time_limit = 60 * 60
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			barracks = raise_barracks(Team.Id.PLAYER)
			me.economy.add("wood", 400)
			me.economy.add("ore", 400)
			var under := barracks.door_point() + Vector2(0, 40)
			check(gs.build_problem(1, "forge", under) == "Загородит вход", "no forge right under the barracks door",
				gs.build_problem(1, "forge", under))
			check(gs.build(1, "tower", Vector2(900, 340)), "a tower out in the open")
			var problem: String = gs.build_problem(1, "forge", Vector2(900, 262))
			check(problem == "Перед входом нет места", "no forge with its anvils up against it", problem)
			# a forge put down anyway, the old way, right on the barracks rally point
			smithy = raise_forge(Team.Id.PLAYER)
			smithy.global_position = barracks.rally_point
			gs.field().get_node("NavFloor").rebake(true)
			var post := Building.clear_of(self, barracks.rally_point)
			check(not smithy.apron().has_point(post)
				and not Rect2(smithy.global_position - smithy.footprint * 0.5, smithy.footprint).grow(20).has_point(post),
				"a post on a building is moved just clear of it", post)
			# soldiers sent to stand on it (they pace round their post, so near it will do)
			for i in 5:
				var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
				unit.team = Team.Id.PLAYER
				unit.position = barracks.door_point() + Vector2(-40 + i * 20, 10)
				current_scene.add_child(unit)
				unit.set_rally(barracks.rally_point)
				soldiers.append(unit)
			stage = 1
			frame = 0
		1:
			if frame < 60 * 12:
				return false
			var settled := 0
			for unit in soldiers:
				if not smithy.apron().has_point(unit.global_position) and unit.global_position.distance_to(unit.post) < 140.0:
					settled += 1
			check(settled == soldiers.size(), "the soldiers keep to their posts, off the forge's front", "%d of %d" % [settled, soldiers.size()])
			return true
	return false
