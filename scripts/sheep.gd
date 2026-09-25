class_name Sheep
extends Node2D
## A ewe, on the same [Gait] core as everything else that walks.
##
## Deliberately not a recoloured deer. A sheep is built differently -- short legs
## under a deep barrel, so it trundles where the deer springs -- and, more to the
## point, it behaves differently: it feeds *while walking*. The deer stops, crops,
## looks up and moves on; the sheep drifts along with its head down and only
## occasionally straightens up to check on the world.
##
## That makes this the first body here where the walking layer and the feeding
## layer run at once, rather than one replacing the other.

const SPINE := 40.0            ## withers to croup: short-coupled
const FORE_UPPER := 13.0
const FORE_LOWER := 13.0
const HIND_UPPER := 14.0
const HIND_LOWER := 13.0
const BODY_DEPTH := 16.0       ## half-thickness of the barrel, which is deep
const NECK := 13.0
const HEAD := 12.0
const HEAD_DEEP := 6.3
const EAR := 7.0
const TAIL := 9.0
const LIMB_WIDTH := 3.4
const JOINT_RADIUS := 1.9

# Short quick steps that barely leave the ground, and a high stance fraction:
# three feet down most of the time. Next to the deer's numbers this is what makes
# the difference between trundling and springing.
const WALK_SPEED := 22.0
const RUN_SPEED := 95.0
const WALK_STRIDE := 25.0
const RUN_STRIDE := 42.0
const WALK_STANCE := 0.72
const RUN_STANCE := 0.52
const WALK_LIFT := 3.2
const RUN_LIFT := 6.5
const WALK_LAG := 0.25
const RUN_LAG := 0.50

const GAIT_EASE := 5.0
const RIDE_SMOOTH := 26.0
const TURN_EASE := 9.0
const MIN_TURN_SCALE := 0.06
const HEAD_EASE := 10.0
const BREATH_RATE := 1.4
const BREATH_RISE := 0.8

# Feeding. The bob is small and the head never comes far off the grass: a sheep
# at work is a woolly back with a face somewhere underneath the front of it.
const GRAZE_PACE := 11.0       ## the shuffle it keeps up while cropping
const CROP_PERIOD := 1.5
const CROP_BOB := 5.0
const GRAZE_EASE := 3.0
# The front end folds down to feed. This is what actually gets the mouth to the
# grass -- a sheep reaches the ground by lowering its shoulders, not by paying
# out neck it does not have.
const GRAZE_SINK := 7.5
const NECK_CROP := 0.92        ## angle of the neck while cropping: down and forward
const NECK_LOOK := -0.95       ## and up and forward when the head comes up
const NECK_BOB := 0.10         ## the crop is a small swing of the neck, not a stretch
const LOOK_EVERY := 7.0        ## roughly how long between one look up and the next
const LOOK_TIME := 1.8
const HEAD_CARRY := 0.50       ## even carried, a sheep's nose is well down
const HEAD_CROP := 1.02        ## 58 deg, not 74: steeper puts the crown of the
                               ## head in front of the muzzle, where the wool on
                               ## it reads as a blob stuck to her nose
const HEAD_LOOK := -0.05

@export var patrol := 150.0
@export var pace := 30.0       ## the pace it makes when it bothers to go anywhere
const SPEED_EASE := 2.6

const FLEECE := Color(0.88, 0.86, 0.80)
const FLEECE_FAR := Color(0.70, 0.68, 0.63)
const FLEECE_EDGE := Color(0.76, 0.74, 0.68)
const FACE := Color(0.34, 0.32, 0.31)
const FACE_FAR := Color(0.25, 0.24, 0.23)
const EYE := Color(0.10, 0.09, 0.09)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.2)

enum Leg { HIND_NEAR, FORE_NEAR, HIND_FAR, FORE_FAR }
enum Mood { GRAZING, LOOKING }

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
var lag := WALK_LAG

var fore_ride := 0.0
var hind_ride := 0.0
var head_at := Vector2.ZERO
var head_angle := HEAD_CARRY
var neck_angle := NECK_CROP
var breath := 0.0
var started := false

var mood := Mood.GRAZING
var mood_time := 0.0
var look := 0.0
var next_look := LOOK_EVERY

func _ready() -> void:
	home = position
	fore_ride = fore_reach()
	hind_ride = hind_reach()
	# staggered, so a flock does not lift its heads in unison
	next_look = LOOK_EVERY * randf_range(0.5, 1.5)
	phase = randf()

func fore_reach() -> float:
	return FORE_UPPER + FORE_LOWER

func hind_reach() -> float:
	return HIND_UPPER + HIND_LOWER

func leg_phase(leg: int) -> float:
	return Gait.quadruped_leg(leg, phase, lag)

func foot_of(leg: int) -> Vector2:
	return Gait.foot_offset(leg_phase(leg), stride, stance_fraction, foot_lift, 1.0)

func is_looking() -> bool:
	return mood == Mood.LOOKING

func _process(delta: float) -> void:
	_drift(delta)

	run_blend = Gait.ease_to(run_blend,
		clampf(inverse_lerp(WALK_SPEED, RUN_SPEED, absf(speed)), 0.0, 1.0), GAIT_EASE, delta)
	stride = lerpf(WALK_STRIDE, RUN_STRIDE, run_blend)
	stance_fraction = lerpf(WALK_STANCE, RUN_STANCE, run_blend)
	foot_lift = lerpf(WALK_LIFT, RUN_LIFT, run_blend)
	lag = lerpf(WALK_LAG, RUN_LAG, run_blend)

	if absf(speed) > 0.6:
		phase = fposmod(phase + absf(speed) * delta / stride, 1.0)
		facing = Gait.ease_to(facing, heading, TURN_EASE, delta)

	look = Gait.ease_to(look, 1.0 if is_looking() else 0.0, GRAZE_EASE, delta)
	breath = sin(Time.get_ticks_msec() / 1000.0 * BREATH_RATE)

	var fore_want := Gait.ride_height([foot_of(Leg.FORE_NEAR), foot_of(Leg.FORE_FAR)], fore_reach())
	var hind_want := Gait.ride_height([foot_of(Leg.HIND_NEAR), foot_of(Leg.HIND_FAR)], hind_reach())
	fore_want -= GRAZE_SINK * (1.0 - look)
	fore_ride = Gait.ease_to(fore_ride, fore_want, RIDE_SMOOTH, delta)
	hind_ride = Gait.ease_to(hind_ride, hind_want, RIDE_SMOOTH, delta)

	_update_head(delta)
	queue_redraw()

## Grazing is the default state, not an interruption of walking. It only stops to
## look up, and the only reason it ever hurries is to get back inside its ground.
func _drift(delta: float) -> void:
	mood_time += delta
	match mood:
		Mood.GRAZING:
			wanted = GRAZE_PACE * heading
			var out := position.x - home.x
			if absf(out) > patrol:
				# too far out: it walks properly back rather than cropping its way
				if signf(out) == heading:
					heading = -heading
				wanted = pace * heading
			if mood_time > next_look:
				mood = Mood.LOOKING
				mood_time = 0.0
		Mood.LOOKING:
			wanted = 0.0
			if mood_time > LOOK_TIME:
				mood = Mood.GRAZING
				mood_time = 0.0
				next_look = LOOK_EVERY * randf_range(0.6, 1.4)

	speed = Gait.ease_to(speed, wanted, SPEED_EASE, delta)
	position.x += speed * delta

func withers() -> Vector2:
	return Vector2(SPINE * 0.5, -fore_ride - breath * BREATH_RISE)

func croup() -> Vector2:
	return Vector2(-SPINE * 0.5, -hind_ride)

## Down in the grass by default, up only when it looks. The crop is a small slow
## bob rather than a strike -- a sheep works at the sward, it does not stab at it.
func _update_head(delta: float) -> void:
	var w := withers()

	# The smoothing is done on the neck's angle, and the head is then placed at
	# exactly one neck's length along it. Smoothing the head's position instead
	# let it cut the corner between poses -- the neck lost a third of its length
	# every time she raised or lowered her head, which is a neck folding up, not
	# a neck swinging.
	var bob := sin(mood_time / CROP_PERIOD * TAU) * NECK_BOB
	var want_neck := lerpf(NECK_CROP + bob, NECK_LOOK, look)
	var want_head := lerpf(HEAD_CROP, HEAD_LOOK, look)

	if not started:
		neck_angle = want_neck
		head_angle = want_head
		started = true
	neck_angle = Gait.ease_to(neck_angle, want_neck, HEAD_EASE, delta)
	head_angle = Gait.ease_to(head_angle, want_head, HEAD_EASE, delta)
	head_at = w + Vector2.from_angle(neck_angle) * NECK

func _draw() -> void:
	_draw_shadow()
	var turn: float = signf(facing) * maxf(absf(facing), MIN_TURN_SCALE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(turn, 1.0))

	var w := withers()
	var c := croup()

	_leg(c, Leg.HIND_FAR, HIND_UPPER, HIND_LOWER, 1.0, FACE_FAR)
	_leg(w, Leg.FORE_FAR, FORE_UPPER, FORE_LOWER, -1.0, FACE_FAR)

	_draw_fleece(w, c)
	_draw_neck_and_head(w)

	_leg(c, Leg.HIND_NEAR, HIND_UPPER, HIND_LOWER, 1.0, FACE)
	_leg(w, Leg.FORE_NEAR, FORE_UPPER, FORE_LOWER, -1.0, FACE)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _leg(root: Vector2, leg: int, upper: float, lower: float, bend: float, color: Color) -> void:
	var foot := Vector2(root.x, 0.0) + foot_of(leg)
	var knee := Gait.joint(root, foot, upper, lower, bend)
	var toe := Gait.reached(root, foot, upper, lower)
	draw_line(root, knee, color, LIMB_WIDTH, true)
	draw_line(knee, toe, color, LIMB_WIDTH, true)
	draw_circle(toe, JOINT_RADIUS, color)

## The fleece is a run of overlapping lumps along the back rather than one smooth
## barrel. That bumpy outline is the whole reason it reads as a sheep and not as
## a small pale deer.
func _draw_fleece(w: Vector2, c: Vector2) -> void:
	var along := (w - c)
	var dir := along.normalized()
	var up := Vector2(dir.y, -dir.x)

	# The bulk sits low, with its top edge under where the lumps will be: put it
	# any higher and it draws a flat line across them and the scalloping is lost.
	draw_colored_polygon(PackedVector2Array([
		c + up * BODY_DEPTH * 0.45 - dir * 4.0,
		w + up * BODY_DEPTH * 0.5 + dir * 3.0,
		w - up * BODY_DEPTH * 0.8 + dir * 2.0,
		c - up * BODY_DEPTH * 0.75 - dir * 3.0,
	]), FLEECE)

	# Few and large, so they scallop the outline. Small and many they simply merge
	# back into one smooth blob, and a second ring of smaller ones underneath
	# peeks out as a row of crescents stamped on the side.
	var lumps := 4
	for i in range(lumps + 1):
		var t := float(i) / float(lumps)
		var at := c.lerp(w, t) - dir * 2.0
		var r: float = BODY_DEPTH * (0.50 + 0.10 * sin(t * PI))
		draw_circle(at + up * BODY_DEPTH * 0.42, r, FLEECE)

	# a shade along the underside, which is the only place a flat tone reads as
	# shadow rather than as another lump
	draw_line(c - up * BODY_DEPTH * 0.62, w - up * BODY_DEPTH * 0.66, FLEECE_EDGE, 3.4, true)

	# the rump, and a stubby tail hanging off it
	draw_circle(c + up * BODY_DEPTH * 0.2, BODY_DEPTH * 0.72, FLEECE)
	draw_line(c - dir * BODY_DEPTH * 0.7 + up * BODY_DEPTH * 0.3,
		c - dir * BODY_DEPTH * 0.7 + up * BODY_DEPTH * 0.3 + Vector2(-2.0, TAIL),
		FLEECE_FAR, 4.0, true)

func _draw_neck_and_head(w: Vector2) -> void:
	# the neck comes out of the fleece dark and short: face and legs are the only
	# parts of a ewe that are not wool
	draw_line(w + Vector2(2.0, 2.0), head_at, FACE, LIMB_WIDTH * 2.1, true)

	var fwd := Vector2.from_angle(head_angle)
	var up := Vector2(fwd.y, -fwd.x)
	var poll := head_at - fwd * HEAD * 0.2

	draw_colored_polygon(PackedVector2Array([
		poll + up * HEAD_DEEP * 0.9,
		poll + fwd * HEAD * 0.5 + up * HEAD_DEEP * 0.62,
		poll + fwd * HEAD + up * HEAD_DEEP * 0.22,
		poll + fwd * HEAD - up * HEAD_DEEP * 0.42,
		poll + fwd * HEAD * 0.4 - up * HEAD_DEEP * 0.8,
		poll - up * HEAD_DEEP * 0.85,
	]), FACE)

	# ears out sideways and down, not pricked: a deer listens, a sheep does not
	var ear_root := poll + up * HEAD_DEEP * 0.45
	draw_line(ear_root, ear_root - fwd * EAR * 0.75 - up * EAR * 0.45, FACE, 3.0, true)
	draw_line(ear_root, ear_root - fwd * EAR * 0.45 + up * EAR * 0.2, FACE_FAR, 2.6, true)

	# a curl of fleece over the forehead -- kept close in, since at any real angle
	# the crown of the head swings out ahead of the face
	draw_circle(poll + up * HEAD_DEEP * 0.55, HEAD_DEEP * 0.48, FLEECE)
	draw_circle(poll - fwd * 3.0 + up * HEAD_DEEP * 0.6, HEAD_DEEP * 0.4, FLEECE)

	draw_circle(poll + fwd * HEAD * 0.45 + up * HEAD_DEEP * 0.05, 1.3, EYE)

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2(SPINE * 0.35 * signf(facing), 0.0), 15.0, SHADOW_COLOR)
	draw_circle(Vector2(-SPINE * 0.35 * signf(facing), 0.0), 15.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
