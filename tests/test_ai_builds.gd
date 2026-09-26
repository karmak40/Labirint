extends "res://tests/lib/test_case.gd"
## One AIDirector against a side that does nothing: it should get workers out,
## save up for a library, lay one out in front of its castle, and start learning
## once it stands, then put up a forge, put smiths to it and order arms or kit there. Short on purpose -- a whole AI match is far too slow to run
## as a check.

var laid_at := -1.0
var studying_at := -1.0
var forge_at := -1.0
var ordered := false

func begin() -> void:
	time_limit = 60 * 420
	# the balanced head; the others build later on purpose (see test_ai_strategies)
	game().ai_strategy = "balanced"
	game().ai_difficulty = "normal"
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	if not playing():
		return false
	var enemy: PlayerState = game().side(Team.Id.ENEMY)
	# it only builds here: against a side that does nothing its waves would
	# win the match before the forge is up
	var head: AIDirector = enemy.get_node("AIDirector")
	head.plan["attack_after"] = INF
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
	if studying_at >= 0.0 and forge_at < 0.0 and enemy.has_forge_site():
		forge_at = game().match_time
		check(true, "then laid out a forge", "at %.0f s, %d soldiers" % [forge_at, enemy.squad.alive().size()])
	var smithy: Forge = enemy.forge()
	if not ordered and smithy != null and not smithy.all_pending().is_empty() and not enemy.smiths().is_empty():
		ordered = true
		check(true, "and ordered arms or kit there", "%s at %.0f s" % [smithy.all_pending()[0], game().match_time])
		check(true, "with smiths at the anvils", enemy.smiths().size())
	# and soldiers armed from it come out of the barracks
	for unit in enemy.squad.alive():
		if unit.loadout != "warrior" and ordered:
			check(true, "an armed soldier joined the ranks", "%s at %.0f s" % [unit.loadout, game().match_time])
			return true
	return false
