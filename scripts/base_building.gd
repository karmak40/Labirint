class_name Base
extends Building
## A side's castle. Lose it and the match is lost: that is the only thing about it
## anything else needs to know, and it says so once, through `base_destroyed`.
##
## Big on purpose -- half the screen high, the thing the whole match is about.
## Its footprint is the curtain wall's base: that is what blocks the way and what
## a blade reaches for (the nearest point of it, see Building.nearest_point).
## Everything above is drawn up from the front edge of that footprint.

signal base_destroyed(team: int)

const STONE := Color(0.52, 0.51, 0.49)
const STONE_LIT := Color(0.60, 0.59, 0.57)
const STONE_DARK := Color(0.40, 0.39, 0.38)
const STONE_EDGE := Color(0.27, 0.26, 0.26)
const ROOF := Color(0.33, 0.30, 0.34)
const ROOF_EDGE := Color(0.22, 0.20, 0.23)
const DOOR := Color(0.18, 0.13, 0.09)
const IRON := Color(0.30, 0.30, 0.32)
const SLIT := Color(0.14, 0.13, 0.14)
const POLE := Color(0.30, 0.23, 0.16)

const WALL_HALF := 150.0       ## half the curtain wall's width
const WALL_TALL := 130.0
const TOWER_HALF := 32.0       ## corner towers, half-width
const TOWER_TALL := 200.0
const KEEP_HALF := 58.0        ## the keep over the gate
const KEEP_TALL := 250.0
const MERLON := 12.0

func _init() -> void:
	health_max = 2000.0
	footprint = Vector2(300.0, 110.0)
	bar_height = 300.0
	bar_width = 180.0

func _ready() -> void:
	super()
	add_to_group("bases")

func _fall() -> void:
	base_destroyed.emit(team)

## Where the front face stands: the near edge of the footprint.
func _front() -> float:
	return footprint.y * 0.5

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, _front() - 6.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, WALL_HALF + 50.0, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_standing() -> void:
	var foot := _front()
	var flag := Team.color(team)
	# the wall runs behind the towers, so it goes down first
	_block(-WALL_HALF, WALL_HALF, foot, WALL_TALL, STONE, 5)
	_slits(-WALL_HALF + 50.0, WALL_HALF - 50.0, foot - WALL_TALL * 0.55, 5)
	for side in [-1.0, 1.0]:
		var x: float = side * (WALL_HALF - 4.0)
		_block(x - TOWER_HALF, x + TOWER_HALF, foot, TOWER_TALL, STONE_LIT, 8)
		_slits(x - 8.0, x + 8.0, foot - TOWER_TALL * 0.6, 2)
		_cone(x, foot - TOWER_TALL, TOWER_HALF + 6.0, 46.0)
		_banner(x, foot - TOWER_TALL - 46.0, 30.0, flag)
	# the keep over the gate, tallest of all
	_block(-KEEP_HALF, KEEP_HALF, foot, KEEP_TALL, STONE, 10)
	_slits(-KEEP_HALF + 18.0, KEEP_HALF - 18.0, foot - KEEP_TALL * 0.72, 3)
	_slits(-KEEP_HALF + 18.0, KEEP_HALF - 18.0, foot - KEEP_TALL * 0.5, 3)
	_banner(0.0, foot - KEEP_TALL - 12.0, 44.0, flag)
	# the side's arms over the gate
	draw_circle(Vector2(0.0, foot - 118.0), 17.0, flag)
	draw_arc(Vector2(0.0, foot - 118.0), 17.0, 0.0, TAU, 28, STONE_EDGE, 2.0, true)
	# and the gate: an arch, a portcullis in it
	var gate_half := 22.0
	draw_rect(Rect2(-gate_half, foot - 52.0, gate_half * 2.0, 52.0), DOOR)
	draw_circle(Vector2(0.0, foot - 52.0), gate_half, DOOR)
	for i in range(-2, 3):
		draw_line(Vector2(i * 8.0, foot - 70.0), Vector2(i * 8.0, foot), IRON, 2.0)
	for i in 3:
		draw_line(Vector2(-gate_half, foot - 14.0 - i * 16.0), Vector2(gate_half, foot - 14.0 - i * 16.0), IRON, 2.0)

## A square-fronted piece of masonry from `left` to `right`, standing on `foot`,
## `tall` high, with courses of stone and battlements along its top.
func _block(left: float, right: float, foot: float, tall: float, face: Color, courses: int) -> void:
	var top := foot - tall
	draw_rect(Rect2(left, top, right - left, tall), _tint(face))
	# a darker strip down one side so it reads as a solid, not a card
	draw_rect(Rect2(left, top, 7.0, tall), _tint(STONE_DARK))
	for i in range(1, courses):
		var y := top + tall * float(i) / float(courses)
		draw_line(Vector2(left, y), Vector2(right, y), STONE_EDGE, 1.0)
	var n := maxi(int((right - left) / (MERLON * 2.0)), 1)
	var step := (right - left) / float(n * 2 - 1) if n > 1 else right - left
	for i in n:
		draw_rect(Rect2(left + step * 2.0 * i, top - MERLON, step, MERLON), _tint(face))
		draw_rect(Rect2(left + step * 2.0 * i, top - MERLON, step, MERLON), STONE_EDGE, false, 1.2)
	draw_rect(Rect2(left, top, right - left, tall), STONE_EDGE, false, 2.0)

func _slits(left: float, right: float, y: float, count: int) -> void:
	for i in count:
		var x := lerpf(left, right, (float(i) + 0.5) / float(count))
		draw_rect(Rect2(x - 2.5, y - 10.0, 5.0, 20.0), SLIT)

## A pointed slate roof on a tower.
func _cone(x: float, base_y: float, half: float, tall: float) -> void:
	var roof := PackedVector2Array([
		Vector2(x - half, base_y - MERLON), Vector2(x, base_y - MERLON - tall), Vector2(x + half, base_y - MERLON)])
	draw_colored_polygon(roof, _tint(ROOF))
	roof.append(roof[0])
	draw_polyline(roof, ROOF_EDGE, 1.6, true)

func _banner(x: float, top: float, pole: float, flag: Color) -> void:
	draw_line(Vector2(x, top), Vector2(x, top - pole), POLE, 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, top - pole), Vector2(x + 30.0, top - pole + 8.0), Vector2(x, top - pole + 16.0)]), flag)

## What is left of a castle: stumps of the towers and the wall, and a great deal
## of stone lying about. It keeps its footprint, so it still stands in the way.
func _draw_ruin() -> void:
	var foot := _front()
	for side in [-1.0, 1.0]:
		var x: float = side * (WALL_HALF - 4.0)
		draw_rect(Rect2(x - TOWER_HALF, foot - 50.0, TOWER_HALF * 2.0, 50.0), STONE_DARK)
		draw_rect(Rect2(x - TOWER_HALF, foot - 50.0, TOWER_HALF * 2.0, 50.0), STONE_EDGE, false, 1.5)
	draw_rect(Rect2(-KEEP_HALF, foot - 70.0, KEEP_HALF * 2.0, 70.0), STONE_DARK)
	draw_rect(Rect2(-KEEP_HALF, foot - 70.0, KEEP_HALF * 2.0, 70.0), STONE_EDGE, false, 1.5)
	for i in range(28):
		var x := lerpf(-WALL_HALF - 20.0, WALL_HALF + 20.0, float((i * 37) % 28) / 27.0)
		var r := 6.0 + float((i * 11) % 9)
		var y := foot - r * 0.5 - float((i * 13) % 30)
		draw_circle(Vector2(x, y), r, RUBBLE if i % 2 == 0 else RUBBLE_DARK)
