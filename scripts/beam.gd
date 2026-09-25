class_name Beam
extends Carriable
## A heavy timber beam: too big for the hands, so it goes up onto a shoulder,
## and far too heavy to throw -- it can only be set down again.
##
## It will also burn, which is the cheapest thing in the world to do to it and
## the most wasteful: a log put to the torch goes to ash and leaves nothing.

const LENGTH := 96.0
const THICKNESS := 13.0
const WOOD_COLOR := Color(0.52, 0.39, 0.25)
const END_COLOR := Color(0.62, 0.48, 0.32)
const GRAIN_COLOR := Color(0.44, 0.33, 0.21)
const ASH_COLOR := Color(0.17, 0.15, 0.15)

const CATCH_TIME := 1.2        ## from the torch touching it to properly alight
const BURN_OUT := 16.0         ## and from alight to gone
const FIRE_TONGUES := 5
const FIRE_TALL := 34.0
const FIRE_WIDE := 8.0
const FIRE_SWAY := 8.0
const FIRE_GLOW := 62.0

var burn_time := -1.0
var alight := 0.0

## How much wood it is at a stockpile. The testbed's beam is one; a match's is
## worth more, since a tree there is the woodcutter's whole morning.
var amount := 1

func _ready() -> void:
	super()
	grip = Grip.ON_SHOULDER
	heavy = true
	shadow_radius = 26.0
	# dead weight: it thuds down rather than bouncing, and stops quickly
	bounce = 0.12
	drag = 420.0
	spin_drag = 9.0

## Put a torch to it. Nothing catches at once: for a moment it is only smoking,
## and it could still be left alone.
func ignite() -> void:
	if burn_time >= 0.0 or state != State.RESTING:
		return
	burn_time = 0.0

func is_burning() -> bool:
	return burn_time >= 0.0

## Nobody picks up a burning log. It is lying perfectly still and is still not
## something anyone is going to put on their shoulder -- which is why this is a
## separate question from whether it is at rest.
func can_be_taken() -> bool:
	return is_free() and not is_burning()

func _process(delta: float) -> void:
	super(delta)
	if burn_time < 0.0:
		return
	burn_time += delta
	alight = clampf(burn_time / CATCH_TIME, 0.0, 1.0)
	if burn_time > CATCH_TIME + BURN_OUT:
		queue_free()

## Timber comes to rest lying along the ground, never propped on end.
func _settle() -> void:
	tilt = 0.0 if absf(angle_difference(tilt, 0.0)) < PI * 0.5 else PI

func _draw() -> void:
	_draw_shadow()
	if alight > 0.01:
		Flame.draw_glow(self, Vector2(0.0, -height - 4.0), FIRE_GLOW * alight, alight, 10, 0.55)

	draw_set_transform(Vector2(0.0, -height), tilt, Vector2.ONE)

	var half := LENGTH * 0.5
	var edge := THICKNESS * 0.5

	var body := PackedVector2Array([
		Vector2(-half, -edge),
		Vector2(half, -edge),
		Vector2(half, edge),
		Vector2(-half, edge),
	])
	draw_colored_polygon(body, WOOD_COLOR.lerp(ASH_COLOR, alight * 0.8))

	# grain, and lighter end grain where it was sawn
	draw_line(Vector2(-half + 4.0, -edge * 0.35), Vector2(half - 4.0, -edge * 0.35), GRAIN_COLOR, 1.2, true)
	draw_line(Vector2(-half + 6.0, edge * 0.4), Vector2(half - 6.0, edge * 0.4), GRAIN_COLOR, 1.2, true)
	draw_line(Vector2(half - 2.0, -edge), Vector2(half - 2.0, edge), END_COLOR, 3.0, true)
	draw_line(Vector2(-half + 2.0, -edge), Vector2(-half + 2.0, edge), END_COLOR, 3.0, true)

	var rim := body.duplicate()
	rim.append(body[0])
	draw_polyline(rim, GRAIN_COLOR, 1.4, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Flames drawn outside the log's own rotated frame: fire goes up, and a log
	# lying at any angle would otherwise burn off sideways along its own length.
	if alight > 0.01:
		var along := Vector2.from_angle(tilt)
		for i in range(FIRE_TONGUES):
			var t := (float(i) / float(FIRE_TONGUES - 1) - 0.5) * LENGTH * 0.82
			var root := along * t + Vector2(0.0, -height)
			var tall := Flame.tongue_height(FIRE_TALL * alight, burn_time, float(i))
			draw_colored_polygon(Flame.tongue(root, Vector2.UP, tall, FIRE_WIDE,
				FIRE_SWAY, burn_time, float(i)), Flame.LOW.lerp(Flame.MID, 0.45))
			draw_colored_polygon(Flame.tongue(root, Vector2.UP, tall * 0.55,
				FIRE_WIDE * 0.34, FIRE_SWAY, burn_time, float(i)), Flame.MID.lerp(Flame.TIP, 0.7))
