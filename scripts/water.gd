class_name Water
extends Node2D
## A lake or a river: ground nothing can cross, drawn as still water with a wet
## bank round it. It has a static body, so the navigation floor bakes round it
## like a trunk or a wall and people walk round. Arrows and bolts fly over it.
##
## Its outline is in field coordinates (the node sits at the origin), so a map
## lists a lake as plain points. A river with a bridge is two pieces with a
## gap between them, and a `Bridge` laid over the gap.

const BANK := Color(0.40, 0.36, 0.25)
const WET := Color(0.30, 0.34, 0.26)
const SHALLOW := Color(0.30, 0.55, 0.60)
const WATER := Color(0.20, 0.42, 0.55)
const DEEP := Color(0.13, 0.31, 0.45)
const GLINT := Color(0.74, 0.88, 0.92, 0.55)
const FOAM := Color(0.85, 0.93, 0.95, 0.5)

@export var outline := PackedVector2Array()

var blocker: StaticBody2D

func _ready() -> void:
	add_to_group("waters")
	z_index = -2                  # over the land (-3), under everything standing on it
	if outline.size() < 3:
		return
	blocker = StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	blocker.add_child(shape)
	add_child(blocker)
	queue_redraw()

## Whether the water reaches into `area` (grown by `margin`): where nothing is built.
func reaches(area: Rect2, margin := 0.0) -> bool:
	if outline.size() < 3:
		return false
	var grown := area.grow(margin)
	var box := PackedVector2Array([grown.position, Vector2(grown.end.x, grown.position.y), grown.end, Vector2(grown.position.x, grown.end.y)])
	return not Geometry2D.intersect_polygons(outline, box).is_empty()

## Whether `point` is in the water.
func covers(point: Vector2) -> bool:
	return outline.size() >= 3 and Geometry2D.is_point_in_polygon(point, outline)

func _fill(points: PackedVector2Array, color: Color) -> void:
	# an offset can split or vanish; draw whatever pieces are left
	if points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty():
		draw_colored_polygon(points, color)

func _layer(grow: float, color: Color) -> void:
	for piece in Geometry2D.offset_polygon(outline, grow, Geometry2D.JOIN_ROUND):
		_fill(piece, color)

func _draw() -> void:
	if outline.size() < 3:
		return
	_layer(20.0, WET)
	_layer(13.0, BANK)
	_layer(5.0, SHALLOW)
	_layer(0.0, WATER)
	_layer(-26.0, DEEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(outline[0]) ^ outline.size()
	var low := outline[0]
	var high := outline[0]
	for p in outline:
		low = low.min(p)
		high = high.max(p)
	# slow-looking ripples: short pale strokes, only where there is water
	var tries := int((high.x - low.x) * (high.y - low.y) / 1800.0)
	for i in tries:
		var at := Vector2(rng.randf_range(low.x, high.x), rng.randf_range(low.y, high.y))
		if not Geometry2D.is_point_in_polygon(at, outline):
			continue
		var length := rng.randf_range(8.0, 22.0)
		draw_line(at, at + Vector2(length, 0.0), GLINT, 1.4, true)
		draw_line(at + Vector2(length * 0.3, 3.0), at + Vector2(length * 0.9, 3.0), GLINT, 1.0, true)
	# foam along the edge
	var edge := outline.duplicate()
	edge.append(outline[0])
	draw_polyline(edge, FOAM, 1.6, true)
