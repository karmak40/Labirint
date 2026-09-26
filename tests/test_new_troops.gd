extends "res://tests/lib/test_case.gd"
## The troops for the rest of the rig's weapons: each is locked until its study,
## comes out with its own weapon, and does its own thing -- a torch and an axe
## hit walls harder, a scout is quick and goes for labourers first, and a mage
## casts across the field at a mark off its own row from well out of reach.
## Once «Исцеление» is learned a mage heals: anyone hurt when there is no fight,
## and in a fight only someone near death.

const KINDS := {
	"axeman": ["axes", PlayerBody.Weapon.AXE],
	"swordsman": ["blades", PlayerBody.Weapon.SWORD],
	"greatsword": ["greatswords", PlayerBody.Weapon.GREATSWORD],
	"scout": ["daggers", PlayerBody.Weapon.DAGGER],
	"torchbearer": ["fire", PlayerBody.Weapon.TORCH],
	"mage": ["magic", PlayerBody.Weapon.STAFF],
}

var stage := 0
var mage: Unit
var mark: Unit
var mark_at := Vector2(1380, 330)
var closest := INF
var healer: Unit
var hurt: Unit
var dying: Unit
var foe_far: Unit

func begin() -> void:
	time_limit = 60 * 40
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
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			raise_barracks(Team.Id.PLAYER)
			var me: PlayerState = gs.human()
			me.economy.add("wood", 500)
			me.economy.add("ore", 500)
			me.economy.add("gold", 200)
			for kind in KINDS:
				var study: String = KINDS[kind][0]
				check(PlayerState.RESEARCH.has(study), "%s has a study, %s" % [kind, study])
				check(not gs.hire(1, kind), "no %s before %s" % [kind, study])
			check(not me.prerequisite_met("greatswords"), "greatswords can not be learned before blades")
			for kind in KINDS:
				me.researched[KINDS[kind][0]] = true
			check(me.prerequisite_met("greatswords"), "and can once blades are known")
			raise_forge(Team.Id.PLAYER)
			check(gs.hire(1, "scout"), "a scout can be ordered once daggers are known")
			# a mage on open ground, a mark held still off its row
			mage = _soldier("mage", Team.Id.PLAYER, Vector2(1200, 220))
			mark = _soldier("warrior", Team.Id.ENEMY, mark_at)
			stage = 1
			frame = 0
		1:
			if frame == 3:
				for kind in KINDS:
					var unit := _soldier(kind, Team.Id.PLAYER, Vector2(400, 470))
					check(unit.weapon == KINDS[kind][1], "a %s carries its own weapon" % kind, unit.weapon)
					unit.queue_free()
				var base: Base = gs.side(Team.Id.ENEMY).base()
				var torch := _soldier("torchbearer", Team.Id.PLAYER, Vector2(400, 470))
				var axe := _soldier("axeman", Team.Id.PLAYER, Vector2(400, 470))
				var sword := _soldier("swordsman", Team.Id.PLAYER, Vector2(400, 470))
				check(is_equal_approx(torch.harm_against(base), torch.strike_harm() * 4.0), "a torch burns walls four times over", torch.harm_against(base))
				check(axe.harm_against(base) > axe.strike_harm() and is_equal_approx(sword.harm_against(base), sword.strike_harm()),
					"an axe hews walls harder, a sword does not")
				for u in [torch, axe, sword]:
					u.queue_free()
				# the scout: quicker than a warrior, and a labourer further off
				# comes before a soldier close by
				var scout := _soldier("scout", Team.Id.PLAYER, Vector2(1800, 470))
				var plain := _soldier("warrior", Team.Id.PLAYER, Vector2(1800, 430))
				check(scout.speed > plain.speed * 1.2, "a scout is quicker", [scout.speed, plain.speed])
				var hand: Worker = load("res://scenes/worker/Worker.tscn").instantiate()
				hand.team = Team.Id.ENEMY
				hand.position = Vector2(1990, 470)
				current_scene.add_child(hand)
				var foe := _soldier("warrior", Team.Id.ENEMY, Vector2(1900, 470))
				check(scout._who_to_watch() == hand, "a scout goes for the labourer first")
				check(plain._who_to_watch() == foe, "a warrior for the nearer soldier")
				for u in [scout, plain, hand, foe]:
					u.queue_free()
			if mark.is_alive():
				mark.global_position = mark_at
				mark.velocity = Vector2.ZERO
			closest = minf(closest, mage.global_position.distance_to(mark.global_position))
			if frame == 60 * 12:
				_start_healing()
			if frame == 60 * 12:
				check(mage.is_shooter() and mage.weapon == PlayerBody.Weapon.STAFF, "a mage carries a staff and shoots")
				check(mark.health < mark.health_max, "the mage's bolts hit a mark off its own row",
					"%d/%d, %.0f px apart in y" % [mark.health, mark.health_max, absf(mark_at.y - mage.global_position.y)])
				check(closest > 90.0, "and it never came within reach of a blade", "%.0f px at closest" % closest)
				stage = 2
				frame = 0
		2:
			if frame == 60 * 3:
				check(hurt.health < hurt.health_max * 0.8, "with no study the mage does not heal", hurt.health)
				check(not healer.can_mend, "and can not")
				check(not gs.human().prerequisite_met("healing") or gs.human().has_researched("magic"), "healing comes after magic")
				gs.human().researched["healing"] = true
				gs.human().kit_out(healer)
				check(healer.can_mend, "healing learned: the mage can heal")
			if frame == 60 * 8:
				check(hurt.health > hurt.health_max * 0.85, "at peace it heals the wounded", "%.0f/%.0f" % [hurt.health, hurt.health_max])
				# now a fight: one scratched, one near death, and an enemy about
				hurt.health = hurt.health_max * 0.7
				dying.health = dying.health_max * 0.3
				foe_far = _soldier("warrior", Team.Id.ENEMY, healer.global_position + Vector2(230, 0))
				foe_far.set_physics_process(false)
			if frame > 60 * 8 and frame < 60 * 12 and is_instance_valid(foe_far):
				foe_far.global_position = healer.global_position + Vector2(230, 0)
				foe_far.health = foe_far.health_max
			if frame == 60 * 12:
				check(dying.health > dying.health_max * 0.45, "in a fight it saves the one near death", "%.0f/%.0f" % [dying.health, dying.health_max])
				check(hurt.health <= hurt.health_max * 0.71, "and leaves a scratch for later", "%.0f/%.0f" % [hurt.health, hurt.health_max])
				check(healer.quarry == foe_far, "while it is minding the enemy", healer.quarry)
				return true
	return false

## A mage with two of its own beside it, one of them hurt, far from anyone.
func _start_healing() -> void:
	healer = _soldier("mage", Team.Id.PLAYER, Vector2(700, 200))
	hurt = _soldier("warrior", Team.Id.PLAYER, Vector2(760, 230))
	dying = _soldier("warrior", Team.Id.PLAYER, Vector2(650, 240))
	hurt.health = hurt.health_max * 0.5
	for u in [healer, hurt, dying]:
		u.set_physics_process(u == healer)
