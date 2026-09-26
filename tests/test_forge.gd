extends "res://tests/lib/test_case.gd"
## The forge: up to two to a side; nothing forged before one stands finished; each
## piece is paid for and takes its time; a finished piece goes straight onto a
## soldier who lacks it, or into the store for the next one hired; a shield
## only goes to a one-handed weapon; and the kit really does keep blows off --
## a helm, plate, and a shield only from the front. Nothing is made without a
## smith: a labourer put to an anvil walks there and hammers, every blow moves
## the work along, two anvils take two smiths, and each goes back to its trade
## when released.

var stage := 0
var smithy: Forge
var bare: Unit
var spear: Unit
var hand: Worker
var hand2: Worker
var first_helm_at := -1.0
var blows_at_start := 0

func begin() -> void:
	time_limit = 60 * 90
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(loadout: String, at: Vector2) -> Unit:
	var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
	unit.loadout = loadout
	unit.team = Team.Id.PLAYER
	unit.guards = false
	unit.position = at
	current_scene.add_child(unit)
	return unit

func _hand(at: Vector2) -> Worker:
	var worker: Worker = load("res://scenes/worker/Worker.tscn").instantiate()
	worker.team = Team.Id.PLAYER
	worker.job = "wood"
	worker.position = at
	current_scene.add_child(worker)
	return worker

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
			check(not gs.forge(1, "helm"), "nothing is forged without a forge")
			check(gs.build(1, "forge", Vector2(620, 180)), "a forge is laid out")
			check(gs.build_problem(1, "forge", Vector2(620, 420)) == "", "a second forge may go up")
			for b in me.buildings:
				if b is Forge: smithy = b
			check(not gs.forge(1, "helm"), "an unfinished forge makes nothing")
			bare = _soldier("warrior", Vector2(600, 300))
			spear = _soldier("spearman", Vector2(700, 330))
			me.squad.add(bare)
			me.squad.add(spear)
			check(not gs.assign_smith(1), "no smith without a forge")
			hand = _hand(Vector2(420, 330))
			hand2 = _hand(Vector2(440, 360))
			stage = 1
		1:
			if not smithy.is_complete():
				return false
			# a warrior has nothing; a spearman already has a helm and a two-handed spear
			check(bare.can_wear("helm") and bare.can_wear("armour") and bare.can_wear("shield"), "a warrior could use all three")
			check(not spear.can_wear("helm") and not spear.can_wear("shield"), "a spearman has a helm and no hand for a shield")
			check(is_equal_approx(bare.guard_against(Vector2(700, 300)), 1.0), "bare, every blow goes home")
			var ore: int = me.economy.ore
			check(gs.forge(1, "helm"), "a helm is ordered")
			check(me.economy.ore == ore - 15, "and paid for", ore - me.economy.ore)
			check(gs.forge(1, "helm"), "and a second, with nobody to wear it yet")
			check(gs.forge(1, "shield") and gs.forge(1, "armour"), "a shield and plate are ordered")
			stage = 2
			frame = 0
		2:
			if frame == 60 * 4:
				check(smithy.on_anvil == ["", ""] and smithy.queue.size() == 4, "without a smith nothing gets made", smithy.on_anvil)
				check(gs.assign_smith(1), "a labourer is put to an anvil")
				check(me.smiths().size() == 1 and me.smith().weapon == PlayerBody.Weapon.HAMMER, "and takes up the hammer")
				check(gs.assign_smith(1), "a second is put to the other anvil")
				check(hand.is_smith() and hand2.is_smith() and hand.anvil != hand2.anvil, "one to each anvil", [hand.anvil, hand2.anvil])
				check(not gs.assign_smith(1), "two smiths to a forge")
			if frame > 60 * 4 and first_helm_at < 0.0 and bare.helm == PlayerBody.Helm.WORN:
				first_helm_at = seconds()
				check(hand.at_anvil() or hand2.at_anvil(), "it was beaten out at an anvil")
				check(int(me.gear["helm"]) == 0, "the first helm went straight onto the warrior", me.gear)
			if smithy.all_pending().is_empty() and frame > 60 * 4:
				check(first_helm_at > 0.0, "the helm was made", "at %.1f s" % first_helm_at)
				check(true, "all four pieces done by", "%.1f s" % seconds())
				check(int(me.gear["helm"]) == 1, "the second helm waits in store", me.gear)
				check(bare.has_shield() and bare.wears_armour(), "the warrior got the shield and the plate")
				check(int(me.gear["shield"]) == 0 and int(me.gear["armour"]) == 0, "and none of those is left over", me.gear)
				check(me.short_of("helm") == 0, "nobody in the ranks lacks a helm now")
				# kit keeps blows off: front and back differ by the shield only
				var front := bare.global_position + Vector2(bare.facing_x * 50.0, 0.0)
				var back := bare.global_position - Vector2(bare.facing_x * 50.0, 0.0)
				check(is_equal_approx(bare.guard_against(back), 0.9 * 0.8), "helm and plate keep off 28% from behind", bare.guard_against(back))
				check(is_equal_approx(bare.guard_against(front), 0.9 * 0.8 * 0.7), "and the shield more from the front", bare.guard_against(front))
				var health := bare.health
				bare.take_hit(front, 20.0)
				check(is_equal_approx(health - bare.health, 20.0 * 0.504), "a blow from the front does half", health - bare.health)
				# the next man hired picks up the helm from the store
				gs.hire(1, "warrior")
				stage = 3
				frame = 0
		3:
			if me.squad.alive().size() >= 3:
				var recruit: Unit = me.squad.alive()[me.squad.alive().size() - 1]
				check(recruit.helm == PlayerBody.Helm.WORN, "a new recruit took the helm from the store")
				check(int(me.gear["helm"]) == 0, "and the store is empty", me.gear)
				check(gs.release_smith(1) and gs.release_smith(1) and hand.job == "wood" and hand.weapon == PlayerBody.Weapon.AXE,
					"released, the smiths go back to felling", hand.job)
				check(me.smiths().is_empty(), "and nobody is left at the anvils")
				return true
	return false
