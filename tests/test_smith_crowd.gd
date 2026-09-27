extends "res://tests/lib/test_case.gd"
## Soldiers ordered, a smith coming to the anvil by himself: their recruits come and
## wait by the forge, and the smith keeps his place and makes their arms. (The
## recruits used to crowd him off his spot, and a smith off his spot strikes no
## blow: nothing was ever made and nobody could be hired.)

var stage := 0
var smithy: Forge
var ordered_at := 0.0

func begin() -> void:
	time_limit = 60 * 120
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _hand(at: Vector2) -> Worker:
	var worker: Worker = load("res://scenes/worker/Worker.tscn").instantiate()
	worker.team = Team.Id.PLAYER
	worker.job = "wood"
	worker.position = at
	current_scene.add_child(worker)
	return worker

func _swordsmen(me: PlayerState) -> int:
	var n := 0
	for unit in me.squad.alive():
		if unit.loadout == "swordsman":
			n += 1
	return n

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			raise_barracks(Team.Id.PLAYER)
			smithy = raise_forge(Team.Id.PLAYER)
			me.economy.add("wood", 500)
			me.economy.add("ore", 500)
			me.researched["blades"] = true
			# two labourers by the castle: one comes to the anvil once there are
			# orders (the last one on the trades is never taken)
			_hand(me.base().door_point() + Vector2(0, 40))
			_hand(me.base().door_point() + Vector2(20, 40))
			stage = 1
			frame = 0
		1:
			for i in 4:
				check(gs.hire(1, "swordsman"), "a swordsman is ordered")
			ordered_at = seconds()
			stage = 2
			frame = 0
		2:
			if _swordsmen(me) >= 4:
				check(true, "all four swordsmen are in the ranks after", "%.1f s" % (seconds() - ordered_at))
				return true
			if frame > 60 * 70:
				check(false, "the smiths made the swords with the recruits waiting round them",
					"%d of 4, %d swords made, forge list %s" % [_swordsmen(me), 4 - smithy.all_pending().size(), smithy.all_pending()])
				return true
	return false
