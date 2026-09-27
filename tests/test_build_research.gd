extends "res://tests/lib/test_case.gd"
## Building and learning. Where a building may and may not go, and why; a
## library and a tower going up over time; nothing learned without a finished
## library; the knight unlocked only by chivalry; smithing and mail making every
## soldier -- the ones already in the ranks too -- hit harder and last longer;
## and a burned library losing the study that was under way in it.

var stage := 0
var hands: Array[Worker] = []
var library: Library
var tower: Tower
var soldier: Unit

func begin() -> void:
	time_limit = 60 * 160
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			raise_barracks(Team.Id.PLAYER)
			me.economy.add("wood", 400)
			me.economy.add("ore", 400)
			me.economy.add("gold", 200)
			var home: Vector2 = me.base().global_position
			check(not gs.research(1, "chivalry"), "nothing is learned without a library")
			check(not gs.hire(1, "knight"), "no knights before chivalry")
			check(gs.build_problem(1, "tower", Vector2(2000, 300)) == "Слишком далеко от своих построек", "too far from our buildings is refused")
			check(gs.build_problem(1, "tower", home) == "Мешает другая постройка", "on top of the castle is refused")
			check(gs.build_problem(1, "tower", Vector2(700, 530)) == "Мешают деревья", "in the woods is refused")
			check(gs.build_problem(1, "tower", Vector2(10, 300)) == "За краем поля", "off the edge is refused")
			check(gs.build_problem(1, "library", Vector2(620, 180)) == "", "open ground near home is fine")
			var wood_before: int = me.economy.wood
			check(gs.build(1, "library", Vector2(620, 180)), "a library is laid out")
			check(me.economy.wood == wood_before - int(gs.BUILDINGS["library"]["cost"]["wood"]), "and paid for")
			check(gs.build_problem(1, "library", Vector2(620, 420)) == "Библиотека уже есть", "a second library is refused")
			check(gs.build(1, "tower", Vector2(760, 330)), "a tower is laid out")
			for b in me.buildings:
				if b is Library: library = b
				if b is Tower: tower = b
			check(not library.is_complete() and library.health < library.health_max, "a site starts unfinished and weak")
			check(not gs.research(1, "chivalry"), "an unfinished library teaches nothing")
			check(gs.hire(1, "warrior"), "a warrior can be hired from the start")
			stage = 1
			frame = 0
		1:
			# nobody to build: the sites wait
			if frame < 120:
				return false
			check(library.built < 0.01 and tower.built < 0.01, "with no labourers nothing goes up", library.built)
			for i in 2:
				var hand: Worker = load("res://scenes/worker/Worker.tscn").instantiate()
				hand.team = Team.Id.PLAYER
				hand.job = "ore"
				hand.position = me.base().door_point() + Vector2(40 * i, 40)
				current_scene.add_child(hand)
				hands.append(hand)
			stage = 5
			frame = 0
		5:
			if frame == 60:
				check(hands[0].job == "build" and hands[1].job == "build" and hands[0].site != hands[1].site,
					"a labourer goes to each site", [hands[0].job, hands[1].job])
				check(hands[0].weapon == PlayerBody.Weapon.HAMMER, "hammer in hand")
			if frame == 60 * 6:
				check(library.built > 0.05 and library.built < 1.0, "and it rises under the hammer", library.built)
			if library.is_complete() and tower.is_complete():
				var took := frame / 60.0
				check(took > float(gs.BUILDINGS["library"]["time"]) * 0.8 and took < float(gs.BUILDINGS["library"]["time"]) + 20.0,
					"the library took about as long as it should, with the walk", "%.1f s" % took)
				stage = 6
				frame = 0
		6:
			if frame < 30:
				return false
			check(hands[0].job == "ore" and hands[1].job == "ore", "done, the builders go back to their ore", [hands[0].job, hands[1].job])
			if true:
				check(library.health > library.health_max * 0.95, "and grew to full strength as it went up", int(library.health))
				soldier = me.squad.alive()[0] if not me.squad.alive().is_empty() else null
				check(soldier != null, "the warrior is in the ranks")
				check(gs.research(1, "forging"), "smithing is being learned")
				check(not gs.research(1, "mail"), "only one study at a time")
				stage = 2
		2:
			if me.has_researched("forging"):
				check(is_equal_approx(soldier.strike_harm(), PlayerBody.STRIKE_HARM[PlayerBody.Weapon.CLUB] * 1.25),
					"a warrior already in the ranks hits 25% harder", soldier.strike_harm())
				check(gs.research(1, "mail"), "mail is being learned")
				stage = 3
		3:
			if me.has_researched("mail"):
				check(is_equal_approx(soldier.health_max, PlayerBody.HEALTH_MAX * 1.25), "and has 25% more health", soldier.health_max)
				check(gs.research(1, "chivalry"), "chivalry is being learned")
				stage = 4
				frame = 0
		4:
			if frame == 60:
				library.take_hit(Vector2.ZERO, 99999.0)
			if frame == 70:
				check(me.researching == "" and not me.has_researched("chivalry"), "burning the library lost the study under way")
				check(not gs.hire(1, "knight"), "so there are still no knights")
				return true
	return false
