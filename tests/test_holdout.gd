extends "res://tests/lib/test_case.gd"
## Room 4, the holdout, quickly: its castle stands mid-field and the enemy has
## none; waves come in from the spawn points the room names, in time, and are
## knocked down by hand; a wave with a reward pays it once it is down; beating
## the last wave wins the room. Also how a room's wave list is spelled out
## (repeats, growth, the difficulty's scale).

const ROOM := 3

var stage := 0
var campaign: Node
var rules: RoomRules
var wood_before := 0

func begin() -> void:
	time_limit = 60 * 90
	campaign = root.get_node("Campaign")
	_check_expand()

## RoomRules.expand: copies at their times, grown and scaled, in order.
func _check_expand() -> void:
	var room := {"wave_scale": {"hard": 2.0},
		"waves": [{"at": 100.0, "units": {"warrior": 3}, "repeat": 2, "every": 50.0, "grow": 0.5},
			{"at": 120.0, "units": {"archer": 1, "knight": 0}}]}
	var plain := RoomRules.expand(room, "normal")
	var times := plain.map(func(w: Dictionary) -> float: return w["at"])
	check(times == [100.0, 120.0, 150.0, 200.0], "repeats come every 50 s, sorted in among the rest", times)
	var sizes := plain.map(func(w: Dictionary) -> int: return int(w["units"].get("warrior", 0)))
	check(sizes == [3, 0, 5, 6], "each copy is half again as big as the first (3, 4.5, 6)", sizes)
	check(not plain[1]["units"].has("knight"), "a kind with none is left out")
	var hard := RoomRules.expand(room, "hard")
	check(int(hard[0]["units"]["warrior"]) == 6 and int(hard[1]["units"]["archer"]) == 2, "a harder difficulty scales the men",
		hard.map(func(w: Dictionary) -> Dictionary: return w["units"]))

func step() -> bool:
	var gs := game()
	if frame == 1 and stage == 0 and not playing():
		# here, not in begin(): Campaign reads its file again once it is ready
		check(not campaign.is_open(ROOM), "the holdout is shut until the siege is won")
		campaign.stars["siege"] = 1
		check(campaign.is_open(ROOM), "and opens after it")
		campaign.start(ROOM)
	match stage:
		0:
			if not playing() or frame < 5:
				return false
			var map: MapData = current_scene.map
			check(map.title == "В кольце", "room 4 builds its own map", map.title)
			var keep: Base = gs.human().base()
			check(absf(keep.global_position.x - map.floor_size.x * 0.5) < 50.0, "our castle stands in the middle", keep.global_position)
			var foe: PlayerState = gs.enemy_of(1)
			check(foe != null and foe.base() == null, "the enemy has no castle on the field")
			check(foe.get_node_or_null("AIDirector") == null, "and no head: the room sends its waves")
			rules = current_scene.get_node_or_null("RoomRules")
			check(rules != null and rules.after_waves == "win", "beating the waves is what wins")
			check(rules.waves.size() == 11, "eleven waves at normal difficulty", rules.waves.size())
			var hud := current_scene.get_node("Hud")
			hud._refresh()
			check(hud.objective.text.contains("Волна 1 из 11"), "the HUD counts down to the first wave", hud.objective.text)
			rules.clock = float(rules.waves[0]["at"]) - 0.02
			stage = 1
			frame = 0
		1:
			if frame < 3:
				return false
			check(rules.sent == 1 and rules.alive_in_waves.size() == 3, "the first wave comes in on time", rules.alive_in_waves.size())
			var first: Unit = rules.alive_in_waves[0]
			check(first.global_position.x < 200.0, "from the west edge", first.global_position)
			check(first.order == Unit.Order.ATTACK_MOVE, "and marches on our castle")
			_knock_down()
			stage = 2
			frame = 0
		2:
			if frame < 3:
				return false
			check(rules.outs[0]["beaten"], "a wave all down counts as beaten")
			check(not rules.open and gs.is_playing(), "one wave beaten is not the end")
			wood_before = gs.human().economy.wood
			# the probes and the first wave from both sides, all at once
			rules.clock = 280.0 - 0.02
			stage = 3
			frame = 0
		3:
			if frame < 3:
				return false
			check(rules.sent == 5, "every wave due by 280 s has come", rules.sent)
			var west := 0
			var east := 0
			for unit in rules.outs[4]["units"]:
				if unit.global_position.x < 400.0: west += 1
				if unit.global_position.x > 2600.0: east += 1
			check(west == 4 and east == 4, "the double wave is split between west and east", "%d / %d" % [west, east])
			_knock_down()
			stage = 4
			frame = 0
		4:
			if frame < 3:
				return false
			# workers may bank a log meanwhile, so at least the reward
			check(gs.human().economy.wood >= wood_before + 60, "the beaten wave's reward is paid", gs.human().economy.wood - wood_before)
			rules.clock = 9999.0
			stage = 5
			frame = 0
		5:
			if frame < 3:
				return false
			check(rules.sent == rules.waves.size(), "then the rest come")
			check(gs.is_playing(), "and while they stand the room is not won", rules.objective())
			# the wave at 600 s: swordsmen, who take a shield, and crossbowmen, who can not
			var shielded := 0
			var swordsmen := 0
			for unit in rules.outs[8]["units"]:
				if unit.loadout == "swordsman": swordsmen += 1
				if unit.has_shield(): shielded += 1
			check(swordsmen == 5 and shielded == 5, "a wave's extra kit goes on whoever can wear it", "%d of %d" % [shielded, swordsmen])
			_knock_down()
			stage = 6
			frame = 0
		6:
			if frame < 5:
				return false
			check(gs.phase == gs.Phase.WON, "beating the last wave wins the room")
			check(campaign.stars_of(ROOM) >= 2, "with a whole castle it is worth at least two stars", campaign.stars_of(ROOM))
			var hud := current_scene.get_node("Hud")
			check(hud.overlay_note.text.contains("Вы выстояли"), "the end screen says we held", hud.overlay_note.text)
			return true
	return false

func _knock_down() -> void:
	for unit in rules.alive_in_waves:
		if is_instance_valid(unit) and unit.is_alive():
			unit.take_hit(Vector2.ZERO, 99999.0)
