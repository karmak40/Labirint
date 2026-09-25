class_name Icons
extends RefCounted
## Little pictures for the HUD, drawn -- like everything else in the game --
## rather than loaded. Each is laid out on a 32x32 grid and scaled to the box
## it is asked to fill, so one drawing serves a resource counter and a card.

const WOOD := Color(0.66, 0.46, 0.26)
const WOOD_DARK := Color(0.42, 0.28, 0.15)
const WOOD_END := Color(0.86, 0.70, 0.48)
const STONE := Color(0.60, 0.59, 0.57)
const STONE_DARK := Color(0.38, 0.37, 0.36)
const ORE := Color(0.80, 0.62, 0.40)
const GOLD := Color(0.98, 0.80, 0.22)
const GOLD_DARK := Color(0.72, 0.54, 0.10)
const STEEL := Color(0.82, 0.84, 0.88)
const STEEL_DARK := Color(0.50, 0.52, 0.58)
const SKIN := Color(0.93, 0.93, 0.92)
const ROOF_RED := Color(0.62, 0.24, 0.18)
const ROOF_BLUE := Color(0.28, 0.40, 0.62)
const PAGE := Color(0.96, 0.93, 0.84)
const FLAG := Color(0.36, 0.56, 0.90)
const LEAF := Color(0.36, 0.62, 0.30)
const LOCK := Color(0.80, 0.76, 0.66)

## Draws `kind` into `box` on `c`.
static func draw(c: CanvasItem, kind: String, box: Rect2) -> void:
	var s := minf(box.size.x, box.size.y) / 32.0
	var o := box.position + (box.size - Vector2(32.0, 32.0) * s) * 0.5
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match kind:
		"wood":
			for i in 3:
				var y := 10.0 + i * 7.0 - (2.0 if i == 1 else 0.0)
				var x := 4.0 + (4.0 if i == 1 else 0.0)
				c.draw_rect(Rect2(p.call(x, y), Vector2(22.0, 6.0) * s), WOOD)
				c.draw_rect(Rect2(p.call(x, y), Vector2(22.0, 6.0) * s), WOOD_DARK, false, maxf(1.0, s))
				c.draw_circle(p.call(x + 22.0, y + 3.0), 3.0 * s, WOOD_END)
				c.draw_circle(p.call(x + 22.0, y + 3.0), 1.2 * s, WOOD_DARK)
		"ore":
			_rock(c, p, s, STONE, STONE_DARK)
			c.draw_circle(p.call(12.0, 16.0), 3.0 * s, ORE)
			c.draw_circle(p.call(19.0, 20.0), 2.4 * s, ORE)
			c.draw_circle(p.call(20.0, 13.0), 1.8 * s, ORE)
		"gold":
			c.draw_colored_polygon(PackedVector2Array([p.call(6.0, 22.0), p.call(11.0, 10.0), p.call(20.0, 7.0),
				p.call(27.0, 14.0), p.call(26.0, 24.0), p.call(14.0, 27.0)]), GOLD)
			c.draw_polyline(PackedVector2Array([p.call(6.0, 22.0), p.call(11.0, 10.0), p.call(20.0, 7.0),
				p.call(27.0, 14.0), p.call(26.0, 24.0), p.call(14.0, 27.0), p.call(6.0, 22.0)]), GOLD_DARK, maxf(1.0, s * 1.2), true)
			c.draw_circle(p.call(15.0, 13.0), 2.4 * s, Color(1.0, 0.96, 0.72))
		"army":
			_sword(c, p, s, 6.0, 26.0, 26.0, 6.0)
			_sword(c, p, s, 26.0, 26.0, 6.0, 6.0)
		"worker":
			_figure(c, p, s)
			c.draw_line(p.call(20.0, 18.0), p.call(28.0, 8.0), WOOD_DARK, 2.0 * s)
		"woodcutter":
			_figure(c, p, s)
			c.draw_line(p.call(20.0, 20.0), p.call(28.0, 8.0), WOOD_DARK, 2.0 * s)
			c.draw_colored_polygon(PackedVector2Array([p.call(25.0, 6.0), p.call(31.0, 9.0), p.call(28.0, 14.0)]), STEEL)
		"miner", "gold_miner":
			_figure(c, p, s)
			c.draw_line(p.call(19.0, 22.0), p.call(27.0, 6.0), WOOD_DARK, 2.0 * s)
			c.draw_polyline(PackedVector2Array([p.call(21.0, 5.0), p.call(27.0, 6.0), p.call(31.0, 11.0)]),
				GOLD if kind == "gold_miner" else STEEL, 2.4 * s, true)
		"warrior":
			_figure(c, p, s)
			c.draw_line(p.call(19.0, 22.0), p.call(28.0, 7.0), WOOD, 3.0 * s)
			c.draw_circle(p.call(28.0, 7.0), 3.4 * s, WOOD)
		"knight":
			c.draw_colored_polygon(PackedVector2Array([p.call(8.0, 8.0), p.call(24.0, 8.0), p.call(24.0, 18.0),
				p.call(16.0, 28.0), p.call(8.0, 18.0)]), STEEL)
			c.draw_polyline(PackedVector2Array([p.call(8.0, 8.0), p.call(24.0, 8.0), p.call(24.0, 18.0),
				p.call(16.0, 28.0), p.call(8.0, 18.0), p.call(8.0, 8.0)]), STEEL_DARK, maxf(1.0, 1.4 * s), true)
			c.draw_rect(Rect2(p.call(10.0, 13.0), Vector2(12.0, 2.5) * s), STEEL_DARK)
			c.draw_line(p.call(16.0, 8.0), p.call(16.0, 2.0), ROOF_RED, 3.0 * s)
		"tower":
			c.draw_rect(Rect2(p.call(10.0, 9.0), Vector2(12.0, 21.0) * s), STONE)
			c.draw_rect(Rect2(p.call(8.0, 6.0), Vector2(16.0, 5.0) * s), STONE)
			for i in 3:
				c.draw_rect(Rect2(p.call(8.0 + i * 6.0, 3.0), Vector2(4.0, 3.0) * s), STONE)
			c.draw_rect(Rect2(p.call(15.0, 15.0), Vector2(2.0, 6.0) * s), STONE_DARK)
			c.draw_rect(Rect2(p.call(10.0, 9.0), Vector2(12.0, 21.0) * s), STONE_DARK, false, maxf(1.0, s))
		"library":
			c.draw_rect(Rect2(p.call(5.0, 14.0), Vector2(22.0, 15.0) * s), STONE)
			c.draw_colored_polygon(PackedVector2Array([p.call(3.0, 14.0), p.call(16.0, 4.0), p.call(29.0, 14.0)]), ROOF_BLUE)
			c.draw_rect(Rect2(p.call(8.0, 17.0), Vector2(4.0, 7.0) * s), GOLD)
			c.draw_rect(Rect2(p.call(20.0, 17.0), Vector2(4.0, 7.0) * s), GOLD)
			c.draw_rect(Rect2(p.call(14.0, 21.0), Vector2(4.0, 8.0) * s), WOOD_DARK)
		"book", "chivalry", "forging", "mail":
			_book(c, p, s)
			match kind:
				"chivalry":
					c.draw_circle(p.call(24.0, 8.0), 6.0 * s, STEEL)
					c.draw_rect(Rect2(p.call(20.0, 7.0), Vector2(8.0, 2.0) * s), STEEL_DARK)
				"forging":
					_sword(c, p, s, 18.0, 16.0, 29.0, 3.0)
				"mail":
					for i in 3:
						for j in 2:
							c.draw_arc(p.call(20.0 + i * 3.6, 5.0 + j * 3.6), 2.0 * s, 0.0, TAU, 10, STEEL, maxf(1.0, s), true)
		"attack":
			_sword(c, p, s, 5.0, 27.0, 27.0, 5.0)
			c.draw_colored_polygon(PackedVector2Array([p.call(20.0, 4.0), p.call(28.0, 4.0), p.call(28.0, 12.0)]), Color(0.95, 0.4, 0.3))
		"rally":
			c.draw_line(p.call(9.0, 29.0), p.call(9.0, 3.0), WOOD_DARK, 2.4 * s)
			c.draw_colored_polygon(PackedVector2Array([p.call(10.0, 4.0), p.call(27.0, 9.0), p.call(10.0, 15.0)]), FLAG)
		"lock":
			c.draw_arc(p.call(16.0, 13.0), 6.0 * s, PI, TAU, 12, LOCK, 2.6 * s, true)
			c.draw_rect(Rect2(p.call(8.0, 13.0), Vector2(16.0, 13.0) * s), LOCK)
			c.draw_circle(p.call(16.0, 19.0), 2.0 * s, STONE_DARK)
		"build":
			c.draw_line(p.call(8.0, 26.0), p.call(22.0, 12.0), WOOD_DARK, 3.0 * s)
			c.draw_rect(Rect2(p.call(18.0, 5.0), Vector2(11.0, 8.0) * s), STEEL_DARK)
		_:
			c.draw_circle(p.call(16.0, 16.0), 10.0 * s, STONE)

static func _rock(c: CanvasItem, p: Callable, s: float, face: Color, edge: Color) -> void:
	var outline := PackedVector2Array([p.call(4.0, 24.0), p.call(7.0, 12.0), p.call(15.0, 6.0),
		p.call(25.0, 9.0), p.call(28.0, 20.0), p.call(22.0, 27.0), p.call(9.0, 27.0)])
	c.draw_colored_polygon(outline, face)
	outline.append(outline[0])
	c.draw_polyline(outline, edge, maxf(1.0, s * 1.2), true)

static func _sword(c: CanvasItem, p: Callable, s: float, x0: float, y0: float, x1: float, y1: float) -> void:
	var a: Vector2 = p.call(x0, y0)
	var b: Vector2 = p.call(x1, y1)
	var along := (b - a).normalized()
	var guard := a + (b - a) * 0.22
	c.draw_line(a, guard, WOOD_DARK, 2.6 * s)
	c.draw_line(guard, b, STEEL, 2.6 * s)
	c.draw_line(guard - along.orthogonal() * 4.0 * s, guard + along.orthogonal() * 4.0 * s, GOLD_DARK, 2.0 * s)

static func _figure(c: CanvasItem, p: Callable, s: float) -> void:
	c.draw_circle(p.call(12.0, 7.0), 4.0 * s, SKIN)
	c.draw_line(p.call(12.0, 11.0), p.call(12.0, 21.0), SKIN, 2.6 * s)
	c.draw_line(p.call(12.0, 21.0), p.call(7.0, 29.0), SKIN, 2.4 * s)
	c.draw_line(p.call(12.0, 21.0), p.call(17.0, 29.0), SKIN, 2.4 * s)
	c.draw_line(p.call(12.0, 13.0), p.call(20.0, 19.0), SKIN, 2.2 * s)
	c.draw_line(p.call(12.0, 13.0), p.call(6.0, 19.0), SKIN, 2.2 * s)

static func _book(c: CanvasItem, p: Callable, s: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([p.call(16.0, 14.0), p.call(4.0, 11.0), p.call(4.0, 27.0), p.call(16.0, 29.0)]), PAGE)
	c.draw_colored_polygon(PackedVector2Array([p.call(16.0, 14.0), p.call(28.0, 11.0), p.call(28.0, 27.0), p.call(16.0, 29.0)]), PAGE)
	c.draw_line(p.call(16.0, 14.0), p.call(16.0, 29.0), WOOD_DARK, 1.4 * s)
	for i in 3:
		c.draw_line(p.call(6.0, 16.0 + i * 3.5), p.call(13.0, 17.5 + i * 3.5), STONE_DARK, maxf(1.0, s * 0.8))
