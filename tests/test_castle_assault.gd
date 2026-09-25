extends "res://tests/lib/test_case.gd"
## One knight hacking at a big castle for a long time, running out of breath
## again and again. It must strike the wall where it stands (the castle is far
## too wide to reach its middle), and when out of breath stand facing the wall
## and wait -- never turn its back and wander off (the old bug).

var knight: Unit
var keep: Base
var at_wall := 0
var turned := 0
var lowest := INF             ## least breath it had at any point

func begin() -> void:
	time_limit = 60 * 50
	var map := Node2D.new()
	keep = Base.new()
	keep.team = Team.Id.ENEMY
	keep.position = Vector2(600, 280)
	map.add_child(keep)
	var nav := NavFloor.new()
	nav.floor_size = Vector2(1200, 560)
	map.add_child(nav)
	knight = load("res://scenes/knight/Knight.tscn").instantiate()
	knight.team = Team.Id.PLAYER
	knight.guards = false
	knight.position = Vector2(820, 280)
	map.add_child(knight)
	root.add_child(map)

func step() -> bool:
	if frame == 5:
		knight.set_attack_move(keep.approach_from(knight.global_position))
	lowest = minf(lowest, knight.stamina)
	if knight.quarry is Base and knight.watch == Unit.Watch.FIGHTING and not knight.is_flinching():
		at_wall += 1
		var wall := keep.nearest_point(knight.global_position)
		# right at a corner the wall is straight above or below: no side to face
		var dx := wall.x - knight.global_position.x
		if absf(dx) > 8.0 and signf(dx) != signf(knight.carry_facing):
			turned += 1
	if frame == 60 * 40:
		check(at_wall > 60 * 20, "the knight fought the castle", "%d frames at the wall" % at_wall)
		check(keep.health < keep.health_max * 0.8, "and did it real harm", "%d/%d" % [keep.health, keep.health_max])
		check(turned == 0, "it never turned its back on the wall", "%d frames turned away" % turned)
		check(not knight.has_wind_for(knight.strike_cost()) or lowest < knight.strike_cost(), "it did run short of breath along the way", "lowest %.0f" % lowest)
		return true
	return false
