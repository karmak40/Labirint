extends "res://tests/lib/test_case.gd"
## Soldiers are men with arms. Ordering one pays for the man and for whatever
## of his arms is not in store; the castle hires him, he walks to the forge and
## waits there until a smith has made his pieces, carries them to the barracks,
## trains, and comes out a soldier of that kind. A warrior's club costs nothing
## and needs no forge. Pieces made ahead into the store are taken off the price.
## A recruit is not a labourer. Lose the man and the order is lost; his pieces
## stay in store. Two forges to a side, no more.

var stage := 0
var smithy: Forge
var spear_man: Worker
var ordered_at := 0.0
var ranks_before := 0
var saw_club := false

func begin() -> void:
	time_limit = 60 * 150
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _hand(at: Vector2) -> Worker:
	var worker: Worker = load("res://scenes/worker/Worker.tscn").instantiate()
	worker.team = Team.Id.PLAYER
	worker.job = "wood"
	worker.position = at
	current_scene.add_child(worker)
	return worker

func _recruits(me: PlayerState) -> Array[Worker]:
	var found: Array[Worker] = []
	for node in get_nodes_in_group("workers"):
		var man := node as Worker
		if man != null and man.team == me.team and man.job == "recruit" and man.is_alive():
			found.append(man)
	return found

func _count(me: PlayerState, kind: String) -> int:
	var n := 0
	for unit in me.squad.alive():
		if unit.loadout == kind:
			n += 1
	return n

func _total(price: Dictionary) -> int:
	var sum := 0
	for resource in price:
		sum += int(price[resource])
	return sum

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			raise_barracks(Team.Id.PLAYER)
			me.economy.add("wood", 600)
			me.economy.add("ore", 600)
			me.researched["spears"] = true
			check(me.order_problem("spearman") == "Нет кузницы", "no spear without a forge", me.order_problem("spearman"))
			check(me.order_problem("warrior") == "", "but a warrior needs none")
			smithy = raise_forge(Team.Id.PLAYER)
			check(_total(me.draft_price("spearman")) == 25, "a spearman costs the man and the spear", me.draft_price("spearman"))
			check(_total(me.draft_price("warrior")) == 10, "a warrior only the man", me.draft_price("warrior"))
			var ore: int = me.economy.ore
			var wood: int = me.economy.wood
			check(gs.hire(1, "spearman"), "a spearman is ordered")
			check(wood + ore - me.economy.wood - me.economy.ore == 25, "and paid for up front")
			check(smithy.queue == ["spear"], "his spear goes on the forge's list", smithy.queue)
			check(me.base().queue.has("recruit"), "and a man on the castle's")
			ordered_at = seconds()
			stage = 1
			frame = 0
		1:
			# no smith yet: he comes out, walks to the forge and waits there
			var men := _recruits(me)
			if men.is_empty() or men[0].draft.stage != Draft.Stage.ARMING or frame < 60 * 12:
				return false
			spear_man = men[0]
			check(not me.workers().has(spear_man), "a recruit is not a labourer")
			check(spear_man.global_position.distance_to(smithy.collect_point()) < 60.0, "he waits at the forge",
				spear_man.global_position.distance_to(smithy.collect_point()))
			check(spear_man.weapon == PlayerBody.Weapon.NONE, "empty handed")
			_hand(me.base().door_point() + Vector2(0, 40))
			check(gs.assign_smith(1), "a smith is put to the anvil")
			stage = 2
			frame = 0
		2:
			if spear_man.draft.stage != Draft.Stage.CARRYING:
				return false
			check(spear_man.weapon == PlayerBody.Weapon.SPEAR, "the spear made, he carries it")
			check(int(me.gear["spear"]) == 0, "out of the store")
			stage = 3
		3:
			if _count(me, "spearman") == 0:
				return false
			check(not is_instance_valid(spear_man) or spear_man.is_queued_for_deletion(), "he went into the barracks")
			check(me.drafts.is_empty(), "and the order is done")
			check(true, "a spearman in the ranks after", "%.1f s" % (seconds() - ordered_at))
			# a warrior walks straight to the barracks with a club from the castle
			ranks_before = _count(me, "warrior")
			check(gs.hire(1, "warrior"), "a warrior is ordered")
			check(smithy.all_pending().is_empty(), "nothing for the forge")
			stage = 4
			frame = 0
		4:
			var men := _recruits(me)
			if not saw_club and not men.is_empty() and men[0].draft.stage == Draft.Stage.CARRYING:
				saw_club = true
				check(men[0].weapon == PlayerBody.Weapon.CLUB, "a club in hand from the castle")
			if _count(me, "warrior") == ranks_before:
				return false
			check(true, "a warrior in the ranks")
			# a spear made ahead comes off the next spearman's price
			check(gs.forge(1, "spear"), "a spear is made into the store")
			stage = 5
		5:
			if int(me.gear["spear"]) < 1:
				return false
			check(_total(me.draft_price("spearman")) == 10, "with a spear in store a spearman costs just the man", me.draft_price("spearman"))
			check(gs.hire(1, "spearman"), "one is ordered")
			check(smithy.all_pending().is_empty(), "and nothing more is forged")
			stage = 6
		6:
			var men := _recruits(me)
			if men.is_empty():
				return false
			# killed on the way: the order goes with him, the spear stays put by for nobody
			men[0].take_hit(Vector2.INF, 10000.0)
			stage = 7
			frame = 0
		7:
			if frame < 30:
				return false
			check(me.drafts.is_empty(), "a dead recruit's order is lost")
			check(me.spare("spear") == 1, "his spear is still in store", me.gear["spear"])
			# a second forge may go up, a third may not
			me.researched["chivalry"] = true
			var spot := Vector2.INF
			for at in [Vector2(620, 150), Vector2(760, 150), Vector2(900, 150), Vector2(760, 420)]:
				if gs.build_problem(1, "forge", at) == "":
					spot = at
					break
			check(spot != Vector2.INF and gs.build(1, "forge", spot), "a second forge may go up")
			check(gs.build_problem(1, "forge", Vector2(620, 420)) == "Уже две кузницы", "a third is refused")
			# a knight takes a sword, a helm, plate and a shield
			check(_total(me.draft_price("knight")) == 110, "a knight's kit is dear", me.draft_price("knight"))
			check(gs.hire(1, "knight"), "a knight is ordered")
			check(smithy.all_pending().size() == 4, "all four pieces go on the list", smithy.all_pending())
			_hand(me.base().door_point() + Vector2(20, 40))
			check(gs.assign_smith(1), "a second smith for the other anvil")
			ordered_at = seconds()
			stage = 8
		8:
			if _count(me, "knight") == 0:
				return false
			var knight: Unit = null
			for unit in me.squad.alive():
				if unit.loadout == "knight":
					knight = unit
			check(knight.has_shield() and knight.wears_armour() and knight.helm == PlayerBody.Helm.WORN, "the knight has all his kit")
			check(int(me.gear["helm"]) == 0 and int(me.gear["armour"]) == 0 and int(me.gear["shield"]) == 0,
				"none of it went to anyone else", me.gear)
			check(true, "a knight in the ranks after", "%.1f s" % (seconds() - ordered_at))
			return true
	return false
