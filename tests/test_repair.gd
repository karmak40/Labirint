extends "res://tests/lib/test_case.gd"
## Repair: a labourer put to mending walks to the most damaged building, hammers it
## back up a little wood a blow, stops once it is whole, and stands idle with
## nothing to mend. Without wood it does nothing; with an enemy by the building
## it leaves it alone. Released, it goes back to its trade.

var stage := 0
var hand: Worker
var tower: Tower
var foe: Unit
var wood_before := 0

func begin() -> void:
	time_limit = 60 * 120
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			me.economy.add("wood", 200)
			me.economy.add("ore", 200)
			var keep := me.base()
			var toward := 1.0 if keep.global_position.x < gs.field().map.floor_size.x * 0.5 else -1.0
			tower = Tower.new()
			tower.team = Team.Id.PLAYER
			tower.position = keep.global_position + Vector2(toward * 420.0, 140.0)
			gs.field().add_child(tower)
			me.adopt(tower)
			hand = load("res://scenes/worker/Worker.tscn").instantiate()
			hand.team = Team.Id.PLAYER
			hand.job = "ore"
			hand.position = keep.door_point() + Vector2(0, 40)
			current_scene.add_child(hand)
			check(not me.anything_to_repair(), "nothing is hurt at the start")
			keep.take_hit(Vector2.INF, 300.0)
			tower.take_hit(Vector2.INF, 200.0)
			check(me.anything_to_repair(), "the castle and the tower are hurt")
			check(gs.assign_repairer(1), "a labourer is put to mending")
			check(hand.job == "repair" and hand.weapon == PlayerBody.Weapon.HAMMER, "and takes up the hammer")
			wood_before = me.economy.wood
			stage = 1
			frame = 0
		1:
			# the tower has lost more of its share: it comes first
			if frame == 60 * 3:
				check(hand.mending == tower, "the worse hurt goes first", hand.mending)
			if tower.health < tower.health_max:
				return false
			check(true, "the tower is whole again after", "%.1f s" % seconds())
			var spent := wood_before - me.economy.wood
			check(spent >= 16 and spent <= 20, "for about a wood a blow", spent)
			stage = 2
		2:
			if me.base().health < me.base().health_max:
				return false
			check(true, "then the castle", "%.1f s" % seconds())
			check(not me.anything_to_repair(), "nothing is left to mend")
			stage = 3
			frame = 0
		3:
			if frame < 60:
				return false
			check(hand.mending == null, "it stands idle")
			# no wood, no mending
			tower.take_hit(Vector2.INF, 100.0)
			me.economy.spend({"wood": me.economy.wood})
			stage = 4
			frame = 0
		4:
			if frame < 60 * 8:
				return false
			check(is_equal_approx(tower.health, tower.health_max - 100.0), "without wood the tower stays hurt", tower.health)
			# wood back, but an enemy by the tower
			me.economy.add("wood", 100)
			foe = load("res://scenes/warrior/Warrior.tscn").instantiate()
			foe.team = Team.Id.ENEMY
			foe.guards = false
			foe.position = tower.global_position + Vector2(0, -120)
			current_scene.add_child(foe)
			stage = 5
			frame = 0
		5:
			if foe.is_alive():
				foe.global_position = tower.global_position + Vector2(0, -120)
				foe.velocity = Vector2.ZERO
			if frame < 60 * 6:
				return false
			check(tower.health <= tower.health_max - 100.0, "with an enemy by it nobody mends it", tower.health)
			foe.queue_free()
			stage = 6
			frame = 0
		6:
			if tower.health < tower.health_max:
				return false
			check(true, "once it is gone the tower is mended")
			check(gs.release_repairer(1) and hand.job == "ore", "released, it goes back to the ore", hand.job)
			return true
	return false
