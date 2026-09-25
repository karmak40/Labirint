extends "res://tests/lib/test_case.gd"
## The kinds of soldier: each comes out with its own kit; an archer and a
## crossbowman hit a mark that is not on their own row (they aim across the
## field, not just along it) from well out of sword's reach; a spearman fights
## with the spear; and none of the three can be hired, nor crossbows learned,
## before what they need has been learned.

var shooters := {}             ## loadout -> [shooter, mark, closest it came]
var stage := 0

func begin() -> void:
	time_limit = 60 * 60
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(loadout: String, team: int, at: Vector2) -> Unit:
	var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
	unit.loadout = loadout
	unit.team = team
	unit.guards = false
	unit.position = at
	current_scene.add_child(unit)
	return unit

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			var me: PlayerState = gs.human()
			me.economy.add("wood", 300)
			me.economy.add("ore", 300)
			me.economy.add("gold", 100)
			for kind in ["spearman", "archer", "crossbowman"]:
				check(not gs.hire(1, kind), "no %s before its study" % kind)
			check(not me.prerequisite_met("crossbows"), "crossbows can not be learned before bows")
			me.researched["archery"] = true
			check(me.prerequisite_met("crossbows"), "and can once bows are known")
			check(gs.hire(1, "archer"), "an archer can be hired once bows are known")
			# two shooters on open ground in the middle, each with a mark held
			# still off their own row
			for spec in [["archer", Vector2(1200, 200), Vector2(1350, 320)], ["crossbowman", Vector2(1200, 420), Vector2(1370, 300)]]:
				var shooter := _soldier(spec[0], Team.Id.PLAYER, spec[1])
				var mark := _soldier("warrior", Team.Id.ENEMY, spec[2])
				shooters[spec[0]] = [shooter, mark, INF, spec[2]]
			var spear := _soldier("spearman", Team.Id.PLAYER, Vector2(1600, 470))
			var dummy_foe := _soldier("warrior", Team.Id.ENEMY, Vector2(1660, 470))
			shooters["spearman"] = [spear, dummy_foe, INF, Vector2(1660, 470)]
			stage = 1
			frame = 0
		1:
			for kind in shooters:
				var entry: Array = shooters[kind]
				var shooter: Unit = entry[0]
				var mark: Unit = entry[1]
				if kind != "spearman" and mark.is_alive():
					mark.global_position = entry[3]
					mark.velocity = Vector2.ZERO
				entry[2] = minf(entry[2], shooter.global_position.distance_to(mark.global_position))
			if frame == 5:
				var archer: Unit = shooters["archer"][0]
				var crossbow: Unit = shooters["crossbowman"][0]
				var spear: Unit = shooters["spearman"][0]
				check(archer.weapon == PlayerBody.Weapon.BOW and archer.is_shooter(), "an archer carries a bow and shoots")
				check(crossbow.weapon == PlayerBody.Weapon.CROSSBOW and crossbow.is_shooter(), "a crossbowman carries a crossbow and shoots")
				check(spear.weapon == PlayerBody.Weapon.SPEAR and not spear.is_shooter(), "a spearman carries a spear and closes")
			if frame == 60 * 14:
				for kind in ["archer", "crossbowman"]:
					var entry: Array = shooters[kind]
					var mark: Unit = entry[1]
					check(mark.health < mark.health_max, "the %s hit a mark off its own row" % kind,
						"%d/%d, %.0f px apart in y" % [mark.health, mark.health_max, absf(entry[3].y - entry[0].global_position.y)])
					check(entry[2] > 90.0, "and never came within reach of a blade", "%.0f px at closest" % entry[2])
				var spear_mark: Unit = shooters["spearman"][1]
				check(spear_mark.health < spear_mark.health_max, "the spearman fought with the spear", "%d/%d" % [spear_mark.health, spear_mark.health_max])
				return true
	return false
