extends "res://tests/lib/test_case.gd"
## The AI's strategies and difficulties. First the profiles themselves; then two
## short matches against a side that does nothing, a couple of minutes each: a
## rushing head goes out early and leaves learning for later, a turtling one
## puts up towers and stays home.

var stage := 0
var head: AIDirector
var went_out_at := -1.0
var library_at := -1.0

func begin() -> void:
	time_limit = 60 * 400
	var easy := AIProfile.make("balanced", "easy")
	var normal := AIProfile.make("balanced", "normal")
	var hard := AIProfile.make("balanced", "hard")
	check(easy["think"] > normal["think"] and normal["think"] > hard["think"], "harder heads think faster",
		[easy["think"], normal["think"], hard["think"]])
	check(easy["workers_full"]["wood"] < hard["workers_full"]["wood"] and easy["wave_max"] < hard["wave_max"],
		"and keep more hands and bigger waves")
	check((easy["studies"] as Array).size() <= 3, "an easy head learns little", easy["studies"])
	check(easy["counter_share"] > 1.0, "and never strikes back straight after beating off an attack")
	var picked := AIProfile.make("random", "normal")
	check(AIProfile.STRATEGIES.has(picked["strategy"]), "«random» picks a real strategy", picked["strategy"])
	check(AIProfile.make("rush", "normal")["mix"].has("warrior"), "a rush fields clubs on purpose")
	check(int(AIProfile.make("turtle", "normal")["towers"]) > int(AIProfile.make("balanced", "normal")["towers"]),
		"a turtle wants more towers than a balanced head")
	game().ai_strategy = "rush"
	game().ai_difficulty = "normal"
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	var gs := game()
	match stage:
		0, 2:
			if not playing():
				return false
			head = gs.enemy_of(1).get_node("AIDirector")
			went_out_at = -1.0
			library_at = -1.0
			frame = 0
			stage += 1
		1:
			var foe: PlayerState = gs.enemy_of(1)
			if head.attacking and went_out_at < 0.0:
				went_out_at = gs.match_time
			if foe.has_library_site() and library_at < 0.0:
				library_at = gs.match_time
			# a rush against a side that does nothing may well win outright first
			if gs.match_time >= 150.0 or not gs.is_playing():
				if not gs.is_playing():
					check(true, "the rush won against a side that did nothing", "at %.0f s" % gs.match_time)
				check(head.strategy == "rush", "the enemy plays the strategy chosen for it", head.strategy)
				check(went_out_at > 0.0, "a rush goes out early", "first attack at %.0f s" % went_out_at)
				check(library_at < 0.0 or went_out_at < library_at, "and goes out before it stops to build a library",
					"library at %.0f s" % library_at)
				gs.ai_strategy = "turtle"
				gs.restart_match()
				stage = 2
		3:
			var foe: PlayerState = gs.enemy_of(1)
			if head.attacking and went_out_at < 0.0:
				went_out_at = gs.match_time
			if gs.match_time >= 240.0 or not gs.is_playing():
				var towers := 0
				for b in foe.buildings:
					if b is Tower: towers += 1
				check(head.strategy == "turtle", "the second match's enemy is a turtle", head.strategy)
				check(towers >= 1, "a turtle puts up towers early", "%d towers by 240 s" % towers)
				check(went_out_at < 0.0, "and does not go out before its time", went_out_at)
				return true
	return false
