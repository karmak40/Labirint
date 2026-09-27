extends "res://tests/lib/test_case.gd"
## The dead are no obstacle: a heap of the fallen lies across the way, and a
## soldier ordered through it walks through it as over open ground. (A body
## that had died used to go on standing in the crowd's avoidance like a man on
## his feet, and a field of them froze the living.)

var stage := 0
var walker: Unit
var fallen: Array[Unit] = []
const FROM := Vector2(900, 280)
const TO := Vector2(1500, 280)

func begin() -> void:
	time_limit = 60 * 40
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(team: int, at: Vector2) -> Unit:
	var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
	unit.team = team
	unit.guards = false
	unit.position = at
	current_scene.add_child(unit)
	return unit

func step() -> bool:
	match stage:
		0:
			if not playing() or frame < 5:
				return false
			silence(Team.Id.ENEMY)
			# thirty of them, packed across the road
			for i in 30:
				fallen.append(_soldier(Team.Id.ENEMY, Vector2(1150 + (i % 6) * 22, 200 + (i / 6) * 36)))
			stage = 1
			frame = 0
		1:
			if frame == 5:
				for body in fallen:
					body.take_hit(Vector2.INF, 10000.0)
			if frame < 60:
				return false
			walker = _soldier(Team.Id.PLAYER, FROM)
			walker.set_attack_move(TO)
			stage = 2
			frame = 0
		2:
			if walker.global_position.distance_to(TO) < 60.0:
				check(true, "a soldier crossed a heap of thirty dead in", "%.1f s" % (frame / 60.0))
				check(frame < 60 * 12, "about as fast as over open ground", "%.1f s" % (frame / 60.0))
				return true
			if frame > 60 * 25:
				check(false, "a soldier gets through a heap of the dead",
					"stuck at %s after 25 s" % walker.global_position.round())
				return true
	return false
