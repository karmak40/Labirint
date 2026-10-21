extends "res://tests/lib/test_case.gd"
## The raid, room 5 «Разведка боем»: a small army and no castle of ours, three
## bandit camps on the way, and the enemy's stronghold guarded by a chieftain
## much stronger than any man, with two knights beside him. Breaking a camp
## frees prisoners who join us; the room counts the camps; the chieftain's fall
## is announced; the castle falling wins it.

var stage := 0
var campaign: Node
var rules: RoomRules
var army_before := 0

func begin() -> void:
	time_limit = 60 * 60
	campaign = root.get_node("Campaign")

func _room() -> int:
	for i in campaign.ROOMS.size():
		if campaign.ROOMS[i]["id"] == "raid":
			return i
	return -1

func step() -> bool:
	var gs := game()
	if frame == 1 and stage == 0 and not playing():
		check(_room() >= 0, "the raid is in the campaign")
		campaign.stars["ring"] = 1
		check(campaign.is_open(_room()), "it opens once the holdout is won")
		campaign.start(_room())
	match stage:
		0:
			if not playing() or frame < 10:
				return false
			var us: PlayerState = gs.human()
			var foe: PlayerState = gs.enemy_of(1)
			check(current_scene.map.title == "Разведка боем", "its own map", current_scene.map.title)
			check(us.base() == null and us.squad.alive().size() == 8, "eight men and no castle of ours", us.squad.alive().size())
			check(get_nodes_in_group("camps").size() == 3, "three camps", get_nodes_in_group("camps").size())
			rules = current_scene.get_node("RoomRules")
			check(rules.boss != null and rules.boss.is_alive(), "the chieftain stands")
			check(rules.boss.team == foe.team and rules.boss.epithet == "Вождь", "on the enemy's side, and named")
			check(rules.boss.health_max > 3.0 * 100.0, "far tougher than a man", rules.boss.health_max)
			check(rules.boss.strike_harm() > rules.boss.harm_scale * 1.0, "and hits harder")
			check(rules.boss.scale.x > 1.2, "and bigger")
			var knights := 0
			for unit in foe.squad.alive():
				if unit.loadout == "knight":
					knights += 1
			check(knights >= 3, "his knights beside him, and the castle's own", knights)
			check(rules.objective().contains("0"), "the objective counts the camps", rules.objective())
			army_before = us.squad.alive().size()
			stage = 1
			frame = 0
		1:
			# a man of ours by the first camp, then the camp is broken
			var us: PlayerState = gs.human()
			var camp: BanditCamp = get_nodes_in_group("camps")[0]
			for other: BanditCamp in get_nodes_in_group("camps"):
				if other.global_position.x < camp.global_position.x:
					camp = other
			if frame == 1:
				us.squad.alive()[0].global_position = camp.global_position + Vector2(-200, 0)
				return false
			if frame == 5:
				for bandit in camp.bandits:
					bandit.take_hit(Vector2.INF, 99999.0)
				return false
			if frame < 30:
				return false
			check(camp.is_cleared and camp.claimed_by == 1, "we broke it")
			check(us.squad.alive().size() == army_before + 3, "three prisoners joined us", us.squad.alive().size())
			check(rules.camps_cleared == 1 and rules.objective().contains("1"), "and the count says one", rules.objective())
			stage = 2
			frame = 0
		2:
			if frame == 1:
				rules.boss.take_hit(Vector2.INF, 99999.0)
				return false
			if frame < 10:
				return false
			check(not rules.boss.is_alive(), "the chieftain can be felled")
			gs.enemy_of(1).base().take_hit(Vector2.INF, 99999.0)
			stage = 3
			frame = 0
		3:
			if frame < 5:
				return false
			check(gs.phase == gs.Phase.WON, "the castle down wins the room")
			check(campaign.last_earned >= 2, "a quick win earns stars", campaign.last_earned)
			return true
	return false
