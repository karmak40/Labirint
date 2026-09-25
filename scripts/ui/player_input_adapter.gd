extends Node2D
## Mouse on the field, turned into the human side's commands. This is the only
## place in the match where a click becomes an order; below it everything is
## plain calls on GameState with a team and a point.
##
##   right click          send the army there, fighting on the way
##   shift + right click  move where new recruits gather
##   placing a building   its outline follows the mouse, green where it may go
##                        and red (with the reason) where not; left click puts it
##                        down, shift keeps placing, right click or Esc stops
##
## A small marker shows where the last order went, so a click is seen to have
## done something.

signal refused(reason: String, tint: Color)

const MARK_TIME := 0.8
const ATTACK_MARK := Color(0.95, 0.45, 0.35)
const RALLY_MARK := Color(0.45, 0.70, 1.0)
const FITS := Color(0.45, 0.95, 0.45)
const NO_FIT := Color(0.98, 0.35, 0.30)

var mark_at := Vector2.INF     ## in world space
var mark_color := ATTACK_MARK
var mark_left := 0.0
var placing := ""              ## the kind of building being placed, "" for none

func begin_placing(kind: String) -> void:
	placing = kind
	queue_redraw()

func cancel_placing() -> void:
	placing = ""
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if event is InputEventMouseMotion and placing != "":
		queue_redraw()
	if click == null or not click.pressed:
		return
	if not GameState.is_playing() or GameState.spectating or get_tree().paused:
		return
	var point := _to_world(click.position)
	if placing != "":
		if click.button_index == MOUSE_BUTTON_LEFT:
			var problem: String = GameState.build_problem(GameState.human_team, placing, point)
			if problem != "":
				refused.emit(problem, UiStyle.BAD)
			elif GameState.build(GameState.human_team, placing, point) and not click.shift_pressed:
				cancel_placing()
			get_viewport().set_input_as_handled()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placing()
			get_viewport().set_input_as_handled()
		return
	if click.button_index != MOUSE_BUTTON_RIGHT:
		return
	if click.shift_pressed:
		GameState.set_rally_point(GameState.human_team, point)
		_mark(point, RALLY_MARK)
	else:
		GameState.attack_move(GameState.human_team, point)
		_mark(point, ATTACK_MARK)
	get_viewport().set_input_as_handled()

func _to_world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen

func _mark(point: Vector2, color: Color) -> void:
	mark_at = point
	mark_color = color
	mark_left = MARK_TIME

func _process(delta: float) -> void:
	if mark_left > 0.0:
		mark_left = maxf(0.0, mark_left - delta)
		queue_redraw()
	elif placing != "":
		queue_redraw()

## Drawn on the HUD layer, so points are carried over to the screen by hand.
func _draw() -> void:
	if placing != "" and GameState.is_playing():
		_draw_placing()
	if mark_left <= 0.0:
		return
	var here := get_viewport().get_canvas_transform() * mark_at
	var t := 1.0 - mark_left / MARK_TIME
	var ring := lerpf(6.0, 18.0, t)
	var color := Color(mark_color, 1.0 - t)
	draw_set_transform(here, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 28, color, 2.0, true)
	draw_arc(Vector2.ZERO, ring * 0.45, 0.0, TAU, 20, color, 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The building's outline where the mouse is, and whether it may go there.
func _draw_placing() -> void:
	var view := get_viewport().get_canvas_transform()
	var world := _to_world(get_viewport().get_mouse_position())
	var problem: String = GameState.build_problem(GameState.human_team, placing, world)
	var tint := FITS if problem == "" else NO_FIT
	var zoom := view.get_scale().x
	var half := GameState.footprint_of(placing) * 0.5 * zoom
	var at := view * world
	draw_rect(Rect2(at - half, half * 2.0), Color(tint, 0.30))
	draw_rect(Rect2(at - half, half * 2.0), tint, false, 2.0)
	# a faint silhouette of what will stand there
	var tall := (98.0 if placing == "tower" else 64.0) * zoom
	var wide := half.x + 4.0 * zoom
	var body := Rect2(Vector2(at.x - wide, at.y + half.y - tall), Vector2(wide * 2.0, tall))
	draw_rect(body, Color(tint, 0.16))
	draw_rect(body, Color(tint, 0.7), false, 1.5)
	if placing == "library":
		draw_colored_polygon(PackedVector2Array([body.position, Vector2(at.x, body.position.y - 32.0 * zoom),
			Vector2(body.end.x, body.position.y)]), Color(tint, 0.22))
	if problem != "":
		var font := ThemeDB.fallback_font
		var wide_text := font.get_string_size(problem, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var spot := Vector2(at.x - wide_text * 0.5, at.y + half.y + 18.0)
		draw_rect(Rect2(spot + Vector2(-5.0, -14.0), Vector2(wide_text + 10.0, 19.0)), Color(0.08, 0.05, 0.04, 0.85))
		draw_string(font, spot, problem, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NO_FIT)
