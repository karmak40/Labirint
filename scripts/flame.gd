class_name Flame
## Fire, shared by everything here that burns.
##
## Came out of the campfire, where it was tangled up with fuel and stone rings.
## Nothing in here knows what is alight -- a fire on the ground, a torch in a
## hand, a tree going up -- it is all arithmetic over a clock and a height.
##
## The one thing that matters and is easy to get wrong: the flicker must be a
## *continuous* function of time. Roll a fresh random number each frame and fire
## reads as television static; it is the continuity that makes it read as
## burning. Everything below is built from summed sines for that reason.
##
## Everything is static: there is no state to share and nothing to instance.

const LOW := Color(0.92, 0.35, 0.10)
const MID := Color(0.97, 0.62, 0.15)
const TIP := Color(1.0, 0.88, 0.45)
const GLOW := Color(1.0, 0.62, 0.25)
const SMOKE := Color(0.55, 0.54, 0.55)
const EMBER := Color(0.85, 0.34, 0.12)
const RING_STEPS := 24

## Smooth pseudo-random in [0,1]. The three frequencies do not divide into one
## another, so the pattern never visibly repeats -- and it never jumps.
static func wobble(t: float, seed_i: float) -> float:
	var a := sin(t * 2.3 + seed_i * 1.7)
	var b := sin(t * 3.7 + seed_i * 4.1)
	var c := sin(t * 5.9 + seed_i * 2.9)
	return 0.5 + (a * 0.5 + b * 0.32 + c * 0.18) * 0.5

## The outline of one tongue of flame, as a closed polygon.
##
## `up` is which way this fire rises, and it is worth passing rather than
## assuming: a torch may be held at any angle but its flame still goes straight
## up. The sway grows with height because a flame is anchored at its base.
static func tongue(root: Vector2, up: Vector2, height: float, width: float,
		sway: float, t: float, seed_i: float, steps: int = 8) -> PackedVector2Array:
	var side := Vector2(-up.y, up.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()

	for s in range(steps + 1):
		var u := float(s) / float(steps)
		var lean := (wobble(t * 2.1 + u * 1.5, seed_i * 3.0) - 0.5) * sway * 2.0 * u * u
		# The taper is late, not linear: a width that falls off in a straight line
		# from base to tip draws exactly a triangle, and at this size it reads as
		# bunting. Holding the body full and pinching only near the top is what
		# makes it a tongue.
		var wide := width * pow(1.0 - u, 0.62) * (0.62 + 0.38 * sin(PI * minf(u * 3.2, 1.0)))
		var spine := root + up * height * u + side * lean
		left.append(spine - side * wide)
		right.append(spine + side * wide)

	var shape := left.duplicate()
	for s in range(right.size()):
		shape.append(right[right.size() - 1 - s])
	return shape

## How tall a tongue stands this instant, before anything scales it.
static func tongue_height(tall: float, t: float, seed_i: float) -> float:
	return tall * (0.55 + 0.45 * wobble(t * 1.35, seed_i))

## Warm light pooled on the ground. Many faint rings rather than a few strong
## ones: too few and the edges show, and it reads as a stack of discs.
##
## Drawn as flattened polygons rather than by setting a transform. That matters:
## draw_set_transform replaces whatever the caller had set rather than combining
## with it, and it cannot be read back to restore. Used inside a figure that is
## mirrored by its transform, it wiped the mirror -- so a torch carried to the
## left had its flames drawn unmirrored, floating off the stick.
static func draw_glow(on: CanvasItem, at: Vector2, reach: float,
		strength: float, rings: int = 12, flatten: float = 0.5) -> void:
	if reach <= 0.5 or strength <= 0.01:
		return
	for i in range(rings):
		var t := float(i) / float(rings - 1)
		var r := reach * (1.0 - t * 0.86)
		var ring := PackedVector2Array()
		for step in range(RING_STEPS):
			var a := TAU * float(step) / float(RING_STEPS)
			ring.append(at + Vector2(cos(a) * r, sin(a) * r * flatten))
		on.draw_colored_polygon(ring,
			Color(GLOW.r, GLOW.g, GLOW.b, (0.016 + 0.016 * t) * strength))
