class_name Tower
extends Building
## A stone tower that shoots at the other side's people. It is not a body --
## a body's arrows belong to its rig -- so it keeps its own: a handful of bolts
## in flight, drawn here, each landing by the same `take_hit` every blade uses.

const RANGE := 150.0
const SCAN_EVERY := 0.3        ## how often it looks round for someone nearer
const SHOOT_EVERY := 1.4
const DAMAGE := 9.0
const BOLT_SPEED := 420.0
const MUZZLE := Vector2(0.0, -78.0)   ## where bolts leave from, up on the platform
const CHEST := Vector2(0.0, -24.0)    ## and what they are aimed at on a man

const STONE := Color(0.52, 0.51, 0.49)
const STONE_DARK := Color(0.40, 0.39, 0.38)
const STONE_EDGE := Color(0.28, 0.27, 0.27)
const BOLT := Color(0.90, 0.86, 0.72)

class Bolt:
	var at := Vector2.ZERO      ## in world space
	var mark: Node2D

var bolts: Array[Bolt] = []
var mark: Node2D = null
var scan_left := 0.0
var reload := 0.0

func _init() -> void:
	health_max = 350.0
	footprint = Vector2(28.0, 22.0)
	bar_height = 98.0

func _ready() -> void:
	super()
	scan_left = randf() * SCAN_EVERY   # towers put up together do not all look at once

## On the physics tick, like everything else that decides how a match goes.
func _physics_process(delta: float) -> void:
	_fly(delta)
	if _tick_construction(delta) or not is_alive():
		return
	scan_left -= delta
	if scan_left <= 0.0 or not _still_in_sight(mark):
		scan_left = SCAN_EVERY
		mark = _nearest_foe()
	reload = maxf(0.0, reload - delta)
	if mark != null and reload <= 0.0:
		reload = SHOOT_EVERY
		var bolt := Bolt.new()
		bolt.at = global_position + MUZZLE
		bolt.mark = mark
		bolts.append(bolt)

## People only: a tower does not waste bolts on walls.
func _nearest_foe() -> Node2D:
	var best: Node2D = null
	var best_distance := RANGE
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or not body.is_alive() or not Team.hostile(team, body.team):
			continue
		var distance := global_position.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

func _still_in_sight(thing: Node2D) -> bool:
	return thing != null and is_instance_valid(thing) and thing.is_alive() \
		and global_position.distance_to(thing.global_position) <= RANGE

func _fly(delta: float) -> void:
	if bolts.is_empty():
		return
	var flying: Array[Bolt] = []
	for bolt in bolts:
		if not is_instance_valid(bolt.mark):
			continue
		# it follows its mark, so a bolt loosed is a bolt that lands
		var step := bolt.mark.global_position + CHEST - bolt.at
		if step.length() <= BOLT_SPEED * delta:
			if bolt.mark.is_alive():
				bolt.mark.take_hit(global_position, DAMAGE)
			continue
		bolt.at += step.normalized() * BOLT_SPEED * delta
		flying.append(bolt)
	bolts = flying
	queue_redraw()

func _draw() -> void:
	super()
	for bolt in bolts:
		if not is_instance_valid(bolt.mark):
			continue
		var here := bolt.at - global_position
		var heading := (bolt.mark.global_position + CHEST - bolt.at).normalized()
		draw_line(here - heading * 9.0, here, BOLT, 2.0, true)

func _draw_standing() -> void:
	var w := footprint.x * 0.5 + 3.0
	var top := MUZZLE.y + 6.0
	draw_rect(Rect2(-w, top, w * 2.0, -top), _tint(STONE))
	draw_rect(Rect2(-w, top, 4.0, -top), _tint(STONE_DARK))
	for i in range(1, 6):
		var y := top * float(i) / 6.0
		draw_line(Vector2(-w, y), Vector2(w, y), STONE_EDGE, 1.0)
	draw_rect(Rect2(-w, top, w * 2.0, -top), STONE_EDGE, false, 1.5)
	# the platform juts out; an arrow slit, and the side's colour under the lip
	draw_rect(Rect2(-w - 5.0, top - 10.0, w * 2.0 + 10.0, 10.0), _tint(STONE))
	draw_rect(Rect2(-w - 5.0, top - 10.0, w * 2.0 + 10.0, 10.0), STONE_EDGE, false, 1.5)
	draw_rect(Rect2(-2.0, top + 14.0, 4.0, 12.0), STONE_EDGE)
	draw_rect(Rect2(-w, top, w * 2.0, 5.0), Team.color(team))
