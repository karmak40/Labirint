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
const FLAME := Color(1.0, 0.62, 0.18)
const FLAME_CORE := Color(1.0, 0.92, 0.55)
const MAGIC := Color(0.55, 0.80, 1.0)
const MEND := Color(0.45, 0.95, 0.50)

## Arms from the forge are drawn as the soldier who carries them; a recruit
## as a labourer; the store of arms as a shield.
const ALIAS := {"spear": "spearman", "bow": "archer", "crossbow": "crossbowman", "axe": "axeman",
	"sword": "swordsman", "dagger": "scout", "torch": "torchbearer", "staff": "mage",
	"recruit": "worker", "arms": "shield"}

## Draws `kind` into `box` on `c`.
static func draw(c: CanvasItem, kind: String, box: Rect2) -> void:
	kind = ALIAS.get(kind, kind)
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
		"spearman":
			_figure(c, p, s)
			c.draw_line(p.call(16.0, 30.0), p.call(28.0, 2.0), WOOD_DARK, 2.0 * s)
			c.draw_colored_polygon(PackedVector2Array([p.call(27.0, 0.0), p.call(31.0, 6.0), p.call(26.0, 5.0)]), STEEL)
		"archer":
			_figure(c, p, s)
			_bow(c, p, s)
		"crossbowman":
			_figure(c, p, s)
			c.draw_line(p.call(16.0, 18.0), p.call(30.0, 14.0), WOOD_DARK, 2.6 * s)
			c.draw_arc(p.call(28.0, 14.0), 5.0 * s, -1.9, 1.3, 10, STEEL, 1.8 * s, true)
		"knight":
			c.draw_colored_polygon(PackedVector2Array([p.call(8.0, 8.0), p.call(24.0, 8.0), p.call(24.0, 18.0),
				p.call(16.0, 28.0), p.call(8.0, 18.0)]), STEEL)
			c.draw_polyline(PackedVector2Array([p.call(8.0, 8.0), p.call(24.0, 8.0), p.call(24.0, 18.0),
				p.call(16.0, 28.0), p.call(8.0, 18.0), p.call(8.0, 8.0)]), STEEL_DARK, maxf(1.0, 1.4 * s), true)
			c.draw_rect(Rect2(p.call(10.0, 13.0), Vector2(12.0, 2.5) * s), STEEL_DARK)
			c.draw_line(p.call(16.0, 8.0), p.call(16.0, 2.0), ROOF_RED, 3.0 * s)
		"axeman":
			_figure(c, p, s)
			_axe(c, p, s, 19.0, 24.0, 27.0, 5.0)
		"swordsman":
			_figure(c, p, s)
			_sword(c, p, s, 19.0, 21.0, 29.0, 4.0)
			c.draw_arc(p.call(12.0, 6.0), 4.4 * s, PI, TAU, 10, STEEL, 2.0 * s, true)
		"greatsword":
			_figure(c, p, s)
			_sword(c, p, s, 17.0, 26.0, 30.0, 0.0)
			c.draw_arc(p.call(12.0, 6.0), 4.4 * s, PI, TAU, 10, STEEL, 2.0 * s, true)
			c.draw_rect(Rect2(p.call(9.0, 12.0), Vector2(6.0, 8.0) * s), STEEL_DARK)
		"scout":
			_figure(c, p, s)
			c.draw_line(p.call(20.0, 19.0), p.call(22.0, 17.0), WOOD_DARK, 2.4 * s)
			c.draw_line(p.call(22.0, 17.0), p.call(28.0, 11.0), STEEL, 2.0 * s)
			c.draw_arc(p.call(12.0, 6.0), 5.0 * s, PI * 0.9, TAU + 0.1, 10, WOOD_DARK, 2.6 * s, true)
		"torchbearer":
			_figure(c, p, s)
			c.draw_line(p.call(19.0, 20.0), p.call(25.0, 9.0), WOOD_DARK, 2.4 * s)
			_flame(c, p, s, 25.5, 7.0, 1.0)
		"mage":
			_figure(c, p, s)
			c.draw_line(p.call(21.0, 30.0), p.call(24.0, 6.0), WOOD, 2.2 * s)
			c.draw_circle(p.call(24.0, 5.0), 4.6 * s, Color(MAGIC.r, MAGIC.g, MAGIC.b, 0.35))
			c.draw_circle(p.call(24.0, 5.0), 2.6 * s, MAGIC)
			c.draw_colored_polygon(PackedVector2Array([p.call(7.0, 4.0), p.call(12.0, -2.0), p.call(17.0, 4.0)]), ROOF_BLUE)
		"tower":
			c.draw_rect(Rect2(p.call(10.0, 9.0), Vector2(12.0, 21.0) * s), STONE)
			c.draw_rect(Rect2(p.call(8.0, 6.0), Vector2(16.0, 5.0) * s), STONE)
			for i in 3:
				c.draw_rect(Rect2(p.call(8.0 + i * 6.0, 3.0), Vector2(4.0, 3.0) * s), STONE)
			c.draw_rect(Rect2(p.call(15.0, 15.0), Vector2(2.0, 6.0) * s), STONE_DARK)
			c.draw_rect(Rect2(p.call(10.0, 9.0), Vector2(12.0, 21.0) * s), STONE_DARK, false, maxf(1.0, s))
		"barracks":
			c.draw_rect(Rect2(p.call(5.0, 15.0), Vector2(22.0, 14.0) * s), WOOD)
			for i in 3:
				c.draw_line(p.call(5.0, 18.5 + i * 3.5), p.call(27.0, 18.5 + i * 3.5), WOOD_DARK, maxf(1.0, s))
			c.draw_colored_polygon(PackedVector2Array([p.call(3.0, 15.0), p.call(16.0, 6.0), p.call(29.0, 15.0)]), ROOF_RED)
			c.draw_rect(Rect2(p.call(13.0, 21.0), Vector2(6.0, 8.0) * s), WOOD_DARK)
			c.draw_line(p.call(24.0, 8.0), p.call(24.0, 1.0), WOOD_DARK, 1.6 * s)
			c.draw_colored_polygon(PackedVector2Array([p.call(24.5, 1.0), p.call(31.0, 3.0), p.call(24.5, 5.5)]), FLAG)
		"forge":
			c.draw_rect(Rect2(p.call(4.0, 14.0), Vector2(24.0, 15.0) * s), STONE_DARK)
			c.draw_colored_polygon(PackedVector2Array([p.call(2.0, 14.0), p.call(7.0, 7.0), p.call(25.0, 7.0), p.call(30.0, 14.0)]), WOOD_DARK)
			c.draw_rect(Rect2(p.call(20.0, 1.0), Vector2(5.0, 9.0) * s), STONE)
			c.draw_rect(Rect2(p.call(7.0, 19.0), Vector2(8.0, 7.0) * s), FLAME)
			c.draw_rect(Rect2(p.call(9.0, 22.0), Vector2(4.0, 4.0) * s), FLAME_CORE)
			c.draw_rect(Rect2(p.call(18.0, 21.0), Vector2(8.0, 3.0) * s), STEEL_DARK)
			c.draw_rect(Rect2(p.call(20.5, 24.0), Vector2(3.0, 4.0) * s), STEEL_DARK)
		"smith":
			_figure(c, p, s)
			c.draw_line(p.call(19.0, 20.0), p.call(26.0, 9.0), WOOD_DARK, 2.2 * s)
			c.draw_colored_polygon(PackedVector2Array([p.call(22.0, 6.0), p.call(29.0, 10.5), p.call(27.0, 13.5), p.call(20.0, 9.0)]), STEEL_DARK)
			c.draw_rect(Rect2(p.call(20.0, 26.0), Vector2(11.0, 3.0) * s), STEEL_DARK)
			c.draw_rect(Rect2(p.call(23.5, 29.0), Vector2(4.0, 3.0) * s), STEEL_DARK)
		"helm":
			c.draw_colored_polygon(PackedVector2Array([p.call(6.0, 24.0), p.call(6.0, 14.0), p.call(10.0, 7.0), p.call(16.0, 5.0),
				p.call(22.0, 7.0), p.call(26.0, 14.0), p.call(26.0, 24.0)]), STEEL)
			c.draw_rect(Rect2(p.call(9.0, 15.0), Vector2(14.0, 3.0) * s), STEEL_DARK)
			c.draw_rect(Rect2(p.call(14.5, 18.0), Vector2(3.0, 7.0) * s), STEEL_DARK)
			c.draw_line(p.call(16.0, 5.0), p.call(16.0, 1.0), ROOF_RED, 2.4 * s)
		"armour":
			c.draw_colored_polygon(PackedVector2Array([p.call(8.0, 6.0), p.call(13.0, 8.0), p.call(19.0, 8.0), p.call(24.0, 6.0),
				p.call(29.0, 11.0), p.call(24.0, 15.0), p.call(23.0, 28.0), p.call(9.0, 28.0), p.call(8.0, 15.0), p.call(3.0, 11.0)]), STEEL)
			c.draw_line(p.call(16.0, 9.0), p.call(16.0, 27.0), STEEL_DARK, maxf(1.0, s))
			c.draw_line(p.call(9.5, 19.0), p.call(22.5, 19.0), STEEL_DARK, maxf(1.0, s))
			c.draw_line(p.call(9.5, 23.5), p.call(22.5, 23.5), STEEL_DARK, maxf(1.0, s))
		"shield":
			var face := PackedVector2Array([p.call(6.0, 5.0), p.call(26.0, 5.0), p.call(26.0, 16.0), p.call(16.0, 29.0), p.call(6.0, 16.0)])
			c.draw_colored_polygon(face, WOOD)
			face.append(face[0])
			c.draw_polyline(face, STEEL_DARK, 2.0 * s, true)
			c.draw_line(p.call(16.0, 6.0), p.call(16.0, 27.0), ROOF_BLUE, 3.0 * s)
			c.draw_line(p.call(7.0, 12.0), p.call(25.0, 12.0), ROOF_BLUE, 3.0 * s)
		"library":
			c.draw_rect(Rect2(p.call(5.0, 14.0), Vector2(22.0, 15.0) * s), STONE)
			c.draw_colored_polygon(PackedVector2Array([p.call(3.0, 14.0), p.call(16.0, 4.0), p.call(29.0, 14.0)]), ROOF_BLUE)
			c.draw_rect(Rect2(p.call(8.0, 17.0), Vector2(4.0, 7.0) * s), GOLD)
			c.draw_rect(Rect2(p.call(20.0, 17.0), Vector2(4.0, 7.0) * s), GOLD)
			c.draw_rect(Rect2(p.call(14.0, 21.0), Vector2(4.0, 8.0) * s), WOOD_DARK)
		"book", "chivalry", "forging", "mail", "spears", "archery", "crossbows", 				"axes", "blades", "greatswords", "daggers", "fire", "magic", "healing":
			_book(c, p, s)
			match kind:
				"spears":
					c.draw_line(p.call(18.0, 12.0), p.call(30.0, 1.0), WOOD_DARK, 1.8 * s)
					c.draw_colored_polygon(PackedVector2Array([p.call(29.0, 0.0), p.call(32.0, 4.0), p.call(28.0, 3.0)]), STEEL)
				"archery":
					c.draw_arc(p.call(22.0, 8.0), 7.0 * s, -2.2, 0.6, 12, WOOD, 2.0 * s, true)
					c.draw_line(p.call(17.0, 2.0), p.call(27.0, 12.0), WOOD_END, 1.0 * s)
				"crossbows":
					c.draw_line(p.call(17.0, 9.0), p.call(30.0, 6.0), WOOD_DARK, 2.2 * s)
					c.draw_arc(p.call(28.0, 7.0), 4.5 * s, -1.9, 1.3, 10, STEEL, 1.6 * s, true)
				"chivalry":
					c.draw_circle(p.call(24.0, 8.0), 6.0 * s, STEEL)
					c.draw_rect(Rect2(p.call(20.0, 7.0), Vector2(8.0, 2.0) * s), STEEL_DARK)
				"forging":
					_sword(c, p, s, 18.0, 16.0, 29.0, 3.0)
				"axes":
					_axe(c, p, s, 19.0, 13.0, 26.0, 2.0)
				"blades":
					_sword(c, p, s, 19.0, 12.0, 28.0, 2.0)
				"greatswords":
					_sword(c, p, s, 17.0, 14.0, 31.0, 0.0)
					_sword(c, p, s, 31.0, 14.0, 17.0, 0.0)
				"daggers":
					c.draw_line(p.call(20.0, 11.0), p.call(22.0, 9.0), WOOD_DARK, 2.2 * s)
					c.draw_line(p.call(22.0, 9.0), p.call(28.0, 3.0), STEEL, 1.8 * s)
				"fire":
					_flame(c, p, s, 24.0, 8.0, 1.1)
				"magic":
					c.draw_circle(p.call(24.0, 7.0), 6.0 * s, Color(MAGIC.r, MAGIC.g, MAGIC.b, 0.35))
					c.draw_circle(p.call(24.0, 7.0), 3.4 * s, MAGIC)
					c.draw_circle(p.call(24.0, 7.0), 1.4 * s, Color(0.95, 0.98, 1.0))
				"healing":
					c.draw_circle(p.call(24.0, 7.0), 6.5 * s, Color(MEND.r, MEND.g, MEND.b, 0.3))
					c.draw_rect(Rect2(p.call(22.5, 2.0), Vector2(3.0, 10.0) * s), MEND)
					c.draw_rect(Rect2(p.call(19.0, 5.5), Vector2(10.0, 3.0) * s), MEND)
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

## Which kind of building this is, by the name the build list and icons use.
static func site_of(building: Building) -> String:
	if building is Tower:
		return "tower"
	if building is Forge:
		return "forge"
	if building is Library:
		return "library"
	return "barracks"

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

## A haft from (x0, y0) to its head at (x1, y1), with a blade out to one side.
static func _axe(c: CanvasItem, p: Callable, s: float, x0: float, y0: float, x1: float, y1: float) -> void:
	c.draw_line(p.call(x0, y0), p.call(x1, y1), WOOD_DARK, 2.2 * s)
	c.draw_colored_polygon(PackedVector2Array([p.call(x1 - 1.0, y1 + 1.0), p.call(x1 + 5.0, y1 - 2.0),
		p.call(x1 + 6.0, y1 + 5.0), p.call(x1, y1 + 4.0)]), STEEL)

## A tongue of fire standing on (x, y).
static func _flame(c: CanvasItem, p: Callable, s: float, x: float, y: float, k: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([p.call(x - 4.0 * k, y), p.call(x - 2.0 * k, y - 5.0 * k),
		p.call(x, y - 10.0 * k), p.call(x + 2.5 * k, y - 5.0 * k), p.call(x + 4.0 * k, y)]), FLAME)
	c.draw_colored_polygon(PackedVector2Array([p.call(x - 2.0 * k, y), p.call(x, y - 5.5 * k),
		p.call(x + 2.0 * k, y)]), FLAME_CORE)

static func _figure(c: CanvasItem, p: Callable, s: float) -> void:
	c.draw_circle(p.call(12.0, 7.0), 4.0 * s, SKIN)
	c.draw_line(p.call(12.0, 11.0), p.call(12.0, 21.0), SKIN, 2.6 * s)
	c.draw_line(p.call(12.0, 21.0), p.call(7.0, 29.0), SKIN, 2.4 * s)
	c.draw_line(p.call(12.0, 21.0), p.call(17.0, 29.0), SKIN, 2.4 * s)
	c.draw_line(p.call(12.0, 13.0), p.call(20.0, 19.0), SKIN, 2.2 * s)
	c.draw_line(p.call(12.0, 13.0), p.call(6.0, 19.0), SKIN, 2.2 * s)

static func _bow(c: CanvasItem, p: Callable, s: float) -> void:
	c.draw_arc(p.call(20.0, 16.0), 11.0 * s, -1.3, 1.3, 14, WOOD, 2.4 * s, true)
	c.draw_line(p.call(24.0, 5.5), p.call(24.0, 26.5), WOOD_END, 1.0 * s)

static func _book(c: CanvasItem, p: Callable, s: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([p.call(16.0, 14.0), p.call(4.0, 11.0), p.call(4.0, 27.0), p.call(16.0, 29.0)]), PAGE)
	c.draw_colored_polygon(PackedVector2Array([p.call(16.0, 14.0), p.call(28.0, 11.0), p.call(28.0, 27.0), p.call(16.0, 29.0)]), PAGE)
	c.draw_line(p.call(16.0, 14.0), p.call(16.0, 29.0), WOOD_DARK, 1.4 * s)
	for i in 3:
		c.draw_line(p.call(6.0, 16.0 + i * 3.5), p.call(13.0, 17.5 + i * 3.5), STONE_DARK, maxf(1.0, s * 0.8))
