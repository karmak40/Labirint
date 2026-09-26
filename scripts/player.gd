class_name PlayerBody
extends CharacterBody2D

enum DeathKind {
	COLLAPSE,     ## legs give way, body topples forward
	KNOCKED_BACK, ## shot: a straight impulse throws the body back off its feet
	CUT_DOWN,     ## struck by a blade: the blow spins the body before it falls
}

enum Weapon {
	NONE,         ## empty handed, arms free
	AXE,          ## chops in an arc, two hands on the strike
	SPEAR,        ## thrusts in a straight line
	BOW,          ## draws, releases, and sends an arrow of its own
	SWORD,        ## cuts through a flat arc one-handed, free arm counterbalancing
	SWORD_SHIELD, ## same cut, but the off arm is committed to the shield
	GREATSWORD,   ## both hands on it at all times, hauled round in a heavy arc
	PICKAXE,      ## not a weapon: driven down into the ground and levered back out
	DAGGER,       ## short, quick, and worth little from the front
	STAFF,        ## no blow at all: gathers, and sends the harm across the room
	TORCH,        ## a poor weapon, but the only one that sets things alight
	CROSSBOW,     ## shoots at once and then is useless until it is spanned again
	CLUB,         ## a length of hard wood: swung like the axe, and all a new recruit gets
	HAMMER,       ## the smith's: swung like the axe, but at an anvil
}

enum ActionKind {
	STRIKE,    ## a blow meant to pass through what it hits
	CHOP_TREE, ## a blow meant to bury itself in it and be worked back out
	PICK_UP,      ## stoop, take hold of something on the floor, straighten up
	THROW,        ## and send it away again
	PUT_DOWN,     ## crouch and set the weapon on the ground beside you
	BACKSTAB,     ## rise out of a crouch and finish something that has not seen you
	HELM,         ## lift the helm off, or settle it back on
	SPAN,         ## haul a crossbow's string back over the nut
}

const KNOCKBACK_SPEED := 210.0
const CUT_KNOCKBACK := 90.0   ## a cut staggers rather than launches
const DEATH_DRAG := 520.0
# a thrust is over quicker than a chop: less mass to move and no arc to travel.
# A bow is slower than either -- most of its time goes into the draw.
const AXE_ATTACK_TIME := 0.62
const SPEAR_ATTACK_TIME := 0.45
const BOW_ATTACK_TIME := 0.85
const SWORD_ATTACK_TIME := 0.42        ## lighter than an axe, so the cut is quicker
const GREATSWORD_ATTACK_TIME := 0.80   ## and the heaviest thing here is the slowest
const PICKAXE_ATTACK_TIME := 0.75      ## a mining stroke, including working it loose
const DAGGER_ATTACK_TIME := 0.30       ## the quickest thing here, and the weakest
const STAFF_ATTACK_TIME := 0.90        ## the slowest, and the only one with reach to spare
const TORCH_ATTACK_TIME := 0.55        ## swung like an axe, but a lighter thing to swing

# The crossbow is the bow's opposite in every way that matters. Where a bow is
# slow to bring to bear and instantly ready again, this looses the moment it is
# pointed and is then so much dead weight until it has been spanned. The reload
# is the whole weapon: it is a long stretch, on the ground, with both hands
# busy, and it is what you are buying when you take the harder-hitting shot.
const CROSSBOW_ATTACK_TIME := 0.34     ## point and pull; there is nothing to hold
const SPAN_TIME := 1.30                ## and this is the price of having done so
const TORCH_RANGE := 74.0              ## how close to hold it to a trunk
const CHOP_TREE_TIME := 0.85           ## unhurried: there is nothing to beat you to it
const PICK_UP_TIME := 0.70
const PUT_DOWN_TIME := 0.60
const THROW_TIME := 0.55
const PICKUP_RANGE := 75.0             ## how close you have to be to reach one
const CHOP_RANGE := 82.0               ## and how close to get an axe into a trunk
const MINE_RANGE := 76.0               ## the pick is worked closer in than the axe

# The sneak. Committed and slow for a dagger, because it is worth a whole kill:
# the cost of that is a long stretch where you cannot do anything else. It also
# has to be started from much closer than an ordinary blow -- an arm's length,
# not a weapon's length.
const BACKSTAB_TIME := 0.62
const BACKSTAB_RANGE := 48.0
const BACKSTAB_LUNGE := 120.0          ## the step taken into it as the blade goes in
const STRIKE_RANGE := 62.0             ## reach of an ordinary blow against a target

## Where the helm is. Off the head it is not gone -- it goes under the near arm,
## which is how a man actually carries one, and is where putting it back on takes
## it from.
enum Helm { NONE, CARRIED, WORN }
const HELM_TIME := 0.70
const HIT_TIME := 0.32        ## hitstun: control is taken away for this long
const HIT_KNOCKBACK := 95.0
const HIT_DRAG := 400.0

const HEAVY_SPEED := 78.0    ## a shouldered beam is not something you run with
const CROUCH_SPEED := 58.0   ## and crouched, you are slower still
const BACK_SPEED := 85.0     ## nobody backs up as fast as they go forwards

# Dodge roll: a short committed burst with a window in the middle where nothing
# can touch you. Committed is the point -- the direction is chosen when it starts
# and cannot be steered afterwards, which is what makes it a decision.
const ROLL_TIME := 0.45
const ROLL_SPEED := 330.0
const ROLL_DRAG := 420.0
const ROLL_SAFE_FROM := 0.15  ## the invulnerable stretch, as a share of the roll
const ROLL_SAFE_TO := 0.72

## Getting back up. Slow, because it is the one thing here you should not want to
## be caught doing -- a body on the ground is helpless for the whole of it.
const RISE_TIME := 1.15

# Wind. Every blow costs some, and a blow that cannot be paid for is not thrown
# at all -- a resource with no consequence is only a number on a bar. The pause
# before it starts coming back is what makes a flurry of swings a real decision:
# spend it all and there is a stretch where you can do nothing.
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 19.0    ## per second, once the breath is caught
const STAMINA_PAUSE := 0.5     ## after any effort, before any of it comes back
const STAMINA_WINDED := 1.7    ## and much longer if you spent the lot

## What one stroke takes out of you, before any skill is counted. Weight and
## commitment, not damage: a greatsword hauled round costs four times a knife,
## and drawing a bow is work even though nothing is swung.
const STRIKE_COST := {
	Weapon.NONE: 6.0,
	Weapon.DAGGER: 7.0,
	Weapon.TORCH: 9.0,
	Weapon.SPEAR: 11.0,
	Weapon.SWORD: 13.0,
	Weapon.BOW: 14.0,
	Weapon.SWORD_SHIELD: 15.0,
	Weapon.AXE: 18.0,
	Weapon.PICKAXE: 20.0,
	Weapon.STAFF: 22.0,
	Weapon.GREATSWORD: 27.0,
	Weapon.CROSSBOW: 5.0,      ## pulling a trigger is nothing
	Weapon.CLUB: 14.0,
	Weapon.HAMMER: 10.0,
}
const SPAN_COST := 24.0        ## spanning it is most of the work of using one
const CHOP_COST := 16.0        ## felling is heavier work than fighting
const BACKSTAB_COST := 12.0

## Skill in a weapon, 0 to SKILL_MAX, kept per weapon. It buys economy, not
## power: a practised man makes the same stroke for less. Multiplicative, so it
## has diminishing returns and never reaches free.
const SKILL_MAX := 5
const SKILL_STEP := 0.86

# Flesh. Unlike wind this does not come back on its own: a body that could shrug
# off wounds by standing still would turn every fight into a waiting game.
const HEALTH_MAX := 100.0

## What one blow takes off. Weight and edge, and deliberately NOT touched by
## skill -- skill buys economy, not power, and a practised man makes the same cut
## for less breath rather than a deeper one.
const STRIKE_HARM = {
	Weapon.NONE: 5.0,
	Weapon.TORCH: 7.0,
	Weapon.DAGGER: 12.0,
	Weapon.SPEAR: 18.0,
	Weapon.SWORD: 20.0,
	Weapon.SWORD_SHIELD: 20.0,
	Weapon.BOW: 22.0,
	Weapon.PICKAXE: 22.0,
	Weapon.AXE: 26.0,
	Weapon.STAFF: 28.0,
	Weapon.GREATSWORD: 34.0,
	Weapon.CROSSBOW: 30.0,     ## harder than a bow, and it needs to be
	Weapon.CLUB: 16.0,         ## a bruise rather than a cut
	Weapon.HAMMER: 14.0,
}

## Fired once as a body goes down, however it went. Nothing in the body listens;
## it is there for whoever keeps score.
signal died(body: PlayerBody)

@export var speed: float = 165.0
@export var acceleration: float = 1400.0
@export var jump_impulse: float = 270.0
@export var gravity: float = 900.0
## Which side this body fights for. Nothing about hitting reads it; only a head
## choosing who to go for does (see Team).
@export var team: int = Team.Id.NEUTRAL

# Height above the floor, simulated separately from the top-down movement plane.
# Apex works out to jump_impulse^2 / (2 * gravity) ~= 40px, about 0.6s airborne.
var air_height := 0.0
var air_velocity := 0.0

var facing_x := 1.0
var is_dead := false
var death_time := 0.0
var death_kind := DeathKind.COLLAPSE
var attack_time := -1.0  ## negative means not swinging
var hit_time := -1.0     ## negative means not flinching
var weapon := Weapon.AXE
var attack_kind := ActionKind.STRIKE
var is_crouching := false
## While locked the body keeps facing where it faces and simply travels, so
## moving against that facing is a backwards step rather than a turn.
var facing_locked := false
var health_max := HEALTH_MAX
var health := HEALTH_MAX
var stamina := STAMINA_MAX
var rest_time := 0.0    ## how long since the last effort
var skills := {}        ## Weapon -> level; anything missing is a raw beginner
var crossbow_loaded := true
var helm := Helm.NONE
## A shield strapped on over a one-handed weapon (given out by the RTS forge).
## The sword-and-shield has its own shield and never needs this.
var shielded := false
const SHIELD_WEAPONS := [Weapon.SWORD, Weapon.CLUB, Weapon.AXE, Weapon.DAGGER, Weapon.TORCH]
var donning := false    ## which way round the current helm action goes
var rise_time := -1.0   ## negative means not getting up
var roll_time := -1.0   ## negative means not rolling
var roll_dir := 1.0
# Deliberately untyped. A rock and a dead man have nothing in common except that
# both can be hoisted, and that is the only thing carrying needs to know.
var carried_item: Node2D = null
var target_item: Node2D = null
## Where a shot is meant to land, on the floor, or INF to shoot straight ahead
## the way a figure seen from the side does. Something that picks its targets
## (Unit) sets it before loosing; the keyboard-driven body never does.
var aim_point := Vector2.INF

## The rig owns everything the body has thrown or dropped, since it is what
## knows where the hands were when it left them.
@onready var rig: Node = get_node_or_null("Walker")

func _ready() -> void:
	# A body is something other bodies can hit, and that is all "targets" means.
	# The straw dummy got here first and set the vocabulary; everything that can
	# be struck answers the same few questions, so nothing that swings a weapon
	# has to know what it is swinging at.
	add_to_group("targets")

func is_alive() -> bool:
	return not is_dead

func team_of() -> int:
	return team

# A corpse answers the same handful of questions a rock does, and no more. It is
# not turned into some other kind of object to be carried: it keeps its own rig,
# its own armour and the attitude it died in, and the carrier simply decides
# where it is. That is why there is no drawing code here at all.
## A body pivots about its own feet, and the shoulder is where those feet are
## put -- so without this it hangs entirely out in front of the bearer instead of
## lying across him. Shifting the hold back by about half a body balances it.
const LIFT_BALANCE := 45.0

var grip := Carriable.Grip.ON_SHOULDER   ## a man goes over the shoulder
var heavy := true                        ## and slows you to a trudge
var height := 0.0                        ## how far off the floor, while carried
var carried_by: Node2D = null
var carry_facing := 1.0   ## the facing actually being drawn, eased, handed over by the rig

func can_be_lifted() -> bool:
	return is_dead and carried_by == null and not is_rising()

func can_be_taken() -> bool:
	return can_be_lifted()

func is_free() -> bool:
	return can_be_lifted()

func grab() -> void:
	velocity = Vector2.ZERO
	_set_solid(false)

## Told by whoever picked it up. grab() cannot work this out for itself, and
## reading the parent instead gave the world rather than the man.
func borne_by(bearer: Node2D) -> void:
	carried_by = bearer

## Driven by the carrier every frame. The node's own position is its feet, so
## lifting it is simply putting those feet where the shoulder is.
func hold_at(world: Vector2, above_floor: float, _angle: float) -> void:
	height = above_floor
	var back := 0.0
	if carried_by != null and "facing_x" in carried_by:
		# It lies the way its bearer faces -- but the offset follows the *drawn*
		# facing, which eases round, not the bearer's raw one, which flips in a
		# single frame. Taken from the raw value the body jumped the full width of
		# the balance, ninety pixels, the instant he turned.
		facing_x = carried_by.facing_x
		back = -carry_facing * LIFT_BALANCE
	global_position = world - Vector2(back, above_floor)

## Set down again. A body is too heavy to throw, so whatever velocity is offered
## is ignored: it goes on the ground where it was let go of.
func launch(from: Vector2, _above_floor: float, _throw: Vector2, _lift: float, _turn: float) -> void:
	global_position = from
	height = 0.0
	velocity = Vector2.ZERO
	carried_by = null
	_set_solid(true)

## A body being carried must not also be an obstacle, or the carrier spends the
## whole time shouldering its way past what it is holding.
func _set_solid(solid: bool) -> void:
	for child in get_children():
		var shape := child as CollisionShape2D
		if shape != null:
			shape.set_deferred("disabled", not solid)

## What the weapon in hand takes off whatever it lands on.
func strike_harm() -> float:
	return STRIKE_HARM.get(weapon, STRIKE_HARM[Weapon.NONE])

## Wind comes back on its own, but not straight away, and slower to start after
## you have emptied yourself entirely.
func _breathe(delta: float) -> void:
	rest_time += delta
	var wait := STAMINA_WINDED if stamina <= 0.01 else STAMINA_PAUSE
	if rest_time < wait:
		return
	stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)

func skill_in(kind: Weapon) -> int:
	return clampi(skills.get(kind, 0), 0, SKILL_MAX)

## Test hook: one more level in whatever is in hand.
func train_current() -> void:
	train(weapon)

func train(kind: Weapon) -> void:
	skills[kind] = mini(skill_in(kind) + 1, SKILL_MAX)

## What the stroke in hand would cost this particular body right now.
func strike_cost() -> float:
	var base: float = STRIKE_COST.get(weapon, STRIKE_COST[Weapon.NONE])
	return base * pow(SKILL_STEP, float(skill_in(weapon)))

func has_wind_for(cost: float) -> bool:
	return stamina >= cost

func spend_wind(cost: float) -> void:
	stamina = maxf(0.0, stamina - cost)
	rest_time = 0.0

## Whether there is breath enough to swing at all. Worth asking from outside: an
## armed man who knows he is spent should stand off rather than flail.
func can_strike() -> bool:
	return not is_dead and not is_attacking() and has_wind_for(strike_cost())

## Whether someone standing at `from` is on the blind side.
func exposed_back_to(from: Vector2) -> bool:
	if is_dead:
		return false
	return (from.x - global_position.x) * facing_x < 0.0

## Struck from behind by something that meant it.
func take_backstab(from: Vector2) -> void:
	if is_dead:
		return
	if absf(from.x - global_position.x) > 1.0:
		facing_x = signf(from.x - global_position.x) * -1.0
	die_cut()

func _physics_process(delta: float) -> void:
	_breathe(delta)

	# Carried: where it is, is the carrier's business. The clock keeps running
	# though -- a man hoisted the instant he drops should finish going limp on
	# the shoulder, not freeze in the attitude he was caught in.
	if carried_by != null:
		if is_dead:
			death_time += delta
		return

	if is_dead:
		death_time += delta
		velocity = velocity.move_toward(Vector2.ZERO, DEATH_DRAG * delta)
		if is_rising():
			rise_time += delta
			if rise_time >= RISE_TIME:
				_finish_rising()
	elif is_rolling():
		# no steering once it is under way: the roll carries you where it was aimed
		roll_time += delta
		if roll_time > ROLL_TIME:
			roll_time = -1.0
		velocity = velocity.move_toward(Vector2.ZERO, ROLL_DRAG * delta)
	elif is_flinching():
		# staggered: the knockback carries the body, input does not
		velocity = velocity.move_toward(Vector2.ZERO, HIT_DRAG * delta)
	else:
		var wish := _get_input_vector()
		var limit := move_speed()
		if facing_locked and wish.x * facing_x < 0.0:
			limit = minf(limit, BACK_SPEED)

		velocity = velocity.move_toward(wish * limit, acceleration * delta)
		if absf(velocity.x) > 5.0 and not facing_locked:
			facing_x = signf(velocity.x)

	move_and_slide()

	if is_attacking():
		attack_time += delta
		if attack_time > attack_duration():
			attack_time = -1.0

	if is_flinching():
		hit_time += delta
		if hit_time > HIT_TIME:
			hit_time = -1.0

	if not is_grounded() or air_velocity > 0.0:
		air_velocity -= gravity * delta
		air_height += air_velocity * delta
		if air_height <= 0.0:
			air_height = 0.0
			air_velocity = 0.0

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or not key.pressed:
		return
	if key.physical_keycode == KEY_SPACE:
		jump()

## Top speed, which a heavy load cuts in half. Everything downstream follows from
## it on its own: the gait blend is driven by speed, so a loaded body walks
## instead of running without anything having to say so.
func move_speed() -> float:
	var limit := speed
	if is_carrying_heavy():
		limit = minf(limit, HEAVY_SPEED)
	if is_crouching:
		limit = minf(limit, CROUCH_SPEED)
	return limit

## A second way of moving rather than a separate one: everything else -- weapons,
## carrying, striking, the idle -- keeps working underneath it.
## Roll clear. Aimed by the movement keys, or straight ahead if none are held.
func roll() -> void:
	if is_dead or is_rolling() or is_attacking() or is_carrying() or not is_grounded():
		return

	var wish := _get_input_vector()
	roll_dir = signf(wish.x) if absf(wish.x) > 0.1 else facing_x
	roll_time = 0.0
	velocity = Vector2(roll_dir * ROLL_SPEED, 0.0)

func is_rolling() -> bool:
	return roll_time >= 0.0

func roll_progress() -> float:
	return roll_time / ROLL_TIME if is_rolling() else 0.0

## Nothing lands during the middle of a roll -- not at the very start, so it
## cannot be used as a panic button, and not at the end, so the recovery is a
## real risk.
func is_invulnerable() -> bool:
	if not is_rolling():
		return false
	var p := roll_progress()
	return p >= ROLL_SAFE_FROM and p <= ROLL_SAFE_TO

func toggle_facing_lock() -> void:
	facing_locked = not facing_locked

## Travelling against the way the body is pointing.
func is_backpedalling() -> bool:
	return absf(velocity.x) > 5.0 and velocity.x * facing_x < 0.0

func toggle_crouch() -> void:
	if is_dead:
		return
	is_crouching = not is_crouching

func is_carrying_heavy() -> bool:
	return carried_item != null and carried_item.heavy

func jump() -> void:
	if is_dead or not is_grounded() or is_carrying_heavy():
		return
	# you straighten up to jump rather than being refused it
	is_crouching = false
	air_velocity = jump_impulse

## Strike with whatever is in hand: the axe chops, the spear thrusts. Movement
## carries on underneath it, the way an attack layers over locomotion, and an
## attack already in progress is not restarted.
func attack() -> void:
	# both hands are on the rock, so there is nothing free to swing with
	if is_dead or is_attacking() or is_carrying() or is_rolling():
		return
	# The sneak is not a separate button: it is what an ordinary blow becomes when
	# you are crouched, holding a dagger, and standing behind something that has
	# not seen you. That is what makes creeping about worth doing.
	if can_backstab():
		if not has_wind_for(BACKSTAB_COST):
			return
		var mark := backstab_target()
		var dx: float = mark.global_position.x - global_position.x
		if absf(dx) > 1.0:
			facing_x = signf(dx)
		spend_wind(BACKSTAB_COST)
		attack_kind = ActionKind.BACKSTAB
		attack_time = 0.0
		return

	# One button, and the state of the weapon decides what it does: a spanned
	# crossbow shoots, an empty one gets spanned. The rhythm -- shoot, span,
	# shoot -- is the weapon, and the span is where you are caught.
	if weapon == Weapon.CROSSBOW and not crossbow_loaded:
		if not has_wind_for(SPAN_COST):
			return
		spend_wind(SPAN_COST)
		attack_kind = ActionKind.SPAN
		attack_time = 0.0
		return

	# A blow you have not the wind for is not thrown at all. Refusing up front,
	# rather than letting it swing weakly, is what makes emptying yourself a
	# decision instead of a slider.
	var cost := strike_cost()
	if not has_wind_for(cost):
		return
	spend_wind(cost)

	attack_kind = ActionKind.STRIKE
	attack_time = 0.0

	# square up to the rock face, the same way the axe squares up to a trunk
	if weapon == Weapon.PICKAXE:
		var vein := nearest_vein()
		if vein != null:
			var dx := vein.global_position.x - global_position.x
			if absf(dx) > 1.0:
				facing_x = signf(dx)

## Felling stroke. Takes the axe in hand first, since it is the only thing here
## that makes sense against a trunk.
func chop_tree() -> void:
	if is_dead or is_attacking():
		return
	var felling := CHOP_COST * pow(SKILL_STEP, float(skill_in(Weapon.AXE)))
	if not has_wind_for(felling):
		return
	weapon = Weapon.AXE
	spend_wind(felling)
	attack_kind = ActionKind.CHOP_TREE
	attack_time = 0.0

	# square up to the trunk before swinging: the notch is cut on the side the
	# axe comes from, so where you stand is what decides which way it goes over
	var target := nearest_tree()
	if target != null:
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 1.0:
			facing_x = signf(dx)

## Called by the rig at the moment the blade actually bites. Nothing is required
## to be there: swinging at empty air is allowed, it just fells nothing.
func bite_tree() -> void:
	var target := nearest_tree()
	if target != null:
		target.take_bite(global_position)

## Called by the rig at the moment the pick bites, on the same terms as the axe:
## swinging at nothing is allowed, it simply wins nothing.
func strike_vein() -> void:
	var vein := nearest_vein()
	if vein != null:
		vein.take_strike(global_position)

func nearest_vein() -> OreVein:
	var best: OreVein = null
	var best_distance := MINE_RANGE
	for node in get_tree().get_nodes_in_group("veins"):
		var candidate := node as OreVein
		if candidate == null or not candidate.has_ore():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func nearest_tree() -> ChopTree:
	var best: ChopTree = null
	var best_distance := CHOP_RANGE
	for node in get_tree().get_nodes_in_group("trees"):
		var candidate := node as ChopTree
		if candidate == null or not candidate.is_standing():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func can_backstab() -> bool:
	return weapon == Weapon.DAGGER and is_crouching and backstab_target() != null

func is_backstabbing() -> bool:
	return is_attacking() and attack_kind == ActionKind.BACKSTAB

## The nearest thing within arm's reach that is facing away from us.
func backstab_target() -> Node2D:
	return _nearest_target(BACKSTAB_RANGE, true)

## Deliberately untyped over the group: a straw dummy and an armoured knight have
## nothing in common except that both can be hit, and that is the only thing the
## blow needs to know about either of them.
func _nearest_target(reach: float, from_behind: bool) -> Node2D:
	var best: Node2D = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("targets"):
		var candidate := node as Node2D
		if candidate == null or candidate == self:
			continue
		if not candidate.has_method("is_alive") or not candidate.is_alive():
			continue
		# a blow goes past a comrade to whoever is beyond him: in a line of
		# shoulders the nearest body is nearly always your own side
		if Team.allied(team, Team.of(candidate)):
			continue
		if from_behind and not candidate.exposed_back_to(global_position):
			continue
		var distance := global_position.distance_to(Team.spot(candidate, global_position))
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

## Called by the rig as the blade goes in, on the same terms as the axe and the
## pick: if nothing is there any more, nothing happens.
func land_backstab() -> void:
	var mark := _nearest_target(BACKSTAB_RANGE * 1.4, true)
	if mark != null:
		mark.take_backstab(global_position)
	velocity = Vector2(facing_x * BACKSTAB_LUNGE, 0.0)

## Whatever is standing at this spot takes a blow. Used by things that travel --
## a bolt finds its own mark rather than being aimed at one when it is cast.
func hit_target_at(world: Vector2, radius: float, damage: float) -> bool:
	for node in get_tree().get_nodes_in_group("targets"):
		var mark := node as Node2D
		if mark == null or mark == self:
			continue
		if not mark.has_method("is_alive") or not mark.is_alive():
			continue
		if Team.allied(team, Team.of(mark)):
			continue
		if world.distance_to(Team.spot(mark, world)) <= radius:
			mark.take_hit(world, damage)
			return true
	return false

## Stands every knocked-over target back up, so the move can be tried again.
func reset_targets() -> void:
	for node in get_tree().get_nodes_in_group("targets"):
		if node.has_method("reset"):
			node.reset()

## And an ordinary blow with whatever is in hand.
func land_strike() -> void:
	var mark := _nearest_target(STRIKE_RANGE, false)
	if mark != null:
		mark.take_hit(global_position, harm_against(mark))

## What a blow does to this particular mark; the same to everything, here.
func harm_against(_mark: Node) -> float:
	return strike_harm()

func is_chopping() -> bool:
	return is_attacking() and attack_kind == ActionKind.CHOP_TREE

## True only while actually striking with the weapon in hand. Anything keyed on
## the weapon has to check this as well: every action shares one progress clock,
## so a pick-up or a throw sweeps past a weapon's release point too.
func is_striking() -> bool:
	return is_attacking() and attack_kind == ActionKind.STRIKE

## Stoop for whatever is nearest within reach -- a rock, or a weapon lying where
## it was thrown or dropped. Nothing happens if there is nothing there: the reach
## is what decides, not the button press.
func pick_up() -> void:
	if is_dead or is_attacking() or carried_item != null:
		return

	var rock := _nearest_carriable()
	var weapon_range := _dropped_weapon_range()
	if rock == null and weapon_range < 0.0:
		return

	# whichever is closer wins; a weapon only if the hands are free of one
	if rock != null and (weapon_range < 0.0 or global_position.distance_to(rock.global_position) <= weapon_range):
		target_item = rock
	else:
		target_item = null

	attack_kind = ActionKind.PICK_UP
	attack_time = 0.0

## Set whatever is in hand on the ground beside you, where it can be picked up
## again. Deliberately a place rather than a throw.
func put_down_weapon() -> void:
	if is_dead or is_attacking() or is_carrying() or weapon == Weapon.NONE:
		return
	attack_kind = ActionKind.PUT_DOWN  # not a throw: it is laid down, not launched
	attack_time = 0.0

func is_putting_down() -> bool:
	return is_attacking() and attack_kind == ActionKind.PUT_DOWN

## How near the closest dropped weapon is, wherever it fell and whoever let go
## of it. Searching only your own rig meant a dead man's sword lay there for ever
## because it belonged to him.
func _dropped_weapon_range() -> float:
	if weapon != Weapon.NONE:
		return -1.0
	var best := -1.0
	for node in get_tree().get_nodes_in_group("rigs"):
		var found: float = node.nearest_dropped_range(global_position, PICKUP_RANGE)
		if found >= 0.0 and (best < 0.0 or found < best):
			best = found
	return best

## Only what can actually be hurled. A beam on the shoulder cannot be, so the
## button simply does nothing rather than pretending.
func throw_rock() -> void:
	if is_dead or is_attacking() or carried_item == null or carried_item.heavy:
		return
	attack_kind = ActionKind.THROW
	attack_time = 0.0

## Set whatever is being carried down instead of hurling it -- the same stoop as
## putting a weapon down, since the body does not care which it is holding.
func put_down_rock() -> void:
	if is_dead or is_attacking() or carried_item == null:
		return
	attack_kind = ActionKind.PUT_DOWN
	attack_time = 0.0

func is_carrying() -> bool:
	return carried_item != null

func is_picking_up() -> bool:
	return is_attacking() and attack_kind == ActionKind.PICK_UP

func is_throwing() -> bool:
	return is_attacking() and attack_kind == ActionKind.THROW

## Called by the rig at the moment the hand actually closes on it.
func take_hold() -> void:
	if target_item != null:
		carried_item = target_item
		target_item = null
		carried_item.grab()
		if carried_item.has_method("borne_by"):
			carried_item.borne_by(self)
		return

	# nothing to carry, so it was a weapon being retrieved
	if rig != null and weapon == Weapon.NONE:
		# whichever rig it is lying in, nearest first
		var best_rig: Node = null
		var best := -1.0
		for node in get_tree().get_nodes_in_group("rigs"):
			var found: float = node.nearest_dropped_range(global_position, PICKUP_RANGE)
			if found >= 0.0 and (best < 0.0 or found < best):
				best = found
				best_rig = node
		if best_rig != null:
			var taken: int = best_rig.take_dropped(global_position, PICKUP_RANGE)
			if taken >= 0:
				weapon = taken as Weapon

## And at the moment it leaves the hand again.
func let_go(from: Vector2, above_floor: float, throw: Vector2, lift: float, turn: float) -> void:
	if carried_item == null:
		return
	carried_item.launch(from, above_floor, throw, lift, turn)
	carried_item = null

func _nearest_carriable() -> Node2D:
	var best: Node2D = null
	var best_distance := PICKUP_RANGE
	for node in get_tree().get_nodes_in_group("carriables"):
		var rock := node as Node2D
		if rock == null or rock == self:
			continue
		if not rock.has_method("can_be_taken") or not rock.can_be_taken():
			continue
		var distance := global_position.distance_to(rock.global_position)
		if distance < best_distance:
			best_distance = distance
			best = rock
	return best

func is_attacking() -> bool:
	return attack_time >= 0.0

func attack_duration() -> float:
	match attack_kind:
		ActionKind.SPAN:
			return SPAN_TIME
		ActionKind.HELM:
			return HELM_TIME
		ActionKind.BACKSTAB:
			return BACKSTAB_TIME
		ActionKind.CHOP_TREE:
			return CHOP_TREE_TIME
		ActionKind.PICK_UP:
			return PICK_UP_TIME
		ActionKind.THROW:
			return THROW_TIME
		ActionKind.PUT_DOWN:
			return PUT_DOWN_TIME
			return THROW_TIME

	match weapon:
		Weapon.SPEAR:
			return SPEAR_ATTACK_TIME
		Weapon.BOW:
			return BOW_ATTACK_TIME
		Weapon.SWORD, Weapon.SWORD_SHIELD:
			return SWORD_ATTACK_TIME
		Weapon.GREATSWORD:
			return GREATSWORD_ATTACK_TIME
		Weapon.PICKAXE:
			return PICKAXE_ATTACK_TIME
		Weapon.DAGGER:
			return DAGGER_ATTACK_TIME
		Weapon.STAFF:
			return STAFF_ATTACK_TIME
		Weapon.TORCH:
			return TORCH_ATTACK_TIME
		Weapon.CROSSBOW:
			return CROSSBOW_ATTACK_TIME
		_:
			return AXE_ATTACK_TIME

func attack_progress() -> float:
	return attack_time / attack_duration() if is_attacking() else 0.0

func equip_axe() -> void:
	_equip(Weapon.AXE)

func equip_spear() -> void:
	_equip(Weapon.SPEAR)

func equip_bow() -> void:
	_equip(Weapon.BOW)

func equip_sword() -> void:
	_equip(Weapon.SWORD)

func equip_sword_shield() -> void:
	_equip(Weapon.SWORD_SHIELD)

func equip_greatsword() -> void:
	_equip(Weapon.GREATSWORD)

func equip_pickaxe() -> void:
	_equip(Weapon.PICKAXE)

## One button for the whole business. With no helm to hand it is simply fetched
## -- there is nothing to watch in reaching into your own pack -- and after that
## it goes on and comes off, which is worth watching.
func toggle_helm() -> void:
	if is_dead or is_attacking() or is_carrying() or is_rolling():
		return
	if helm == Helm.NONE:
		helm = Helm.CARRIED
		return
	donning = helm == Helm.CARRIED
	attack_kind = ActionKind.HELM
	attack_time = 0.0

func is_helm_action() -> bool:
	return is_attacking() and attack_kind == ActionKind.HELM

## Called by the rig at the moment it leaves the head, or settles onto it.
func seat_helm() -> void:
	helm = Helm.WORN if donning else Helm.CARRIED

## Plate on or off. Not an action: it is a test switch, not something a man does
## between one breath and the next.
func toggle_armour() -> void:
	if rig != null:
		rig.armoured = not rig.armoured

func equip_dagger() -> void:
	_equip(Weapon.DAGGER)

func equip_staff() -> void:
	_equip(Weapon.STAFF)

func equip_torch() -> void:
	_equip(Weapon.TORCH)

func equip_crossbow() -> void:
	_equip(Weapon.CROSSBOW)
	crossbow_loaded = true

func is_spanning() -> bool:
	return is_attacking() and attack_kind == ActionKind.SPAN

## Called by the rig as the string goes over the nut.
func load_crossbow() -> void:
	crossbow_loaded = true

## And as the trigger goes.
func shoot_crossbow() -> void:
	crossbow_loaded = false

## Called by the rig as the flame comes through. A torch is a bad weapon and a
## good match: it barely hurts anyone, and it is the only thing here that starts
## fires.
##
## A hearth is tried before anything else, because standing over one with a torch
## in your hand you are almost never trying to burn down the wood behind it.
## After that, timber standing, then timber lying.
func torch_strike() -> void:
	var hearth := _nearest_unlit_fire(TORCH_RANGE)
	if hearth != null and hearth.light():
		return
	var target := _nearest_standing_tree(TORCH_RANGE)
	if target != null:
		target.ignite()
		return
	var timber := _nearest_timber(TORCH_RANGE)
	if timber != null:
		timber.ignite()

func _nearest_unlit_fire(reach: float) -> Campfire:
	var best: Campfire = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("fires"):
		var hearth := node as Campfire
		if hearth == null or hearth.going:
			continue
		var distance := global_position.distance_to(hearth.global_position)
		if distance < best_distance:
			best_distance = distance
			best = hearth
	return best

func _nearest_timber(reach: float) -> Beam:
	var best: Beam = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("carriables"):
		var timber := node as Beam
		if timber == null or not timber.is_free() or timber.is_burning():
			continue
		var distance := global_position.distance_to(timber.global_position)
		if distance < best_distance:
			best_distance = distance
			best = timber
	return best

func _nearest_standing_tree(reach: float) -> ChopTree:
	var best: ChopTree = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("trees"):
		var candidate := node as ChopTree
		if candidate == null or not candidate.is_standing():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _equip(next: Weapon) -> void:
	if is_dead or weapon == next:
		return
	weapon = next
	attack_time = -1.0

## Struck but still standing: knocked back a step, control briefly lost, and any
## swing in progress is interrupted.
## `from` is where the blow came from, when the striker knows. Without it the
## body is simply pushed backwards relative to the way it is facing, which is
## what the test button does.
func take_hit(from: Vector2 = Vector2.INF, damage: float = 10.0) -> void:
	if is_dead or is_invulnerable():
		return

	var away := -facing_x
	if from.x < INF and absf(from.x - global_position.x) > 1.0:
		away = signf(global_position.x - from.x)

	health = maxf(0.0, health - damage)
	if health <= 0.0:
		_die_from(away)
		return

	hit_time = 0.0
	attack_time = -1.0
	velocity = Vector2(away * HIT_KNOCKBACK, 0.0)

## The last blow. Which way it goes down is decided by where the blow came from,
## not by what made it: struck from the front a body is thrown backwards, and
## struck from behind it pitches forward over its own feet.
func _die_from(away: float) -> void:
	# `away` points where the blow shoves you. Shoved against your own facing, the
	# blow came from in front of you; shoved along it, from behind.
	if away * facing_x < 0.0:
		die_shot()                 # struck from the front: thrown onto your back
	else:
		die()                      # struck from behind: pitched onto your face
	velocity = Vector2(away * KNOCKBACK_SPEED, 0.0)

func is_flinching() -> bool:
	return hit_time >= 0.0

func die() -> void:
	_start_death(DeathKind.COLLAPSE)

## Shot or struck from the front: thrown backwards, away from where it was facing.
func die_shot() -> void:
	if _start_death(DeathKind.KNOCKED_BACK):
		velocity = Vector2(-facing_x * KNOCKBACK_SPEED, 0.0)

## Cut down in melee: a blade carries across rather than driving through, so the
## body is spun by the blow instead of launched by it.
func die_cut() -> void:
	if _start_death(DeathKind.CUT_DOWN):
		velocity = Vector2(-facing_x * CUT_KNOCKBACK, 0.0)

## Start getting up. Nothing is cleared here: the body stays dead, and helpless,
## for as long as it takes to stand. Clearing the state on the way up is what
## made this an instant reset before.
func revive() -> void:
	if not is_dead or is_rising():
		return
	rise_time = 0.0

func is_rising() -> bool:
	return rise_time >= 0.0

func rise_progress() -> float:
	return clampf(rise_time / RISE_TIME, 0.0, 1.0) if is_rising() else 0.0

## Called once he is actually on his feet, not when the button was pressed.
func _finish_rising() -> void:
	rise_time = -1.0
	is_dead = false
	remove_from_group("carriables")
	_set_solid(true)
	# back on your feet is not back in one piece, but it is not nothing either
	health = maxf(health, health_max * 0.25)
	# a man who has just picked himself up off the ground is not fresh
	stamina = minf(stamina, STAMINA_MAX * 0.4)
	rest_time = 0.0
	velocity = Vector2.ZERO
	air_height = 0.0
	air_velocity = 0.0
	hit_time = -1.0
	roll_time = -1.0

func is_grounded() -> bool:
	return air_height <= 0.0

func _start_death(kind: DeathKind) -> bool:
	if is_dead:
		return false
	is_dead = true
	is_crouching = false
	death_kind = kind
	death_time = 0.0
	attack_time = -1.0
	hit_time = -1.0
	roll_time = -1.0
	rise_time = -1.0
	# only now is it something anyone would pick up -- and no longer something
	# anyone has to walk round
	add_to_group("carriables")
	_set_solid(false)
	died.emit(self)
	return true

func _get_input_vector() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir.normalized() if dir.length() > 0.0 else dir
