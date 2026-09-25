class_name Terrain
extends Node2D
## The look of the land a match is fought on: grass, a road between the castles,
## trodden earth where people work, and a sky with hills beyond the far edge.
##
## Presentation only. Nothing here blocks, nothing is struck, nothing counts --
## the field is the same field it was on the grey debug floor. Its randomness
## is seeded from the map, so the same map always looks the same.
##
## All of it is drawn once, through Pens, into strips a few hundred pixels
## wide: a strip is one draw call however much grass is in it, the renderer
## skips the strips off screen, and nothing is redrawn frame by frame. The
## only thing that moves is the clouds, and they move without being redrawn.

const STRIP := 500.0           ## width of one pre-drawn piece of land
const SIDE := 420.0            ## land carried on past each end of the field
const SKY := 420.0             ## how far up beyond the far edge the sky goes
const BANK := 160.0            ## and how far down beyond the near edge the earth

const GRASS := Color(0.36, 0.50, 0.27)
const GRASS_LIGHT := Color(0.42, 0.57, 0.30)
const GRASS_DARK := Color(0.30, 0.43, 0.23)
const BLADE_DARK := Color(0.24, 0.37, 0.18)
const BLADE_LIGHT := Color(0.50, 0.65, 0.34)
const DIRT := Color(0.50, 0.41, 0.29)
const DIRT_EDGE := Color(0.44, 0.45, 0.28)   ## where dirt meets grass, a mix of both
const DIRT_LIGHT := Color(0.57, 0.48, 0.34)
const GRAVEL := Color(0.47, 0.45, 0.41)
const PEBBLE := Color(0.58, 0.57, 0.54)
const PEBBLE_DARK := Color(0.40, 0.39, 0.37)
const FOREST_FLOOR := Color(0.25, 0.36, 0.20)
const LEAF_LITTER := Color(0.42, 0.36, 0.20)
const SOIL := Color(0.33, 0.25, 0.17)
const SOIL_DEEP := Color(0.16, 0.12, 0.09)
const FLOWERS := [Color(0.95, 0.93, 0.85), Color(0.97, 0.84, 0.30), Color(0.72, 0.56, 0.86), Color(0.92, 0.50, 0.46)]

const SKY_HIGH := Color(0.38, 0.56, 0.82)
const SKY_LOW := Color(0.80, 0.87, 0.92)
const MOUNTAIN_FAR := Color(0.62, 0.69, 0.79)
const MOUNTAIN_SNOW := Color(0.88, 0.91, 0.95)
const HILLS := Color(0.47, 0.59, 0.47)
const HILLS_NEAR := Color(0.36, 0.50, 0.33)
const TREELINE := Color(0.21, 0.34, 0.21)
const TREELINE_DARK := Color(0.16, 0.27, 0.17)
const CLOUD := Color(1.0, 1.0, 1.0, 0.85)

var map: MapData
var rng := RandomNumberGenerator.new()
var strips := {}               ## strip index -> Pen, for everything drawn over the ground
var beds := {}                 ## strip index -> Pen, for the ground itself, under all of it
var road: PackedVector2Array   ## the main road, castle gate to castle gate

## A pre-drawn strip of land: holds its triangles and hands them over once.
class Strip:
	extends Node2D
	var pen: Pen
	func _draw() -> void:
		pen.flush(self)

## One cloud, drawn once and then only moved.
class Cloud:
	extends Node2D
	var puffs: Array = []      ## [offset, radius]
	var drift := 6.0
	var span := Vector2.ZERO   ## x range it wraps across
	func _draw() -> void:
		for puff in puffs:
			draw_circle(puff[0], puff[1], CLOUD)
	func _process(delta: float) -> void:
		position.x += drift * delta
		if position.x > span.y:
			position.x = span.x

func build(data: MapData) -> void:
	map = data
	rng.seed = hash(map.title) ^ 0x51ab
	var size := map.floor_size
	z_index = -3
	road = _road_line()
	_sky(size)
	_ground(size)
	_forest_floor()
	_worn_ground()
	_road()
	_scatter(size)
	_bank(size)
	# every bed before any detail, so a patch or a hill that runs over a strip's
	# edge is never painted over by the next strip's plain ground
	for layer in [["Bed", beds], ["Strip", strips]]:
		for index in layer[1]:
			var strip := Strip.new()
			strip.pen = layer[1][index]
			strip.name = "%s%d" % [layer[0], index]
			add_child(strip)
	_clouds(size)

## The pen for whatever is drawn around `x`.
func _pen(x: float) -> Pen:
	var index := int(floorf(x / STRIP))
	if not strips.has(index):
		var pen := Pen.new()
		pen.begin()
		strips[index] = pen
	return strips[index]

func _left() -> float:
	return -SIDE

func _right() -> float:
	return map.floor_size.x + SIDE

## The pen for the plain ground under `x`: sky and grass, before anything else.
func _bed(x: float) -> Pen:
	var index := int(floorf(x / STRIP))
	if not beds.has(index):
		var pen := Pen.new()
		pen.begin()
		beds[index] = pen
	return beds[index]

## For every strip across [from, to], call `paint(pen, strip_left, strip_right)`
## with that strip's bed.
func _across(from: float, to: float, paint: Callable) -> void:
	var x := floorf(from / STRIP) * STRIP
	while x < to:
		paint.call(_bed(x + 1.0), maxf(x, from), minf(x + STRIP, to))
		x += STRIP

# --- beyond the far edge: sky, mountains, hills, the edge of the woods ----------

func _sky(size: Vector2) -> void:
	_across(_left(), _right(), func(pen: Pen, a: float, b: float) -> void:
		pen.gradient_quad(Vector2(a, -SKY), Vector2(b, -SKY), Vector2(b, 0.0), Vector2(a, 0.0), SKY_HIGH, SKY_LOW))
	# far mountains, pale with the distance, a few with snow on them
	var x := _left()
	while x < _right():
		var wide := rng.randf_range(160.0, 320.0)
		var tall := rng.randf_range(90.0, 170.0)
		var peak := Vector2(x + wide * rng.randf_range(0.35, 0.65), -48.0 - tall)
		var foot := -40.0
		_pen(peak.x).colored_polygon(PackedVector2Array([Vector2(x, foot), peak, Vector2(x + wide, foot)]), MOUNTAIN_FAR)
		if tall > 125.0:
			var cap := 0.22
			_pen(peak.x).colored_polygon(PackedVector2Array([
				peak, peak.lerp(Vector2(x + wide, foot), cap), peak.lerp(Vector2(x, foot), cap)]), MOUNTAIN_SNOW)
		x += wide * rng.randf_range(0.45, 0.7)
	# rolling hills in two bands, nearer ones greener
	for band in [[HILLS, -38.0, 46.0], [HILLS_NEAR, -18.0, 34.0]]:
		x = _left()
		while x < _right():
			var r := rng.randf_range(60.0, 130.0)
			_pen(x).ellipse(Vector2(x, band[1]), Vector2(r, band[2] * rng.randf_range(0.7, 1.2)), band[0])
			x += r * 0.9
	# and the edge of the woods the field is cut out of, right along its far side
	x = _left()
	while x < _right():
		var r := rng.randf_range(14.0, 26.0)
		var tone: Color = TREELINE if rng.randf() < 0.6 else TREELINE_DARK
		_pen(x).circle(Vector2(x, -rng.randf_range(4.0, 16.0)), r, tone)
		x += r * rng.randf_range(0.7, 1.1)
	x = _left()
	while x < _right():
		_pen(x).rect(Rect2(x, -8.0, minf(STRIP, _right() - x), 12.0), TREELINE_DARK)
		x += STRIP

func _clouds(size: Vector2) -> void:
	for i in int(_right() - _left()) / 380:
		var cloud := Cloud.new()
		cloud.z_index = -3
		cloud.position = Vector2(rng.randf_range(_left(), _right()), rng.randf_range(-SKY + 50.0, -150.0))
		cloud.span = Vector2(_left() - 150.0, _right() + 150.0)
		cloud.drift = rng.randf_range(3.0, 9.0)
		var width := rng.randf_range(60.0, 130.0)
		for j in rng.randi_range(4, 7):
			var along := rng.randf_range(-width * 0.5, width * 0.5)
			cloud.puffs.append([Vector2(along, rng.randf_range(-8.0, 6.0) - (width * 0.5 - absf(along)) * 0.15),
				rng.randf_range(14.0, 26.0)])
		add_child(cloud)

# --- the field itself -----------------------------------------------------------

func _ground(size: Vector2) -> void:
	_across(_left(), _right(), func(pen: Pen, a: float, b: float) -> void:
		pen.rect(Rect2(a, 0.0, b - a, size.y), GRASS))
	# broad patches of lighter and darker grass, so the green is not one flat colour
	for i in int((_right() - _left()) * size.y / 9000.0):
		var at := Vector2(rng.randf_range(_left(), _right()), rng.randf_range(10.0, size.y - 10.0))
		var tone: Color = GRASS_LIGHT if rng.randf() < 0.5 else GRASS_DARK
		tone = GRASS.lerp(tone, rng.randf_range(0.25, 0.55))
		_pen(at.x).ellipse(at, Vector2(rng.randf_range(40.0, 110.0), rng.randf_range(16.0, 40.0)), tone)

## Darker ground under the trees, strewn with old leaves.
func _forest_floor() -> void:
	for spot in map.tree_positions:
		_pen(spot.x).ellipse(spot + Vector2(0.0, -6.0), Vector2(62.0, 30.0), GRASS.lerp(FOREST_FLOOR, 0.6))
	for spot in map.tree_positions:
		_pen(spot.x).ellipse(spot + Vector2(0.0, -4.0), Vector2(42.0, 18.0), FOREST_FLOOR)
		for j in 5:
			var leaf := spot + Vector2(rng.randf_range(-48.0, 48.0), rng.randf_range(-22.0, 16.0))
			_pen(leaf.x).ellipse(leaf, Vector2(2.6, 1.4), LEAF_LITTER, 6)

## Earth worn bare where people stand about: before the castle gates, round the
## barracks, and gravel round the seams.
func _worn_ground() -> void:
	for layout in map.sides():
		var gate := _gate_of(layout)
		_patch(gate + Vector2(0.0, 18.0), Vector2(120.0, 36.0))
		_patch(layout.barracks + Vector2(0.0, 12.0), Vector2(62.0, 24.0))
		_patch(layout.stockpile, Vector2(70.0, 34.0))
		_path([gate, layout.barracks + Vector2(0.0, 16.0)], 14.0)
		_path([gate, layout.stockpile], 14.0)
	for spot in map.vein_positions + map.gold_positions + map.boulder_positions:
		_pen(spot.x).ellipse(spot + Vector2(0.0, 4.0), Vector2(64.0, 26.0), GRASS.lerp(GRAVEL, 0.55))
		_pen(spot.x).ellipse(spot + Vector2(0.0, 4.0), Vector2(46.0, 18.0), GRAVEL)
		for j in 7:
			var stone := spot + Vector2(rng.randf_range(-56.0, 56.0), rng.randf_range(-12.0, 22.0))
			_pen(stone.x).ellipse(stone, Vector2(rng.randf_range(2.0, 4.0), rng.randf_range(1.4, 2.6)),
				PEBBLE if rng.randf() < 0.6 else PEBBLE_DARK, 7)

func _patch(center: Vector2, radii: Vector2) -> void:
	_pen(center.x).ellipse(center, radii * 1.18, DIRT_EDGE)
	_pen(center.x).ellipse(center, radii, DIRT)
	_pen(center.x).ellipse(center + Vector2(-radii.x * 0.2, -radii.y * 0.15), radii * 0.5, DIRT_LIGHT)

## Where a castle's gate opens: the middle of its front wall. The footprint is
## 110 deep (Base), so the front face is 55 in front of the castle's middle.
func _gate_of(layout: SideLayout) -> Vector2:
	return Vector2(layout.base.x, layout.base.y + 66.0)

## The main road: from one castle's gate to the other's, wandering a little.
func _road_line() -> PackedVector2Array:
	var line := PackedVector2Array()
	if map.player == null or map.enemy == null:
		return line
	var from := _gate_of(map.player) + Vector2(0.0, 10.0)
	var to := _gate_of(map.enemy) + Vector2(0.0, 10.0)
	var steps := int(absf(to.x - from.x) / 40.0)
	var mid := map.floor_size.y * 0.52
	for i in steps + 1:
		var t := float(i) / float(maxi(steps, 1))
		var x := lerpf(from.x, to.x, t)
		# it leaves each gate heading out into the field, and wanders across the middle
		var settle := smoothstep(0.0, 0.12, t) * smoothstep(1.0, 0.88, t)
		var y := lerpf(lerpf(from.y, to.y, t), mid + sin(x / 230.0) * 34.0, settle)
		line.append(Vector2(x, y))
	return line

func _road() -> void:
	_path(road, 22.0)

func _path(points: PackedVector2Array, half: float) -> void:
	# a soft verge, the beaten earth, and a paler strip down the middle where
	# the wheels go
	for layer in [[half * 1.45, DIRT_EDGE], [half, DIRT], [half * 0.32, DIRT_LIGHT]]:
		for i in range(points.size() - 1):
			var a := points[i]
			var b := points[i + 1]
			var pen := _pen((a.x + b.x) * 0.5)
			pen.line(a, b, layer[1], layer[0] * 2.0)
			pen.circle(b, layer[0], layer[1], 10)

func _near_road(at: Vector2) -> bool:
	for i in range(0, road.size(), 2):
		if absf(road[i].x - at.x) < 30.0 and absf(road[i].y - at.y) < 34.0:
			return true
	return false

## Tufts, flowers and pebbles over the whole field, kept off the road.
func _scatter(size: Vector2) -> void:
	var area := (_right() - _left()) * size.y
	for i in int(area / 700.0):
		var at := Vector2(rng.randf_range(_left(), _right()), rng.randf_range(4.0, size.y - 2.0))
		if _near_road(at):
			continue
		var pen := _pen(at.x)
		var tone: Color = BLADE_DARK if rng.randf() < 0.6 else BLADE_LIGHT
		var tall := rng.randf_range(4.0, 8.0)
		for blade in 3:
			var lean := (float(blade) - 1.0) * rng.randf_range(1.5, 3.0)
			pen.line(at + Vector2(float(blade - 1) * 1.6, 0.0), at + Vector2(lean, -tall), tone, 1.2)
	for i in int(area / 9000.0):
		var at := Vector2(rng.randf_range(_left(), _right()), rng.randf_range(8.0, size.y - 6.0))
		if _near_road(at):
			continue
		var petal: Color = FLOWERS[rng.randi() % FLOWERS.size()]
		for j in rng.randi_range(2, 5):
			var bloom := at + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-5.0, 5.0))
			_pen(bloom.x).circle(bloom, 1.8, petal, 6)
			_pen(bloom.x).circle(bloom, 0.7, FLOWERS[1], 4)
	for i in int(area / 14000.0):
		var at := Vector2(rng.randf_range(_left(), _right()), rng.randf_range(8.0, size.y - 6.0))
		_pen(at.x).ellipse(at, Vector2(rng.randf_range(2.0, 4.5), rng.randf_range(1.5, 2.8)),
			PEBBLE if rng.randf() < 0.5 else PEBBLE_DARK, 7)

## Past the near edge the ground falls away: a grass lip, then bare earth,
## going dark the way the ground does beyond the light.
func _bank(size: Vector2) -> void:
	_across(_left(), _right(), func(pen: Pen, a: float, b: float) -> void:
		pen.gradient_quad(Vector2(a, size.y), Vector2(b, size.y), Vector2(b, size.y + 26.0), Vector2(a, size.y + 26.0), GRASS_DARK, SOIL)
		pen.gradient_quad(Vector2(a, size.y + 26.0), Vector2(b, size.y + 26.0), Vector2(b, size.y + BANK), Vector2(a, size.y + BANK), SOIL, SOIL_DEEP))
	# grass hanging over the lip
	var x := _left()
	while x < _right():
		_pen(x).line(Vector2(x, size.y - 2.0), Vector2(x + rng.randf_range(-3.0, 3.0), size.y + rng.randf_range(5.0, 11.0)), GRASS_DARK, 2.0)
		x += rng.randf_range(4.0, 9.0)
