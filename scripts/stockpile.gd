class_name Stockpile
extends Node2D
## Where a side's timber and stone turn into numbers. Anything set down on it is
## banked and gone, the same way a log laid in a fire ring is burnt: nothing is
## counted until it has physically been brought here (see Campfire._take_fuel).

signal received(kind: String, amount: int)

const RADIUS := 46.0          ## how far out from the middle a delivery still counts
const WORTH := {"wood": 1, "ore": 1, "gold": 1}

const EARTH := Color(0.40, 0.35, 0.28)
const EARTH_EDGE := Color(0.30, 0.26, 0.21)
const PLANK := Color(0.55, 0.43, 0.29)
const PLANK_EDGE := Color(0.39, 0.30, 0.20)
const POLE := Color(0.30, 0.23, 0.16)

@export var team: int = Team.Id.NEUTRAL

## Set by the side that owns it. Until then, nothing is taken in.
var economy: Economy

func _ready() -> void:
	add_to_group("stockpiles")
	queue_redraw()

func team_of() -> int:
	return team

## What a thing would be banked as, or "" if it is not worth anything here.
static func kind_of(thing: Node) -> String:
	if thing is Beam:
		return "wood"
	if thing is Rock:
		return (thing as Rock).resource_kind
	return ""

func _physics_process(_delta: float) -> void:
	if economy != null:
		_take_deliveries()

func _take_deliveries() -> void:
	for node in get_tree().get_nodes_in_group("carriables"):
		var thing := node as Carriable
		# only what has been set down and come to rest; a burning log is not stock
		if thing == null or not thing.can_be_taken():
			continue
		# freeing is deferred to the end of the frame, so a piece already banked
		# is still sitting in the group and would otherwise be counted twice
		if thing.is_queued_for_deletion():
			continue
		if global_position.distance_to(thing.global_position) > RADIUS:
			continue
		var kind := kind_of(thing)
		if kind == "":
			continue
		# a rock says what it is worth; anything that does not is worth the usual
		var carried = thing.get("amount")
		var worth: int = int(carried) if carried != null else int(WORTH.get(kind, 1))
		economy.add(kind, worth)
		received.emit(kind, worth)
		thing.queue_free()

func _draw() -> void:
	# a patch of trodden earth with a pallet of planks and the side's flag
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, RADIUS, EARTH)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, EARTH_EDGE, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(4):
		var y := -9.0 + i * 6.0
		draw_rect(Rect2(-22.0, y, 44.0, 4.5), PLANK)
		draw_rect(Rect2(-22.0, y, 44.0, 4.5), PLANK_EDGE, false, 1.0)
	var flag := Team.color(team)
	draw_line(Vector2(RADIUS * 0.8, 6.0), Vector2(RADIUS * 0.8, -44.0), POLE, 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(RADIUS * 0.8, -44.0), Vector2(RADIUS * 0.8 + 20.0, -38.0),
		Vector2(RADIUS * 0.8, -32.0)]), flag)
