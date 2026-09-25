class_name TargetDummy
extends Node2D
## A straw training dummy on a post -- something with a front and a back.
##
## It exists so that creeping up on things means something. A backstab needs a
## back, and until there are units to have one, this is the smallest thing that
## can. What it exposes -- which way it looks, whether a given spot is behind it,
## and the two ways it can be struck -- is the interface an actual unit will
## implement later, so the verb does not have to be rewritten when one arrives.

const POST_HEIGHT := 78.0
const ARMS_AT := 52.0         ## how far up the crossbar sits
const ARM_SPAN := 21.0        ## half the crossbar
const BODY_TOP := 62.0
const BODY_BOTTOM := 26.0
const BODY_WIDTH := 13.0      ## half-width of the straw bundle
const HEAD_AT := 70.0
const HEAD_RADIUS := 9.0

# Mounted on a springy post, so unlike stone it does rock back and forth.
const ROCK := 0.30
const ROCK_DECAY := 4.5
const ROCK_FREQ := 15.0

const BUNDLE := 80.0          ## how much punishment the straw will take
const FALL_TIME := 0.55
const FALL_ANGLE := PI * 0.5
const FALL_EXPONENT := 1.8

const POST := Color(0.44, 0.34, 0.23)
const POST_EDGE := Color(0.33, 0.25, 0.17)
const STRAW := Color(0.72, 0.62, 0.36)
const STRAW_EDGE := Color(0.56, 0.47, 0.26)
const SACK := Color(0.74, 0.67, 0.5)
const SACK_EDGE := Color(0.56, 0.5, 0.37)
const MARK := Color(0.28, 0.24, 0.2)       ## the painted face, so the front is obvious
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.18)

enum State { UP, FALLING, DOWN }

## Which way it looks. Set this in the scene to turn the dummy round.
@export var facing_x := -1.0

var state := State.UP
var damage := 0.0
var rock := 0.0
var rock_time := 0.0
var fall_time := 0.0
var fall_dir := 1.0
var tilt := 0.0
var blocker: StaticBody2D

func _ready() -> void:
	add_to_group("targets")
	blocker = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	blocker.add_child(shape)
	add_child(blocker)

func is_alive() -> bool:
	return state == State.UP

## True when `from` is on the blind side. This is the whole rule the sneak
## depends on, so it lives on the target rather than in the striker: a unit gets
## to decide for itself what counts as behind it.
func exposed_back_to(from: Vector2) -> bool:
	if not is_alive():
		return false
	# behind means on the side away from where it is looking, so the product of
	# the offset and the facing is negative -- not positive, which is the side it
	# can see
	return (from.x - global_position.x) * facing_x < 0.0

## An ordinary blow. It takes what it is given, so a greatsword puts it over in
## three where a dagger needs seven -- the same numbers that apply to a man.
func take_hit(from: Vector2, harm: float = 20.0) -> void:
	if not is_alive():
		return
	damage += harm
	rock = ROCK
	rock_time = 0.0
	fall_dir = _push_from(from)
	if damage >= BUNDLE:
		_go_over()

## And the one from behind, which finishes it whatever its state. That is the
## point of the sneak: the same dagger that needs four blows from the front
## needs one from the back.
func take_backstab(from: Vector2) -> void:
	if not is_alive():
		return
	damage = BUNDLE
	fall_dir = _push_from(from)
	_go_over()

func _push_from(from: Vector2) -> float:
	var d := global_position.x - from.x
	return signf(d) if absf(d) > 1.0 else 1.0

func _go_over() -> void:
	state = State.FALLING
	fall_time = 0.0
	var shape := blocker.get_child(0) as CollisionShape2D
	(shape.shape as CircleShape2D).radius = 6.0

## Puts it back on its post, so the move can be tried again.
func reset() -> void:
	state = State.UP
	damage = 0.0
	tilt = 0.0
	rock = 0.0
	fall_time = 0.0
	var shape := blocker.get_child(0) as CollisionShape2D
	(shape.shape as CircleShape2D).radius = 11.0

func _process(delta: float) -> void:
	match state:
		State.UP:
			rock_time += delta
			if rock > 0.0001:
				rock = ROCK * exp(-ROCK_DECAY * rock_time)
			tilt = fall_dir * rock * cos(ROCK_FREQ * rock_time)
		State.FALLING:
			fall_time += delta
			tilt = fall_dir * FALL_ANGLE * clampf(pow(fall_time / FALL_TIME, FALL_EXPONENT), 0.0, 1.0)
			if fall_time > FALL_TIME:
				state = State.DOWN
		State.DOWN:
			pass
	queue_redraw()

func _draw() -> void:
	_draw_shadow()
	# mirrored about the post, so turning it round turns the painted face too
	draw_set_transform(Vector2.ZERO, tilt, Vector2(signf(facing_x), 1.0))
	_draw_post()
	_draw_body()
	_draw_head()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shadow() -> void:
	var reach := sin(tilt) * POST_HEIGHT * 0.6
	draw_set_transform(Vector2(reach * 0.5, 2.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 13.0 + absf(reach) * 0.4, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_post() -> void:
	draw_line(Vector2.ZERO, Vector2(0.0, -POST_HEIGHT), POST, 6.0, true)
	draw_line(Vector2(-ARM_SPAN, -ARMS_AT), Vector2(ARM_SPAN, -ARMS_AT), POST, 5.0, true)
	draw_line(Vector2(-ARM_SPAN, -ARMS_AT), Vector2(ARM_SPAN, -ARMS_AT), POST_EDGE, 1.2, true)

func _draw_body() -> void:
	var bundle := PackedVector2Array([
		Vector2(-BODY_WIDTH, -BODY_BOTTOM),
		Vector2(-BODY_WIDTH - 2.0, -BODY_TOP + 8.0),
		Vector2(-BODY_WIDTH + 3.0, -BODY_TOP),
		Vector2(BODY_WIDTH - 3.0, -BODY_TOP),
		Vector2(BODY_WIDTH + 2.0, -BODY_TOP + 8.0),
		Vector2(BODY_WIDTH, -BODY_BOTTOM),
	])
	draw_colored_polygon(bundle, STRAW)
	var rim := bundle.duplicate()
	rim.append(bundle[0])
	draw_polyline(rim, STRAW_EDGE, 1.4, true)

	# the cords binding the straw to the post
	draw_line(Vector2(-BODY_WIDTH - 1.0, -BODY_TOP + 10.0), Vector2(BODY_WIDTH + 1.0, -BODY_TOP + 10.0), POST_EDGE, 1.6, true)
	draw_line(Vector2(-BODY_WIDTH - 1.0, -BODY_BOTTOM - 8.0), Vector2(BODY_WIDTH + 1.0, -BODY_BOTTOM - 8.0), POST_EDGE, 1.6, true)

	# loose straw poking out of the bottom of the bundle
	for i in range(-2, 3):
		var x := float(i) * 5.0
		draw_line(Vector2(x, -BODY_BOTTOM), Vector2(x * 1.5, -BODY_BOTTOM + 7.0), STRAW_EDGE, 1.2, true)

func _draw_head() -> void:
	var here := Vector2(0.0, -HEAD_AT)
	draw_circle(here, HEAD_RADIUS, SACK)
	draw_arc(here, HEAD_RADIUS, 0.0, TAU, 20, SACK_EDGE, 1.3, true)
	# a face on one side only: which way it is looking has to be readable at a
	# glance, or creeping round behind it is guesswork
	# drawn looking along +x, which is what facing_x = 1 means; the transform
	# mirrors it for the other direction
	draw_circle(here + Vector2(4.4, -2.0), 1.7, MARK)
	draw_circle(here + Vector2(0.6, -2.6), 1.7, MARK)
	draw_line(here + Vector2(5.0, 3.0), here + Vector2(0.5, 3.6), MARK, 1.4, true)
