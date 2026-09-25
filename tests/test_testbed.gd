extends "res://tests/lib/test_case.gd"
## The animation and combat testbed (Main.tscn) must keep working exactly as it
## did: the knight is a Unit on the enemy side, goes for the player, and leaves
## straw dummies and its own side alone. It walks along X only there, because
## the testbed has no navigation floor.

var main: Node
var knight: Unit
var player: PlayerBody
var stage := 0

func begin() -> void:
	time_limit = 60 * 30
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)

func step() -> bool:
	knight = main.get_node("Knight")
	player = main.get_node("Player")
	match stage:
		0:
			if frame < 2:
				return false
			check(knight is Unit, "the testbed knight is a Unit")
			check(knight.team == Team.Id.ENEMY and player.team == Team.Id.PLAYER, "sides come from the scenes", [knight.team, player.team])
			check(main.has_node("DebugPanel"), "the debug panel is there")
			check(not knight.rig.batched, "the testbed draws stroke by stroke, not through a Pen")
			player.global_position = knight.global_position + Vector2(150.0, 0.0)
			stage = 1
			frame = 0
		1:
			if frame == 120:
				check(knight.watch == Unit.Watch.FIGHTING and knight.quarry == player, "the knight goes for the player",
					[Unit.Watch.keys()[knight.watch], knight.quarry])
				player.team = Team.Id.ENEMY
				stage = 2
				frame = 0
		2:
			if frame == 20:
				check(knight.quarry == null, "an ally in its face is left alone", knight.quarry)
				player.team = Team.Id.PLAYER
				player.global_position = Vector2(-5000.0, -5000.0)
				for node in get_nodes_in_group("targets"):
					if node is TargetDummy:
						knight.global_position = node.global_position + Vector2(60.0, 0.0)
				stage = 3
				frame = 0
		3:
			if frame == 20:
				check(knight.quarry == null, "a straw dummy is furniture", knight.quarry)
				return true
	return false
