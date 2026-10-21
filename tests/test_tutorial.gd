extends "res://tests/lib/test_case.gd"
## The training room. It is open from the start, like the first room; it builds
## its own map: an army of twelve and no castle of ours, the enemy's castle with
## two towers and ten defenders nobody commands. Our mage already knows how to
## heal. The lessons go one by one as each is done (driven here by hand, as the
## HUD's input would); knocking the castle down wins it, three stars for a
## quick win with the army whole, and losing the whole army loses it.

var stage := 0
var campaign: Node
var hud: Node
var lesson: Tutorial

func begin() -> void:
	time_limit = 60 * 120
	campaign = root.get_node("Campaign")

func _mage(us: PlayerState) -> Unit:
	for unit in us.squad.alive():
		if unit.loadout == "mage":
			return unit
	return null

## Waits until the lesson is past `index`.
func _past(index: int) -> bool:
	return lesson.step > index

func step() -> bool:
	var gs := game()
	if frame == 1 and stage == 0 and not playing():
		check(campaign.is_open(0) and bool(campaign.ROOMS[0].get("tutorial", false)), "the training room comes first and is open")
		campaign.start(0)
	match stage:
		0:
			if not playing() or frame < 10:
				return false
			var us: PlayerState = gs.human()
			var foe: PlayerState = gs.enemy_of(1)
			check(current_scene.map.title == "Учебный штурм", "it builds its own map", current_scene.map.title)
			check(us.base() == null and us.squad.alive().size() == 12, "an army of twelve and no castle of ours", us.squad.alive().size())
			check(foe.base() != null and foe.get_node_or_null("AIDirector") == null, "their castle, with nobody at its head")
			var towers := 0
			for b in foe.buildings:
				if b is Tower: towers += 1
			check(towers == 2 and foe.squad.alive().size() == 10, "two towers and ten defenders", [towers, foe.squad.alive().size()])
			check(_mage(us) != null and _mage(us).can_mend, "our mage already knows how to heal")
			check(FogOfWar.current != null and current_scene.get_node_or_null("Weather") == null, "fog, and no weather to confuse a beginner")
			hud = current_scene.get_node("Hud")
			lesson = hud.tutorial
			check(lesson != null and lesson.visible and lesson.step == 0, "the first lesson is up")
			stage = 1
			frame = 0
		1:
			# the lessons, done the way the HUD's input would do them
			var us: PlayerState = gs.human()
			match lesson.step:
				0:
					if frame == 5:
						root.get_camera_2d().global_position += Vector2(300, 0)
				1:
					hud.input.choose([us.squad.alive()[0]])
				2:
					hud.input.choose(us.squad.alive().slice(0, 4))
				3:
					hud.input.keep_group(1)
				4:
					if frame % 120 == 0:
						gs.attack_move(1, Vector2(1100, 300))
				5:
					FogOfWar.current.explored.fill(1)
				6:
					for b in (gs.enemy_of(1).buildings if frame % 60 == 0 else []):
						if b is Tower and b.is_alive():
							b.take_hit(Vector2.INF, 99999.0)
							break
				7:
					var glow := Node.new()
					glow.add_to_group("mend_glows")
					current_scene.add_child(glow)
				8:
					check(true, "every lesson went by in turn", "%.0f s" % seconds())
					stage = 2
					frame = 0
			if frame > 60 * 60:
				check(false, "the lessons go on", lesson.step)
				return true
		2:
			# the castle down: the room is won
			gs.enemy_of(1).base().take_hit(Vector2.INF, 99999.0)
			stage = 3
			frame = 0
		3:
			if frame < 5:
				return false
			check(gs.phase == gs.Phase.WON, "knocking their castle down wins the room")
			check(campaign.last_earned == 3, "a quick win with the whole army is three stars", campaign.last_earned)
			campaign.start(0)
			stage = 4
			frame = 0
		4:
			if not playing() or frame < 10:
				return false
			for unit in gs.human().squad.alive():
				unit.take_hit(Vector2.INF, 99999.0)
			stage = 5
			frame = 0
		5:
			if frame < 10:
				return false
			check(gs.phase == gs.Phase.LOST, "losing the whole army loses the room")
			return true
	return false
