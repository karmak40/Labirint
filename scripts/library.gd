class_name Library
extends Building
## Where a side learns: new soldiers, better steel, stronger mail. The learning
## itself is the side's (PlayerState.RESEARCH); this is where it happens, so
## without a library standing -- and finished -- nothing can be studied, and
## burning one down loses whatever was being worked out in it.

const STONE := Color(0.62, 0.60, 0.55)
const STONE_DARK := Color(0.48, 0.46, 0.42)
const STONE_EDGE := Color(0.30, 0.29, 0.27)
const ROOF := Color(0.24, 0.34, 0.52)
const ROOF_EDGE := Color(0.15, 0.22, 0.34)
const WINDOW := Color(0.95, 0.83, 0.48)
const WINDOW_FRAME := Color(0.30, 0.25, 0.18)
const DOOR := Color(0.22, 0.15, 0.10)
const PAGE := Color(0.96, 0.93, 0.84)
const INK := Color(0.30, 0.26, 0.22)
const STUDY := Color(0.55, 0.78, 1.0)

const WALL_TALL := 58.0
const ROOF_TALL := 34.0

func _init() -> void:
	health_max = 600.0
	footprint = Vector2(74.0, 34.0)
	bar_height = 108.0
	bar_width = 70.0

func _ready() -> void:
	super()
	add_to_group("libraries")

## Redrawn while something is being learned, so the bar moves.
func _process(delta: float) -> void:
	super(delta)
	if side != null and side.researching != "" and is_complete():
		queue_redraw()

func _draw_standing() -> void:
	var w := footprint.x * 0.5 + 6.0
	var foot := footprint.y * 0.5
	var top := foot - WALL_TALL
	# the hall, pale dressed stone
	draw_rect(Rect2(-w, top, w * 2.0, WALL_TALL), _tint(STONE))
	draw_rect(Rect2(-w, top, 6.0, WALL_TALL), _tint(STONE_DARK))
	for i in range(1, 4):
		var y := top + WALL_TALL * float(i) / 4.0
		draw_line(Vector2(-w, y), Vector2(w, y), STONE_DARK, 1.0)
	draw_rect(Rect2(-w, top, w * 2.0, WALL_TALL), STONE_EDGE, false, 1.5)
	# a steep blue roof
	var roof := PackedVector2Array([Vector2(-w - 6.0, top), Vector2(0.0, top - ROOF_TALL), Vector2(w + 6.0, top)])
	draw_colored_polygon(roof, _tint(ROOF))
	roof.append(roof[0])
	draw_polyline(roof, ROOF_EDGE, 1.6, true)
	# tall arched windows, lit from inside
	for x in [-w + 12.0, w - 12.0]:
		draw_rect(Rect2(x - 5.0, top + 14.0, 10.0, 22.0), WINDOW)
		draw_circle(Vector2(x, top + 14.0), 5.0, WINDOW)
		draw_rect(Rect2(x - 5.0, top + 14.0, 10.0, 22.0), WINDOW_FRAME, false, 1.2)
		draw_line(Vector2(x, top + 10.0), Vector2(x, top + 36.0), WINDOW_FRAME, 1.0)
	# the door, and an open book over it
	draw_rect(Rect2(-8.0, foot - 24.0, 16.0, 24.0), DOOR)
	draw_circle(Vector2(0.0, foot - 24.0), 8.0, DOOR)
	var book := Vector2(0.0, top + 12.0)
	draw_colored_polygon(PackedVector2Array([book, book + Vector2(-11.0, -3.0), book + Vector2(-11.0, 7.0), book + Vector2(0.0, 9.0)]), PAGE)
	draw_colored_polygon(PackedVector2Array([book, book + Vector2(11.0, -3.0), book + Vector2(11.0, 7.0), book + Vector2(0.0, 9.0)]), PAGE)
	draw_line(book, book + Vector2(0.0, 9.0), INK, 1.2)
	for i in 2:
		draw_line(book + Vector2(-8.0, 1.0 + i * 3.0), book + Vector2(-3.0, 2.0 + i * 3.0), INK, 0.8)
		draw_line(book + Vector2(3.0, 2.0 + i * 3.0), book + Vector2(8.0, 1.0 + i * 3.0), INK, 0.8)
	draw_circle(Vector2(0.0, top - ROOF_TALL * 0.45), 4.5, Team.color(team))
	# and while something is being learned, how far along it is
	if side != null and side.researching != "":
		var at := Vector2(-w, foot + 4.0)
		draw_rect(Rect2(at, Vector2(w * 2.0, 4.0)), BAR_BACK)
		draw_rect(Rect2(at, Vector2(w * 2.0 * side.research_share(), 4.0)), STUDY)
