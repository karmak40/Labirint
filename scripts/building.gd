class_name Building
extends StaticBody2D
## Anything a side has put up: a keep, a barracks, a tower.
##
## It is a target on exactly the terms the straw dummy set -- `is_alive`,
## `take_hit`, `exposed_back_to` -- and nothing more, so every blade and arrow
## that already knows how to hit a man knows how to hit a wall. It does not
## inherit the body: a wall has no legs, no wind and no back to be stabbed in.
##
## Its node position is the middle of its footprint on the floor, the same as a
## man's feet; everything is drawn upwards from there. The footprint is kept
## small on purpose: a blow reaches for the middle, so a wall a swordsman could
## not get within a sword's length of could never be knocked down.

signal destroyed(building: Building)
## Fired once, when a building that was put up in the match is finished.
signal completed(building: Building)

const FLASH_TIME := 0.18
const BAR_BACK := Color(0.08, 0.08, 0.09, 0.8)
const BAR_HURT := Color(0.85, 0.30, 0.22)
const BAR_WELL := Color(0.40, 0.78, 0.36)
const SHADOW := Color(0.0, 0.0, 0.0, 0.2)
const RUBBLE := Color(0.36, 0.35, 0.34)
const RUBBLE_DARK := Color(0.25, 0.24, 0.24)
const SITE_EARTH := Color(0.42, 0.34, 0.24)
const SCAFFOLD := Color(0.55, 0.42, 0.27)
const SCAFFOLD_DARK := Color(0.36, 0.27, 0.17)
const SITE_STONE := Color(0.55, 0.54, 0.51)
const BUILD_BAR := Color(0.95, 0.80, 0.35)
const SITE_START := 0.15       ## share of its health a site has the moment it is laid out

@export var team: int = Team.Id.NEUTRAL

## Set by each kind of building in _init; kept as plain fields rather than exports
## so a scene can not quietly give one keep more walls than another.
var health_max := 400.0
var footprint := Vector2(60.0, 30.0)   ## size on the floor, which is also what blocks
var bar_height := 90.0                 ## how far up its health is shown
var bar_width := 56.0

## Seconds it takes to put up, when it is put up in the match; 0 for anything
## the map stands up whole.
var build_time := 0.0
var built := 1.0               ## 0 a marked-out site, 1 finished
## Laid out in a match: it rises only under a builder's hammer (`build_blow`),
## `build_time` seconds of hammering in all. Anything else rises on its own.
var needs_builder := false
const BUILD_BLOW := 0.75       ## seconds of work one blow is worth
const DUST_TIME := 0.35
var _dust := 1.0               ## seconds since the last blow, for the puff it raises

var health := 0.0
var flash := 0.0
## The side that owns it, handed over by that side (PlayerState._claim_field).
var side: PlayerState

func _ready() -> void:
	health = health_max if is_complete() else health_max * SITE_START
	_seed = hash(Vector2i(position.round())) ^ get_instance_id()
	add_to_group("targets")
	add_to_group("buildings")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = footprint
	shape.shape = box
	add_child(shape)
	queue_redraw()

## Marks it as a site to be built over `seconds`. Call before it is added.
func start_construction(seconds: float) -> void:
	build_time = maxf(seconds, 0.1)
	built = 0.0

func is_complete() -> bool:
	return built >= 1.0

## Raises it a little. True while it is still going up -- a site does nothing
## else until it is finished. Its walls rise with it, and so does its health.
func _tick_construction(delta: float) -> bool:
	if is_complete():
		return false
	if not is_alive():
		return true
	if needs_builder:
		return true
	_raise(delta / build_time)
	return not is_complete()

## A blow of a builder's hammer on the site.
func build_blow() -> void:
	if is_complete() or not is_alive():
		return
	_dust = 0.0
	_raise(BUILD_BLOW / build_time)

func _raise(step: float) -> void:
	built = minf(1.0, built + step)
	health = minf(health_max, health + health_max * (1.0 - SITE_START) * step)
	queue_redraw()
	if is_complete():
		completed.emit(self)

func _physics_process(delta: float) -> void:
	_tick_construction(delta)

## The point of the footprint nearest `from`: what a blade reaches for, and where
## anyone attacking it has to get to.
func nearest_point(from: Vector2) -> Vector2:
	var half := footprint * 0.5
	var local := from - global_position
	return global_position + Vector2(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y))

## A place to stand in front of it, seen from `from`: just off the nearest wall.
func approach_from(from: Vector2) -> Vector2:
	var wall := nearest_point(from)
	var out := from - wall
	return wall + (out.normalized() if out.length() > 1.0 else Vector2.RIGHT) * 36.0

func team_of() -> int:
	return team

## Ground in front of it that has to stay open, as a rectangle in the world:
## a door people go in and out of, anvils smiths stand at. Nothing may be
## built on it, and nobody is posted to stand on it. Empty for none.
func apron() -> Rect2:
	return apron_at(global_position)

## The same, for one standing at `origin` (for a building not yet put down).
func apron_at(_origin: Vector2) -> Rect2:
	return Rect2()

## `point`, moved just clear of any building standing on it or on the open
## ground in front of one -- somewhere a man can actually stand.
static func clear_of(tree: SceneTree, point: Vector2, margin: float = 24.0) -> Vector2:
	if tree == null:
		return point
	for pass_ in 3:
		var moved := false
		for node in tree.get_nodes_in_group("buildings"):
			var building := node as Building
			if building == null or not building.is_alive():
				continue
			var body := Rect2(building.global_position - building.footprint * 0.5, building.footprint).grow(margin)
			for keep_off in [body, building.apron()]:
				if keep_off.has_area() and keep_off.has_point(point):
					point = _out_of(keep_off, point)
					moved = true
		if not moved:
			break
	return point

## The nearest point just outside `area` from `point` inside it.
static func _out_of(area: Rect2, point: Vector2) -> Vector2:
	var to_left := point.x - area.position.x
	var to_right := area.end.x - point.x
	var to_top := point.y - area.position.y
	var to_bottom := area.end.y - point.y
	var least := minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if least == to_left:
		return Vector2(area.position.x - 2.0, point.y)
	if least == to_right:
		return Vector2(area.end.x + 2.0, point.y)
	if least == to_top:
		return Vector2(point.x, area.position.y - 2.0)
	return Vector2(point.x, area.end.y + 2.0)

func is_alive() -> bool:
	return health > 0.0

## A wall has no back to be caught from.
func exposed_back_to(_from: Vector2) -> bool:
	return false

func take_backstab(_from: Vector2) -> void:
	pass

func take_hit(from: Vector2 = Vector2.INF, damage: float = 10.0) -> void:
	if not is_alive():
		return
	health = maxf(0.0, health - damage)
	flash = FLASH_TIME
	if is_complete():
		_chip(from, damage)
	if health <= 0.0:
		_begin_collapse(from)
		_fall()
		destroyed.emit(self)
	queue_redraw()

## What a blow of a repairer's hammer puts back, and what it costs the side.
const REPAIR_HP := 12.0
const REPAIR_COST := {"wood": 1}

## Whether a repairer has anything to do here: finished, standing, and hurt.
func needs_repair() -> bool:
	return is_alive() and is_complete() and health < health_max

## A blow of a repairer's hammer: paid for out of `store`, a little health
## back. False, and nothing taken, if there is nothing to mend or no wood.
func repair_blow(store: Economy) -> bool:
	if not needs_repair() or store == null or not store.spend(REPAIR_COST):
		return false
	health = minf(health_max, health + REPAIR_HP)
	queue_redraw()
	return true

## What happens when it goes. The ruin stays where it was, and keeps blocking.
func _fall() -> void:
	pass

func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		queue_redraw()
	if _dust < DUST_TIME:
		_dust += delta
		queue_redraw()
	if _settle_shards(delta):
		queue_redraw()
	if collapse >= 0.0 and collapse < DUST_CLOUD_TIME:
		collapse += delta
		if collapse < COLLAPSE_TIME:
			_shed_while_falling(delta)
		queue_redraw()
	elif is_alive() and is_complete() and wear() >= SMOKE_FROM:
		_smoke_time += delta
		queue_redraw()

func _draw() -> void:
	_draw_shadow()
	if is_alive() and not is_complete():
		_draw_site()
	elif is_alive():
		_draw_standing()
		_draw_wear()
		_draw_health()
	elif collapse >= 0.0 and collapse < COLLAPSE_TIME:
		_draw_collapsing()
	else:
		_draw_ruin()
	_draw_shards()
	if collapse >= 0.0 and collapse < DUST_CLOUD_TIME:
		_draw_dust_cloud()

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, footprint.y / footprint.x))
	draw_circle(Vector2.ZERO, footprint.x * 0.62, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Each kind draws itself standing; this is only a placeholder block.
func _draw_standing() -> void:
	draw_rect(Rect2(-footprint.x * 0.5, -bar_height * 0.7, footprint.x, bar_height * 0.7), _tint(RUBBLE))

## A building going up: its footprint dug out, walls rising to as far as the
## work has got, scaffolding round them, and how far along it is.
func _draw_site() -> void:
	var w := footprint.x * 0.5
	var d := footprint.y * 0.5
	draw_rect(Rect2(-w - 4.0, -d * 0.6, footprint.x + 8.0, d * 1.6), SITE_EARTH)
	var tall := bar_height * 0.8
	var up := tall * built
	draw_rect(Rect2(-w, d - up, footprint.x, up), _tint(SITE_STONE))
	for i in range(1, 6):
		var y := d - up * float(i) / 6.0
		draw_line(Vector2(-w, y), Vector2(w, y), RUBBLE_DARK, 1.0)
	# poles at the corners and through the middle, planks every so often
	var poles := [-w - 3.0, 0.0, w + 3.0]
	for x in poles:
		draw_line(Vector2(x, d + 2.0), Vector2(x, d - tall - 6.0), SCAFFOLD_DARK, 2.5)
	var level := d - 10.0
	while level > d - tall:
		draw_line(Vector2(-w - 6.0, level), Vector2(w + 6.0, level), SCAFFOLD, 2.5)
		level -= 26.0
	draw_line(Vector2(-w - 3.0, d), Vector2(w + 3.0, d - tall), SCAFFOLD_DARK, 1.5)
	# a puff of dust off the last blow
	if _dust < DUST_TIME:
		var rise := _dust / DUST_TIME
		for i in 4:
			var x := lerpf(-w * 0.8, w * 0.8, float(i) / 3.0) + sin(float(i) * 2.3) * 6.0
			draw_circle(Vector2(x, d - up - 4.0 - rise * 14.0), 4.0 + rise * 6.0, Color(0.72, 0.64, 0.52, 0.5 * (1.0 - rise)))
	var at := Vector2(-bar_width * 0.5, -bar_height - 10.0)
	draw_rect(Rect2(at, Vector2(bar_width, 5.0)), BAR_BACK)
	draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2((bar_width - 2.0) * built, 3.0)), BUILD_BAR)

func _draw_ruin() -> void:
	var w := footprint.x * 0.5
	for i in range(7):
		var x := lerpf(-w, w, float(i) / 6.0)
		var r := 5.0 + float((i * 7) % 5)
		draw_circle(Vector2(x, -r * 0.4 + float((i * 3) % 4) - 2.0), r, RUBBLE if i % 2 == 0 else RUBBLE_DARK)

func _draw_health() -> void:
	if health >= health_max or Pen.bare:
		return
	var at := Vector2(-bar_width * 0.5, -bar_height - 10.0)
	draw_rect(Rect2(at, Vector2(bar_width, 5.0)), BAR_BACK)
	var share := health / health_max
	draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2((bar_width - 2.0) * share, 3.0)),
		BAR_HURT.lerp(BAR_WELL, share))

## A colour, whitened for a moment after each blow, so a hit reads on a wall
## that does not flinch.
func _tint(base: Color) -> Color:
	return base.lerp(Color.WHITE, 0.55 * flash / FLASH_TIME) if flash > 0.0 else base

# --- wear, debris and the fall ------------------------------------------------------
#
# Every blow knocks bits off: stone chips or splinters (`debris_colors`) fly
# from the face that was struck, towards whoever struck it, fall, bounce and lie
# on the ground a while. The walls show what they have taken: cracks first, then
# holes knocked out of them, then smoke. When it goes, it does not just turn
# into a ruin: it shakes, leans, sinks into itself in a rain of debris, and a
# cloud of dust rolls out over the rubble. All of it is for the eye -- the ruin
# blocks from the first moment, as it always did.

const SHARD_GRAVITY := 900.0   ## px/s² pulling a chip back down to the floor
const SHARD_BOUNCE := 0.35     ## of its fall speed a chip keeps when it bounces
const SHARD_REST := 5.0        ## seconds a chip lies on the ground
const SHARD_FADE := 1.0        ## and fades over the last of them
const COLLAPSE_TIME := 1.5     ## from the last blow to the ruin
const DUST_CLOUD_TIME := 3.2   ## how long the cloud hangs over it
const SMOKE_FROM := 0.55       ## worn this far, it smokes
const CRACK := Color(0.10, 0.09, 0.08, 0.8)
const CRACK_LIGHT := Color(1.0, 1.0, 1.0, 0.18)
const HOLE := Color(0.09, 0.08, 0.08, 0.9)
const HOLE_RIM := Color(0.30, 0.28, 0.26, 0.9)
const SMOKE_PUFF := Color(0.22, 0.21, 0.21, 0.42)
const DUST_PUFF := Color(0.64, 0.59, 0.52, 0.7)

class Shard:
	var at := Vector2.ZERO     ## where it is over the floor, in the building's frame
	var z := 0.0               ## how high above the floor
	var vel := Vector2.ZERO    ## across the floor
	var vz := 0.0              ## up
	var angle := 0.0
	var spin := 0.0
	var size := 3.0
	var color := Color.GRAY
	var resting := -1.0        ## seconds on the ground; -1 still flying

var shards: Array[Shard] = []
## Seconds since it began to come down; -1 while it stands.
var collapse := -1.0
var _lean := 0.0               ## which way, and how far, it keeps over as it falls
var _seed := 0
var _smoke_time := 0.0
var _shed_owed := 0.0
## What the standing drawing is drawn through: the identity, except while it falls.
var _xf := Transform2D.IDENTITY

## 0 whole to 1 down.
func wear() -> float:
	return clampf(1.0 - health / health_max, 0.0, 1.0)

## The faces a blow can show on: where cracks run and chips fly from, in its
## own frame, each with its foot on the ground line. A kind with a shape of its
## own says so.
func damage_faces() -> Array[Rect2]:
	var tall := bar_height * 0.5
	return [Rect2(-footprint.x * 0.5, -tall, footprint.x, tall)]

## What it is made of, as far as the bits knocked off it go.
func debris_colors() -> Array[Color]:
	return [RUBBLE, RUBBLE_DARK]

## The most chips one building keeps in the air or on the ground at once.
func _shards_max() -> int:
	return clampi(int(footprint.x * 0.6), 30, 90)

## Draws through the fall's transform: for a kind whose drawing sets its own
## (instead of draw_set_transform, which would undo the fall).
func _draw_xf(local: Transform2D = Transform2D.IDENTITY) -> void:
	draw_set_transform_matrix(_xf * local)

## The face nearest a blow from `from` (any one with none).
func _face_toward(from: Vector2) -> Rect2:
	var faces := damage_faces()
	if from == Vector2.INF:
		return faces[randi() % faces.size()]
	var local := from - global_position
	var best := faces[0]
	var best_gap := INF
	for face in faces:
		var gap := absf(clampf(local.x, face.position.x, face.end.x) - local.x) + randf() * 20.0
		if gap < best_gap:
			best_gap = gap
			best = face
	return best

## Bits off the face a blow landed on, flying towards whoever landed it.
func _chip(from: Vector2, damage: float) -> void:
	var face := _face_toward(from)
	var local := from - global_position if from != Vector2.INF else Vector2(randf_range(-1.0, 1.0), 1.0) * 100.0
	var x := clampf(local.x, face.position.x + 2.0, face.end.x - 2.0)
	# men strike low: most chips come off the lower part of a wall
	var up := randf_range(4.0, face.size.y * 0.6)
	var away := local.normalized() if local.length() > 1.0 else Vector2.DOWN
	for i in clampi(int(damage / 7.0) + 1, 1, 5):
		var dir := away.rotated(randf_range(-0.9, 0.9))
		_add_shard(Vector2(x + randf_range(-4.0, 4.0), face.end.y + randf_range(1.0, 4.0)), up,
			dir * randf_range(40.0, 120.0), randf_range(50.0, 170.0), randf_range(2.0, 4.5))

func _add_shard(at: Vector2, z: float, vel: Vector2, vz: float, size: float) -> void:
	if shards.size() >= _shards_max():
		shards.pop_front()
	var shard := Shard.new()
	shard.at = at
	shard.z = z
	shard.vel = vel
	shard.vz = vz
	shard.size = size
	shard.angle = randf() * TAU
	shard.spin = randf_range(-12.0, 12.0)
	var colors := debris_colors()
	shard.color = colors[randi() % colors.size()]
	shards.append(shard)

## Moves the chips: up, over, down, a bounce or two, then still; the ones that
## have lain long enough go. True while anything changed on screen.
func _settle_shards(delta: float) -> bool:
	if shards.is_empty():
		return false
	var changed := false
	var kept: Array[Shard] = []
	for shard in shards:
		if shard.resting < 0.0:
			shard.vz -= SHARD_GRAVITY * delta
			shard.z += shard.vz * delta
			shard.at += shard.vel * delta
			shard.angle += shard.spin * delta
			if shard.z <= 0.0:
				shard.z = 0.0
				if shard.vz < -70.0:
					shard.vz = -shard.vz * SHARD_BOUNCE
					shard.vel *= 0.55
					shard.spin *= 0.5
				else:
					shard.resting = 0.0
			changed = true
		else:
			shard.resting += delta
			if shard.resting > SHARD_REST - SHARD_FADE:
				changed = true
		if shard.resting < SHARD_REST:
			kept.append(shard)
		else:
			changed = true
	shards = kept
	return changed

func _draw_shards() -> void:
	for shard in shards:
		var fade := 1.0
		if shard.resting > SHARD_REST - SHARD_FADE:
			fade = clampf((SHARD_REST - shard.resting) / SHARD_FADE, 0.0, 1.0)
		if shard.z > 2.0:
			draw_circle(shard.at, shard.size * 0.7, Color(0.0, 0.0, 0.0, 0.18 * fade))
		var at := shard.at + Vector2(0.0, -shard.z)
		var s := shard.size
		var points := PackedVector2Array([
			at + Vector2(s, 0.0).rotated(shard.angle),
			at + Vector2(-s * 0.4, s * 0.8).rotated(shard.angle),
			at + Vector2(-s * 0.8, -s * 0.3).rotated(shard.angle),
			at + Vector2(s * 0.2, -s * 0.9).rotated(shard.angle)])
		draw_colored_polygon(points, Color(shard.color, fade))

## The marks of what it has taken, over its standing drawing: cracks from the
## first blows, holes knocked out of the walls past a third, smoke past half.
## Laid out by its own seed, so they stay put, and go as it is mended.
func _draw_wear() -> void:
	var worn := wear()
	if worn <= 0.05:
		return
	var faces := damage_faces()
	var dice := RandomNumberGenerator.new()
	for i in int(worn * 10.0):
		dice.seed = _seed + i * 7919
		var face := _pick_face(faces, dice)
		var at := Vector2(dice.randf_range(face.position.x + 3.0, face.end.x - 3.0),
			dice.randf_range(face.position.y + 4.0, face.end.y - 4.0))
		var line := PackedVector2Array([at])
		var heading := dice.randf_range(0.6, 2.5)   # mostly downwards
		var step := clampf(face.size.y * 0.12, 5.0, 16.0)
		for k in 4:
			heading += dice.randf_range(-0.7, 0.7)
			at += Vector2.from_angle(heading) * step * dice.randf_range(0.6, 1.2)
			at = Vector2(clampf(at.x, face.position.x, face.end.x), clampf(at.y, face.position.y, face.end.y))
			line.append(at)
		draw_polyline(line, CRACK, 1.5)
		var lit := line.duplicate()
		for k in lit.size():
			lit[k] += Vector2(1.0, 1.0)
		draw_polyline(lit, CRACK_LIGHT, 1.0)
	for i in int(maxf(0.0, worn - 0.3) * 8.0):
		dice.seed = _seed + 104729 + i * 31
		var face := _pick_face(faces, dice)
		var middle := Vector2(dice.randf_range(face.position.x + 6.0, face.end.x - 6.0),
			dice.randf_range(face.position.y + 4.0, face.position.y + face.size.y * 0.6))
		var r := clampf(face.size.x * 0.06, 4.0, 11.0) * dice.randf_range(0.7, 1.3)
		var hole := PackedVector2Array()
		for k in 7:
			hole.append(middle + Vector2.from_angle(TAU * k / 7.0) * r * dice.randf_range(0.6, 1.15))
		var rim := hole.duplicate()
		for k in rim.size():
			rim[k] = middle + (rim[k] - middle) * 1.25
		draw_colored_polygon(rim, HOLE_RIM)
		draw_colored_polygon(hole, HOLE)
	if worn >= SMOKE_FROM:
		var strength := clampf((worn - SMOKE_FROM) / (1.0 - SMOKE_FROM) + 0.3, 0.0, 1.0)
		for k in 3:
			dice.seed = _seed + 7 + k
			var face := _pick_face(faces, dice)
			var root := Vector2(dice.randf_range(face.position.x + 4.0, face.end.x - 4.0), face.position.y + 4.0)
			for p in 4:
				var t := fmod(_smoke_time * 0.45 + float(p) / 4.0 + float(k) * 0.37, 1.0)
				var drift := sin(_smoke_time * 0.8 + float(p) * 1.7 + float(k)) * 6.0 * t
				draw_circle(root + Vector2(drift + t * 10.0, -t * 70.0), 4.0 + t * 13.0,
					Color(SMOKE_PUFF, SMOKE_PUFF.a * (1.0 - t) * strength))

static func _pick_face(faces: Array[Rect2], dice: RandomNumberGenerator) -> Rect2:
	var total := 0.0
	for face in faces:
		total += face.get_area()
	var pick := dice.randf() * total
	for face in faces:
		pick -= face.get_area()
		if pick <= 0.0:
			return face
	return faces[faces.size() - 1]

## The last blow: it starts to come down, and a burst of debris goes out.
func _begin_collapse(from: Vector2) -> void:
	collapse = 0.0
	_lean = randf_range(0.04, 0.10) * (signf(global_position.x - from.x) if from != Vector2.INF else 1.0)
	for face in damage_faces():
		var count := clampi(int(face.size.x / 8.0), 4, 18)
		for i in count:
			var x := randf_range(face.position.x, face.end.x)
			var out := Vector2(randf_range(-1.0, 1.0), randf_range(0.2, 1.0)).normalized()
			_add_shard(Vector2(x, face.end.y + randf_range(-2.0, 6.0)), randf_range(0.0, face.size.y),
				out * randf_range(30.0, 140.0), randf_range(20.0, 200.0), randf_range(2.5, 6.0))

## While it sinks, its top edge sheds more.
func _shed_while_falling(delta: float) -> void:
	_shed_owed += delta * clampf(footprint.x * 0.3, 12.0, 40.0)
	var standing := 1.0 - _sinking()
	while _shed_owed >= 1.0:
		_shed_owed -= 1.0
		var faces := damage_faces()
		var face := faces[randi() % faces.size()]
		_add_shard(Vector2(randf_range(face.position.x, face.end.x), face.end.y + randf_range(0.0, 8.0)),
			face.size.y * standing * randf_range(0.6, 1.0),
			Vector2(randf_range(-60.0, 60.0), randf_range(0.0, 50.0)), randf_range(0.0, 80.0), randf_range(2.5, 5.5))

## How far down it has gone, 0 to 1, falling faster as it goes.
func _sinking() -> float:
	var t := clampf(collapse / COLLAPSE_TIME, 0.0, 1.0)
	return t * t

## The ground line under its faces: what it sinks towards.
func _ground_line() -> float:
	var foot := -INF
	for face in damage_faces():
		foot = maxf(foot, face.end.y)
	return foot

## Coming down: the ruin already there underneath, and the standing building
## drawn over it shaking, leaning, and squashed into the ground.
func _draw_collapsing() -> void:
	_draw_ruin()
	var sink := _sinking()
	var foot := _ground_line()
	var shake := sin(collapse * 55.0) * 3.0 * (1.0 - sink)
	var fall := Transform2D(_lean * sink, Vector2(1.0 + 0.06 * sink, maxf(0.05, 1.0 - 0.92 * sink)), 0.0,
		Vector2(shake, foot))
	_xf = fall * Transform2D(0.0, Vector2(0.0, -foot))
	draw_set_transform_matrix(_xf)
	_draw_standing()
	_draw_wear()
	_xf = Transform2D.IDENTITY
	draw_set_transform_matrix(_xf)

## The dust that rolls out of it as it comes down, and hangs a while.
func _draw_dust_cloud() -> void:
	var t := clampf(collapse / DUST_CLOUD_TIME, 0.0, 1.0)
	var fade := (1.0 - t) * minf(1.0, collapse * 4.0)
	var foot := _ground_line()
	var left := INF
	var right := -INF
	var tall := 0.0
	for face in damage_faces():
		left = minf(left, face.position.x)
		right = maxf(right, face.end.x)
		tall = maxf(tall, face.size.y)
	var dice := RandomNumberGenerator.new()
	dice.seed = _seed + 999
	var puffs := clampi(int((right - left) / 14.0), 6, 26)
	for i in puffs:
		var x := lerpf(left, right, dice.randf()) + dice.randf_range(-1.0, 1.0) * 30.0 * t
		var rise := dice.randf_range(0.1, 0.8) * tall * (0.3 + t)
		var r := dice.randf_range(13.0, 26.0) * (0.6 + 1.5 * t)
		draw_circle(Vector2(x, foot - rise * 0.5 + dice.randf_range(-4.0, 8.0)), r,
			Color(DUST_PUFF, DUST_PUFF.a * fade * dice.randf_range(0.6, 1.0)))
