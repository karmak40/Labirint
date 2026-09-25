extends Node2D
## Draws a faint grid over the floor to sell the top-down perspective.

@export var floor_size: Vector2 = Vector2(900.0, 560.0)
@export var step: float = 40.0

func _draw() -> void:
	var grid_color := Color(1.0, 1.0, 1.0, 0.05)
	var x := 0.0
	while x <= floor_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, floor_size.y), grid_color, 1.0)
		x += step
	var y := 0.0
	while y <= floor_size.y:
		draw_line(Vector2(0.0, y), Vector2(floor_size.x, y), grid_color, 1.0)
		y += step
