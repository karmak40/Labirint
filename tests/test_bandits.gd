extends "res://tests/lib/test_case.gd"
## Bandit camps. The first room and the long skirmish map have none; the
## gorge has two, one by each gold seam, each of four bandits of their own side,
## enemies of both. They keep to their camp. Labourers will not work a seam a
## camp guards. Clear a camp and the side nearest takes its chest; the bandits'
## arms lie as trophies, and the seam is free to work. The enemy's head clears
## the camp on its own half.

var stage := 0
var camps: Array[BanditCamp] = []
var near: BanditCamp           ## the one on our half
var miner: Worker
var army: Array[Unit] = []
var wood_before := 0
var gold_before := 0
var cleared_at := -1

func begin() -> void:
	time_limit = 60 * 150
	game().map = load("res://resources/maps/campaign_forest.tres")
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _gorge_veins() -> Array[OreVein]:
	var found: Array[OreVein] = []
	for node in get_nodes_in_group("veins"):
		var vein := node as OreVein
		if vein != null and vein.resource_kind == "gold":
			found.append(vein)
	return found

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing():
				return false
			check(get_nodes_in_group("camps").is_empty(), "the first room has no bandits")
			check((load("res://resources/maps/skirmish_long.tres") as MapData).camp_positions.is_empty(), "nor the long skirmish")
			gs.map = load("res://resources/maps/campaign_gorge.tres")
			gs.restart_match()
			stage = 1
		1:
			if not playing() or current_scene.map.title != "Золотое ущелье" or frame < 5:
				return false
			silence(Team.Id.ENEMY)
			for node in get_nodes_in_group("camps"):
				camps.append(node)
			check(camps.size() == 2, "the gorge has two camps", camps.size())
			if camps.size() < 2:
				return true
			near = camps[0] if camps[0].global_position.x < camps[1].global_position.x else camps[1]
			for camp in camps:
				check(camp.alive() == 4, "four bandits to a camp", camp.alive())
				check(Team.hostile(camp.bandits[0].team, Team.Id.PLAYER) and Team.hostile(camp.bandits[0].team, Team.Id.ENEMY),
					"enemies of both sides")
			for vein in _gorge_veins():
				check(BanditCamp.guarded(self, vein.global_position), "each gold seam is guarded")
			var me: PlayerState = gs.human()
			miner = load("res://scenes/worker/Worker.tscn").instantiate()
			miner.team = Team.Id.PLAYER
			miner.job = "gold"
			miner.position = gs.field().map.player.stockpile + Vector2(0, -40)
			current_scene.add_child(miner)
			# the enemy's head would go for the camp on its own half, not ours
			var head := AIDirector.new()
			head.team = Team.Id.ENEMY
			current_scene.add_child(head)
			head.game = gs
			var theirs := head._camp_to_clear(gs.side(Team.Id.ENEMY))
			check(theirs != null and theirs != near, "the enemy's head picks the camp on its half")
			var ours := head._camp_to_clear(me)
			check(ours == near, "and ours is the one on our half")
			head.free()
			stage = 2
			frame = 0
		2:
			if frame < 60 * 8:
				return false
			check(miner.source == null, "a gold miner will not work a guarded seam", miner.source)
			for camp in camps:
				for bandit in camp.bandits:
					check(bandit.global_position.distance_to(camp.global_position) < 260.0, "the bandits keep to their camp",
						bandit.global_position.distance_to(camp.global_position))
			# eight knights of ours go for the near camp
			var me: PlayerState = gs.human()
			wood_before = me.economy.wood
			gold_before = me.economy.gold
			for i in 8:
				var knight: Unit = load("res://scenes/knight/Knight.tscn").instantiate()
				knight.team = Team.Id.PLAYER
				knight.position = near.global_position + Vector2(-260 - (i % 3) * 30, -30 + (i / 3) * 35)
				current_scene.add_child(knight)
				me.squad.add(knight)
				army.append(knight)
			stage = 3
			frame = 0
		3:
			if frame == 2:
				gs.attack_move(Team.Id.PLAYER, near.global_position)
			if not near.is_cleared:
				return false
			# the last one down lets go of his weapon a moment later
			if cleared_at < 0:
				cleared_at = frame
			if frame < cleared_at + 60:
				return false
			var me: PlayerState = gs.human()
			check(true, "the camp was cleared in", "%.1f s" % (cleared_at / 60.0))
			check(near.claimed_by == Team.Id.PLAYER, "and its chest is ours", near.claimed_by)
			check(me.economy.wood == wood_before + 40 and me.economy.gold == gold_before + 20, "the bounty is in the store",
				[me.economy.wood - wood_before, me.economy.gold - gold_before])
			var loot := []
			for node in get_nodes_in_group("trophies"):
				loot.append((node as Trophy).item)
			check(loot.has("spear") and loot.has("bow"), "the bandits' arms lie as trophies", loot)
			gs.rally_home(Team.Id.PLAYER)
			stage = 4
			frame = 0
		4:
			# the other camp may have come for the knights; either way the near seam is free
			if miner.source == null or not (miner.source is OreVein):
				if frame > 60 * 20:
					check(false, "the gold miner goes to the freed seam")
					return true
				return false
			check(not BanditCamp.guarded(self, miner.source.global_position), "the gold miner works the freed seam")
			return true
	return false
