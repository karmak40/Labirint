class_name Rock
extends Carriable
## A rock: light enough to carry in both hands and to throw.

const OUTLINE := [          ## deliberately irregular: a circle reads as a ball
	Vector2(-13.0, -2.0),
	Vector2(-9.0, -9.0),
	Vector2(-1.0, -12.0),
	Vector2(7.0, -10.0),
	Vector2(12.0, -3.0),
	Vector2(11.0, 5.0),
	Vector2(3.0, 9.0),
	Vector2(-6.0, 8.0),
	Vector2(-12.0, 4.0),
]
const FACE_COLOR := Color(0.47, 0.46, 0.45)
const EDGE_COLOR := Color(0.63, 0.62, 0.60)
const GOLD_FLECK := Color(0.98, 0.80, 0.18)

## What the stockpile banks it as. The vein that let it go says which.
var resource_kind := "ore"
## How much it is worth at a stockpile.
var amount := 1

func _ready() -> void:
	super()
	grip = Grip.IN_HANDS
	heavy = false
	shadow_radius = 12.0

func _draw() -> void:
	_draw_shadow()
	draw_set_transform(Vector2(0.0, -height), tilt, Vector2.ONE)

	var face := PackedVector2Array()
	for i in OUTLINE.size():
		var point: Vector2 = OUTLINE[i]
		face.append(point)
	draw_colored_polygon(face, FACE_COLOR)

	var rim := face.duplicate()
	rim.append(face[0])
	draw_polyline(rim, EDGE_COLOR, 1.6, true)

	# gold shows in the stone, so a carrier and a heap can be told apart at a glance
	if resource_kind == "gold":
		draw_circle(Vector2(-4.0, -4.0), 2.6, GOLD_FLECK)
		draw_circle(Vector2(4.0, -1.0), 2.0, GOLD_FLECK)
		draw_circle(Vector2(-1.0, 4.0), 1.6, GOLD_FLECK)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
