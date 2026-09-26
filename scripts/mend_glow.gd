class_name MendGlow
extends Node2D
## What a heal looks like: a green thread from the healer's staff to whoever it
## mended, then a glow round them and little crosses rising off them. It follows
## the one healed and is gone in under a second. Presentation only.

const LIFE := 0.9
const THREAD := 0.25           ## how long the thread from the staff shows
const COLOR := Color(0.45, 0.95, 0.50)
const CORE := Color(0.85, 1.0, 0.85)
const HEIGHT := 46.0           ## about the middle of a figure

var patient: Node2D
var source := Vector2.ZERO     ## where the staff was, in world space
var age := 0.0

func _ready() -> void:
	z_index = 5
	if is_instance_valid(patient):
		global_position = patient.global_position

func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	if is_instance_valid(patient):
		global_position = patient.global_position
	queue_redraw()

func _draw() -> void:
	var t := age / LIFE
	var fade := 1.0 - t
	var middle := Vector2(0.0, -HEIGHT)
	if age < THREAD:
		var from := to_local(source)
		var a := 1.0 - age / THREAD
		draw_line(from, middle, Color(COLOR.r, COLOR.g, COLOR.b, 0.5 * a), 4.0)
		draw_line(from, middle, Color(CORE.r, CORE.g, CORE.b, 0.8 * a), 1.5)
	draw_circle(middle, 16.0 + 10.0 * t, Color(COLOR.r, COLOR.g, COLOR.b, 0.22 * fade))
	# a few crosses drifting up and apart
	for i in 4:
		var side := -12.0 + i * 8.0
		var rise := 10.0 + 34.0 * t + float(i % 2) * 8.0
		var at := Vector2(side, -HEIGHT - rise + 20.0)
		var tint := Color(COLOR.r, COLOR.g, COLOR.b, fade)
		draw_rect(Rect2(at - Vector2(1.0, 3.5), Vector2(2.0, 7.0)), tint)
		draw_rect(Rect2(at - Vector2(3.5, 1.0), Vector2(7.0, 2.0)), tint)
