class_name ProductionBuilding
extends Building
## Where a side hires. `queue_unit(kind)` is the whole interface, and it is the
## same call whether the one asking is a HUD button or the enemy's head: pay up
## front out of the side's store, wait, and the recruit walks out to the rally
## point.

signal unit_ready(unit: PlayerBody)

## Everything that can be hired here. Plain data, so costs are balanced in one place.
const CATALOG := {
	# each trade is paid for in the other one's goods, so a side that has run out
	# of one can still hire the hands to get more of it
	"woodcutter": {"scene": "res://scenes/worker/Worker.tscn", "job": "wood", "cost": {"ore": 10}, "time": 4.0},
	"miner": {"scene": "res://scenes/worker/Worker.tscn", "job": "ore", "cost": {"wood": 10}, "time": 4.0},
	"gold_miner": {"scene": "res://scenes/worker/Worker.tscn", "job": "gold", "cost": {"wood": 15}, "time": 5.0},
	# the first soldier anyone can put in the field
	"warrior": {"scene": "res://scenes/warrior/Warrior.tscn", "cost": {"wood": 15}, "time": 5.0},
	# everything past the warrior has to be learned first (PlayerState.RESEARCH)
	"knight": {"scene": "res://scenes/knight/Knight.tscn", "cost": {"wood": 20, "ore": 20}, "time": 6.0, "requires": "chivalry"},
}
const QUEUE_MAX := 5
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
@export var kinds: PackedStringArray = PackedStringArray(["woodcutter", "miner", "gold_miner", "warrior", "knight"])
## Where recruits go and stand, relative to the building, until told otherwise.
@export var rally_offset := Vector2(0.0, 90.0)

var queue: Array[String] = []
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
	return is_alive() and side != null and kinds.has(kind) and queue.size() < QUEUE_MAX \
		and is_unlocked(kind) and side.economy.can_afford(CATALOG[kind]["cost"])

## Whether the side knows how to field one at all, whatever it can afford.
func is_unlocked(kind: String) -> bool:
	var needs: String = CATALOG[kind].get("requires", "")
	return needs == "" or (side != null and side.has_researched(needs))

## Pays and puts a recruit in the queue. False, and nothing taken, if it can not.
func queue_unit(kind: String) -> bool:
	if not can_hire(kind):
		return false
	if not side.economy.spend(CATALOG[kind]["cost"]):
		return false
	queue.append(kind)
	queue_redraw()
	return true

func current_share() -> float:
	if queue.is_empty():
		return 0.0
	return clampf(progress / float(CATALOG[queue[0]]["time"]), 0.0, 1.0)

## On the physics tick, like everything else that decides how a match goes.
func _physics_process(delta: float) -> void:
	if _tick_construction(delta) or not is_alive() or queue.is_empty():
		return
	progress += delta
	if progress >= float(CATALOG[queue[0]]["time"]):
		progress = 0.0
		_turn_out(queue.pop_front())
	queue_redraw()

func _turn_out(kind: String) -> void:
	var entry: Dictionary = CATALOG[kind]
	var recruit: PlayerBody = (load(entry["scene"]) as PackedScene).instantiate()
	recruit.team = team
	if entry.has("job"):
		recruit.set("job", entry["job"])
	recruit.position = position + DOOR_OUT
	get_parent().add_child(recruit)
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
