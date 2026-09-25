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
const LEASH := 200.0           ## once posted somewhere, how far from it it will chase anyone
const WALL_BIAS := 90.0
const HAND_BIAS := 120.0       ## marching on a goal, a labourer counts this much further off still        ## a wall counts as this much further off than a man

@export var patrol := 120.0
@export var guards := true     ## false: stands its post instead of pacing it
## What it is kitted out as: "knight" (plate, sword and shield, trained) or
## "warrior" (a club and no armour -- the first thing anyone can hire).
@export var loadout := "knight"

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
	post = point
	rallying = true
	leash = LEASH
	if watch == Watch.PATROL:
		_set_watch(Watch.RETURNING)

## Walk at a point, fighting whatever turns up on the way, and hold it on arrival.
func set_attack_move(goal: Vector2) -> void:
	order = Order.ATTACK_MOVE
	attack_goal = goal

func _ready() -> void:
	super()
	post = global_position
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

func set_scales(harm: float, toughness: float) -> void:
	harm_scale = harm
	if not is_equal_approx(toughness, health_scale):
		var share := health / health_max if health_max > 0.0 else 1.0
		health_max = health_max / health_scale * toughness
		health_scale = toughness
		if not is_dead:
			health = health_max * share

func strike_harm() -> float:
	return super() * harm_scale

func _kit_out() -> void:
	if loadout == "warrior":
		# a man handed a club: no plate, no helm, no training to speak of
		weapon = Weapon.CLUB
		helm = Helm.NONE
		skills[Weapon.CLUB] = 1
		health_max = HEALTH_MAX
		health = health_max
		if rig != null:
			rig.armoured = false
		return
	weapon = Weapon.SWORD_SHIELD
	helm = Helm.WORN
	# a man who does this for a living: the same stroke costs him a third less
	skills[Weapon.SWORD_SHIELD] = 3
	# plate is worth something even before he learns to use the shield
	health_max = HEALTH_MAX * 1.5
	health = health_max
	if rig != null:
		rig.armoured = true

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

func _refresh_ring() -> void:
	if ring_drawn_alive != (not is_dead):
		ring_drawn_alive = not is_dead
		queue_redraw()

func _physics_process(delta: float) -> void:
	_refresh_ring()
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
				if _walk_towards(post, ADVANCE_SPEED):
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
	var reach := LOSE_SIGHT if quarry != null else SIGHT
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
		elif candidate is Worker and order == Order.ATTACK_MOVE:
			distance += HAND_BIAS
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _still_minding(mark: Node2D) -> bool:
	return is_instance_valid(mark) and mark.is_alive() 		and Team.hostile(team, Team.of(mark)) and _within_leash(mark) 		and global_position.distance_to(Team.spot(mark, global_position)) < LOSE_SIGHT

func _within_leash(mark: Node2D) -> bool:
	return order != Order.HOLD or leash <= 0.0 		or post.distance_to(Team.spot(mark, post)) <= leash

func _pace() -> void:
	if not guards:
		return
	var out := global_position.x - post.x
	if absf(out) > patrol and signf(out) == march:
		march = -march
	wish = Vector2(march * PATROL_SPEED, 0.0)

## Marching on the goal; once there, the goal simply becomes the post.
func _advance() -> void:
	# a goal on top of something solid -- a keep, its ruin -- is reached as near
	# as the floor goes
	var blocked := path.has_floor_plan() and path.is_navigation_finished() 		and global_position.distance_to(attack_goal) < GOAL_SLACK
	if _walk_towards(attack_goal, ADVANCE_SPEED) or blocked:
		set_rally(global_position if blocked else attack_goal)

func _face(mark: Node2D) -> void:
	if mark == null:
		return
	var dx := Team.spot(mark, global_position).x - global_position.x
	if absf(dx) > 1.0:
		facing_x = signf(dx)

func _fight() -> void:
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
