class_name Minimap
extends Control
## The whole field at a glance, in the corner: the road, the woods and the seams,
## every building and every body as a dot in its side's colour, and the part the
## camera is showing. Click or drag on it to look somewhere else.
##
## It only reads what is standing on the field; it never touches it.

const REFRESH := 0.2
const GRASS := Color(0.30, 0.44, 0.24)
const GRASS_EDGE := Color(0.20, 0.30, 0.17)
const ROAD := Color(0.50, 0.41, 0.29)
const TREE := Color(0.16, 0.30, 0.15)
const ORE := Color(0.62, 0.60, 0.56)
const GOLD := Color(0.98, 0.80, 0.22)
const VIEW := Color(1.0, 1.0, 1.0, 0.85)

var field: MapBuilder
var refresh_left := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(300.0, 56.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Карта: нажмите, чтобы перейти"

func _process(delta: float) -> void:
	refresh_left -= delta
	if refresh_left <= 0.0:
		refresh_left = REFRESH
		queue_redraw()

func _scale() -> float:
	if field == null or field.map == null:
		return 1.0
	var extent := field.map.floor_size
	return minf(size.x / extent.x, size.y / extent.y)

func _to_map(world: Vector2) -> Vector2:
	return world * _scale()

func _draw() -> void:
	if field == null or not is_instance_valid(field) or field.map == null:
		return
	var s := _scale()
	var extent := field.map.floor_size * s
	draw_rect(Rect2(Vector2.ZERO, extent), GRASS)
	var land := field.get_node_or_null("Terrain") as Terrain
	if land != null and land.road.size() > 1:
		var line := PackedVector2Array()
		for point in land.road:
			line.append(point * s)
		draw_polyline(line, ROAD, maxf(1.5, 30.0 * s))
	for spot in field.map.tree_positions:
		draw_circle(spot * s, maxf(1.3, 16.0 * s), TREE)
	for spot in field.map.boulder_positions:
		draw_circle(spot * s, maxf(1.6, 36.0 * s), Color(0.45, 0.44, 0.42))
	for spot in field.map.vein_positions:
		draw_rect(Rect2(spot * s - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), ORE)
	for spot in field.map.gold_positions:
		draw_rect(Rect2(spot * s - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), GOLD)
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or not building.is_alive():
			continue
		var tint := Team.color(building.team)
		if not building.is_complete():
			tint = tint.darkened(0.35)
		var half := (building.footprint * s * 0.5).max(Vector2(2.0, 2.0))
		draw_rect(Rect2(building.global_position * s - half, half * 2.0), tint)
		draw_rect(Rect2(building.global_position * s - half, half * 2.0), Color(0, 0, 0, 0.6), false, 1.0)
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or not body.is_alive() or body.team == Team.Id.NEUTRAL:
			continue
		var tint := Team.color(body.team).lightened(0.25 if body is Worker else 0.0)
		draw_rect(Rect2(body.global_position * s - Vector2(1.0, 1.0), Vector2(2.0, 2.0) if body is Worker else Vector2(3.0, 3.0)), tint)
	# what the camera is looking at
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var seen := get_viewport().get_visible_rect().size / camera.zoom
		var view := Rect2((camera.get_screen_center_position() - seen * 0.5) * s, seen * s)
		draw_rect(view.intersection(Rect2(Vector2(-1, -1), extent + Vector2(2, 2))), VIEW, false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, extent), GRASS_EDGE, false, 1.0)

func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	var drag := event as InputEventMouseMotion
	if (press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT) \
			or (drag != null and drag.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_look_at(event.position)
		accept_event()

func _look_at(local: Vector2) -> void:
	var camera := get_viewport().get_camera_2d() as RtsCamera
	if camera == null or field == null:
		return
	camera.position = local / _scale()
	camera._clamp()
	queue_redraw()
