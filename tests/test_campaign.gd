extends "res://tests/lib/test_case.gd"
## The campaign, room by room, quickly: nothing is played out for real -- the
## enemy's head is taken off and castles are knocked down by hand -- because
## what is checked is the campaign's own doing: which rooms are open, what a win
## is worth and that it is kept, that each room stands its own map up, and
## that the siege's gates stay shut until its waves are beaten.

var stage := 0
var campaign: Node
var rules: RoomRules

func begin() -> void:
	time_limit = 60 * 120
	campaign = root.get_node("Campaign")
	check(campaign.save_path == CAMPAIGN_FILE, "campaign progress is kept in the test's own file")
	check(campaign.is_open(0) and not campaign.is_open(1) and not campaign.is_open(2), "only the first room is open to begin with")

func step() -> bool:
	var gs := game()
	if frame == 1 and stage == 0 and not playing():
		campaign.start(0)
	match stage:
		0:
			if not playing() or frame < 5:
				return false
			check(current_scene.map.title == "Лесной рубеж", "room 1 builds its own map", current_scene.map.title)
			rules = current_scene.get_node_or_null("RoomRules")
			check(rules != null, "the room's rules are in the match")
			var hud := current_scene.get_node("Hud")
			hud._refresh()
			check(hud.objective.text.contains("Разрушить"), "the HUD shows the room's goal", hud.objective.text)
			silence(Team.Id.ENEMY)
			gs.enemy_of(1).base().take_hit(Vector2.ZERO, 99999.0)
			stage = 1
			frame = 0
		1:
			if frame < 3:
				return false
			check(gs.phase == gs.Phase.WON, "knocking their castle down wins the room")
			check(campaign.last_earned == 3 and campaign.stars_of(0) == 3, "a quick win with the castle whole is three stars", campaign.last_earned)
			check(campaign.is_open(1), "and opens the second room")
			campaign.load_from(CAMPAIGN_FILE)
			check(campaign.stars_of(0) == 3, "the stars are still there read back from disk")
			var hud := current_scene.get_node("Hud")
			check(hud.next_button.visible and hud.overlay_title.text.contains("★★★"), "the end screen shows the stars and a way on", hud.overlay_title.text)
			campaign.current = 0
			hud.next_button.pressed.emit()
			stage = 2
			frame = 0
		2:
			if not playing() or frame < 10:
				return false
			var map: MapData = current_scene.map
			check(map.title == "Золотое ущелье" and campaign.current == 1, "«Следующая комната» went on to the gorge")
			check(get_nodes_in_group("boulders").size() == map.boulder_positions.size() and map.boulder_positions.size() > 20,
				"the gorge's walls of rock are standing", get_nodes_in_group("boulders").size())
			var towers := 0
			for b in gs.enemy_of(1).buildings:
				if b is Tower: towers += 1
			check(towers == 2, "the enemy holds the gorge with two towers", towers)
			check(gs.build_problem(1, "tower", map.boulder_positions[4]) != "", "nothing can be built on the rocks")
			# the way from one side of the gorge's top wall to the other runs down through the gorge
			var nav_map: RID = (current_scene.get_node("NavFloor") as NavFloor).get_navigation_map()
			var way := NavigationServer2D.map_get_path(nav_map, Vector2(1060, 70), Vector2(1960, 70), true)
			var lowest := 0.0
			for point in way:
				lowest = maxf(lowest, point.y)
			check(way.size() > 2 and lowest > 150.0, "the way over the gorge goes round through it, not over the rocks",
				"%d points, down to y=%.0f" % [way.size(), lowest])
			# on to the siege
			campaign.stars["gorge"] = 1
			campaign.start(2)
			stage = 3
			frame = 0
		3:
			if not playing() or frame < 5:
				return false
			rules = current_scene.get_node("RoomRules")
			silence(Team.Id.ENEMY)
			var keep: Base = gs.enemy_of(1).base()
			check(keep.shut, "the siege starts with the enemy's gates shut")
			var before := keep.health
			keep.take_hit(Vector2.ZERO, 500.0)
			check(keep.health == before, "and a shut castle takes no harm")
			check(rules.waves.size() == 5, "five waves are coming", rules.waves.size())
			var ours := 0
			for b in gs.human().buildings:
				if b is Tower: ours += 1
			check(ours == 1, "we start with a tower of our own", ours)
			rules.clock = float(rules.waves[0]["at"]) - 0.02
			stage = 4
			frame = 0
		4:
			if frame == 3:
				check(rules.sent == 1 and rules.alive_in_waves.size() == 4, "the first wave comes out on time", rules.alive_in_waves.size())
				var first: Unit = rules.alive_in_waves[0]
				check(first.order == Unit.Order.ATTACK_MOVE, "and marches on our castle")
				rules.clock = 9999.0
			if frame > 3 and rules.sent == rules.waves.size() and stage == 4:
				check(not rules.open, "the gates stay shut while the last wave stands", rules.objective())
				for unit in rules.alive_in_waves:
					if unit.is_alive():
						unit.take_hit(Vector2.ZERO, 99999.0)
				stage = 5
				frame = 0
		5:
			if frame == 3:
				var keep: Base = gs.enemy_of(1).base()
				check(rules.open and not keep.shut, "with every wave beaten the gates open")
				var before := keep.health
				keep.take_hit(Vector2.ZERO, 500.0)
				check(keep.health < before, "and the castle can be struck at last")
				return true
	return false
