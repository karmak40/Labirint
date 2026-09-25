class_name Carriable
extends Node2D
## Anything lying about that can be picked up, carried and set down again.
##
## Its node position is the point on the floor it sits over, with height kept
## separately -- the same split the dropped weapons and arrows use, so a carried
## thing can be let go of and simply fall.
##
## Subclasses supply the drawing and say how they are held and how heavy they
## are; everything below is the same whatever the thing is.

enum State {
	RESTING,  ## on the floor, free to be picked up
	CARRIED,  ## held: position is driven by whoever is carrying it
	FLYING,   ## in the air or still sliding to a stop
}

enum Grip {
	IN_HANDS,    ## held out in front in both hands
	ON_SHOULDER, ## hoisted up and rested across one shoulder
}

const GRAVITY := 900.0
const REST_SPEED := 18.0
const REST_BOUNCE := 40.0
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.25)

## Set by subclasses: how it is held, how hard it is to shift, and how it settles.
var grip := Grip.IN_HANDS
var heavy := false
var bounce := 0.32
var drag := 210.0
var spin_drag := 4.0
var shadow_radius := 12.0

var state := State.RESTING
var height := 0.0
var velocity := Vector2.ZERO
var height_velocity := 0.0
var spin := 0.0
var tilt := 0.0

func _ready() -> void:
	add_to_group("carriables")

func _process(delta: float) -> void:
	if state == State.FLYING:
		_fly(delta)
	queue_redraw()

func is_free() -> bool:
	return state == State.RESTING

## Whether a pair of hands can close on it. Separate from is_free, which is only
## about where it is: a burning log is lying perfectly still and is still not
## something anyone is going to pick up.
func can_be_taken() -> bool:
	return is_free()

func grab() -> void:
	state = State.CARRIED
	velocity = Vector2.ZERO
	height_velocity = 0.0
	spin = 0.0

## Driven by the carrier every frame while held.
func hold_at(world: Vector2, above_floor: float, angle: float) -> void:
	global_position = world
	height = above_floor
	tilt = angle

func launch(from: Vector2, above_floor: float, throw: Vector2, lift: float, turn: float) -> void:
	global_position = from
	height = above_floor
	velocity = throw
	height_velocity = lift
	spin = turn
	state = State.FLYING

func _fly(delta: float) -> void:
	height_velocity -= GRAVITY * delta
	height += height_velocity * delta

	if height <= 0.0:
		height = 0.0
		height_velocity = -height_velocity * bounce
		velocity *= 0.55
		spin *= 0.4
		if absf(height_velocity) < REST_BOUNCE and velocity.length() < REST_SPEED:
			height_velocity = 0.0
			velocity = Vector2.ZERO
			spin = 0.0
			state = State.RESTING
			_settle()

	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	spin = lerpf(spin, 0.0, minf(1.0, spin_drag * delta))

	global_position += velocity * delta
	tilt += spin * delta

## What it does once it has stopped moving. A rock does not care which way up it
## is; a beam has to come to rest lying down.
func _settle() -> void:
	pass

func _draw_shadow() -> void:
	var fade := clampf(height / 120.0, 0.0, 0.5)
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, shadow_radius * (1.0 - fade * 0.6), Color(
		SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_COLOR.a * (1.0 - fade)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
