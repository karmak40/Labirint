class_name Pathfinder
extends NavigationAgent2D
## The way round things, for any body that walks on its own.
##
## It only ever answers "which way, from here": deciding where to go stays with
## whoever owns the body. It also speaks for the body to the crowd, so bodies on
## the move bend round each other instead of meeting shoulder to shoulder.
##
## On a floor with no navigation baked there is nothing to ask, and
## `has_floor_plan()` says so -- the owner then walks however it did before.

const REPATH := 16.0   ## how far a goal has to move before the way is worked out again
const STALL_SPEED := 20.0  ## slower than this while trying to walk counts as not getting anywhere
const STALL_TIME := 0.8    ## and this long of it means stuck
const SIDESTEP_TIME := 0.5
const SIDESTEP_ANGLE := 1.25   ## about seventy degrees off the way it wanted to go

var goal := Vector2.INF
## The crowd's answer to where we meant to go: the same wish, bent round anyone
## else about to be in the same place. It comes back a physics frame late.
var steered := Vector2.INF
var walking := false
var stalled := 0.0
var sidestep_left := 0.0
var sidestep_sign := 1.0

func _init(top_speed: float) -> void:
	radius = 14.0
	path_desired_distance = 6.0
	target_desired_distance = 8.0
	avoidance_enabled = true
	max_speed = top_speed
	velocity_computed.connect(func(safe: Vector2) -> void: steered = safe / max_speed)

func _ready() -> void:
	# which way this one steps round a jam: fixed per body, so two meeting
	# head on do not both step the same way and meet again
	sidestep_sign = 1.0 if get_parent().get_instance_id() % 2 == 0 else -1.0

func has_floor_plan() -> bool:
	var map := get_navigation_map()
	return map.is_valid() and not NavigationServer2D.map_get_regions(map).is_empty()

## Unit direction to head in to get to `there`.
func heading_to(there: Vector2) -> Vector2:
	var here := (get_parent() as Node2D).global_position
	# a moving quarry would otherwise have the way worked out afresh every frame
	if there.distance_to(goal) > REPATH:
		goal = there
		target_position = there
	walking = true
	var step := get_next_path_position() - here
	if step.length() < 1.0:
		# no way found (or not yet): make for it directly and let the walls argue
		step = there - here
	return step.normalized()

## Once a frame, after the owner has decided: tells the crowd what the body means
## to do -- standing still included, so movers go round it -- and hands back the
## wish to actually walk on. `give_way`: standing about with nothing to do, so
## step aside for anyone coming through rather than stand there like a post.
func settle(wish: Vector2, give_way := false) -> Vector2:
	velocity = wish * max_speed
	var out := wish
	if steered != Vector2.INF and (walking or (give_way and wish == Vector2.ZERO)):
		out = steered
	if walking:
		out = _unstick(wish, out)
	else:
		stalled = 0.0
	walking = false
	return out

## Walking into someone head on, or held in a knot the crowd can not untie:
## step off to one side for a moment and try again from there.
func _unstick(wish: Vector2, out: Vector2) -> Vector2:
	var delta := get_physics_process_delta_time()
	if sidestep_left > 0.0:
		sidestep_left -= delta
		return wish.rotated(SIDESTEP_ANGLE * sidestep_sign)
	var body := get_parent() as CharacterBody2D
	if body != null and wish.length() > 0.3 and body.velocity.length() < STALL_SPEED:
		stalled += delta
		if stalled > STALL_TIME:
			stalled = 0.0
			sidestep_left = SIDESTEP_TIME
	else:
		stalled = 0.0
	return out
