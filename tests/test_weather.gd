extends "res://tests/lib/test_case.gd"
## The sky over a match. It starts in daylight and dry; the day turns to dusk,
## night and dawn on the clock, and the rain comes when the map's seed says, the
## same every time. At night everyone sees less far, towers included; in the
## rain bows and crossbows hit softer and a torch burns walls slower. The panel
## shows the time of day, and the testbed has no weather at all.

var stage := 0
var sky: Weather
var archer: Unit
var crossbow: Unit
var spear: Unit
var torch: Unit
var hud: Node

func begin() -> void:
	time_limit = 60 * 30
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(loadout: String, at: Vector2) -> Unit:
	var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
	unit.loadout = loadout
	unit.team = Team.Id.PLAYER
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
			sky = gs.field().get_node_or_null("Weather")
			hud = current_scene.get_node("Hud")
			check(sky != null and Weather.current == sky, "a match has weather")
			check(sky.phase == "day" and not sky.is_raining(), "it starts in daylight and dry")
			check(sky.spells[0].x >= Weather.FIRST_RAIN, "and no rain for the first while", sky.spells[0])
			var again := Weather.new(gs.field().map.title)
			check(again.spells == sky.spells, "the same map has the same rain every time")
			again.free()
			check(Weather.phase_at(160.0) == "dusk" and Weather.phase_at(200.0) == "night" and Weather.phase_at(280.0) == "dawn"
				and Weather.phase_at(310.0) == "day", "the day goes round")
			archer = _soldier("archer", Vector2(1200, 250))
			crossbow = _soldier("crossbowman", Vector2(1250, 250))
			spear = _soldier("spearman", Vector2(1300, 250))
			torch = _soldier("torchbearer", Vector2(1350, 250))
			check(is_equal_approx(spear._sight(), Unit.SIGHT), "by day a soldier sees as far as ever")
			stage = 1
			frame = 0
		1:
			if frame < 10:
				return false
			check(hud.sky_label.text == "День", "the panel says it is day", hud.sky_label.text)
			var bow := archer.strike_harm()
			var bolt := crossbow.strike_harm()
			var jab := spear.strike_harm()
			var burn := torch.harm_against(gs.human().base())
			sky.forced_rain = 1
			sky.rain = 1.0
			sky._physics_process(0.0)
			check(sky.is_raining(), "rain")
			check(is_equal_approx(archer.strike_harm(), bow * Weather.RAIN_BOW), "a wet bow hits softer", "%.1f -> %.1f" % [bow, archer.strike_harm()])
			check(is_equal_approx(crossbow.strike_harm(), bolt * Weather.RAIN_CROSSBOW), "a crossbow a little softer")
			check(is_equal_approx(spear.strike_harm(), jab), "a spear no different")
			check(is_equal_approx(torch.harm_against(gs.human().base()), burn * Weather.RAIN_FIRE), "a torch burns walls slower")
			check(spear._sight() < Unit.SIGHT, "and everyone sees a little less")
			sky.forced_rain = 0
			sky.rain = 0.0
			sky._physics_process(0.0)
			# on to the dead of night
			sky.clock = 200.0
			sky._physics_process(0.0)
			stage = 2
			frame = 0
		2:
			if frame < 10:
				return false
			check(sky.phase == "night" and is_equal_approx(sky.darkness(), 1.0), "night falls on the clock")
			check(is_equal_approx(spear._sight(), Unit.SIGHT * Weather.NIGHT_SIGHT), "a soldier sees less far", spear._sight())
			check(archer._lose_sight() >= archer.reach() + 40.0, "but an archer never loses sight inside his own bowshot")
			check(is_equal_approx(Weather.tower_sight(), Weather.NIGHT_TOWER), "and a tower shoots less far")
			check(hud.sky_label.text == "Ночь", "the panel says it is night", hud.sky_label.text)
			sky.clock = 310.0
			sky._physics_process(0.0)
			check(sky.phase == "day" and is_equal_approx(spear._sight(), Unit.SIGHT), "and day comes round again")
			change_scene_to_file("res://scenes/main/Main.tscn")
			stage = 3
			frame = 0
		3:
			if frame < 30:
				return false
			check(Weather.current == null and is_equal_approx(Weather.sight(), 1.0), "the testbed has no weather")
			return true
	return false
