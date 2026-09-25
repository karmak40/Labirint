class_name OreVein
extends Node2D
## An outcrop of stone with ore in it, worked with a pick.
##
## The same middle-of-the-chain job the tree does for the axe: the mining stroke
## already stoops and throws chips, and a rock already gets picked up, carried
## and thrown. This is what turns one into the other.
##
## Where a tree goes over in one event, a vein wears away -- so it shrinks and
## pits as it is worked, and gives up its ore a piece at a time rather than all
## at the end. That difference is the whole point of having both: one is a
## commitment, the other is a grind you can walk away from part-way through.

const HEIGHT := 58.0
const WIDTH := 34.0            ## half-width at the base
const SPENT_SCALE := 0.42      ## how much is left once the ore is out

const POCKETS := 3             ## rocks in it
const HITS_PER_POCKET := 3

# Stone does not ring the way a trunk does: it takes the blow and stops. So this
# is a hard knock that dies away, with no oscillation through neutral at all.
const JOLT := 3.4
const JOLT_DECAY := 14.0
const SINK := 2.2              ## and it settles down into the ground under the blow

# Sized against the rock's own drag, not picked by eye: at 210 px/s^2 a toss of
# 50 px/s dies after four pixels, which drops the ore back inside the outcrop.
const ROCK_TOSS := 165.0       ## ore comes loose towards whoever knocked it out
const ROCK_LIFT := 130.0

const STONE := Color(0.42, 0.42, 0.44)
const STONE_LIT := Color(0.53, 0.53, 0.55)
const STONE_EDGE := Color(0.29, 0.29, 0.31)
const ORE := Color(0.76, 0.66, 0.36)       ## the metal still in the rock
const ORE_EDGE := Color(0.88, 0.79, 0.48)
const GOLD := Color(0.98, 0.80, 0.18)      ## a gold seam: brighter and warmer than ore
const GOLD_EDGE := Color(1.0, 0.94, 0.58)
const SCAR := Color(0.58, 0.57, 0.56)      ## freshly broken stone, paler than weathered
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.18)

## Deliberately lumpy: a smooth mound reads as a pile of sand rather than rock.
const OUTLINE := [
	Vector2(-1.0, 0.0),
	Vector2(-0.93, -0.34),
	Vector2(-0.62, -0.51),
	Vector2(-0.68, -0.76),
	Vector2(-0.34, -0.95),
	Vector2(0.02, -1.0),
	Vector2(0.38, -0.88),
	Vector2(0.45, -0.62),
	Vector2(0.78, -0.55),
	Vector2(1.0, -0.22),
	Vector2(0.94, 0.0),
]

## Where the ore sits in the face, in the same normalised frame as the outline.
const POCKET_SPOTS := [
	Vector2(-0.42, -0.58),
	Vector2(0.30, -0.72),
	Vector2(0.12, -0.28),
]

## What comes out of it: "ore", or "gold" for a richer seam. Worked exactly the
## same way; only what the stockpile banks it as differs.
@export var resource_kind := "ore"
## How many rocks come out of it, and what each is worth at a stockpile. The
## defaults are the testbed's small outcrop: three rocks of one. A match's seam
## is far richer -- twenty rocks of ten is two hundred ore -- worked the same way.
@export var rocks := POCKETS
@export var rock_worth := 1
## Seconds from worked out to full again; 0 leaves a spent stub for good.
@export var refill_time := 0.0

var hits := 0
var taken := 0                 ## pockets knocked out so far
var jolt := 0.0
var jolt_time := 0.0
var scars: Array[Vector2] = [] ## where the pick has bitten, in the same frame
var spent_time := 0.0          ## how long it has been worked out
var blocker: StaticBody2D

func _ready() -> void:
	add_to_group("veins")
	blocker = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = WIDTH * 0.7
	shape.shape = circle
	blocker.add_child(shape)
	add_child(blocker)

func has_ore() -> bool:
	return taken < rocks

## How far through it is, which is what drives the shrinking silhouette.
func wear() -> float:
	return clampf(float(hits) / float(rocks * HITS_PER_POCKET), 0.0, 1.0)

## What is left of it, and so how much it holds still, from 0 to 1.
func richness() -> float:
	return 1.0 - float(taken) / float(maxi(rocks, 1))

## How many of the three drawn pockets are still showing, for however many
## rocks it really holds.
func _pockets_showing() -> int:
	return ceili(float(POCKETS) * richness()) if has_ore() else 0

func scale_now() -> float:
	return lerpf(1.0, SPENT_SCALE, wear())

## One stroke of the pick landed. Every third one frees a rock, so the work pays
## out along the way instead of only at the end.
func take_strike(from: Vector2) -> void:
	if not has_ore():
		return

	hits += 1
	jolt = JOLT
	jolt_time = 0.0

	# a fresh bite mark, near whichever pocket is being worked on
	var spot: Vector2 = POCKET_SPOTS[clampi(POCKETS - _pockets_showing(), 0, POCKET_SPOTS.size() - 1)]
	scars.append(spot + Vector2(randf_range(-0.14, 0.14), randf_range(-0.14, 0.14)))
	# a rich seam takes sixty blows; the face only has room to show the latest
	if scars.size() > 18:
		scars.pop_front()

	if hits % HITS_PER_POCKET == 0:
		_free_rock(from)

func _free_rock(from: Vector2) -> void:
	taken += 1
	var parent := get_parent()
	if parent == null:
		return

	# it comes loose towards the miner, which is the way it was being struck
	var away := signf(global_position.x - from.x)
	if absf(global_position.x - from.x) < 1.0:
		away = 1.0

	var ore := Rock.new()
	ore.position = position
	ore.resource_kind = resource_kind
	ore.amount = rock_worth
	parent.add_child(ore)
	ore.launch(
		ore.global_position, HEIGHT * scale_now() * 0.6,
		Vector2(-away * randf_range(ROCK_TOSS * 0.55, ROCK_TOSS), randf_range(-34.0, 34.0)),
		ROCK_LIFT, randf_range(-5.0, 5.0))

	if not has_ore():
		# worked out: what is left is a low stub, still in the way
		var shape := blocker.get_child(0) as CollisionShape2D
		(shape.shape as CircleShape2D).radius = WIDTH * 0.7 * SPENT_SCALE

func _process(delta: float) -> void:
	if refill_time > 0.0 and not has_ore():
		spent_time += delta
		if spent_time >= refill_time:
			_refill()
	if jolt > 0.001:
		jolt_time += delta
		jolt = JOLT * exp(-JOLT_DECAY * jolt_time)
	queue_redraw()

## The seam has come back: full size, unmarked, every pocket in it again.
func _refill() -> void:
	hits = 0
	taken = 0
	spent_time = 0.0
	scars.clear()
	var shape := blocker.get_child(0) as CollisionShape2D
	(shape.shape as CircleShape2D).radius = WIDTH * 0.7

func _draw() -> void:
	var s := scale_now()
	# the blow drives it down into the ground rather than rocking it about
	var press := jolt * SINK / JOLT

	_draw_shadow(s)
	draw_set_transform(Vector2(0.0, press), 0.0, Vector2.ONE)
	_draw_body(s)
	_draw_scars(s)
	_draw_ore(s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shadow(s: float) -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, WIDTH * s * 1.05, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _at(point: Vector2, s: float) -> Vector2:
	return Vector2(point.x * WIDTH * s, point.y * HEIGHT * s)

func _draw_body(s: float) -> void:
	var face := PackedVector2Array()
	for point in OUTLINE:
		face.append(_at(point, s))
	draw_colored_polygon(face, STONE)

	var rim := face.duplicate()
	rim.append(face[0])
	draw_polyline(rim, STONE_EDGE, 1.7, true)

	# a lit facet, so the outcrop has a shape rather than being a flat blot
	draw_colored_polygon(PackedVector2Array([
		_at(Vector2(-0.34, -0.95), s),
		_at(Vector2(0.02, -1.0), s),
		_at(Vector2(0.38, -0.88), s),
		_at(Vector2(0.05, -0.6), s),
		_at(Vector2(-0.3, -0.64), s),
	]), STONE_LIT)

func _draw_scars(s: float) -> void:
	# each bite leaves a pale pit; they build up where the work has been done
	for scar in scars:
		draw_circle(_at(scar, s), 3.4 * s, SCAR)

func _draw_ore(s: float) -> void:
	# only the pockets still in the rock are drawn, so what is left to get is
	# visible at a glance and the outcrop reads as emptied once they are gone
	for i in range(POCKETS - _pockets_showing(), POCKETS):
		var spot: Vector2 = POCKET_SPOTS[i]
		var here := _at(spot, s)
		var metal := GOLD if resource_kind == "gold" else ORE
		var glint := GOLD_EDGE if resource_kind == "gold" else ORE_EDGE
		draw_circle(here, 5.0 * s, metal)
		draw_circle(here + Vector2(4.5, 2.6) * s, 3.0 * s, metal)
		draw_circle(here + Vector2(-3.4, 3.2) * s, 2.4 * s, glint)
