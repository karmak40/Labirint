extends "res://tests/lib/test_case.gd"
## A tower shoots the other side's people and nobody of its own.

var tower: Tower
var foe: Unit
var ally: Unit

func begin() -> void:
	time_limit = 60 * 20
	var map := Node2D.new()
	tower = Tower.new()
	tower.team = Team.Id.ENEMY
	tower.position = Vector2(300, 300)
	map.add_child(tower)
	var knight := load("res://scenes/knight/Knight.tscn")
	foe = knight.instantiate(); foe.team = Team.Id.PLAYER; foe.guards = false; foe.position = Vector2(420, 300)
	ally = knight.instantiate(); ally.team = Team.Id.ENEMY; ally.guards = false; ally.position = Vector2(300, 400)
	map.add_child(foe)
	map.add_child(ally)
	root.add_child(map)

func step() -> bool:
	# held in place: this is only about the tower's aim
	foe.global_position = Vector2(420, 300)
	ally.global_position = Vector2(300, 400)
	if frame == 60 * 12:
		check(foe.health < foe.health_max, "the tower hit the enemy in range", "%d/%d" % [foe.health, foe.health_max])
		check(ally.health == ally.health_max, "and never its own side", "%d/%d" % [ally.health, ally.health_max])
		return true
	return false
