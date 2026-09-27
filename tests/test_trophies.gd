extends "res://tests/lib/test_case.gd"
## Trophies: a soldier who falls leaves his weapon and his kit lying as
## trophies (a knight: sword, helm, plate, shield); a warrior's club is worth
## nothing. A labourer nearby carries them to a forge of its side, which takes
## them into the store -- but only while there is a forge, and never from under
## an enemy's nose. Left lying, a trophy rusts away, and the fallen themselves
## fade and are gone after a while.

var stage := 0
var smithy: Forge
var hand: Worker
var knight: Unit
var guard: Unit
var guarded: Trophy
var anchor := Vector2.ZERO

func begin() -> void:
	time_limit = 60 * 120
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(loadout: String, team: int, at: Vector2) -> Unit:
	var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
	unit.loadout = loadout
	unit.team = team
	unit.guards = false
	unit.position = at
	current_scene.add_child(unit)
	return unit

func _trophies() -> Array[Trophy]:
	var found: Array[Trophy] = []
	for node in get_nodes_in_group("trophies"):
		if not node.is_queued_for_deletion():
			found.append(node)
	return found

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			var field = gs.field()
			var layout: SideLayout = field.map.player
			anchor = layout.barracks + Vector2(signf(layout.barracks.x - layout.base.x) * 170.0, 0.0)
			hand = load("res://scenes/worker/Worker.tscn").instantiate()
			hand.team = Team.Id.PLAYER
			hand.job = "ore"
			hand.position = anchor + Vector2(120, 60)
			current_scene.add_child(hand)
			knight = load("res://scenes/knight/Knight.tscn").instantiate()
			knight.team = Team.Id.ENEMY
			knight.guards = false
			knight.position = anchor + Vector2(220, 40)
			current_scene.add_child(knight)
			stage = 1
			frame = 0
		1:
			if frame == 5:
				knight.take_hit(knight.global_position + Vector2(-40, 0), 10000.0)
			if frame < 90:
				return false
			var items := []
			for trophy in _trophies():
				items.append(trophy.item)
			items.sort()
			check(items == ["armour", "helm", "shield", "sword"], "a fallen knight leaves sword, helm, plate and shield", items)
			check(knight.helm == PlayerBody.Helm.NONE and not knight.wears_armour(), "and lies there without them")
			for item in knight.rig.dropped:
				check(item.kind != PlayerBody.Weapon.SWORD_SHIELD, "his sword is the trophy, not the rig's own")
			# a club is worth nothing
			var warrior := _soldier("warrior", Team.Id.ENEMY, anchor + Vector2(300, 120))
			warrior.take_hit(Vector2.INF, 10000.0)
			stage = 2
			frame = 0
		2:
			if frame < 60 * 4:
				return false
			check(_trophies().size() == 4, "a club leaves no trophy", _trophies().size())
			check(not hand.carried_item is Trophy and hand.fetching == null, "with no forge nobody picks them up")
			smithy = raise_forge(Team.Id.PLAYER)
			stage = 3
			frame = 0
		3:
			if smithy.trophies_taken < 4:
				return false
			check(true, "a labourer carried all four to the forge in", "%.1f s" % (frame / 60.0))
			check(int(me.gear["sword"]) == 1 and int(me.gear["helm"]) == 1 and int(me.gear["armour"]) == 1
				and int(me.gear["shield"]) == 1, "and they are in the store", me.gear)
			check(hand.job == "ore", "then it went back to its ore")
			# one lying under an enemy's nose stays where it is
			guarded = Trophy.new()
			guarded.item = "spear"
			guarded.position = anchor + Vector2(200, 100)
			current_scene.add_child(guarded)
			guard = _soldier("warrior", Team.Id.ENEMY, anchor + Vector2(260, 100))
			stage = 4
			frame = 0
		4:
			if guard.is_alive():
				guard.global_position = anchor + Vector2(260, 100)
				guard.velocity = Vector2.ZERO
			if frame < 60 * 6:
				return false
			check(is_instance_valid(guarded) and guarded.is_free() and smithy.trophies_taken == 4,
				"a trophy by an enemy is left alone")
			guard.queue_free()
			guarded.age = Trophy.LIFE - 0.5
			stage = 5
			frame = 0
		5:
			if frame < 60:
				return false
			check(not is_instance_valid(guarded), "and left lying, it rusts away")
			stage = 6
		6:
			# the knight fell in the first seconds; a body lies CORPSE_LIFE and fades
			if is_instance_valid(knight) and knight.death_time > PlayerBody.CORPSE_LIFE - 2.0 and knight.death_time < PlayerBody.CORPSE_LIFE - 1.0:
				check(knight.modulate.a < 0.5, "a body fades before it goes", knight.modulate.a)
			if is_instance_valid(knight) and not knight.is_queued_for_deletion():
				return false
			check(true, "and the fallen knight is gone after", "%.0f s" % seconds())
			return true
	return false
