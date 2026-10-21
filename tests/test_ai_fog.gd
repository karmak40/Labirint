extends "res://tests/lib/test_case.gd"
## The enemy's head is under the fog too. It has its own sight (a quiet
## FogOfWar, reckoned like ours: its men, its labourers, its buildings); at the
## start it does not know where our castle is, and does not see our men out on
## the field. When it does not know its own half it sends one soldier to look
## it over (its labourers usually have by then), and its waves go
## out along the road to the edge of what it has seen until they find our
## castle -- then at the castle.

var stage := 0
var head: AIDirector
var looked := false

func begin() -> void:
	time_limit = 60 * 240
	game().ai_strategy = "balanced"
	game().ai_difficulty = "hard"
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	var enemy: PlayerState = gs.side(Team.Id.ENEMY)
	match stage:
		0:
			if not playing() or frame < 10:
				return false
			head = enemy.get_node("AIDirector")
			head.plan["attack_after"] = INF
			var vision: FogOfWar = gs.field().get_node_or_null("Vision%d" % Team.Id.ENEMY)
			check(vision != null and vision.quiet and FogOfWar.current != vision, "the enemy's head has a sight of its own")
			check(gs.field().get_node_or_null("Vision%d" % Team.Id.PLAYER) == null, "and ours is the fog on the screen")
			check(not head._knows(me.base().global_position), "it does not know where our castle is")
			check(head._sees(enemy.base().global_position) and not head._sees(Vector2(1500, 300)), "it sees round its own castle, not the middle")
			var goal := head._war_goal(enemy)
			check(goal != Vector2.INF and goal.distance_to(enemy.base().global_position) < goal.distance_to(me.base().global_position),
				"its waves would go to the edge of what it has seen, not at our castle", goal)
			stage = 1
		1:
			# its labourers out at the seams uncover much of its half anyway; once
			# it has soldiers, make it forget all that, and it sends one to look
			if enemy.squad.alive().size() < 2:
				return false
			var vision: FogOfWar = gs.field().get_node("Vision%d" % Team.Id.ENEMY)
			vision.explored.fill(0)
			stage = 3
			frame = 0
		3:
			if head.scouting:
				looked = true
			if not looked or not head._knows(Vector2(1700, 300)):
				if frame > 60 * 90:
					check(false, "a scout looks over its half of the field")
					return true
				return false
			check(true, "a scout looked over its half of the field", "%.0f s after it forgot" % (frame / 60.0))
			# one of its men walks up to our castle: now it knows
			var spy: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
			spy.loadout = "scout"
			spy.team = Team.Id.ENEMY
			spy.guards = false
			spy.position = me.base().global_position + Vector2(420, 60)
			current_scene.add_child(spy)
			stage = 2
			frame = 0
		2:
			if frame < 60:
				return false
			check(head._knows(me.base().global_position), "a man of its own by our castle shows it where it is")
			check(head._war_goal(enemy) == Vector2.INF, "and its waves now go at the castle")
			return true
	return false
