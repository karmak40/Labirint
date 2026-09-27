class_name Unit
extends PlayerBody
## An armoured knight: the same body as the player, told what to do by something
## other than a keyboard.
##
## This is the point the whole rig was built towards. The figure already knows
## how to walk, run, swing seven weapons, flinch, bleed out three different ways
## and get back up; none of that knows or cares where the intent comes from. So
## a unit is not a second figure -- it is the same body with `_get_input_vector`
## answered by a head instead of by hands on a keyboard.
##
## What is genuinely new here is only the deciding: where to stand, when to
## close, when to swing.

const SIGHT := 240.0           ## how far off it notices someone
const LOSE_SIGHT := 330.0      ## and how far they have to get to be left alone
const ENGAGE := 54.0           ## it stops closing at about a sword's length
const TOO_CLOSE := 34.0        ## and gives ground if crowded inside that
const SWING_AT := 66.0         ## reach it will commit a swing from
const PATROL_SPEED := 0.42     ## share of full speed while nothing is happening
const ADVANCE_SPEED := 0.85

const NOTICE_TIME := 0.45      ## a beat between seeing you and moving: armour is slow
const RECOVER := 0.30          ## and a pause between swings, so it can be fought
const GUARD_TIME := 2.6        ## how long it stands its ground before pacing again

const ARRIVE := 8.0            ## close enough to a point to call it reached
const SCAN_EVERY := 0.25       ## a full look round is dear with a crowd about: not every frame
const GOAL_SLACK := 80.0       ## how near an unreachable goal counts as there
const HOME_SLACK := 18.0       ## pushed further than this off its place, it steps back
const RALLY_GIVE_UP := 12.0    ## seconds on the way to a place it cannot get to
const HOME_GIVE_UP := 6.0      ## and trying to step back to it through a crowd
const LEASH := 200.0           ## once posted somewhere, how far from it it will chase anyone
const WALL_BIAS := 90.0
const HAND_BIAS := 120.0       ## marching on a goal, a labourer counts this much further off still        ## a wall counts as this much further off than a man

@export var patrol := 120.0
@export var guards := true     ## false: stands its post instead of pacing it
## What it is kitted out as, one of LOADOUTS.
@export var loadout := "knight"

## Every kind of soldier is the same body with different kit. `health` is a share
## of the body's own; `reach` > 0 makes it a shooter that keeps that far off.
const LOADOUTS := {
	"knight": {"weapon": Weapon.SWORD_SHIELD, "helm": true, "armour": true, "health": 1.5, "skill": 3},
	"warrior": {"weapon": Weapon.CLUB, "helm": false, "armour": false, "health": 1.0, "skill": 1},
	"spearman": {"weapon": Weapon.SPEAR, "helm": true, "armour": false, "health": 1.15, "skill": 2},
	"archer": {"weapon": Weapon.BOW, "helm": false, "armour": false, "health": 0.9, "skill": 2, "reach": 220.0},
	"crossbowman": {"weapon": Weapon.CROSSBOW, "helm": true, "armour": false, "health": 1.0, "skill": 1, "reach": 250.0},
	"axeman": {"weapon": Weapon.AXE, "helm": false, "armour": false, "health": 1.1, "skill": 2, "siege": 1.5},
	"swordsman": {"weapon": Weapon.SWORD, "helm": true, "armour": false, "health": 1.2, "skill": 2},
	"greatsword": {"weapon": Weapon.GREATSWORD, "helm": true, "armour": true, "health": 1.4, "skill": 2},
	"scout": {"weapon": Weapon.DAGGER, "helm": false, "armour": false, "health": 0.8, "skill": 3, "speed": 1.3, "hunts": true},
	"torchbearer": {"weapon": Weapon.TORCH, "helm": false, "armour": false, "health": 0.9, "skill": 1, "siege": 4.0},
	"mage": {"weapon": Weapon.STAFF, "helm": false, "armour": false, "health": 0.8, "skill": 1, "reach": 260.0, "mends": true},
}
## Optional keys: `siege` multiplies its blows against buildings, `speed` its
## pace, `hunts` makes it go for the other side's labourers first, and `mends`
## lets it heal once its side has learned how («Исцеление»).

## Healing. Who gets it depends on how things stand: out of a fight anyone
## scratched is seen to; in one only someone near death is worth breaking off
## for; and with an enemy at its own elbow it does neither.
const MEND_REACH := 200.0
const MEND_AMOUNT := 30.0
const MEND_EVERY := 1.6        ## seconds between casts
const MEND_LOOK := 0.4         ## how often it looks round when nobody needed it
const MEND_WOUNDED := 0.85     ## the share of health under which, at peace, it heals
const MEND_URGENT := 0.45      ## and under which it breaks off a fight to
const SHOOTER_CLOSE := 90.0    ## nearer than this a shooter steps back before loosing
const SHOOTER_RECOVER := 0.4   ## and a breath between shots
const AIM_LEAD := 0.35         ## seconds of the mark's running it aims ahead by

enum Watch { PATROL, NOTICED, FIGHTING, RETURNING }

## What it has been told to do, as against what it is doing this moment. The
## watch above already is a rally point -- it paces round `post` and walks back
## there after a fight -- so holding is nothing more than moving the post.
enum Order { HOLD, ATTACK_MOVE }

var post := Vector2.ZERO
var march := 1.0
var watch := Watch.PATROL
var watch_time := 0.0
var wish := Vector2.ZERO
var quarry: Node2D = null
var scan_left := 0.0
var order := Order.HOLD
var attack_goal := Vector2.ZERO
var home_try := 0.0     ## how long it has been stepping back to its place
var rallying := false   ## sent to a new post and not there yet: no giving up halfway
## How far from its post it will go after someone; 0 is no limit. A man told to
## hold a place holds it, rather than following the first passer-by off into
## the enemy's towers. Only an order sets it, so the testbed's knight is as free
## as it always was.
var leash := 0.0

## Finds the way round things, when there is a floor to find it on. On a floor
## with no navigation baked (the testbed) it is simply never consulted.
var path: Pathfinder

## Stand and guard here. Everything that already guards a post now guards this.
func set_rally(point: Vector2) -> void:
	order = Order.HOLD
	# never a post inside a wall or on the ground in front of a door or an anvil:
	# a man sent there shoved at it for ever, in everybody's way
	post = Building.clear_of(get_tree(), point) if is_inside_tree() and Pen.crowd_mode else point
	rallying = true
	leash = LEASH
	if watch == Watch.PATROL:
		_set_watch(Watch.RETURNING)

## Walk at a point, fighting whatever turns up on the way, and hold it on arrival.
func set_attack_move(goal: Vector2) -> void:
	order = Order.ATTACK_MOVE
	attack_goal = goal

## In a match soldiers are on a physics layer of their own: they bump into the
## world and into each other, but labourers (who only mind the world) walk
## through them -- an idle army standing on the way to the stockpile used to be
## a wall the carriers could not get past.
const UNIT_LAYER := 4

func _ready() -> void:
	super()
	decays = Pen.crowd_mode
	if Pen.crowd_mode:
		collision_layer = UNIT_LAYER
		collision_mask = 1 | UNIT_LAYER
	post = global_position
	# in a match a soldier stands his place in the ranks; the testbed's knight
	# still paces his
	if Pen.crowd_mode:
		guards = false
	_kit_out()
	path = Pathfinder.new(speed)
	add_child(path)
	# the body jumps on the space bar for whoever is at the keyboard; this one
	# is told what to do by its head, never by keys
	set_process_unhandled_key_input(false)
	# spread out, so a squad hired together does not all look round in one frame
	scan_left = randf() * SCAN_EVERY

## What the side's learning has done for it (PlayerState.kit_out): harder
## blows, a tougher hide. Health keeps its share, so a wounded man stays wounded.
var harm_scale := 1.0
var health_scale := 1.0
var can_mend := false          ## a healer whose side has learned to heal
var mending: PlayerBody = null ## who the cast under way is for
var mend_left := 0.0

# --- experience ---------------------------------------------------------------

## Kills that earn each star, and what a star gives: a level of skill in the
## weapon in hand (the same stroke for less wind), a harder blow and a tougher
## hide. Only in a match: the testbed's knight stays exactly as he was.
const STARS_AT := [2, 5, 10]
const STAR_HARM := 0.08
const STAR_HEALTH := 0.10
const STAR_GOLD := Color(1.0, 0.84, 0.30)
const STAR_EDGE := Color(0.45, 0.30, 0.08)
const STAR_HEIGHT := 116.0     ## over its feet: clear of the head and the health bar

var kills := 0                 ## men brought down
var razed := 0                 ## buildings brought down
var stars := 0
var earns_stars := Pen.crowd_mode

# --- trophies ------------------------------------------------------------------

## What it fell with, kept from the moment it went down; the rig lets the
## weapon go a frame later, and the kit comes off the body as it lies.
var _fell_with := Weapon.NONE
var _fell_kit: Array[String] = []
var _shed := false

func _start_death(kind: DeathKind) -> bool:
	if not is_dead and earns_stars:
		_fell_with = weapon
		_fell_kit.clear()
		if helm == Helm.WORN:
			_fell_kit.append("helm")
		if wears_armour():
			_fell_kit.append("armour")
		if has_shield():
			_fell_kit.append("shield")
	return super(kind)

## Once the rig has let the weapon go, it becomes a trophy flying the same
## way, and the kit falls off beside the body.
func _shed_trophies() -> void:
	if _shed or not is_dead or not earns_stars or rig == null or not rig.was_dead:
		return
	_shed = true
	var weapon_item := Trophy.item_for(_fell_with)
	if weapon_item != "":
		var dropped: Array = rig.dropped
		for i in range(dropped.size() - 1, -1, -1):
			var lying = dropped[i]
			if lying.kind == _fell_with:
				dropped.remove_at(i)
				var trophy := _trophy(weapon_item)
				trophy.launch(lying.pos, lying.z, lying.vel, lying.z_vel, lying.spin)
				trophy.tilt = lying.angle
				break
	for piece in _fell_kit:
		var trophy := _trophy(piece)
		var toss := Vector2(randf_range(-60.0, 60.0), randf_range(-20.0, 20.0))
		trophy.launch(global_position + Vector2(0.0, -4.0), 30.0, toss, 90.0, randf_range(-6.0, 6.0))
	# and the body lies there without it
	helm = Helm.NONE
	shielded = false
	if rig != null:
		rig.armoured = false

func _trophy(piece: String) -> Trophy:
	var trophy := Trophy.new()
	trophy.item = piece
	get_parent().add_child(trophy)
	return trophy

func felled(mark: Node) -> void:
	if not earns_stars:
		return
	if mark is Building:
		razed += 1
		return
	kills += 1
	while stars < STARS_AT.size() and kills >= int(STARS_AT[stars]):
		_promote()

## One more star, and what comes with it. A wound keeps its size, the new
## health on top of what is left.
func _promote() -> void:
	stars += 1
	train(weapon)
	var gain := health_max * STAR_HEALTH
	health_max += gain
	if not is_dead:
		health += gain
	queue_redraw()

## Kills still wanted for the next star, or 0 with all of them.
func kills_to_next_star() -> int:
	if stars >= STARS_AT.size():
		return 0
	return int(STARS_AT[stars]) - kills

func set_scales(harm: float, toughness: float) -> void:
	harm_scale = harm
	if not is_equal_approx(toughness, health_scale):
		var share := health / health_max if health_max > 0.0 else 1.0
		health_max = health_max / health_scale * toughness
		health_scale = toughness
		if not is_dead:
			health = health_max * share

func strike_harm() -> float:
	return super() * harm_scale * (1.0 + STAR_HARM * float(stars)) * Weather.shot_scale(weapon)

## A torch or an axe does more to a wall than to a man.
func harm_against(mark: Node) -> float:
	var harm := strike_harm()
	if mark is Building:
		harm *= float(LOADOUTS.get(loadout, {}).get("siege", 1.0))
		if weapon == Weapon.TORCH:
			harm *= Weather.fire_scale()
	return harm

## In a match the torch is for the enemy's walls: it does not set the forest,
## everyone's timber, alight.
func torch_strike() -> void:
	pass

## Whether this kind can heal and its side knows how (PlayerState.kit_out).
func set_mending(known: bool) -> void:
	can_mend = known and bool(LOADOUTS.get(loadout, {}).get("mends", false))

## Takes over this moment if someone needs healing more than the fight needs it.
func _mend(delta: float) -> bool:
	mend_left -= delta
	if not can_mend:
		return false
	if mending != null and not is_instance_valid(mending):
		mending = null
	if mending != null:
		if is_attacking():
			_face(mending)
			return true
		mending = null
	if is_attacking() or mend_left > 0.0 or not can_strike():
		return false
	if quarry != null and global_position.distance_to(Team.spot(quarry, global_position)) < SHOOTER_CLOSE:
		return false
	var fighting := watch == Watch.FIGHTING and quarry != null
	var patient := _most_hurt(MEND_URGENT if fighting else MEND_WOUNDED)
	if patient == null:
		mend_left = MEND_LOOK
		return false
	mending = patient
	aim_point = patient.global_position
	_face(patient)
	attack()
	mend_left = MEND_EVERY
	watch_time = 0.0
	return true

## The worst hurt of its own side within reach, itself included, if any is
## below `share` of its health.
func _most_hurt(share: float) -> PlayerBody:
	var best: PlayerBody = null
	var best_share := share
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or body.is_dead or not Team.allied(team, Team.of(body)):
			continue
		if global_position.distance_to(body.global_position) > MEND_REACH:
			continue
		var left := body.health / body.health_max
		if left < best_share:
			best_share = left
			best = body
	return best

# --- kit that keeps blows off ---------------------------------------------------

## What each piece keeps off a blow. They add up: a knight's helm and plate
## together let through 0.72 of it, and his shield less again from the front.
const HELM_GUARD := 0.9
const ARMOUR_GUARD := 0.8
const SHIELD_GUARD := 0.7      ## only a blow or a shot from in front, onto the shield
const GEAR := ["helm", "armour", "shield"]

func take_hit(from: Vector2 = Vector2.INF, damage: float = 10.0) -> void:
	super(from, damage * guard_against(from))

## The share of a blow from `from` that gets through its kit.
func guard_against(from: Vector2) -> float:
	var share := 1.0
	if helm == Helm.WORN:
		share *= HELM_GUARD
	if wears_armour():
		share *= ARMOUR_GUARD
	if has_shield() and from.x < INF and absf(from.x - global_position.x) > 1.0 			and signf(from.x - global_position.x) == signf(facing_x):
		share *= SHIELD_GUARD
	return share

func wears_armour() -> bool:
	return rig != null and rig.armoured

func has_shield() -> bool:
	return weapon == Weapon.SWORD_SHIELD or (shielded and SHIELD_WEAPONS.has(weapon))

## Whether a piece from the forge would be any use to it.
func can_wear(item: String) -> bool:
	if is_dead:
		return false
	match item:
		"helm":
			return helm != Helm.WORN
		"armour":
			return not wears_armour()
		"shield":
			return not has_shield() and SHIELD_WEAPONS.has(weapon)
	return false

func wear(item: String) -> void:
	match item:
		"helm":
			helm = Helm.WORN
		"armour":
			if rig != null:
				rig.armoured = true
		"shield":
			shielded = true

## Called by the rig as the staff casts: a heal goes out instead of a bolt.
func release_mend() -> bool:
	if mending == null:
		return false
	var patient := mending
	mending = null
	if is_instance_valid(patient) and not patient.is_dead 			and global_position.distance_to(patient.global_position) < MEND_REACH * 1.3:
		patient.health = minf(patient.health_max, patient.health + MEND_AMOUNT)
		var glow := MendGlow.new()
		glow.patient = patient
		glow.source = global_position + Vector2(0.0, -58.0)
		get_parent().add_child(glow)
	return true

func _hunts() -> bool:
	return bool(LOADOUTS.get(loadout, {}).get("hunts", false))

func _kit_out() -> void:
	var kit: Dictionary = LOADOUTS.get(loadout, LOADOUTS["knight"])
	weapon = kit["weapon"]
	helm = Helm.WORN if kit["helm"] else Helm.NONE
	# training: each level makes the same stroke cheaper in breath
	skills[weapon] = int(kit["skill"])
	health_max = HEALTH_MAX * float(kit["health"])
	health = health_max
	speed *= float(kit.get("speed", 1.0))
	if rig != null:
		rig.armoured = bool(kit["armour"])

## How far off it fights from: a sword's length, or a bowshot.
func reach() -> float:
	return float(LOADOUTS.get(loadout, {}).get("reach", 0.0))

func is_shooter() -> bool:
	return reach() > 0.0

## The knight's whole contribution: everything else on this body already exists.
func _get_input_vector() -> Vector2:
	return wish

## The side's colour under its feet while it lives; a corpse is nobody's.
var ring_drawn_alive := true
## Only in a match: the testbed's knight is drawn exactly as it always was.
var show_ring := Pen.crowd_mode

func _draw() -> void:
	if show_ring and not is_dead:
		Team.draw_foot_ring(self, team)
	if stars > 0 and not is_dead:
		for i in stars:
			_draw_star(Vector2((float(i) - float(stars - 1) * 0.5) * 11.0, -STAR_HEIGHT))

func _draw_star(at: Vector2) -> void:
	var points := PackedVector2Array()
	for k in 10:
		var r := 5.0 if k % 2 == 0 else 2.2
		points.append(at + Vector2.from_angle(-PI * 0.5 + k * PI / 5.0) * r)
	draw_colored_polygon(points, STAR_GOLD)
	points.append(points[0])
	draw_polyline(points, STAR_EDGE, 1.0, true)

func _refresh_ring() -> void:
	# the stars go with the ring when it falls
	if ring_drawn_alive != (not is_dead):
		ring_drawn_alive = not is_dead
		queue_redraw()

func _physics_process(delta: float) -> void:
	_refresh_ring()
	_shed_trophies()
	_decide(delta)
	if path.has_floor_plan():
		wish = path.settle(wish, watch == Watch.PATROL and not is_attacking())
	super(delta)

func _decide(delta: float) -> void:
	watch_time += delta
	wish = Vector2.ZERO
	facing_locked = false   # only a backward step in a fight holds the facing
	if is_dead or is_flinching():
		return

	# Between looks the one it is minding stays minded, as long as it is still
	# worth minding; a dead or vanished quarry sends it looking again at once.
	scan_left -= delta
	if scan_left <= 0.0 or (quarry != null and not _still_minding(quarry)):
		scan_left = SCAN_EVERY
		quarry = _who_to_watch()

	if _mend(delta):
		return

	match watch:
		Watch.PATROL:
			if order == Order.ATTACK_MOVE:
				_advance()
			else:
				_pace()
			if quarry != null:
				_set_watch(Watch.NOTICED)
		Watch.NOTICED:
			# it squares up before it moves: a man in plate does not startle
			_face(quarry)
			if quarry == null:
				_set_watch(Watch.RETURNING)
			elif watch_time > NOTICE_TIME:
				_set_watch(Watch.FIGHTING)
		Watch.FIGHTING:
			if quarry == null:
				_set_watch(Watch.RETURNING)
			else:
				_fight()
		Watch.RETURNING:
			if quarry != null:
				_set_watch(Watch.FIGHTING)
			elif order == Order.ATTACK_MOVE:
				_set_watch(Watch.PATROL)
			elif rallying:
				# an order, not a drift back: walks with purpose and sees it through
				if _walk_towards(post, ADVANCE_SPEED) or _as_near_as_it_gets(post):
					rallying = false
					_set_watch(Watch.PATROL)
				elif watch_time > RALLY_GIVE_UP:
					# somewhere it cannot get to: a free place where it is will do
					post = _free_place_near(global_position)
					rallying = false
					_set_watch(Watch.PATROL)
			elif _walk_towards(post, PATROL_SPEED) or watch_time > GUARD_TIME:
				_set_watch(Watch.PATROL)

func _set_watch(next: Watch) -> void:
	watch = next
	watch_time = 0.0

## Whoever it is currently minding. Deliberately sticky: once it has taken an
## interest it keeps it until you are well clear, so backing off a step does not
## make an armed man forget about you.
func _who_to_watch() -> Node2D:
	var reach := _lose_sight() if quarry != null else _sight()
	var best: Node2D = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("targets"):
		var candidate := node as Node2D
		if candidate == null or candidate == self:
			continue
		# it minds the other side, not its own and not straw: a training dummy
		# never declared a side, so it is furniture
		if not Team.hostile(team, Team.of(candidate)):
			continue
		if not candidate.has_method("is_alive") or not candidate.is_alive():
			continue
		if not _within_leash(candidate):
			continue
		var distance := global_position.distance_to(Team.spot(candidate, global_position))
		# people first: a keep will still be there once the men defending it are not
		if candidate is Building:
			distance += WALL_BIAS
		# sent somewhere to fight, it does not wander off after every woodcutter
		# on the way -- only the ones it all but walks into
		elif candidate is Worker and _hunts():
			distance -= HAND_BIAS
		elif candidate is Worker and order == Order.ATTACK_MOVE:
			distance += HAND_BIAS
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _still_minding(mark: Node2D) -> bool:
	return is_instance_valid(mark) and mark.is_alive() 		and Team.hostile(team, Team.of(mark)) and _within_leash(mark) 		and global_position.distance_to(Team.spot(mark, global_position)) < _lose_sight()

## How far off it notices someone now: less by night and in the rain (Weather).
func _sight() -> float:
	return SIGHT * Weather.sight()

## And how far they have to get to be left alone -- never inside a shooter's
## own bowshot, or it would lose sight of whoever it had just stepped back from.
func _lose_sight() -> float:
	return maxf(LOSE_SIGHT * Weather.sight(), reach() + 40.0)

func _within_leash(mark: Node2D) -> bool:
	return order != Order.HOLD or leash <= 0.0 		or post.distance_to(Team.spot(mark, post)) <= leash

func _pace() -> void:
	if not guards:
		# stands; shoved off its place by the crowd, it steps back quietly
		if path.has_floor_plan() and global_position.distance_to(post) > HOME_SLACK 				and not _as_near_as_it_gets(post):
			_walk_towards(post, PATROL_SPEED)
			home_try += get_physics_process_delta_time()
			if home_try > HOME_GIVE_UP:
				home_try = 0.0
				# walled in by the ranks: the nearest free place to where it
				# stands will do
				post = _free_place_near(global_position)
		else:
			home_try = 0.0
		return
	var out := global_position.x - post.x
	if absf(out) > patrol and signf(out) == march:
		march = -march
	wish = Vector2(march * PATROL_SPEED, 0.0)

## `point`, or the nearest spot round it that nobody of ours holds.
func _free_place_near(point: Vector2) -> Vector2:
	for ring in [0.0, 22.0, 44.0]:
		for k in (1 if ring == 0.0 else 8):
			var spot: Vector2 = point + Vector2.from_angle(TAU * k / 8.0) * ring
			if _nobody_holds(spot):
				return spot
	return point

## Whether no one of ours holds a place near `point`.
func _nobody_holds(point: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("targets"):
		var other := node as Unit
		if other != null and other != self and other.team == team and not other.is_dead 				and (other.post if other.order == Order.HOLD else other.attack_goal).distance_to(point) < HOME_SLACK * 1.5:
			return false
	return true

## Whether `point` itself cannot be reached (something solid stands on it)
## and it is already at the end of the way there.
func _as_near_as_it_gets(point: Vector2) -> bool:
	if not path.has_floor_plan() or path.goal.distance_to(point) > Pathfinder.REPATH:
		return false
	var end := path.get_final_position()
	return end.distance_to(point) > ARRIVE and global_position.distance_to(end) < ARRIVE * 2.0

## Marching on the goal; once there, the goal simply becomes the post.
func _advance() -> void:
	# a goal on top of something solid -- a keep, its ruin -- is reached as near
	# as the floor goes
	var blocked := path.has_floor_plan() and path.is_navigation_finished() 		and global_position.distance_to(attack_goal) < GOAL_SLACK
	if _walk_towards(attack_goal, ADVANCE_SPEED) or blocked:
		# in a match the goal is a place in the ranks, kept even when the way
		# there is jammed for a moment
		set_rally(attack_goal if Pen.crowd_mode or not blocked else global_position)

func _face(mark: Node2D) -> void:
	if mark == null:
		return
	var dx := Team.spot(mark, global_position).x - global_position.x
	if absf(dx) > 1.0:
		facing_x = signf(dx)

func _fight() -> void:
	if is_shooter():
		_shoot()
		return
	_face(quarry)
	# a wall is fought where it is nearest, a man where he stands
	var aim := Team.spot(quarry, global_position)
	var gap := global_position.distance_to(aim)

	# Crowded, so it backs off rather than swinging through someone stood on its
	# toes. A sword has a near edge to its reach as well as a far one.
	# Stepping back keeps the face to the enemy: it backpedals rather than
	# turning round to walk away, which would offer its back mid-fight.
	if gap < TOO_CLOSE and quarry is PlayerBody:
		facing_locked = true
		wish = Vector2(-facing_x * PATROL_SPEED, 0.0)
		return

	if gap > ENGAGE:
		_walk_towards(aim, ADVANCE_SPEED)
		return

	# Spent, so he stands his ground, guard up and facing them, until he has the
	# breath for the next blow: a tired man swings less often, he does not turn
	# his back. This falls out of the same rule the player lives under.
	if not can_strike() and not is_attacking():
		return

	# in reach and standing still: swing, then leave a gap to be punished in
	if gap <= SWING_AT and not is_attacking() and watch_time > RECOVER:
		attack()
		watch_time = 0.0

## A bow, a crossbow or a staff: stand off at a bowshot, back away (facing them) from
## anyone who closes, and loose at where the mark will be. A crossbow's attack
## spans it when it is empty, so the same call does both.
func _shoot() -> void:
	_face(quarry)
	var aim := Team.spot(quarry, global_position)
	var gap := global_position.distance_to(aim)
	if gap < SHOOTER_CLOSE and quarry is PlayerBody and not is_attacking():
		facing_locked = true
		wish = (global_position - aim).normalized() * PATROL_SPEED
		return
	if gap > reach():
		_walk_towards(aim, ADVANCE_SPEED)
		return
	if not can_strike() and not is_attacking():
		return
	if not is_attacking() and watch_time > SHOOTER_RECOVER:
		# where it will be by the time the shot gets there, roughly
		var running := (quarry as CharacterBody2D).velocity if quarry is CharacterBody2D else Vector2.ZERO
		aim_point = aim + running * AIM_LEAD * clampf(gap / reach(), 0.3, 1.0)
		attack()
		watch_time = 0.0

## Walks at a point and says whether it has arrived.
func _walk_towards(there: Vector2, effort: float) -> bool:
	if not path.has_floor_plan():
		# no map to read: straight along the floor, as it always has
		var dx := there.x - global_position.x
		if absf(dx) < ARRIVE:
			return true
		wish = Vector2(signf(dx) * effort, 0.0)
		return false

	if global_position.distance_to(there) < ARRIVE:
		return true
	wish = path.heading_to(there) * effort
	return false
