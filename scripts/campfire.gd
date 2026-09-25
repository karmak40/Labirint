class_name Campfire
extends Node2D
## A fire in a ring of stones, which burns down and can be fed.
##
## It is the other end of a chain that until now went nowhere: a tree is felled,
## the trunk breaks into beams, a beam is shouldered and carried -- and then set
## down, and that was that. Lay one within reach of this and it goes on the fire.
##
## Nothing here has a skeleton, so none of [Gait] applies. What does carry over is
## the discipline: the shape is a continuous function of time, and the flicker is
## *smooth* pseudo-randomness rather than a fresh random number every frame. Roll
## the dice per frame and a fire reads as television static; it is the continuity
## that makes it read as burning.

const TONGUES := 5
const BASE_WIDE := 15.0        ## how far the flames spread along the ground
const FLAME_TALL := 34.0       ## height of the tallest tongue at a full burn
const FLAME_WIDE := 7.0
const SWAY := 5.5              ## sideways travel at the tip; the base barely moves
const STEPS := 5               ## samples up each tongue; fewer reads as a triangle

const RING := 21.0             ## radius of the stone ring
const STONES := 7
const LOG_LONG := 17.0

const FUEL_MAX := 3.0          ## logs' worth it can hold
const BURN_RATE := 0.055       ## logs per second: one lasts about twenty seconds
const LOG_WORTH := 1.0
const EMBER_TIME := 18.0       ## how long it stays hot enough to catch a fresh log
const FEED_RANGE := 46.0
const CATCH_FLARE := 1.6       ## a log just thrown on burns hard for a moment

const SPARKS := 14
const SPARK_RISE := 34.0
const SPARK_LIFE := 1.5
const SMOKE := 5
const SMOKE_RISE := 26.0
const SMOKE_LIFE := 3.2

# Many faint rings rather than a few stronger ones: four had visible edges and
# read as a stack of discs. Squashed, too, because this is light lying on the
# ground around the fire, not a ball of it hanging in the air.
const GLOW_RINGS := 12
const GLOW_REACH := 96.0
const GLOW_FLAT := 0.5

const STONE := Color(0.45, 0.44, 0.45)
const STONE_LIT := Color(0.62, 0.53, 0.44)   ## the side facing the fire is warmed
const STONE_EDGE := Color(0.31, 0.30, 0.31)
const WOOD := Color(0.36, 0.27, 0.19)
const CHAR := Color(0.16, 0.14, 0.14)
const EMBER := Color(0.85, 0.34, 0.12)
const FLAME_LOW := Color(0.92, 0.35, 0.10)
const FLAME_MID := Color(0.97, 0.62, 0.15)
const FLAME_TIP := Color(1.0, 0.88, 0.45)
const SMOKE_COLOR := Color(0.55, 0.54, 0.55)
const GLOW := Color(1.0, 0.62, 0.25)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.16)

@export var lit := true
@export var fuel := 2.0

# Whether the wood is actually alight, kept apart from how much wood there is.
# Conflating the two made the blaze follow the fuel unconditionally, so a dead
# ring lit itself the instant anyone laid a log in it.
var going := false
var burn := 0.0                ## 0 when out, 1 at a full blaze -- what everything scales by
var flare := 0.0               ## the surge just after a log goes on
var ember_left := 0.0
var clock := 0.0
var sparks: Array = []
var smokes: Array = []

class Mote:
	var at := Vector2.ZERO
	var drift := Vector2.ZERO
	var life := 0.0
	var span := 1.0
	var size := 1.0

func _ready() -> void:
	add_to_group("fires")
	if lit and fuel > 0.0:
		going = true
		ember_left = EMBER_TIME
		burn = clampf(fuel, 0.0, 1.0)

func is_lit() -> bool:
	return burn > 0.02

## Hot enough that a log laid on it will catch.
func is_hot() -> bool:
	return is_lit() or ember_left > 0.0

func _process(delta: float) -> void:
	clock += delta
	_take_fuel()

	if going and fuel > 0.0:
		fuel = maxf(0.0, fuel - BURN_RATE * delta)
		ember_left = EMBER_TIME
	else:
		ember_left = maxf(0.0, ember_left - delta)
		if fuel <= 0.0:
			going = false

	# The blaze follows the fuel but lags well behind it, so the fire does not
	# snap out the instant the last log is spent -- it sinks.
	var want := clampf(fuel, 0.0, 1.0) if going else 0.0
	burn = Gait.ease_to(burn, want, 0.9, delta)
	flare = maxf(0.0, flare - delta * 1.4)

	_drift_motes(delta)
	if is_lit():
		_feed_motes(delta)
	queue_redraw()

## Put a flame to it. It needs something to burn: a ring of cold stones with no
## wood in it stays a ring of cold stones however long you hold a torch to it.
func light() -> bool:
	if going or fuel <= 0.0:
		return false
	going = true
	ember_left = EMBER_TIME
	burn = maxf(burn, 0.35)
	flare = CATCH_FLARE
	_burst()
	return true

## Anything flammable lying within reach goes on. Deliberately looking for a
## resting carriable rather than being handed one: the player sets a log down and
## the fire takes it, which needs no new verb on the player at all.
##
## Wood is taken whether or not the fire is alight -- laying logs in a dead ring
## is building a fire, and refusing it left a burnt-out fire that nothing could
## ever restart.
func _take_fuel() -> void:
	if fuel >= FUEL_MAX:
		return
	for node in get_tree().get_nodes_in_group("carriables"):
		var thing := node as Carriable
		if thing == null or not thing.is_free() or not (thing is Beam):
			continue
		# freeing is deferred to the end of the frame, so a log already taken is
		# still sitting in the group and would otherwise be burnt twice over
		if thing.is_queued_for_deletion():
			continue
		if global_position.distance_to(thing.global_position) > FEED_RANGE:
			continue
		fuel = minf(FUEL_MAX, fuel + LOG_WORTH)
		# a log dropped on a live fire catches; one stacked on a dead one waits
		if is_hot():
			flare = CATCH_FLARE
			burn = maxf(burn, 0.35)
			_burst()
		thing.queue_free()
		return

func _tongue_height(i: int) -> float:
	var full := Flame.tongue_height(FLAME_TALL, clock, float(i))
	var shape := 1.0 - absf(float(i) - float(TONGUES - 1) * 0.5) / float(TONGUES)
	return full * shape * (0.45 + 0.55 * burn) * (1.0 + flare * 0.35)

func _drift_motes(delta: float) -> void:
	for arr in [sparks, smokes]:
		var live: Array = []
		for m in arr:
			var mote: Mote = m
			mote.life += delta
			mote.at += mote.drift * delta
			mote.drift.x += sin(clock * 2.0 + mote.life * 3.0) * 6.0 * delta
			if mote.life < mote.span:
				live.append(mote)
		arr.assign(live)

func _feed_motes(delta: float) -> void:
	if sparks.size() < SPARKS and randf() < delta * 14.0 * burn:
		var m := Mote.new()
		m.at = Vector2(randf_range(-BASE_WIDE, BASE_WIDE) * 0.6, -6.0)
		m.drift = Vector2(randf_range(-9.0, 9.0), -SPARK_RISE * randf_range(0.7, 1.4))
		m.span = SPARK_LIFE * randf_range(0.6, 1.2)
		m.size = randf_range(0.9, 1.9)
		sparks.append(m)
	if smokes.size() < SMOKE and randf() < delta * 3.0:
		var m := Mote.new()
		m.at = Vector2(randf_range(-6.0, 6.0), -FLAME_TALL * 0.7 * burn)
		m.drift = Vector2(randf_range(-5.0, 5.0), -SMOKE_RISE * randf_range(0.7, 1.2))
		m.span = SMOKE_LIFE
		m.size = randf_range(3.0, 6.0)
		smokes.append(m)

func _burst() -> void:
	for i in range(18):
		var m := Mote.new()
		m.at = Vector2(randf_range(-BASE_WIDE, BASE_WIDE) * 0.7, -8.0)
		m.drift = Vector2(randf_range(-40.0, 40.0), randf_range(-110.0, -40.0))
		m.span = SPARK_LIFE * randf_range(0.5, 1.1)
		m.size = randf_range(1.0, 2.2)
		sparks.append(m)

func _draw() -> void:
	_draw_glow()
	_draw_shadow()
	_draw_logs()
	if is_lit():
		_draw_flames()
	elif ember_left > 0.0:
		_draw_embers()
	_draw_ring()
	_draw_motes()

func _draw_glow() -> void:
	if burn <= 0.02 and ember_left <= 0.0:
		return
	# breathes on its own slow wobble, a good deal slower than the flames, or the
	# whole clearing appears to pulse
	var pulse := 0.9 + 0.1 * Flame.wobble(clock * 0.5, 9.0)
	var reach := GLOW_REACH * (0.3 + 0.7 * burn) * pulse
	Flame.draw_glow(self, Vector2(0.0, -4.0), reach, 1.0, GLOW_RINGS, GLOW_FLAT)

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, RING * 1.05, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_logs() -> void:
	# three logs laid across one another, charred where the fire has been at them
	var lays := [-0.42, 0.0, 0.45]
	for i in lays.size():
		var a: float = lays[i]
		var dir := Vector2.from_angle(a * 0.8)
		var at := Vector2(0.0, -3.0 - float(i) * 1.6)
		var burnt: float = clampf(burn + 0.25, 0.0, 1.0)
		draw_line(at - dir * LOG_LONG, at + dir * LOG_LONG,
			WOOD.lerp(CHAR, burnt), 5.4, true)
		draw_line(at - dir * LOG_LONG * 0.35, at + dir * LOG_LONG * 0.35,
			CHAR.lerp(EMBER, burn * 0.6), 3.0, true)

func _draw_ring() -> void:
	for i in range(STONES):
		var a := TAU * float(i) / float(STONES) + 0.3
		var at := Vector2(cos(a) * RING, sin(a) * RING * 0.45 + 2.0)
		# only the stones this side of the fire are drawn over it
		var warm := clampf(1.0 - absf(at.x) / RING, 0.0, 1.0) * burn
		var r := 5.0 + 1.6 * sin(float(i) * 2.3)
		draw_circle(at, r, STONE.lerp(STONE_LIT, warm * 0.8))
		draw_arc(at, r, 0.0, TAU, 12, STONE_EDGE, 1.1, true)

## Each tongue is a tapering shape sampled up a swaying spine, rather than a
## triangle: the taper is what stops it reading as bunting.
func _draw_flames() -> void:
	for i in range(TONGUES):
		var root_x := lerpf(-BASE_WIDE, BASE_WIDE, float(i) / float(TONGUES - 1))
		root_x *= 0.5 + 0.5 * burn
		var tall := _tongue_height(i)
		if tall < 2.0:
			continue

		var wide := FLAME_WIDE * (0.6 + 0.4 * burn)
		var shape := Flame.tongue(Vector2(root_x, -4.0), Vector2.UP,
			tall, wide, SWAY, clock, float(i), STEPS)

		var heat := float(i) / float(TONGUES - 1)
		draw_colored_polygon(shape, Flame.LOW.lerp(Flame.MID, 0.35 + 0.4 * heat))

		# a brighter core, shorter and narrower than the tongue it sits in
		draw_colored_polygon(Flame.tongue(Vector2(root_x, -4.0), Vector2.UP,
			tall * 0.7, wide * 0.42, SWAY, clock, float(i), STEPS), Flame.TIP)

func _draw_embers() -> void:
	var glow := clampf(ember_left / EMBER_TIME, 0.0, 1.0)
	for i in range(6):
		var a := TAU * float(i) / 6.0 + clock * 0.2
		var at := Vector2(cos(a) * 7.0, sin(a) * 3.0 - 4.0)
		var beat := 0.55 + 0.45 * Flame.wobble(clock * 0.9, float(i))
		draw_circle(at, 2.6, Color(EMBER.r, EMBER.g, EMBER.b, glow * beat))

func _draw_motes() -> void:
	for m in smokes:
		var mote: Mote = m
		var t := mote.life / mote.span
		draw_circle(mote.at, mote.size * (1.0 + t * 1.8),
			Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.16 * (1.0 - t)))
	for m in sparks:
		var mote: Mote = m
		var t := mote.life / mote.span
		draw_circle(mote.at, mote.size * (1.0 - t * 0.5),
			Color(FLAME_TIP.r, FLAME_TIP.g, FLAME_TIP.b, 1.0 - t))
