class_name Chicken
extends Node2D
## A hen: two legs again, but almost nothing else in common with the figure.
##
## Third skeleton on [Gait], and the one that pushes hardest on it. A bird's
## visible leg joint folds backwards, its body hangs forward off the hips rather
## than sitting on top of them, and its head does something no other body here
## does.
##
## A walking hen holds its head still in the world while the body walks in under
## it, then throws it forward to a new spot and holds again. Everything else in
## this project smooths motion out; this is the one thing that must not be
## smoothed, because the hold and the snap are the whole look of it.

const LEG_UPPER := 12.0        ## drumstick
const LEG_LOWER := 14.0        ## tarsus, the long bare part
const TOE := 5.0
const BODY_LONG := 17.0        ## half-length of the body, tail to breast
const BODY_TALL := 11.0
const NECK := 9.0
const HEAD_R := 5.0
const BEAK := 6.0
const TAIL := 14.0
const LIMB_WIDTH := 2.6

const WALK_SPEED := 18.0
const RUN_SPEED := 70.0
const WALK_STRIDE := 17.0
const RUN_STRIDE := 27.0
const WALK_STANCE := 0.62
const RUN_STANCE := 0.46
const WALK_LIFT := 4.5
const RUN_LIFT := 7.5

# The head hold. It stays where it is until the body has come this far under it,
# then it is thrown forward again -- fast, because a thrust that eases is just a
# head drifting along and the effect disappears entirely.
const HEAD_AHEAD := 17.0       ## where the head parks, ahead of the body
const HEAD_HOLD := 6.0         ## and how close the body may get before it moves on
const THRUST_EASE := 34.0
const HEAD_EASE := 12.0        ## the slower following used when standing still

const GAIT_EASE := 5.0
const RIDE_SMOOTH := 26.0
const TURN_EASE := 9.0
const MIN_TURN_SCALE := 0.06
const PITCH := 0.30            ## how far the body tips nose-down
const PITCH_ALERT := 0.05      ## and how it straightens when the head comes up
const PITCH_PECK := 0.72       ## and how far it goes over to feed
const PECK_SINK := 6.0         ## the legs fold a little as she goes down to it
const PECK_LEAN := 0.55        ## share of the lean held throughout, the rest per strike

# Pecking, which is nothing like the deer's slow cropping: short hard strikes
# with a pause between them.
const PECK_TIME := 4.0
const ALERT_TIME := 1.4
const PECK_PERIOD := 0.62
const PECK_DOWN := 0.15        ## share of each peck spent going down
const PECK_AHEAD := 13.0
const PECK_ARC := 13.0         ## how far the swing down bows out ahead of the chord
const PECK_HOVER := 16.0       ## head height held between jabs, just off the grass
const PECK_REACH := 2.5        ## the jab creeps barely forward: it is a drop, not a swing
const PECK_SETTLE := 0.45      ## she gets her head down before she starts jabbing
const BEAK_REST := 0.14        ## a hen carries her beak a little below level
const BEAK_HOVER := 0.80       ## looking down at the ground while working it
const BEAK_PECK := 1.20        ## and right into it on the jab
const MOOD_EASE := 7.0

@export var patrol := 120.0
@export var pace := 34.0
const SPEED_EASE := 3.4

const BODY_COLOR := Color(0.90, 0.87, 0.80)
const BODY_SHADE := Color(0.74, 0.70, 0.63)
const WING_COLOR := Color(0.80, 0.76, 0.69)
const COMB_COLOR := Color(0.76, 0.22, 0.20)
const BEAK_COLOR := Color(0.88, 0.70, 0.26)
const LEG_COLOR := Color(0.82, 0.62, 0.24)
const LEG_FAR := Color(0.62, 0.46, 0.18)
const EYE_COLOR := Color(0.14, 0.12, 0.11)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.2)

enum Mood { WALKING, PECKING, ALERT }

var home := Vector2.ZERO
var heading := 1.0
var facing := 1.0
var speed := 0.0
var wanted := 0.0

var phase := 0.0
var run_blend := 0.0
var stride := WALK_STRIDE
var stance_fraction := WALK_STANCE
var foot_lift := WALK_LIFT

var ride := 0.0
var mood := Mood.WALKING
var mood_time := 0.0
var peck := 0.0
var alert := 0.0
var dip := 0.0                 ## the current strike within a bout of pecking
var beak_angle := BEAK_REST

var head_hold := 0.0           ## the world x the head is currently parked at
var head_at := Vector2.ZERO
var started := false

func _ready() -> void:
	home = position
	ride = LEG_UPPER + LEG_LOWER
	head_hold = position.x + HEAD_AHEAD

func leg_reach() -> float:
	return LEG_UPPER + LEG_LOWER

func foot_of(side: float) -> Vector2:
	var p := phase if side > 0.0 else phase + 0.5
	return Gait.foot_offset(p, stride, stance_fraction, foot_lift, 1.0)

func is_pecking() -> bool:
	return mood == Mood.PECKING

func is_alert() -> bool:
	return mood == Mood.ALERT

func _process(delta: float) -> void:
	_potter_about(delta)

	run_blend = Gait.ease_to(run_blend,
		clampf(inverse_lerp(WALK_SPEED, RUN_SPEED, absf(speed)), 0.0, 1.0), GAIT_EASE, delta)
	stride = lerpf(WALK_STRIDE, RUN_STRIDE, run_blend)
	stance_fraction = lerpf(WALK_STANCE, RUN_STANCE, run_blend)
	foot_lift = lerpf(WALK_LIFT, RUN_LIFT, run_blend)

	if absf(speed) > 1.0:
		phase = fposmod(phase + absf(speed) * delta / stride, 1.0)
		facing = Gait.ease_to(facing, heading, TURN_EASE, delta)

	peck = Gait.ease_to(peck, 1.0 if is_pecking() else 0.0, MOOD_EASE, delta)
	alert = Gait.ease_to(alert, 1.0 if is_alert() else 0.0, MOOD_EASE, delta)

	dip = _peck_dip()
	# the beak is already down while she works the ground, and goes further in on
	# the jab -- it does not come back up to level between one seed and the next
	var beak_want := lerpf(BEAK_REST, BEAK_HOVER, peck)
	beak_want = lerpf(beak_want, BEAK_PECK, dip)
	beak_angle = Gait.ease_to(beak_angle, beak_want, THRUST_EASE, delta)

	# feeding folds the legs a little as well as tipping the body: a hen that
	# only leans over ends up with her beak short of the ground
	var stand := Gait.ride_height([foot_of(1.0), foot_of(-1.0)], leg_reach())
	stand -= PECK_SINK * peck * lerpf(0.45, 1.0, dip)
	ride = Gait.ease_to(ride, stand, RIDE_SMOOTH, delta)

	_update_head(delta)
	queue_redraw()

func _potter_about(delta: float) -> void:
	mood_time += delta
	match mood:
		Mood.WALKING:
			wanted = pace * heading
			var out := position.x - home.x
			if absf(out) > patrol and signf(out) == heading:
				_set_mood(Mood.PECKING)
		Mood.PECKING:
			wanted = 0.0
			if mood_time > PECK_TIME:
				_set_mood(Mood.ALERT)
		Mood.ALERT:
			wanted = 0.0
			if mood_time > ALERT_TIME:
				heading = -heading
				_set_mood(Mood.WALKING)

	speed = Gait.ease_to(speed, wanted, SPEED_EASE, delta)
	position.x += speed * delta

func _set_mood(next: Mood) -> void:
	mood = next
	mood_time = 0.0

func body() -> Vector2:
	return Vector2(0.0, -ride)

## How far the body is tipped nose-down. Feeding is mostly a held lean with a
## further push on each strike, rather than the head going down on its own -- a
## hen pecks with her whole body and the head is just the end of it.
func body_pitch() -> float:
	var tip := lerpf(PITCH, PITCH_ALERT, alert)
	return lerpf(tip, PITCH_PECK, peck * lerpf(PECK_LEAN, 1.0, dip))

## Where in the strike she is: down hard, up again, then a beat before the next.
func _peck_dip() -> float:
	if peck <= 0.01:
		return 0.0
	# The strikes only start once the head is actually down there. Counted from
	# the moment she stopped, the first jab fired while she was still standing up,
	# so she stabbed at the ground from head height.
	var working := mood_time - PECK_SETTLE
	if working < 0.0:
		return 0.0
	var u := fposmod(working / PECK_PERIOD, 1.0)
	if u < PECK_DOWN:
		return smoothstep(0.0, 1.0, u / PECK_DOWN)
	if u < PECK_DOWN * 2.0:
		return 1.0 - smoothstep(0.0, 1.0, (u - PECK_DOWN) / PECK_DOWN)
	return 0.0

## Where the head is, and the only piece of this project that deliberately does
## not follow the body.
func _update_head(delta: float) -> void:
	var carried := body() + Vector2(BODY_LONG * 0.55, -BODY_TALL * 0.45 - NECK)
	carried.y -= 5.0 * alert

	if is_pecking():
		# down to the ground and back, over and over, with a beat between
		# Two different motions, and conflating them was what made this look
		# wrong. Getting down to the grass is one long swing forward and down,
		# on a curve, and it happens once. The pecks themselves are short sharp
		# drops from there -- a hen that already has her head at the grass does
		# not swing it back up and round for every seed.
		var hover := Vector2(PECK_AHEAD, -PECK_HOVER)
		var grass := Vector2(PECK_AHEAD + PECK_REACH, -HEAD_R * 0.9)
		var want := _arc(carried, hover, peck).lerp(grass, dip)
		head_at = head_at.lerp(want, 1.0 - exp(-THRUST_EASE * delta))
		head_hold = position.x + head_at.x * signf(facing)
		return

	if absf(speed) > 1.0:
		# The hold: the head keeps its world position while the body walks in
		# under it. Once the body has closed the gap, it is thrown forward again.
		# The anchor is a world position, so anything that moves the body without
		# walking it -- a respawn, a level load -- would leave the head parked
		# where the body used to be, strung out on a neck yards long.
		var gap := (head_hold - position.x) * heading
		if gap < HEAD_HOLD or absf(gap) > HEAD_AHEAD * 3.0:
			head_hold = position.x + heading * HEAD_AHEAD
		var want := Vector2((head_hold - position.x) * signf(facing), carried.y)
		head_at = head_at.lerp(want, 1.0 - exp(-THRUST_EASE * delta))
		return

	if started:
		head_at = head_at.lerp(carried, 1.0 - exp(-HEAD_EASE * delta))
	else:
		head_at = carried
		started = true
	head_hold = position.x + head_at.x * signf(facing)

## Quadratic Bezier for the long swing down into the feeding posture, bowed out
## ahead of the chord so the head travels round the front of her rather than
## down through her own breast.
func _arc(from: Vector2, to: Vector2, t: float) -> Vector2:
	var span := to - from
	var out := Vector2(span.y, -span.x).normalized()   # forward and up, off the line
	var control := from + span * 0.5 + out * PECK_ARC
	var inv := 1.0 - t
	return from * (inv * inv) + control * (2.0 * inv * t) + to * (t * t)

func _draw() -> void:
	_draw_shadow()
	var turn: float = signf(facing) * maxf(absf(facing), MIN_TURN_SCALE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(turn, 1.0))

	var b := body()
	_leg(b, -1.0, LEG_FAR)
	_draw_body(b)
	_draw_neck_and_head(b)
	_leg(b, 1.0, LEG_COLOR)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A bird's leg folds the other way from a person's: the joint you can see is the
## ankle, and it points backwards. One sign on the same IK.
func _leg(b: Vector2, side: float, color: Color) -> void:
	var hip := b + Vector2(-2.0, BODY_TALL * 0.2)
	var foot := Vector2(0.0, 0.0) + foot_of(side)
	var ankle := Gait.joint(hip, foot, LEG_UPPER, LEG_LOWER, -1.0)
	var toe := Gait.reached(hip, foot, LEG_UPPER, LEG_LOWER)

	draw_line(hip, ankle, color, LIMB_WIDTH * 1.5, true)
	draw_line(ankle, toe, color, LIMB_WIDTH, true)
	# a forward toe and a back one, so it has a foot rather than a stump
	draw_line(toe, toe + Vector2(TOE, 0.0), color, LIMB_WIDTH * 0.8, true)
	draw_line(toe, toe + Vector2(-TOE * 0.5, 0.0), color, LIMB_WIDTH * 0.8, true)

func _draw_body(b: Vector2) -> void:
	var fwd := Vector2.from_angle(body_pitch())
	var up := Vector2(fwd.y, -fwd.x)

	var shape := PackedVector2Array([
		b - fwd * BODY_LONG + up * BODY_TALL * 0.35,
		b - fwd * BODY_LONG * 0.55 + up * BODY_TALL,
		b + fwd * BODY_LONG * 0.35 + up * BODY_TALL * 0.9,
		b + fwd * BODY_LONG + up * BODY_TALL * 0.25,
		b + fwd * BODY_LONG * 0.9 - up * BODY_TALL * 0.55,
		b + fwd * BODY_LONG * 0.1 - up * BODY_TALL,
		b - fwd * BODY_LONG * 0.7 - up * BODY_TALL * 0.7,
	])
	draw_colored_polygon(shape, BODY_COLOR)

	# a folded wing, which is what stops the body reading as an egg on legs
	draw_colored_polygon(PackedVector2Array([
		b - fwd * BODY_LONG * 0.4 + up * BODY_TALL * 0.5,
		b + fwd * BODY_LONG * 0.35 + up * BODY_TALL * 0.35,
		b + fwd * BODY_LONG * 0.2 - up * BODY_TALL * 0.3,
		b - fwd * BODY_LONG * 0.5 - up * BODY_TALL * 0.15,
	]), WING_COLOR)
	draw_line(b - fwd * BODY_LONG * 0.45 + up * BODY_TALL * 0.45,
		b + fwd * BODY_LONG * 0.3 - up * BODY_TALL * 0.15, BODY_SHADE, 1.2, true)

	_draw_tail(b, fwd, up)

## Cocked up and back, the way a hen carries it. Built by adding the body's own
## "up" to its "backwards": subtracting it instead swept the whole fan down into
## a plank trailing along behind her.
func _draw_tail(b: Vector2, fwd: Vector2, up: Vector2) -> void:
	var root := b - fwd * BODY_LONG * 0.85 + up * BODY_TALL * 0.45
	var out := (-fwd + up * 1.25).normalized()
	for i in range(3):
		var spread := -0.34 + float(i) * 0.34
		var length := TAIL * (0.82 + (1.0 - absf(spread) * 2.4) * 0.22)
		draw_line(root, root + out.rotated(spread) * length,
			BODY_COLOR if i == 1 else BODY_SHADE, 3.0, true)

func _draw_neck_and_head(b: Vector2) -> void:
	# the neck leaves the body in the body's own frame, so it stays on the breast
	# as she tips rather than sliding off the front of her
	var fwd := Vector2.from_angle(body_pitch())
	var up := Vector2(fwd.y, -fwd.x)
	var breast := b + fwd * BODY_LONG * 0.5 + up * BODY_TALL * 0.35
	draw_line(breast, head_at, BODY_COLOR, LIMB_WIDTH * 2.4, true)
	draw_circle(head_at, HEAD_R, BODY_COLOR)

	# the whole head turns with the beak, so at the bottom of a strike she is
	# looking into the ground rather than straight ahead through it
	var hf := Vector2.from_angle(beak_angle)
	var hu := Vector2(hf.y, -hf.x)

	# comb along the crown and a wattle under the chin: with these it is a hen
	# and without them it is a pigeon
	for i in range(3):
		var at := head_at + hu * (HEAD_R + 0.6) + hf * (-2.0 + float(i) * 2.6)
		draw_circle(at, 2.0 - absf(1.0 - float(i)) * 0.4, COMB_COLOR)
	draw_circle(head_at + hf * HEAD_R * 0.55 - hu * HEAD_R * 0.75, 1.9, COMB_COLOR)

	draw_colored_polygon(PackedVector2Array([
		head_at + hf * HEAD_R * 0.75 + hu * 1.6,
		head_at + hf * (HEAD_R * 0.75 + BEAK) - hu * 0.4,
		head_at + hf * HEAD_R * 0.75 - hu * 2.2,
	]), BEAK_COLOR)
	draw_circle(head_at + hf * HEAD_R * 0.3 + hu * 1.2, 1.3, EYE_COLOR)

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, BODY_LONG * 0.85, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
