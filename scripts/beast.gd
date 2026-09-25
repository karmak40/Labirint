class_name Beast
extends Node2D
## A four-legged animal, drawn the same way the figure is and walking on the
## same machinery.
##
## This exists as a test of whether the gait code generalises. Everything that
## makes walking read -- the stance foot planted in the world, the Hermite swing
## with matched end slopes, the constant-length supporting limb, the two-bone IK
## -- comes from [Gait] unchanged. What differs is only the skeleton it is hung
## on: four legs instead of two, a phase offset per leg, and a body with two ends
## that ride their own feet instead of one hip riding both.
##
## That last part is what four legs actually buy you. The front pair and the hind
## pair rise and fall out of step with each other, so the back tilts and rolls
## without anything being written to make it do so.

const SPINE := 52.0            ## withers to croup
const FORE_UPPER := 20.0
const FORE_LOWER := 19.0
const HIND_UPPER := 23.0
const HIND_LOWER := 20.0
const BODY_DEPTH := 13.0       ## half-thickness of the barrel
const NECK := 26.0
const HEAD := 16.0             ## poll to muzzle
const HEAD_DEEP := 6.0         ## depth of the skull at the poll
const HEAD_THIN := 2.4         ## and at the nose, so it tapers to a muzzle
const EAR := 8.0
const TAIL := 21.0
const LIMB_WIDTH := 4.0
const JOINT_RADIUS := 2.2

# Two gaits, blended by speed, exactly as the figure blends walking into running.
const WALK_SPEED := 40.0
const TROT_SPEED := 130.0
const WALK_STRIDE := 44.0
const TROT_STRIDE := 74.0
const WALK_STANCE := 0.66      ## three feet down most of the time
const TROT_STANCE := 0.45      ## and down to two, on opposite corners
const WALK_LIFT := 6.0
const TROT_LIFT := 11.0

# The footfall pattern, and the only thing here that is really about having four
# legs. At a walk the hind foot of a side leads its own forefoot by a quarter of
# the cycle, which gives the four-beat sequence you can count out. Close that lag
# to half and the diagonal pairs land together instead: that is a trot.
const WALK_LAG := 0.25
const TROT_LAG := 0.50

const GAIT_EASE := 5.0
const RIDE_SMOOTH := 26.0
const TURN_EASE := 9.0
const MIN_TURN_SCALE := 0.06
const HEAD_EASE := 11.0
const HEAD_LEAD := 0.35        ## how much of the body's rise the head answers
const TAIL_EASE := 6.0
const TAIL_SWAY := 7.0
const BREATH_RATE := 1.6
const BREATH_RISE := 1.1

# Grazing. An animal that only walks and stands looks like it is waiting for
# something; one that puts its head down and comes back up looks like it lives
# there. Coming up is the part that matters -- that is when it checks on you.
const GRAZE_TIME := 3.4
const ALERT_TIME := 1.3
const GRAZE_EASE := 3.4
const GRAZE_SINK := 3.5        ## the shoulders drop a little as the neck goes down
const GRAZE_AHEAD := 12.0      ## how far in front of the forefeet it crops
const NIBBLE_RATE := 7.5
const NIBBLE := 2.2
const HEAD_CARRY_ANGLE := 0.16 ## nose a touch below level
const HEAD_GRAZE_ANGLE := 1.28 ## and straight down into the grass
const HEAD_ALERT_ANGLE := -0.22
const ALERT_LIFT := 7.0

# It paces a beat, stops to look about, and paces back. Enough to see the gait
# start and stop, which is where a walk usually falls apart.
@export var patrol := 190.0    ## how far it walks before turning round
@export var pace := 68.0       ## how fast it goes
const PAUSE := 1.6
const SPEED_EASE := 3.2

const NEAR_COLOR := Color(0.62, 0.49, 0.36)
const FAR_COLOR := Color(0.47, 0.37, 0.27)
const BELLY_COLOR := Color(0.72, 0.62, 0.48)
const EYE_COLOR := Color(0.16, 0.14, 0.12)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.2)

## Each leg is a phase offset and which end of the spine it hangs from.
enum Leg { HIND_NEAR, FORE_NEAR, HIND_FAR, FORE_FAR }

## Walk to the end of the patrol, put the head down for a while, look up and
## check, then turn round and walk back.
enum Mood { WALKING, GRAZING, ALERT }

var home := Vector2.ZERO
var heading := 1.0
var facing := 1.0
var speed := 0.0
var wanted := 0.0
var wait := 0.0

var phase := 0.0
var trot_blend := 0.0
var stride := WALK_STRIDE
var stance_fraction := WALK_STANCE
var foot_lift := WALK_LIFT
var lag := WALK_LAG

var fore_ride := 0.0
var hind_ride := 0.0
var head_at := Vector2.ZERO
var tail_angle := 0.0
var breath := 0.0
var started := false
var graze := 0.0
var alert := 0.0
var head_angle := HEAD_CARRY_ANGLE
var mood_time := 0.0
var mood := Mood.WALKING

func _ready() -> void:
	home = position
	fore_ride = FORE_UPPER + FORE_LOWER
	hind_ride = HIND_UPPER + HIND_LOWER

func fore_reach() -> float:
	return FORE_UPPER + FORE_LOWER

func hind_reach() -> float:
	return HIND_UPPER + HIND_LOWER

## The point in its own cycle each leg is at. Front and hind of the same side are
## separated by the lag; the two sides are always half a cycle apart.
func leg_phase(leg: int) -> float:
	return Gait.quadruped_leg(leg, phase, lag)

func foot_of(leg: int) -> Vector2:
	return Gait.foot_offset(leg_phase(leg), stride, stance_fraction, foot_lift, 1.0)

func _process(delta: float) -> void:
	_walk_about(delta)

	trot_blend = Gait.ease_to(trot_blend,
		clampf(inverse_lerp(WALK_SPEED, TROT_SPEED, absf(speed)), 0.0, 1.0), GAIT_EASE, delta)
	stride = lerpf(WALK_STRIDE, TROT_STRIDE, trot_blend)
	stance_fraction = lerpf(WALK_STANCE, TROT_STANCE, trot_blend)
	foot_lift = lerpf(WALK_LIFT, TROT_LIFT, trot_blend)
	lag = lerpf(WALK_LAG, TROT_LAG, trot_blend)

	if absf(speed) > 1.0:
		phase = fposmod(phase + absf(speed) * delta / stride, 1.0)
		facing = Gait.ease_to(facing, heading, TURN_EASE, delta)

	breath = sin(Time.get_ticks_msec() / 1000.0 * BREATH_RATE)

	# Each end of the animal rides its own pair of feet. Nothing couples them, so
	# the back pitches and rolls purely because the pairs are out of step.
	var fore_want := Gait.ride_height([foot_of(Leg.FORE_NEAR), foot_of(Leg.FORE_FAR)], fore_reach())
	var hind_want := Gait.ride_height([foot_of(Leg.HIND_NEAR), foot_of(Leg.HIND_FAR)], hind_reach())
	fore_ride = Gait.ease_to(fore_ride, fore_want, RIDE_SMOOTH, delta)
	hind_ride = Gait.ease_to(hind_ride, hind_want, RIDE_SMOOTH, delta)

	_update_head(delta)
	tail_angle = Gait.ease_to(tail_angle,
		-TAIL_SWAY * 0.017 * sin(phase * TAU) * (0.3 + trot_blend), TAIL_EASE, delta)

	queue_redraw()

## Paces out, crops for a while, looks up, and comes back. Speed is eased rather
## than switched, so the gait has to survive starting and stopping -- which is
## where a walk usually shows its seams.
func _walk_about(delta: float) -> void:
	mood_time += delta
	match mood:
		Mood.WALKING:
			wanted = pace * heading
			# only when it is still heading outwards: having turned round it is
			# still past the mark for a while, and testing the distance alone made
			# it stop and graze again on the very next frame, for ever
			var out := position.x - home.x
			if absf(out) > patrol and signf(out) == heading:
				_set_mood(Mood.GRAZING)
		Mood.GRAZING:
			wanted = 0.0
			if mood_time > GRAZE_TIME:
				_set_mood(Mood.ALERT)
		Mood.ALERT:
			wanted = 0.0
			if mood_time > ALERT_TIME:
				# it only turns round once it has looked up and had a look
				heading = -heading
				_set_mood(Mood.WALKING)

	speed = Gait.ease_to(speed, wanted, SPEED_EASE, delta)
	position.x += speed * delta

func _set_mood(next: Mood) -> void:
	mood = next
	mood_time = 0.0

func is_grazing() -> bool:
	return mood == Mood.GRAZING

func is_alert() -> bool:
	return mood == Mood.ALERT

func withers() -> Vector2:
	return Vector2(SPINE * 0.5, -fore_ride - breath * BREATH_RISE + GRAZE_SINK * graze)

func croup() -> Vector2:
	return Vector2(-SPINE * 0.5, -hind_ride)

## The head answers the front end's rise, but late and only partly -- an animal
## carries its head level over a body that is bobbing under it. Grazing drops the
## whole neck down and forward to the grass in front of the forefeet.
func _update_head(delta: float) -> void:
	graze = Gait.ease_to(graze, 1.0 if is_grazing() else 0.0, GRAZE_EASE, delta)
	alert = Gait.ease_to(alert, 1.0 if is_alert() else 0.0, GRAZE_EASE, delta)

	var w := withers()
	var neck_top := w + Vector2(NECK * 0.52, -NECK * 0.86)
	var carried := Vector2(neck_top.x, lerpf(-fore_reach() - NECK * 0.8, neck_top.y, HEAD_LEAD))
	carried.y -= ALERT_LIFT * alert

	var cropping := Vector2(w.x + GRAZE_AHEAD, -HEAD_DEEP)
	var want := carried.lerp(cropping, graze)

	# cropping is not one long hold: the muzzle works at the grass in short pulls
	if graze > 0.01:
		var t := mood_time * NIBBLE_RATE
		want += Vector2(sin(t) * NIBBLE, absf(sin(t * 0.5)) * -NIBBLE * 0.8) * graze

	var want_angle := lerpf(HEAD_CARRY_ANGLE, HEAD_ALERT_ANGLE, alert)
	want_angle = lerpf(want_angle, HEAD_GRAZE_ANGLE, graze)
	head_angle = Gait.ease_to(head_angle, want_angle, HEAD_EASE, delta)

	if started:
		head_at = head_at.lerp(want, 1.0 - exp(-HEAD_EASE * delta))
	else:
		head_at = want
		started = true

func _draw() -> void:
	_draw_shadow()
	var turn: float = signf(facing) * maxf(absf(facing), MIN_TURN_SCALE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(turn, 1.0))

	var w := withers()
	var c := croup()

	# far legs first, dimmed, exactly as the two-legged figure stacks its sides
	_leg(c, Leg.HIND_FAR, HIND_UPPER, HIND_LOWER, 1.0, FAR_COLOR)
	_leg(w, Leg.FORE_FAR, FORE_UPPER, FORE_LOWER, -1.0, FAR_COLOR)

	_draw_tail(c)
	_draw_barrel(w, c)
	_draw_neck_and_head(w)

	# and the hock folds forward while the carpus folds back: one sign, two very
	# different legs, which is the whole reason the IK takes it as a parameter
	_leg(c, Leg.HIND_NEAR, HIND_UPPER, HIND_LOWER, 1.0, NEAR_COLOR)
	_leg(w, Leg.FORE_NEAR, FORE_UPPER, FORE_LOWER, -1.0, NEAR_COLOR)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _leg(root: Vector2, leg: int, upper: float, lower: float, bend: float, color: Color) -> void:
	var foot := Vector2(root.x, 0.0) + foot_of(leg)
	var knee := Gait.joint(root, foot, upper, lower, bend)
	var toe := Gait.reached(root, foot, upper, lower)
	draw_line(root, knee, color, LIMB_WIDTH, true)
	draw_line(knee, toe, color, LIMB_WIDTH, true)
	draw_circle(toe, JOINT_RADIUS, color)

func _draw_barrel(w: Vector2, c: Vector2) -> void:
	var along := (w - c).normalized()
	var up := Vector2(along.y, -along.x)
	var body := PackedVector2Array([
		c + up * BODY_DEPTH * 0.8 - along * 5.0,
		w + up * BODY_DEPTH * 0.9 + along * 4.0,
		w - up * BODY_DEPTH * 0.7 + along * 3.0,
		c - up * BODY_DEPTH * 0.85 - along * 4.0,
	])
	draw_colored_polygon(body, NEAR_COLOR)
	draw_line(c - up * BODY_DEPTH * 0.6, w - up * BODY_DEPTH * 0.5, BELLY_COLOR, 3.0, true)

## The skull is built on its own angle rather than on the direction of the neck.
## Hung off the neck it swung about whenever the neck did, which is backwards:
## an animal points its head where it is looking and lets the neck get it there.
func _draw_neck_and_head(w: Vector2) -> void:
	var fwd := Vector2.from_angle(head_angle)
	var up := Vector2(fwd.y, -fwd.x)
	var poll := head_at - fwd * HEAD * 0.15

	draw_line(w, poll, NEAR_COLOR, LIMB_WIDTH * 2.0, true)

	var skull := PackedVector2Array([
		poll + up * HEAD_DEEP * 0.75,
		poll + fwd * HEAD * 0.55 + up * HEAD_DEEP * 0.62,
		poll + fwd * HEAD + up * HEAD_THIN,
		poll + fwd * HEAD - up * HEAD_THIN * 0.8,
		poll + fwd * HEAD * 0.45 - up * HEAD_DEEP * 0.72,
		poll - up * HEAD_DEEP * 0.8,
	])
	draw_colored_polygon(skull, NEAR_COLOR)

	# ear on the poll, pricked back and up: with a muzzle at one end and an ear at
	# the other, which way it is looking reads even at this size
	var ear_root := poll + up * HEAD_DEEP * 0.5
	draw_colored_polygon(PackedVector2Array([
		ear_root - fwd * 2.0,
		ear_root - fwd * EAR * 0.42 + up * EAR,
		ear_root + fwd * 2.4 + up * EAR * 0.5,
	]), NEAR_COLOR)

	draw_circle(poll + fwd * HEAD * 0.42 + up * HEAD_DEEP * 0.12, 1.5, EYE_COLOR)
	draw_circle(poll + fwd * (HEAD - 1.6) - up * HEAD_THIN * 0.2, 1.4, EYE_COLOR)

## Carried out and then dropping, not held up straight: a tail drawn as one stiff
## line reads as an aerial rather than as part of the animal.
func _draw_tail(c: Vector2) -> void:
	var at := c + Vector2(0.0, -3.0)
	var dir := Vector2(-1.0, -0.18).normalized().rotated(tail_angle)
	var mid := at + dir * TAIL * 0.5
	var tip := mid + dir.rotated(0.95 + tail_angle * 1.6) * TAIL * 0.5
	draw_line(at, mid, FAR_COLOR, 3.6, true)
	draw_line(mid, tip, FAR_COLOR, 2.6, true)
	draw_circle(tip, 1.6, FAR_COLOR)

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2(SPINE * 0.5 * signf(facing), 0.0), 15.0, SHADOW_COLOR)
	draw_circle(Vector2(-SPINE * 0.5 * signf(facing), 0.0), 16.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
