extends "res://tests/lib/test_case.gd"
## One AIDirector against a side that does nothing: it should get workers out,
## save up for a library, lay one out in front of its castle, and start learning
## once it stands. Short on purpose -- a whole AI match is far too slow to run
## as a check.

var laid_at := -1.0
var studying_at := -1.0

func begin() -> void:
	time_limit = 60 * 180
	# the balanced head; the others build later on purpose (see test_ai_strategies)
	game().ai_strategy = "balanced"
	game().ai_difficulty = "normal"
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	if not playing():
		return false
	var enemy: PlayerState = game().side(Team.Id.ENEMY)
	if laid_at < 0.0 and enemy.has_library_site():
		laid_at = game().match_time
		var library: Library = null
		for b in enemy.buildings:
			if b is Library: library = b
		check(true, "the AI laid out a library", "at %.0f s, %d workers" % [laid_at, enemy.workers().size()])
		check(absf(library.global_position.x - enemy.base().global_position.x) < 800.0, "near its own castle", library.global_position.round())
	if laid_at >= 0.0 and studying_at < 0.0 and (enemy.researching != "" or not enemy.researched.is_empty()):
		studying_at = game().match_time
		check(true, "and started learning once it stood", "%s at %.0f s" % [enemy.researching, studying_at])
		return true
	return false
