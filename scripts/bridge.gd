class_name Bridge
extends Node2D
## Planks laid over the gap in a river. It blocks nothing: the gap in the water
## is open ground, and this is only the look of it. The bridge runs along its
## wider side, with rails and posts along the two long edges.

const PLANK := Color(0.52, 0.38, 0.22)
const PLANK_DARK := Color(0.40, 0.29, 0.17)
const PLANK_LIGHT := Color(0.62, 0.47, 0.29)
const RAIL := Color(0.30, 0.21, 0.12)
const SHADOW := Color(0.0, 0.0, 0.0, 0.22)

## The span in field coordinates.
@export var span := Rect2()

func _ready() -> void:
	add_to_group("bridges")
	z_index = -1                  # over the water (-2), under people
	queue_redraw()

func _draw() -> void:
	if not span.has_area():
		return
	var along_x := span.size.x >= span.size.y
	var r := span
	draw_rect(r.grow(5.0), SHADOW)
	draw_rect(r, PLANK_DARK)
	var step := 11.0
	if along_x:
		var x := r.position.x + 2.0
		var i := 0
		while x < r.end.x - 2.0:
			draw_rect(Rect2(x, r.position.y + 2.0, step - 2.0, r.size.y - 4.0), PLANK if i % 2 == 0 else PLANK_LIGHT)
			x += step
			i += 1
		for edge_y in [r.position.y, r.end.y]:
			draw_line(Vector2(r.position.x, edge_y), Vector2(r.end.x, edge_y), RAIL, 4.0)
			var post_x := r.position.x
			while post_x <= r.end.x + 0.1:
				draw_rect(Rect2(post_x - 3.0, edge_y - 6.0, 6.0, 10.0), RAIL)
				post_x += 44.0
	else:
		var y := r.position.y + 2.0
		var j := 0
		while y < r.end.y - 2.0:
			draw_rect(Rect2(r.position.x + 2.0, y, r.size.x - 4.0, step - 2.0), PLANK if j % 2 == 0 else PLANK_LIGHT)
			y += step
			j += 1
		for edge_x in [r.position.x, r.end.x]:
			draw_line(Vector2(edge_x, r.position.y), Vector2(edge_x, r.end.y), RAIL, 4.0)
