class_name Boulder
extends Node2D
## A great lump of rock: the walls of a gorge are made of these. It cannot be
## chopped, mined or knocked down; all it does is stand in the way, with a
## static body the navigation floor bakes round like any trunk or wall.

const STONE := Color(0.50, 0.49, 0.47)
const STONE_LIGHT := Color(0.60, 0.59, 0.56)
const STONE_DARK := Color(0.36, 0.35, 0.34)
const STONE_EDGE := Color(0.26, 0.25, 0.25)
const MOSS := Color(0.34, 0.46, 0.27)
const SHADOW := Color(0.0, 0.0, 0.0, 0.22)

## How big this one is: its footprint radius. Its height follows from it.
@export var radius := 38.0

var blocker: StaticBody2D
var shape_seed := 0

func _ready() -> void:
	add_to_group("boulders")
	blocker = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	blocker.add_child(shape)
	add_child(blocker)
	# each one its own lumpy outline, the same every time for the same spot
	shape_seed = int(absf(position.x * 7.0 + position.y * 13.0))
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius * 1.15, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the mass of it: a lumpy dome standing up off its footprint
	var tall := radius * rng.randf_range(1.3, 1.7)
	var outline := PackedVector2Array()
	var points := 11
	for i in points + 1:
		var t := float(i) / float(points)
		var angle := PI + t * PI
		var bulge := rng.randf_range(0.82, 1.08)
		outline.append(Vector2(cos(angle) * radius * 1.1 * bulge, sin(angle) * tall * bulge + radius * 0.25))
	outline.append(Vector2(radius * 1.05, radius * 0.35))
	outline.append(Vector2(-radius * 1.05, radius * 0.35))
	draw_colored_polygon(outline, STONE)
	# a lit face and a dark side, so it reads as a solid
	draw_colored_polygon(PackedVector2Array([Vector2(-radius * 0.2, -tall * 0.85), Vector2(radius * 0.55, -tall * 0.6),
		Vector2(radius * 0.35, -tall * 0.1), Vector2(-radius * 0.35, -tall * 0.25)]), STONE_LIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(-radius * 1.05, radius * 0.3), Vector2(-radius * 0.95, -tall * 0.35),
		Vector2(-radius * 0.55, -tall * 0.1), Vector2(-radius * 0.6, radius * 0.3)]), STONE_DARK)
	var rim := outline.duplicate()
	rim.append(outline[0])
	draw_polyline(rim, STONE_EDGE, 2.0, true)
	# a crack or two and a patch of moss
	var crack := Vector2(rng.randf_range(-0.3, 0.3) * radius, -tall * 0.55)
	draw_polyline(PackedVector2Array([crack, crack + Vector2(radius * 0.15, tall * 0.2), crack + Vector2(radius * 0.05, tall * 0.4)]), STONE_EDGE, 1.3, true)
	draw_circle(Vector2(-radius * 0.35, -tall * 0.78), radius * 0.22, MOSS)
	draw_circle(Vector2(-radius * 0.15, -tall * 0.82), radius * 0.16, MOSS)
