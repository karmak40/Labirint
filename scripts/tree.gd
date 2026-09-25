class_name ChopTree
extends Node2D
## A tree that can be felled with an axe, and that turns into timber when it
## lands.
##
## It exists to give the chopping stroke something to act on, so the loop closes
## on things that already work: the axe already swings and throws splinters, the
## beam already gets hoisted onto a shoulder and set down again. This is the
## middle of that chain.
##
## Like everything else out here its node position is the point on the floor it
## stands on; the trunk is drawn upwards from there and rotates about that point,
## because a tree goes over on its stump rather than sliding off it.

const TRUNK_HEIGHT := 190.0
const TRUNK_BASE := 15.0      ## half-width at the ground
const TRUNK_TOP := 8.0        ## and at the crown, so the trunk tapers
const STUMP_HEIGHT := 16.0

const BITES := 6              ## good strokes before it goes over
const NOTCH_AT := 26.0        ## how far up the trunk the cut is made
const NOTCH_DEPTH := 13.0     ## how deep the notch is once the cut is finished
const NOTCH_SPAN := 17.0      ## and how tall the wedge is

# Every stroke jars the whole tree. The shudder is a damped oscillation rather
# than a plain decay because a struck trunk really does ring -- unlike a struck
# body, where ringing reads as a second hit.
const SHAKE := 0.05
const SHAKE_DECAY := 6.5
const SHAKE_FREQ := 23.0
const LEAN_MAX := 0.12        ## how far a fully cut tree leans before it goes

const FALL_TIME := 1.15
const FALL_EXPONENT := 2.1    ## it accelerates over: slow to start, fast at the end
const FALL_ANGLE := PI * 0.5
const IMPACT_BOUNCE := 0.055
const IMPACT_DECAY := 7.0
const IMPACT_FREQ := 19.0
const BREAK_DELAY := 0.5      ## the landing gets a beat to read before it breaks up

# The crown lags behind the trunk, which is what makes a falling tree look heavy
# at the bottom and loose at the top.
const CROWN_WHIP := 0.055
const CROWN_WHIP_LIMIT := 0.5
const CROWN_EASE := 9.0

# Fire. A second way to fell a tree, and a worse one on purpose: it takes no
# effort and no axe, and it leaves you nothing. Chopping costs six strokes and
# gives timber; burning costs a moment and gives ash. Having both is the point.
const CATCH_TIME := 1.4       ## from the torch touching it to properly alight
const BURN_THROUGH := 9.0     ## and from alight to falling
const FLAME_CLIMB := 0.7      ## share of the trunk the fire has run up when it goes
# Sized so the curve in a tongue is actually visible. At thirty pixels the whole
# S of it fell inside two or three, and every flame on the tree read as a plain
# triangle no matter how well the shape itself was drawn.
const FIRE_TONGUES := 7       ## overlapping, or they read as arrows up the trunk
const FIRE_TALL := 58.0
const FIRE_WIDE := 11.0
const FIRE_SWAY := 11.0
const CROWN_FIRE := 46.0      ## how far the flames stand off the burning crown
const ASH := Color(0.19, 0.17, 0.17)
const EMBER_BARK := Color(0.66, 0.26, 0.10)

const LOGS := 2               ## how many beams the trunk makes
const LOG_SCATTER := 26.0

const BARK := Color(0.33, 0.25, 0.18)
const BARK_EDGE := Color(0.25, 0.19, 0.13)
const CUT := Color(0.74, 0.6, 0.41)   ## fresh inner wood, much paler than bark
const LEAF := Color(0.24, 0.45, 0.24)
const LEAF_LIGHT := Color(0.31, 0.55, 0.28)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.18)
const CROWN_SHADOW := 34.0

enum State { STANDING, FALLING, DOWN }

## How many beams the trunk breaks into: the testbed's two, a match's ten.
@export var logs := LOGS
## What each of those beams is worth at a stockpile.
@export var log_worth := 1
## Seconds from lying felled to standing again; 0 leaves a stump for good. A
## match that is meant to go on needs its woods to come back.
@export var regrow_time := 0.0

var state := State.STANDING
var bites := 0
var fall_dir := 1.0           ## which way it goes over: away from whoever cut it
var shake := 0.0              ## strength of the current shudder
var shake_time := 0.0
var fall_time := 0.0
var tilt := 0.0
var crown_whip := 0.0
var prev_tilt := 0.0
var alight := 0.0             ## 0 not burning, 1 fully involved
var burn_time := -1.0         ## how long it has been alight
var burnt := false            ## felled by fire rather than by the axe
var down_time := 0.0          ## how long it has been lying felled
var blocker: StaticBody2D

func _ready() -> void:
	add_to_group("trees")
	blocker = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = TRUNK_BASE - 1.0
	shape.shape = circle
	blocker.add_child(shape)
	add_child(blocker)

func is_standing() -> bool:
	return state == State.STANDING

## Which way this tree would go over if it were cut from `from`: away from the
## axe, the way the notch points.
func fall_side_from(from: Vector2) -> float:
	var d := global_position.x - from.x
	return signf(d) if absf(d) > 1.0 else 1.0

## A torch held against it. Nothing catches instantly: there is a moment where it
## is smouldering and could still be walked away from.
func ignite() -> void:
	if state != State.STANDING or burn_time >= 0.0:
		return
	burn_time = 0.0

func is_burning() -> bool:
	return burn_time >= 0.0

## One stroke of the axe landed.
func take_bite(from: Vector2) -> void:
	if state != State.STANDING:
		return

	# The notch is cut on the side the axe comes from, and the notch is what
	# decides which way it goes. Re-read every stroke, so moving round the trunk
	# part-way through the cut changes where it lands.
	fall_dir = fall_side_from(from)
	bites += 1
	shake = SHAKE
	shake_time = 0.0

	if bites >= BITES:
		state = State.FALLING
		fall_time = 0.0

func cut_ratio() -> float:
	return clampf(float(bites) / float(BITES), 0.0, 1.0)

func _process(delta: float) -> void:
	shake_time += delta
	if burn_time >= 0.0:
		burn_time += delta
		alight = clampf(burn_time / CATCH_TIME, 0.0, 1.0)
		# it burns through its own base and goes over, the same fall as any other
		if state == State.STANDING and burn_time > CATCH_TIME + BURN_THROUGH:
			burnt = true
			fall_dir = signf(sin(burn_time * 3.0))
			if fall_dir == 0.0:
				fall_dir = 1.0
			state = State.FALLING
			fall_time = 0.0

	if shake > 0.0001:
		shake = SHAKE * exp(-SHAKE_DECAY * shake_time)

	match state:
		State.STANDING:
			# leaning further with every stroke: the tree says how far along the
			# cut is before it commits to going over
			var ring := shake * cos(SHAKE_FREQ * shake_time)
			tilt = fall_dir * LEAN_MAX * cut_ratio() + ring
		State.FALLING:
			fall_time += delta
			tilt = fall_dir * _fall_angle(fall_time)
			if fall_time > FALL_TIME + BREAK_DELAY:
				_break_up()
		State.DOWN:
			if regrow_time > 0.0:
				down_time += delta
				if down_time >= regrow_time:
					_regrow()

	# the crown trails the trunk, so it whips through the arc and settles after it
	var rate := (tilt - prev_tilt) / maxf(delta, 0.0001)
	prev_tilt = tilt
	var want := clampf(-rate * CROWN_WHIP, -CROWN_WHIP_LIMIT, CROWN_WHIP_LIMIT)
	crown_whip = lerpf(crown_whip, want, 1.0 - exp(-CROWN_EASE * delta))

	queue_redraw()

func _fall_angle(t: float) -> float:
	# starts from the lean it already had, not from upright: a cut tree is
	# already tipping, and resetting to vertical to begin the fall reads as the
	# trunk being jerked back before it goes
	var angle := lerpf(LEAN_MAX, FALL_ANGLE,
		clampf(pow(t / FALL_TIME, FALL_EXPONENT), 0.0, 1.0))
	if t > FALL_TIME:
		# it does not stop dead: the trunk rebounds off the ground once and rocks
		var since := t - FALL_TIME
		angle -= (FALL_ANGLE - LEAN_MAX) * IMPACT_BOUNCE * exp(-IMPACT_DECAY * since) * cos(IMPACT_FREQ * since)
	return angle

## The trunk on the ground becomes timber. The beams are laid out along where it
## was lying, so nothing jumps: the logs are simply the trunk, in pieces.
func _break_up() -> void:
	state = State.DOWN
	var parent := get_parent()
	if parent == null:
		return

	# nothing usable comes out of a tree that burned down -- that is the trade
	if burnt:
		var shape := blocker.get_child(0) as CollisionShape2D
		(shape.shape as CircleShape2D).radius = TRUNK_BASE - 4.0
		return

	var span := (TRUNK_HEIGHT - STUMP_HEIGHT) / float(logs)
	for i in range(logs):
		var along := STUMP_HEIGHT + span * (float(i) + 0.5)
		var timber := Beam.new()
		timber.amount = log_worth
		timber.position = position + Vector2(fall_dir * along, randf_range(-6.0, 6.0))
		parent.add_child(timber)
		# a nudge apart, so they do not sit in one stack pretending to be one log
		timber.launch(
			timber.global_position, 3.0,
			Vector2(fall_dir * randf_range(8.0, LOG_SCATTER), randf_range(-14.0, 14.0)),
			30.0, randf_range(-0.6, 0.6))

	# what is left is a stump, and a stump is still something to walk round
	var shape := blocker.get_child(0) as CollisionShape2D
	(shape.shape as CircleShape2D).radius = TRUNK_BASE - 4.0

## Back on its stump, whole, as if the seasons had passed.
func _regrow() -> void:
	state = State.STANDING
	bites = 0
	down_time = 0.0
	fall_time = 0.0
	tilt = 0.0
	prev_tilt = 0.0
	crown_whip = 0.0
	shake = 0.0
	burnt = false
	burn_time = -1.0
	alight = 0.0
	var shape := blocker.get_child(0) as CollisionShape2D
	(shape.shape as CircleShape2D).radius = TRUNK_BASE - 1.0

func _draw() -> void:
	_draw_shadow()
	if state == State.DOWN:
		_draw_stump()
		return

	draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	_draw_trunk()
	_draw_crown()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Drawn outside the trunk's rotated frame, because fire goes up whatever the
	# tree is doing. Inside it, a tree going over carried its flames round with it
	# and by the end they were burning sideways.
	if alight > 0.01:
		_draw_burning()

	# the stump stays upright behind a falling trunk: it never left the ground
	if state == State.FALLING:
		_draw_stump()

## The shadow is the tree seen from above: the trunk drops to a strip running out
## from the stump, the crown to a disc over wherever the treetop currently is.
## Both fall straight down onto the floor, so a tilt only moves them sideways.
func _draw_shadow() -> void:
	var reach := sin(tilt) * TRUNK_HEIGHT
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.4))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -TRUNK_BASE),
		Vector2(reach, -TRUNK_TOP),
		Vector2(reach, TRUNK_TOP),
		Vector2(0.0, TRUNK_BASE),
	]), SHADOW_COLOR)
	# upright, this sits over the stump, which is exactly where the crown is
	draw_circle(Vector2(reach, 0.0), CROWN_SHADOW, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Where a point on the trunk actually is once the tree has tilted.
func _on_trunk(up: float) -> Vector2:
	return Vector2(0.0, -TRUNK_HEIGHT * up).rotated(tilt)

## Flames running up the trunk, and the crown going with it once the fire gets
## there. Both stand upright in the world: only where they start moves.
func _draw_burning() -> void:
	var run := clampf(alight, 0.0, 1.0) * FLAME_CLIMB
	if state == State.FALLING:
		run = FLAME_CLIMB
	var clock := burn_time

	Flame.draw_glow(self, _on_trunk(0.08), 70.0 * alight, alight, 10, 0.55)

	for i in range(FIRE_TONGUES):
		# bunched low and thinning upwards, the way a fire actually climbs
		var up := 0.03 + run * pow(float(i) / float(FIRE_TONGUES - 1), 1.5)
		var root := _on_trunk(up) + Vector2(sin(float(i) * 2.1) * TRUNK_BASE * 0.7, 0.0)
		# shorter the further up it has got, so the fire tapers as it climbs
		var reach := FIRE_TALL * alight * (1.0 - 0.4 * float(i) / float(FIRE_TONGUES - 1))
		var tall := Flame.tongue_height(reach, clock, float(i))
		draw_colored_polygon(Flame.tongue(root, Vector2.UP, tall, FIRE_WIDE,
			FIRE_SWAY, clock, float(i)), Flame.LOW.lerp(Flame.MID, 0.4))
		draw_colored_polygon(Flame.tongue(root, Vector2.UP, tall * 0.55,
			FIRE_WIDE * 0.34, FIRE_SWAY, clock, float(i)), Flame.MID.lerp(Flame.TIP, 0.7))

	# once the fire has run the height of the trunk the crown goes up all at once
	var crown_lit := clampf((burn_time - CATCH_TIME - BURN_THROUGH * 0.45) / 2.0, 0.0, 1.0)
	if crown_lit > 0.01:
		var top := _on_trunk(1.0)
		for i in range(5):
			var at := top + Vector2(-30.0 + float(i) * 15.0, 6.0)
			var tall := Flame.tongue_height(CROWN_FIRE * crown_lit, clock, float(i) + 7.0)
			draw_colored_polygon(Flame.tongue(at, Vector2.UP, tall, FIRE_WIDE * 1.2,
				FIRE_SWAY, clock, float(i) + 7.0), Flame.LOW.lerp(Flame.MID, 0.55))

func _draw_trunk() -> void:
	var body := PackedVector2Array([
		Vector2(-TRUNK_BASE, 0.0),
		Vector2(-TRUNK_TOP, -TRUNK_HEIGHT),
		Vector2(TRUNK_TOP, -TRUNK_HEIGHT),
		Vector2(TRUNK_BASE, 0.0),
	])
	draw_colored_polygon(body, BARK.lerp(ASH, alight * 0.75))
	var rim := body.duplicate()
	rim.append(body[0])
	draw_polyline(rim, BARK_EDGE.lerp(EMBER_BARK, alight * 0.5), 1.6, true)

	# bark grain, so the trunk is not a flat slab
	draw_line(Vector2(-TRUNK_BASE * 0.4, -4.0), Vector2(-TRUNK_TOP * 0.5, -TRUNK_HEIGHT + 8.0), BARK_EDGE, 1.3, true)
	draw_line(Vector2(TRUNK_BASE * 0.35, -10.0), Vector2(TRUNK_TOP * 0.4, -TRUNK_HEIGHT + 16.0), BARK_EDGE, 1.3, true)

	_draw_notch()

## The wedge cut out by the axe: on the side the strokes came from, deepening
## with every one of them. Pale, because the wood inside is nothing like the bark.
func _draw_notch() -> void:
	var cut := cut_ratio()
	if cut <= 0.0:
		return

	# the notch faces the axe, which is the side opposite the way it will fall
	var side := -fall_dir
	var depth := NOTCH_DEPTH * cut
	var edge := side * TRUNK_BASE * 0.9
	var wedge := PackedVector2Array([
		Vector2(edge, -NOTCH_AT + NOTCH_SPAN * 0.5),
		Vector2(edge - side * depth, -NOTCH_AT),
		Vector2(edge, -NOTCH_AT - NOTCH_SPAN * 0.5),
	])
	draw_colored_polygon(wedge, CUT)

func _draw_crown() -> void:
	# The crown rides the top of the trunk, so its frame has to carry the trunk's
	# own tilt: draw_set_transform replaces the current transform rather than
	# combining with it, and a crown given only its whip stayed hanging where the
	# treetop would be if the tree were still upright.
	draw_set_transform(
		Vector2(0.0, -TRUNK_HEIGHT).rotated(tilt), tilt + crown_whip, Vector2.ONE)
	var blobs := [
		[Vector2(0.0, -26.0), 34.0, LEAF],
		[Vector2(-26.0, -6.0), 26.0, LEAF],
		[Vector2(26.0, -8.0), 25.0, LEAF],
		[Vector2(-9.0, -42.0), 22.0, LEAF_LIGHT],
		[Vector2(14.0, -32.0), 20.0, LEAF_LIGHT],
	]
	var scorch := clampf((burn_time - CATCH_TIME - BURN_THROUGH * 0.45) / 2.5, 0.0, 1.0) 		if burn_time >= 0.0 else 0.0
	for blob in blobs:
		draw_circle(blob[0], blob[1], (blob[2] as Color).lerp(ASH, scorch * 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_stump() -> void:
	var body := PackedVector2Array([
		Vector2(-TRUNK_BASE, 0.0),
		Vector2(-TRUNK_BASE + 1.5, -STUMP_HEIGHT),
		Vector2(TRUNK_BASE - 1.5, -STUMP_HEIGHT),
		Vector2(TRUNK_BASE, 0.0),
	])
	draw_colored_polygon(body, BARK.lerp(ASH, alight * 0.85))
	var rim := body.duplicate()
	rim.append(body[0])
	draw_polyline(rim, BARK_EDGE, 1.6, true)
	# the sawn face, left showing where the trunk came off
	draw_colored_polygon(PackedVector2Array([
		Vector2(-TRUNK_BASE + 1.5, -STUMP_HEIGHT),
		Vector2(TRUNK_BASE - 1.5, -STUMP_HEIGHT),
		Vector2(TRUNK_BASE - 3.0, -STUMP_HEIGHT - 3.5),
		Vector2(-TRUNK_BASE + 3.0, -STUMP_HEIGHT - 3.5),
	]), CUT)
