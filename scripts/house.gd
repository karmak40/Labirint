class_name House
extends Building
## A cottage for the side's people. Every man a side has -- labourer, recruit or
## soldier, and every one still being hired -- needs a roof somewhere: the castle
## houses PlayerState.POP_BASE of them, each finished house POP_HOUSE more
## (PlayerState.pop_cap). Burn the houses and nobody new can be taken on until
## they are built again; those already there stay.

const WALL := Color(0.70, 0.60, 0.44)
const WALL_DARK := Color(0.56, 0.47, 0.34)
const BEAM := Color(0.36, 0.25, 0.15)
const THATCH := Color(0.72, 0.58, 0.30)
const THATCH_DARK := Color(0.55, 0.43, 0.21)
const WINDOW := Color(0.95, 0.80, 0.45)
const DOOR := Color(0.30, 0.20, 0.12)
const SMOKE := Color(0.62, 0.62, 0.62, 0.35)

const WALL_TALL := 26.0
const ROOF_TALL := 22.0

func _init() -> void:
	health_max = 250.0
	footprint = Vector2(46.0, 26.0)
	bar_height = 62.0
	bar_width = 44.0

func _ready() -> void:
	super()
	add_to_group("houses")

func debris_colors() -> Array[Color]:
	return [WALL, BEAM, THATCH]

func _draw_standing() -> void:
	var w := footprint.x * 0.5 + 3.0
	var foot := footprint.y * 0.5
	var top := foot - WALL_TALL
	# whitewashed walls between dark beams
	draw_rect(Rect2(-w, top, w * 2.0, WALL_TALL), _tint(WALL))
	draw_rect(Rect2(-w, top, 5.0, WALL_TALL), _tint(WALL_DARK))
	for x in [-w, -w * 0.3, w * 0.3, w - 2.5]:
		draw_rect(Rect2(x, top, 2.5, WALL_TALL), BEAM)
	draw_line(Vector2(-w, top + 1.0), Vector2(w, top + 1.0), BEAM, 2.0)
	# a thatched roof, overhanging, and a chimney
	var roof := PackedVector2Array([Vector2(-w - 5.0, top + 2.0), Vector2(0.0, top - ROOF_TALL), Vector2(w + 5.0, top + 2.0)])
	draw_colored_polygon(roof, _tint(THATCH))
	for i in 3:
		var y := top - ROOF_TALL * (0.25 + 0.25 * i)
		var half := (w + 5.0) * (1.0 - (0.25 + 0.25 * i))
		draw_line(Vector2(-half, y), Vector2(half, y), THATCH_DARK, 1.0)
	roof.append(roof[0])
	draw_polyline(roof, THATCH_DARK, 1.4, true)
	draw_rect(Rect2(w * 0.35, top - ROOF_TALL * 0.75, 6.0, 12.0), _tint(WALL_DARK))
	draw_circle(Vector2(w * 0.35 + 3.0, top - ROOF_TALL * 0.75 - 6.0), 4.0, SMOKE)
	# a lit window and the door
	draw_rect(Rect2(-w + 7.0, top + 8.0, 8.0, 7.0), WINDOW)
	draw_rect(Rect2(-w + 7.0, top + 8.0, 8.0, 7.0), BEAM, false, 1.0)
	draw_rect(Rect2(3.0, foot - 15.0, 9.0, 15.0), DOOR)
	draw_circle(Vector2(0.0, top - ROOF_TALL * 0.4), 3.0, Team.color(team))
