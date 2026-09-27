extends "res://tests/lib/test_case.gd"
## Fog of war. At the start we see round our own castle and nothing of the
## enemy's side: their castle and men are hidden. A scout sees furthest; the
## dark closes in on men on foot but not on buildings. A scout sent to their
## castle uncovers it; once he leaves, the castle stays on the map but their
## men vanish from it, and cannot be picked. A match being watched, and the
## testbed, have no fog.

var stage := 0
var fog: FogOfWar
var scout: Unit
var foe: Unit

func begin() -> void:
	time_limit = 60 * 60
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(loadout: String, team: int, at: Vector2) -> Unit:
	var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
	unit.loadout = loadout
	unit.team = team
	unit.guards = false
	unit.position = at
	current_scene.add_child(unit)
	return unit

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing() or frame < 5:
				return false
			silence(Team.Id.ENEMY)
			fog = gs.field().get_node_or_null("FogOfWar")
			check(fog != null and FogOfWar.current == fog, "a match has fog of war")
			var ours: Base = gs.human().base()
			var theirs: Base = gs.side(Team.Id.ENEMY).base()
			check(FogOfWar.sees(ours.global_position), "we see our own castle")
			check(not FogOfWar.knows(theirs.global_position) and not theirs.visible, "and nothing of theirs")
			check(FogOfWar.vision_of(_soldier("scout", Team.Id.PLAYER, ours.global_position + Vector2(300, 0)))
				> FogOfWar.UNIT_VISION * 1.5, "a scout sees furthest")
			foe = _soldier("warrior", Team.Id.ENEMY, theirs.global_position + Vector2(-260, 60))
			stage = 1
			frame = 0
		1:
			if frame < 20:
				return false
			check(not foe.visible, "their men out of sight are hidden")
			var hud: Node = current_scene.get_node("Hud")
			check(hud.input.body_at(foe.global_position + Vector2(0, -40)) == null, "and can not be picked")
			# a scout walks up to their gate
			var theirs: Base = gs.side(Team.Id.ENEMY).base()
			scout = _soldier("scout", Team.Id.PLAYER, theirs.global_position + Vector2(-420, 60))
			stage = 2
			frame = 0
		2:
			if frame < 20:
				return false
			var theirs: Base = gs.side(Team.Id.ENEMY).base()
			check(FogOfWar.knows(theirs.global_position) and theirs.visible, "the scout uncovers their castle")
			check(foe.visible, "and their man by it")
			# and goes home
			scout.global_position = gs.human().base().global_position + Vector2(300, 0)
			stage = 3
			frame = 0
		3:
			if frame < 30:
				return false
			var theirs: Base = gs.side(Team.Id.ENEMY).base()
			check(theirs.visible and not FogOfWar.sees(theirs.global_position), "their castle stays on the map, out of sight")
			check(not foe.visible, "their man is gone from it")
			# the dark closes in on men, not on walls
			var day := FogOfWar.vision_of(scout)
			var keep := FogOfWar.vision_of(gs.human().base())
			gs.field().get_node("Weather").clock = 210.0
			gs.field().get_node("Weather")._physics_process(0.0)
			check(FogOfWar.vision_of(scout) < day * 0.7, "at night a man sees less far", FogOfWar.vision_of(scout))
			check(is_equal_approx(FogOfWar.vision_of(gs.human().base()), keep), "a castle no less")
			# a match only watched has none
			gs.spectating = true
			gs.restart_match()
			stage = 4
			frame = 0
		4:
			if not playing() or frame < 10:
				return false
			check(gs.field().get_node_or_null("FogOfWar") == null and FogOfWar.current == null, "a watched match has no fog")
			gs.spectating = false
			change_scene_to_file("res://scenes/main/Main.tscn")
			stage = 5
			frame = 0
		5:
			if frame < 30:
				return false
			check(FogOfWar.current == null and FogOfWar.sees(Vector2(9999, 9999)), "the testbed has none")
			return true
	return false
