class_name ProductionBuilding
extends Building
## Where a side hires. At the castle that is labourers, and the recruits an
## order for a soldier needs (PlayerState.order_soldier); at a barracks it is
## where a recruit who has collected his arms trains (`train`) and comes out a
## soldier. `queue_unit(kind)` still hires outright, paying the catalogue price,
## for test scenes that have no forge.

signal unit_ready(unit: PlayerBody)

## Everything that can be hired here. Plain data, so costs are balanced in one place.
const CATALOG := {
	# Labourers, hired at the castle. They are all the same man: "worker" goes to
	# whichever of wood and ore is shorter of hands, and is moved between trades
	# afterwards (PlayerState.move_worker); the other three are the same hire
	# sent straight to one trade, for the AI. `pay_any` is paid in whichever of
	# wood and ore the store has more of, so a side that has run out of one can
	# still hire the hands to get more of it. `cost` is only what a card shows.
	"worker": {"scene": "res://scenes/worker/Worker.tscn", "job": "auto", "pay_any": 10, "cost": {"wood": 10}, "time": 4.0},
	"woodcutter": {"scene": "res://scenes/worker/Worker.tscn", "job": "wood", "pay_any": 10, "cost": {"wood": 10}, "time": 4.0},
	"miner": {"scene": "res://scenes/worker/Worker.tscn", "job": "ore", "pay_any": 10, "cost": {"wood": 10}, "time": 4.0},
	"gold_miner": {"scene": "res://scenes/worker/Worker.tscn", "job": "gold", "pay_any": 10, "cost": {"wood": 10}, "time": 4.0},
	# the man an order for a soldier is filled with: he goes for his arms
	"recruit": {"scene": "res://scenes/worker/Worker.tscn", "job": "recruit", "pay_any": 10, "cost": {"wood": 10}, "time": 2.5},
	# Soldiers. `arms` are what a recruit collects to become one: pieces from the
	# forge (Forge.GEAR), or the club, which the castle hands out for nothing.
	# `requires` is the study that teaches how to make them; `cost` and `time`
	# are only for hiring outright (queue_unit).
	# the first soldier anyone can put in the field
	"warrior": {"scene": "res://scenes/warrior/Warrior.tscn", "arms": ["club"], "cost": {"wood": 15}, "time": 5.0},
	# everything past the warrior has to be learned first (PlayerState.RESEARCH)
	"spearman": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "spearman", "arms": ["spear"], "cost": {"wood": 15, "ore": 5}, "time": 5.0, "requires": "spears"},
	"archer": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "archer", "arms": ["bow"], "cost": {"wood": 20}, "time": 5.0, "requires": "archery"},
	"crossbowman": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "crossbowman", "arms": ["crossbow"], "cost": {"wood": 15, "ore": 15}, "time": 6.0, "requires": "crossbows"},
	"knight": {"scene": "res://scenes/knight/Knight.tscn", "arms": ["sword", "helm", "armour", "shield"], "cost": {"wood": 20, "ore": 20}, "time": 6.0, "requires": "chivalry"},
	"axeman": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "axeman", "arms": ["axe"], "cost": {"wood": 20, "ore": 5}, "time": 5.0, "requires": "axes"},
	"swordsman": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "swordsman", "arms": ["sword"], "cost": {"wood": 15, "ore": 15}, "time": 6.0, "requires": "blades"},
	"greatsword": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "greatsword", "arms": ["greatsword"], "cost": {"wood": 20, "ore": 25}, "time": 7.0, "requires": "greatswords"},
	"scout": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "scout", "arms": ["dagger"], "cost": {"wood": 10}, "time": 4.0, "requires": "daggers"},
	"torchbearer": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "torchbearer", "arms": ["torch"], "cost": {"wood": 15}, "time": 5.0, "requires": "fire"},
	"mage": {"scene": "res://scenes/warrior/Warrior.tscn", "loadout": "mage", "arms": ["staff"], "cost": {"wood": 25, "ore": 15}, "time": 7.0, "requires": "magic"},
}
const QUEUE_MAX := 5
const TRAIN_TIME := 3.0        ## how long an armed recruit trains in the barracks
const DOOR_OUT := Vector2(0.0, 34.0)   ## where a recruit is put down: just outside the door

const TIMBER := Color(0.52, 0.39, 0.25)
const TIMBER_DARK := Color(0.40, 0.29, 0.18)
const TIMBER_EDGE := Color(0.27, 0.19, 0.12)
const ROOF := Color(0.45, 0.20, 0.16)
const ROOF_EDGE := Color(0.30, 0.13, 0.10)
const DOOR := Color(0.20, 0.14, 0.09)
const PROGRESS := Color(0.95, 0.85, 0.45)

const WALL_HEIGHT := 40.0
const ROOF_HEIGHT := 30.0

## What it can hire; a subset of CATALOG.
## Soldiers for a barracks; the castle (Base) hires the labourers.
@export var kinds: PackedStringArray = PackedStringArray(SOLDIERS)
const SOLDIERS := ["warrior", "spearman", "archer", "crossbowman", "knight",
	"axeman", "swordsman", "greatsword", "scout", "torchbearer", "mage"]
const LABOURERS := ["worker", "woodcutter", "miner", "gold_miner"]
## Where recruits go and stand, relative to the building, until told otherwise.
@export var rally_offset := Vector2(0.0, 90.0)

var queue: Array[String] = []
var times: Array[float] = []   ## how long each in the queue takes, alongside it
var progress := 0.0
var rally_point := Vector2.INF

func _init() -> void:
	health_max = 500.0
	footprint = Vector2(60.0, 28.0)
	bar_height = 84.0

func _ready() -> void:
	super()
	if rally_point == Vector2.INF:
		rally_point = global_position + rally_offset

## Where finished recruits should walk to.
func set_rally_point(point: Vector2) -> void:
	rally_point = point

func can_hire(kind: String) -> bool:
	return is_alive() and is_complete() and side != null and kinds.has(kind) and queue.size() < QUEUE_MAX \
		and is_unlocked(kind) and side.economy.can_afford(price_for(kind))

## What hiring one costs right now, out of this side's store.
func price_for(kind: String) -> Dictionary:
	var entry: Dictionary = CATALOG[kind]
	if not entry.has("pay_any"):
		return entry["cost"]
	var store := side.economy if side != null else null
	var from := "ore" if store != null and store.ore > store.wood else "wood"
	return {from: int(entry["pay_any"])}

## Whether the side knows how to field one at all, whatever it can afford.
func is_unlocked(kind: String) -> bool:
	var needs: String = CATALOG[kind].get("requires", "")
	return needs == "" or (side != null and side.has_researched(needs))

## Pays and puts a recruit in the queue. False, and nothing taken, if it can not.
func queue_unit(kind: String) -> bool:
	if not can_hire(kind):
		return false
	if not side.economy.spend(price_for(kind)):
		return false
	_enqueue(kind, float(CATALOG[kind]["time"]))
	return true

## Already paid for (an order's recruit): onto the queue whatever its length.
func queue_paid(kind: String) -> void:
	_enqueue(kind, float(CATALOG[kind]["time"]))

## An armed recruit comes in to train, and will come out a `kind`.
func train(kind: String) -> void:
	_enqueue(kind, TRAIN_TIME)

func _enqueue(kind: String, time: float) -> void:
	queue.append(kind)
	times.append(time)
	queue_redraw()

func current_share() -> float:
	if queue.is_empty():
		return 0.0
	return clampf(progress / times[0], 0.0, 1.0)

## On the physics tick, like everything else that decides how a match goes.
func _physics_process(delta: float) -> void:
	if _tick_construction(delta) or not is_alive() or queue.is_empty():
		return
	progress += delta
	if progress >= times[0]:
		progress = 0.0
		times.pop_front()
		_turn_out(queue.pop_front())
	if redraw_while_hiring:
		queue_redraw()

## False for a building too big to redraw every tick (the castle).
var redraw_while_hiring := true

## Where a recruit is put down, relative to the building.
func _door() -> Vector2:
	return DOOR_OUT

## The door in the world: where recruits come out, and armed ones go in to train.
func door_point() -> Vector2:
	return global_position + _door()

func _turn_out(kind: String) -> void:
	var entry: Dictionary = CATALOG[kind]
	var recruit: PlayerBody = (load(entry["scene"]) as PackedScene).instantiate()
	recruit.team = team
	if entry.has("job"):
		var job: String = entry["job"]
		if job == "auto":
			job = side.least_staffed_job() if side != null else "wood"
		recruit.set("job", job)
	if entry.has("loadout"):
		recruit.set("loadout", entry["loadout"])
	recruit.position = position + _door()
	get_parent().add_child(recruit)
	if recruit is Worker and side != null and (recruit as Worker).job == "recruit":
		side.take_recruit(recruit)
	var soldier := recruit as Unit
	if soldier != null:
		soldier.set_rally(rally_point)
		if side != null:
			side.squad.add(soldier)
			side.kit_out(soldier)
	unit_ready.emit(recruit)

func _draw_standing() -> void:
	var w := footprint.x * 0.5 + 6.0
	# log walls, then a pitched roof over them
	draw_rect(Rect2(-w, -WALL_HEIGHT, w * 2.0, WALL_HEIGHT), _tint(TIMBER))
	for i in range(1, 4):
		var y := -WALL_HEIGHT * float(i) / 4.0
		draw_line(Vector2(-w, y), Vector2(w, y), TIMBER_DARK, 1.5)
	draw_rect(Rect2(-w, -WALL_HEIGHT, w * 2.0, WALL_HEIGHT), TIMBER_EDGE, false, 1.5)
	var roof := PackedVector2Array([
		Vector2(-w - 6.0, -WALL_HEIGHT), Vector2(0.0, -WALL_HEIGHT - ROOF_HEIGHT),
		Vector2(w + 6.0, -WALL_HEIGHT)])
	draw_colored_polygon(roof, _tint(ROOF))
	roof.append(roof[0])
	draw_polyline(roof, ROOF_EDGE, 1.5, true)
	draw_rect(Rect2(-8.0, -22.0, 16.0, 22.0), DOOR)
	draw_circle(Vector2(0.0, -WALL_HEIGHT - 11.0), 5.5, Team.color(team))
	# a bar at the foot of the wall while someone is being hired, a dot per one waiting
	if not queue.is_empty():
		var at := Vector2(-w, 4.0)
		draw_rect(Rect2(at, Vector2(w * 2.0, 4.0)), BAR_BACK)
		draw_rect(Rect2(at, Vector2(w * 2.0 * current_share(), 4.0)), PROGRESS)
		for i in range(queue.size() - 1):
			draw_circle(Vector2(-w + 4.0 + i * 8.0, 13.0), 2.5, PROGRESS)
