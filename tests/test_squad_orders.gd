extends "res://tests/lib/test_case.gd"
## Squad orders with no navigation floor: rally to a point, then attack-move
## onto an enemy standing in the way. Two against one, they should win without
## loss -- and without hitting each other (friendly fire is off).

var squad := Squad.new()
var a: Unit
var b: Unit
var foe: Unit

func begin() -> void:
	time_limit = 60 * 40
	var knight := load("res://scenes/knight/Knight.tscn")
	a = knight.instantiate(); a.position = Vector2(100, 100); a.team = Team.Id.ENEMY
	b = knight.instantiate(); b.position = Vector2(100, 140); b.team = Team.Id.ENEMY
	foe = knight.instantiate(); foe.position = Vector2(900, 120); foe.team = Team.Id.PLAYER; foe.guards = false
	for unit in [a, b, foe]:
		root.add_child(unit)
	root.add_child(squad)
	squad.add(a)
	squad.add(b)

func step() -> bool:
	if frame == 5:
		squad.rally(Vector2(300, 100))
	if frame == 200:
		check(absf(a.global_position.x - 300.0) < 140.0, "the squad went to its rally point and guards it", a.global_position.round())
		check(a.order == Unit.Order.HOLD, "a rally is a hold order")
		squad.attack_move(Vector2(1200, 120))
	if frame > 200 and not foe.is_alive():
		check(true, "attack-move met the enemy on the way and killed it", "t=%.0fs" % seconds())
		check(squad.alive().size() == 2, "neither of the two was lost", [int(a.health), int(b.health)])
		return true
	if frame == 60 * 38:
		check(false, "the enemy was killed", int(foe.health))
		return true
	return false
