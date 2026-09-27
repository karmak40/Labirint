extends "res://tests/lib/test_case.gd"
## Soldiers stand at the rally point instead of wandering (user report). Each
## recruit out of the barracks gets a place of his own round the point, beside
## those already there; a soldier sent on an attack-move ends on a place of his
## own round the goal; and «Сбор» brings everyone back to a place each. Once
## there, they stand still.

const RALLY := Vector2(800, 300)
const OUT := 12
const STILL := 12.0            ## px a standing man may drift over the watch

var stage := 0
var barracks: ProductionBuilding
var turned_out := 0
var watched := {}              ## unit -> where it was when the watch began

func begin() -> void:
	time_limit = 60 * 120
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _ranks() -> Array[Unit]:
	return game().human().squad.alive()

## Every one within reach of his post, and no two posts on top of each other.
func _check_placed(what: String) -> void:
	var ranks := _ranks()
	var off := 0
	var shared := 0
	for i in ranks.size():
		if ranks[i].global_position.distance_to(ranks[i].post) > 25.0:
			off += 1
		for j in range(i + 1, ranks.size()):
			if ranks[i].post.distance_to(ranks[j].post) < 18.0:
				shared += 1
	check(ranks.size() == OUT, what + ": everyone is there", ranks.size())
	check(off == 0, what + ": each stands at his place", "%d of %d away" % [off, ranks.size()])
	check(shared == 0, what + ": no two share a place", shared)

func _start_watch() -> void:
	watched.clear()
	for unit in _ranks():
		watched[unit] = unit.global_position

func _check_still(what: String) -> void:
	var worst := 0.0
	for unit in watched:
		if is_instance_valid(unit):
			worst = maxf(worst, (unit as Unit).global_position.distance_to(watched[unit]))
	check(worst < STILL, what + ": they stand still", "%.1f px at most" % worst)

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			barracks = raise_barracks(Team.Id.PLAYER)
			gs.set_rally_point(Team.Id.PLAYER, RALLY)
			stage = 1
			frame = 0
		1:
			# one out of the door every half second, the way they come
			if frame % 30 == 0 and turned_out < OUT:
				barracks._turn_out("warrior")
				turned_out += 1
			if frame == 60 * 20:
				_check_placed("out of the barracks")
				var nearest := INF
				for unit in _ranks():
					nearest = minf(nearest, unit.post.distance_to(RALLY))
				check(nearest < 20.0, "the first stands on the rally point itself", nearest)
				_start_watch()
			if frame == 60 * 24:
				_check_still("at the rally point")
				gs.attack_move(Team.Id.PLAYER, Vector2(1300, 280))
				stage = 2
				frame = 0
		2:
			# the march there, and a few seconds for the ranks to sort themselves out
			if frame == 60 * 24:
				var ranks := _ranks()
				var there := 0
				for unit in ranks:
					if unit.order == Unit.Order.HOLD and unit.global_position.distance_to(Vector2(1300, 280)) < 160.0:
						there += 1
				check(there == ranks.size(), "an attack-move ends with everyone holding round the goal",
					"%d of %d" % [there, ranks.size()])
				_check_placed("after the attack-move")
				gs.rally_home(Team.Id.PLAYER)
				stage = 3
				frame = 0
		3:
			if frame == 60 * 16:
				_check_placed("after «Сбор»")
				_start_watch()
			if frame == 60 * 20:
				_check_still("back home")
				return true
	return false
