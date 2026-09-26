extends "res://tests/lib/test_case.gd"
## Labourers and the barracks on the long map. There is no barracks at the
## start, so no soldier can be hired; labourers are hired at the castle and all
## alike, paid in whichever of wood and ore the store has more of, each going
## to the trade shorter of hands; any of them can be moved to another trade.
## A barracks is built like anything else (one to a side), and soldiers can be
## hired only once it is finished; they go to the side's rally point.

var stage := 0
var barracks: ProductionBuilding
var came_out: Array[Vector2] = []

func begin() -> void:
	time_limit = 60 * 90
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			check(me.barracks() == null, "no barracks at the start")
			check(not gs.hire(1, "warrior"), "so no soldier can be hired")
			check(me.base().kinds.has("worker"), "the castle hires labourers")
			me.base().unit_ready.connect(func(hand: PlayerBody) -> void: came_out.append(hand.global_position))
			# 60 wood, 60 ore: the first is paid in wood, then ore once it has more
			check(gs.hire(1, "worker"), "a labourer is hired at the castle")
			check(me.economy.wood == 50 and me.economy.ore == 60, "paid in wood when there is as much of both", [me.economy.wood, me.economy.ore])
			check(gs.hire(1, "worker"), "and a second")
			check(me.economy.ore == 50, "paid in ore, now there is more of it", [me.economy.wood, me.economy.ore])
			gs.hire(1, "worker")
			stage = 1
			frame = 0
		1:
			if me.workers().size() < 3:
				return false
			var count := me.hands()
			check(int(count["wood"]) == 2 and int(count["ore"]) == 1, "they went where hands were short: 2 on wood, 1 on ore", count)
			var gate: float = me.base().global_position.y + me.base().footprint.y * 0.5
			for at in came_out:
				check(at.y > gate, "each came out of the gate, not inside the wall", at.round())
			check(gs.assign_worker(1, "gold"), "one is sent to gold")
			count = me.hands()
			check(int(count["gold"]) == 1 and int(count["wood"]) == 1, "taken from wood, which had the most", count)
			var digger: Worker = null
			for hand in me.workers():
				if hand.job == "gold": digger = hand
			check(digger.weapon == PlayerBody.Weapon.PICKAXE, "and takes up a pick")
			check(gs.assign_worker(1, "wood") and me.hands()["wood"] == 2, "and one moved back to wood", me.hands())
			check(not gs.assign_worker(1, "stone"), "there is no such trade as stone")
			# the barracks
			me.economy.add("wood", 200)
			me.economy.add("ore", 200)
			var spot: Vector2 = gs.field().map.player.barracks
			check(gs.build(1, "barracks", spot), "a barracks is laid out")
			check(gs.build_problem(1, "barracks", spot + Vector2(0, 160)) == "Казарма уже есть", "a second is refused")
			barracks = me.barracks()
			check(barracks != null and not barracks.is_complete(), "it starts as a site")
			check(not gs.hire(1, "warrior"), "and hires nobody until it is finished")
			stage = 2
		2:
			if not barracks.is_complete():
				return false
			check(gs.hire(1, "warrior"), "finished, it hires a warrior")
			check(not gs.hire(1, "worker") or me.base().queue.size() > 0, "labourers are still the castle's")
			stage = 3
			frame = 0
		3:
			if me.squad.alive().is_empty():
				return false
			var soldier: Unit = me.squad.alive()[0]
			check(soldier.post.distance_to(gs.field().map.player.rally) < 1.0, "the recruit goes to the side's rally point", soldier.post)
			return true
	return false
