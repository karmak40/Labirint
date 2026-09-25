class_name Gait
## The parts of walking that have nothing to do with what is doing the walking.
##
## These came out of the two-legged figure, where they were bound up with its
## weapons, its deaths and its idle fidgeting. Nothing in here knows how many
## legs there are, which way anything faces, or what a hand is -- it is all
## arithmetic over a phase, a stride and a pair of bone lengths, which is why a
## four-legged animal can run on exactly the same code.
##
## Everything is static: there is no state to share and nothing to instance.

## Where a foot sits relative to the body, for a given point in the step cycle.
##
## This is the piece that decides whether walking reads as walking. During
## stance the foot travels backwards at exactly the speed the body travels
## forwards, so it stays put on the ground; the swing is a Hermite curve whose
## end slopes match that, so the foot's speed never jumps at toe-off or heel
## strike. The slight overshoot near contact is real gait -- the foot reaches,
## then retracts.
##
## `travel` is +1 going forwards and -1 going backwards, and it is the direction
## of travel, not of facing. Get that wrong and a body walking backwards drags
## its feet, because the stance pushes them the way the body is already going.
static func foot_offset(p: float, stride: float, stance_fraction: float,
		foot_lift: float, travel: float) -> Vector2:
	var reach := stride * stance_fraction * 0.5
	var step := Vector2.ZERO

	p = fposmod(p, 1.0)
	if p < stance_fraction:
		# linear travel backwards == stationary in world space
		step.x = reach - 2.0 * reach * (p / stance_fraction)
	else:
		var u := (p - stance_fraction) / (1.0 - stance_fraction)
		var m := -2.0 * reach * (1.0 - stance_fraction) / stance_fraction
		var u2 := u * u
		var u3 := u2 * u
		step.x = (2.0 * u3 - 3.0 * u2 + 1.0) * -reach \
			+ (u3 - 2.0 * u2 + u) * m \
			+ (-2.0 * u3 + 3.0 * u2) * reach \
			+ (u3 - u2) * m
		# ^1.5 flattens both ends, so the foot also has no vertical speed jump
		step.y = -foot_lift * pow(sin(PI * u), 1.5)

	step.x *= travel
	return step

## How high a body rides over its planted feet.
##
## The supporting limb keeps a constant length and the body simply vaults over
## it. That matters for how it reads: hold the length fixed and the joint keeps
## one slight bend all through stance, whereas letting the body sink below the
## limb's reach folds it hard -- the geometry is unforgiving, a few pixels of
## sink swing the joint out by triple that.
##
## `feet` are the offsets of every foot carrying this end of the body; whichever
## is nearest to underneath is the one taking the weight.
static func ride_height(feet: Array, limb_reach: float) -> float:
	var support := INF
	for foot in feet:
		support = minf(support, absf((foot as Vector2).x))
	if support == INF:
		support = 0.0
	return sqrt(maxf(1.0, limb_reach * limb_reach - support * support))

## Two-bone IK: where the knee, elbow or hock lands between root and tip.
##
## `bend_sign` picks which way it folds, which is the whole difference between a
## knee and an elbow -- and, on an animal, between a foreleg and a hind leg.
static func joint(root: Vector2, tip: Vector2, a: float, b: float, bend_sign: float) -> Vector2:
	var delta := tip - root
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.DOWN
	var d: float = clampf(delta.length(), absf(a - b) + 0.01, a + b - 0.01)

	var x := (d * d + a * a - b * b) / (2.0 * d)
	var h := sqrt(maxf(0.0, a * a - x * x))
	return root + dir * x + Vector2(dir.y, -dir.x) * h * bend_sign

## Where the limb's tip actually ends up: a limb never stretches past its reach,
## so a tip asked for beyond it is pulled back in along the same line.
static func reached(root: Vector2, tip: Vector2, a: float, b: float) -> Vector2:
	var delta := tip - root
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.DOWN
	var d: float = clampf(delta.length(), absf(a - b) + 0.01, a + b - 0.01)
	return root + dir * d

## Where one leg of a four-legged animal is in its own cycle.
##
## `lag` is how far the forefoot of a side trails the hindfoot of the same side,
## and it is the only number that decides the footfall pattern. At a quarter you
## get the four-beat sequence of a walk, which you can count out; close it to a
## half and the diagonal pairs land together, which is a trot. Everything between
## is a real gait too, so it can simply be interpolated with speed.
static func quadruped_leg(leg: int, phase: float, lag: float) -> float:
	match leg:
		0:   # hind, near side
			return phase
		1:   # fore, near side
			return phase + lag
		2:   # hind, far side
			return phase + 0.5
		_:   # fore, far side
			return phase + 0.5 + lag

## Exponential approach, frame-rate independent. Used for everything that has to
## catch up to a target rather than snap to it.
static func ease_to(current: float, target: float, rate: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-rate * delta))
