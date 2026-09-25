extends "res://tests/lib/test_case.gd"
## Achievements come from what really happens in a match -- a legion of ten, the
## first enemy down, a victory -- are kept on disk, and survive being read back.
## (Kept in the test's own file: see test_case.gd.) The enemy's head is taken off
## and one of its warriors put in the way, so the match plays out the same way
## every time: this is about the achievements, not about beating the AI.

var stage := 0
var got: Array[String] = []

func begin() -> void:
	time_limit = 60 * 240
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	var gs := game()
	var ach := root.get_node("Achievements")
	match stage:
		0:
			if not playing():
				return false
			check(ach.save_path == ACHIEVEMENTS_FILE, "achievements are kept in the test's own file", ach.save_path)
			check(ach.done.is_empty(), "and start empty")
			ach.unlocked.connect(func(id: String) -> void: got.append(id))
			silence(Team.Id.ENEMY)
			var guard: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
			guard.team = Team.Id.ENEMY
			guard.position = gs.side(Team.Id.ENEMY).base().approach_from(gs.human().base().global_position)
			current_scene.add_child(guard)
			gs.human().economy.add("wood", 300)
			gs.human().economy.add("ore", 300)
			stage = 1
		1:
			if gs.human().barracks().queue.size() < 5:
				gs.hire(1, "warrior")
			if gs.human().squad.alive().size() >= 10:
				check("army_10" in got, "ten soldiers at once is «Легион»")
				gs.attack_enemy_base(1)
				stage = 2
		2:
			if not gs.is_playing():
				check(gs.phase == gs.Phase.WON, "the match was won")
				check("victory" in got, "a win is «Крепость пала»")
				check("first_blood" in got, "an enemy down is «Первая кровь»")
				ach.load_from(ACHIEVEMENTS_FILE)
				check(ach.is_unlocked("victory") and ach.is_unlocked("army_10"), "they are still there read back from disk")
				check(int(ach.totals["wins"]) == 1, "and the win is counted", ach.totals)
				return true
	return false
