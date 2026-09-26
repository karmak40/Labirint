class_name Forge
extends Building
## Where a side's arms and kit are made, one piece at a time on each of its two
## anvils: spears, bows, swords and the rest, and helms, plate and shields.
## Nothing gets made without a smith (a Worker given the "smith" job) standing
## at an anvil and swinging the hammer; every blow that lands moves the piece
## on that anvil along (hammer_blow). A finished piece goes to the side's store
## (PlayerState.receive_gear): a weapon waits there for a recruit to come and
## collect it, kit goes straight on a soldier who has none unless an order has
## it put by. Burn the forge down and whatever was on the list is lost with it.

signal forged(item: String)

## `work` is how many seconds of hammering a piece takes: BLOW_WORK a blow.
## A weapon's `weapon` is what a recruit carrying it holds; which soldier needs
## which pieces is ProductionBuilding.CATALOG's `arms`, and a piece may be
## made once any soldier who needs it can be fielded (PlayerState.knows_recipe).
const GEAR := {
	"spear": {"title": "Копьё", "about": "Оружие копейщика.",
		"cost": {"wood": 10, "ore": 5}, "work": 4.0, "weapon": PlayerBody.Weapon.SPEAR},
	"bow": {"title": "Лук", "about": "Оружие лучника.",
		"cost": {"wood": 15}, "work": 4.0, "weapon": PlayerBody.Weapon.BOW},
	"crossbow": {"title": "Арбалет", "about": "Оружие арбалетчика.",
		"cost": {"wood": 10, "ore": 15}, "work": 7.0, "weapon": PlayerBody.Weapon.CROSSBOW},
	"axe": {"title": "Секира", "about": "Оружие секироносца.",
		"cost": {"wood": 10, "ore": 10}, "work": 5.0, "weapon": PlayerBody.Weapon.AXE},
	"sword": {"title": "Меч", "about": "Оружие мечника и рыцаря.",
		"cost": {"wood": 5, "ore": 15}, "work": 6.0, "weapon": PlayerBody.Weapon.SWORD},
	"greatsword": {"title": "Двуручный меч", "about": "Оружие двуручника.",
		"cost": {"wood": 5, "ore": 25}, "work": 9.0, "weapon": PlayerBody.Weapon.GREATSWORD},
	"dagger": {"title": "Кинжал", "about": "Оружие лазутчика.",
		"cost": {"ore": 5}, "work": 2.0, "weapon": PlayerBody.Weapon.DAGGER},
	"torch": {"title": "Факел", "about": "Оружие поджигателя.",
		"cost": {"wood": 10}, "work": 1.0, "weapon": PlayerBody.Weapon.TORCH},
	"staff": {"title": "Посох", "about": "Оружие мага.",
		"cost": {"wood": 15, "ore": 15}, "work": 8.0, "weapon": PlayerBody.Weapon.STAFF},
	"helm": {"title": "Шлем", "about": "Бережёт голову: −10% урона. Надевает боец без шлема.",
		"cost": {"ore": 15}, "work": 6.0},
	"armour": {"title": "Латы", "about": "−20% урона. Надевает боец без доспеха.",
		"cost": {"ore": 30, "wood": 10}, "work": 10.0},
	"shield": {"title": "Щит", "about": "−30% урона от ударов и стрел спереди. Только к одноручному оружию: дубине, секире, мечу, кинжалу, факелу.",
		"cost": {"wood": 20, "ore": 5}, "work": 6.0},
}
## Pieces a soldier wears rather than wields: they go on whoever lacks them.
const KIT := ["helm", "armour", "shield"]
const QUEUE_MAX := 5           ## pieces ordered by hand; an order's pieces are never refused
const BLOW_WORK := 0.75        ## what one blow of the hammer is worth
## The anvils, out in front of the door where a smith can get at them, and
## where each smith stands to his (to its left, facing right).
const ANVILS := [Vector2(-22.0, 34.0), Vector2(36.0, 34.0)]
const SMITH_OFFSET := Vector2(-30.0, 2.0)
const ANVIL_SIZE := 1.4
## Where recruits come for their arms, in front of the forge.
const COLLECT := Vector2(0.0, 70.0)

const STONE := Color(0.46, 0.44, 0.42)
const STONE_DARK := Color(0.34, 0.32, 0.31)
const STONE_EDGE := Color(0.22, 0.21, 0.20)
const ROOF := Color(0.30, 0.24, 0.20)
const ROOF_EDGE := Color(0.18, 0.14, 0.11)
const FIRE := Color(1.0, 0.55, 0.15)
const FIRE_CORE := Color(1.0, 0.88, 0.45)
const IRON := Color(0.25, 0.25, 0.28)
const IRON_EDGE := Color(0.12, 0.12, 0.14)
const HOT := Color(1.0, 0.45, 0.12)
const STUMP := Color(0.42, 0.30, 0.19)
const SMOKE := Color(0.55, 0.55, 0.55, 0.35)
const WORK := Color(1.0, 0.70, 0.30)
const SPARK_TIME := 0.18

const WALL_TALL := 44.0
const ROOF_TALL := 20.0

var queue: Array[String] = []  ## waiting for an anvil
var on_anvil: Array[String] = ["", ""]   ## what each anvil has on it, "" for nothing
var worked: Array[float] = [0.0, 0.0]    ## and how far along it is
var _glow := 0.0
var _spark := [1.0, 1.0]       ## seconds since the last blow on each anvil

func _init() -> void:
	health_max = 550.0
	footprint = Vector2(70.0, 32.0)
	bar_height = 96.0
	bar_width = 66.0

func _ready() -> void:
	super()
	add_to_group("forges")

## Whether `item` can be ordered by hand: known, paid for, and room on the list.
func can_forge(item: String) -> bool:
	return is_alive() and is_complete() and side != null and GEAR.has(item) 		and queue.size() < QUEUE_MAX and side.knows_recipe(item) and side.economy.can_afford(GEAR[item]["cost"])

## Pays and puts a piece on the list. False, and nothing taken, if it can not.
func queue_gear(item: String) -> bool:
	if not can_forge(item) or not side.economy.spend(GEAR[item]["cost"]):
		return false
	queue.append(item)
	queue_redraw()
	return true

## A piece already paid for, for an order: onto the list whatever its length.
func queue_paid(item: String) -> void:
	queue.append(item)
	queue_redraw()

## How many of `item` are on the list or on an anvil.
func pending(item: String) -> int:
	return queue.count(item) + on_anvil.count(item)

## Everything still to make, on the anvils first.
func all_pending() -> Array[String]:
	var all: Array[String] = []
	for item in on_anvil:
		if item != "":
			all.append(item)
	all.append_array(queue)
	return all

## How far along the furthest piece of `item` is (or of anything, for ""), 0 to 1.
func current_share(item: String = "") -> float:
	var best := 0.0
	for i in ANVILS.size():
		if on_anvil[i] != "" and (item == "" or on_anvil[i] == item):
			best = maxf(best, clampf(worked[i] / float(GEAR[on_anvil[i]]["work"]), 0.0, 1.0))
	return best

## Whether there is anything for the smith at anvil `anvil` to beat out.
func has_work(anvil: int = -1) -> bool:
	if not is_alive() or not is_complete():
		return false
	if anvil < 0:
		return not queue.is_empty() or on_anvil[0] != "" or on_anvil[1] != ""
	return on_anvil[anvil] != "" or not queue.is_empty()

## Where the smith at `anvil` stands, in the world.
func smith_spot(anvil: int = 0) -> Vector2:
	return global_position + ANVILS[anvil] + SMITH_OFFSET

func anvil_point(anvil: int = 0) -> Vector2:
	return global_position + ANVILS[anvil]

## Where a recruit waits for his arms; `slot` spreads a crowd of them out.
func collect_point(slot: int = 0) -> Vector2:
	return global_position + COLLECT + Vector2(float(slot % 5 - 2) * 16.0, float(slot / 5 % 2) * 14.0)

## A blow of the hammer on anvil `anvil`: the piece on it moves along, and a
## bare anvil takes the next piece off the list.
func hammer_blow(anvil: int = 0) -> void:
	if not has_work(anvil):
		return
	if on_anvil[anvil] == "":
		on_anvil[anvil] = queue.pop_front()
		worked[anvil] = 0.0
	_spark[anvil] = 0.0
	worked[anvil] += BLOW_WORK
	if worked[anvil] >= float(GEAR[on_anvil[anvil]]["work"]):
		var item := on_anvil[anvil]
		on_anvil[anvil] = ""
		worked[anvil] = 0.0
		if side != null:
			side.receive_gear(item)
		forged.emit(item)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_tick_construction(delta)

## The fire flickers and the sparks fly while there is work on; redrawn only then.
func _process(delta: float) -> void:
	super(delta)
	if (has_work() or _spark.min() < SPARK_TIME) and is_complete():
		_glow += delta
		for i in _spark.size():
			_spark[i] += delta
		queue_redraw()

func _draw_standing() -> void:
	var w := footprint.x * 0.5 + 6.0
	var foot := footprint.y * 0.5
	var top := foot - WALL_TALL
	# a low smithy of rough stone
	draw_rect(Rect2(-w, top, w * 2.0, WALL_TALL), _tint(STONE))
	draw_rect(Rect2(-w, top, 6.0, WALL_TALL), _tint(STONE_DARK))
	for i in range(1, 3):
		var y := top + WALL_TALL * float(i) / 3.0
		draw_line(Vector2(-w, y), Vector2(w, y), STONE_DARK, 1.0)
	draw_rect(Rect2(-w, top, w * 2.0, WALL_TALL), STONE_EDGE, false, 1.5)
	# a lean roof, and the chimney standing out of it
	var roof := PackedVector2Array([Vector2(-w - 5.0, top), Vector2(-w + 8.0, top - ROOF_TALL),
		Vector2(w - 8.0, top - ROOF_TALL), Vector2(w + 5.0, top)])
	draw_colored_polygon(roof, _tint(ROOF))
	roof.append(roof[0])
	draw_polyline(roof, ROOF_EDGE, 1.5, true)
	var chimney := Rect2(w - 22.0, top - ROOF_TALL - 20.0, 12.0, 26.0)
	draw_rect(chimney, _tint(STONE_DARK))
	draw_rect(chimney, STONE_EDGE, false, 1.2)
	var working := has_work()
	if working:
		for i in 3:
			var drift := fmod(_glow * 0.8 + i * 0.33, 1.0)
			draw_circle(Vector2(chimney.get_center().x + drift * 8.0, chimney.position.y - 4.0 - drift * 22.0),
				4.0 + drift * 5.0, Color(SMOKE, SMOKE.a * (1.0 - drift)))
	# the open hearth: a glow that brightens while there is work on
	var hearth := Rect2(-w + 8.0, foot - 24.0, 22.0, 18.0)
	draw_rect(hearth, Color(0.10, 0.07, 0.05))
	var flicker := 0.75 + 0.25 * sin(_glow * 11.0) if working else 0.45
	draw_rect(Rect2(hearth.position + Vector2(3.0, 7.0), Vector2(16.0, 11.0)), Color(FIRE, flicker))
	draw_rect(Rect2(hearth.position + Vector2(7.0, 11.0), Vector2(8.0, 7.0)), Color(FIRE_CORE, flicker))
	draw_rect(hearth, STONE_EDGE, false, 1.2)
	# the door, and the side's banner under the eaves
	draw_rect(Rect2(w - 22.0, foot - 22.0, 14.0, 22.0), Color(0.22, 0.15, 0.10))
	draw_circle(Vector2(0.0, top - ROOF_TALL * 0.5), 4.5, Team.color(team))
	for i in ANVILS.size():
		_draw_anvil(i)
		# and while something is on an anvil, how far along it is, under it
		if on_anvil[i] != "":
			var at: Vector2 = ANVILS[i] + Vector2(-18.0, 6.0)
			draw_rect(Rect2(at, Vector2(36.0, 4.0)), BAR_BACK)
			draw_rect(Rect2(at, Vector2(36.0 * worked[i] / float(GEAR[on_anvil[i]]["work"]), 4.0)), WORK)

## The anvil on its stump, with the piece being worked glowing on it, and a
## spray of sparks for a moment after every blow.
func _draw_anvil(anvil: int) -> void:
	draw_set_transform(ANVILS[anvil], 0.0, Vector2.ONE * ANVIL_SIZE)
	var a := Vector2.ZERO
	draw_rect(Rect2(a + Vector2(-6.0, -8.0), Vector2(12.0, 8.0)), STUMP)
	draw_line(a + Vector2(-6.0, -8.0), a + Vector2(6.0, -8.0), Color(0.30, 0.21, 0.13), 1.0)
	draw_rect(Rect2(a + Vector2(-4.0, -14.0), Vector2(8.0, 6.0)), IRON)
	var face := PackedVector2Array([a + Vector2(-12.0, -20.0), a + Vector2(9.0, -20.0),
		a + Vector2(16.0, -17.0), a + Vector2(7.0, -14.0), a + Vector2(-10.0, -14.0)])
	draw_colored_polygon(face, IRON)
	draw_line(a + Vector2(-12.0, -20.0), a + Vector2(9.0, -20.0), IRON_EDGE, 1.2)
	if on_anvil[anvil] != "":
		draw_rect(Rect2(a + Vector2(-5.0, -23.0), Vector2(9.0, 3.0)), HOT)
	if _spark[anvil] < SPARK_TIME:
		var fly: float = _spark[anvil] / SPARK_TIME
		for i in 6:
			var angle := -PI * 0.5 + (i - 2.5) * 0.42
			var from := a + Vector2(0.0, -22.0)
			var dir := Vector2.from_angle(angle)
			draw_line(from + dir * 4.0 * fly, from + dir * (5.0 + 12.0 * fly), Color(FIRE_CORE, 1.0 - fly), 1.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
