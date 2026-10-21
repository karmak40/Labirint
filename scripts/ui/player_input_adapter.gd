extends Node2D
## Mouse on the field, turned into the human side's commands. This is the only
## place in the match where a click becomes an order; below it everything is
## plain calls on GameState with a team and a point.
##
##   left click           pick one of our soldiers (or just look at anyone
##                        else: the HUD shows him); on empty ground, nobody
##   left drag            a box: every soldier of ours inside it
##   shift                adds to what is picked instead
##   double click         every soldier of that kind on the screen
##   1..9 / ctrl+1..9     pick a group / keep what is picked as that group;
##                        the same number twice brings the camera to it
##   right click          send what is picked (the whole army if nothing is)
##                        there, fighting on the way, in formation
##   shift + right click  move where new recruits gather
##   placing a building   its outline follows the mouse, green where it may go
##                        and red (with the reason) where not; left click puts it
##                        down, shift keeps placing, right click or Esc stops
##
##   rally button armed   (arm_rally) the next left click moves the gathering
##                        point; right click or Esc disarms it
##
## Fingers (TouchInput) come in through tap / hold / move_ghost: a tap looks at
## a body, a long press sends the army, and a building being placed is an
## outline that a tap moves and a tap on it lays out. The mouse the engine
## emulates from a touch is ignored here, so each touch counts once.
##
## A small marker shows where the last order went, so a click is seen to have
## done something.

signal refused(reason: String, tint: Color)
signal picked(body: PlayerBody)
## Placing began or ended, or the rally button was armed or disarmed.
signal mode_changed
## What is picked (`chosen`) changed.
signal chosen_changed
## A short line to show: a group kept, and the like.
signal note(text: String)

const MARK_TIME := 0.8
const ATTACK_MARK := Color(0.95, 0.45, 0.35)
const RALLY_MARK := Color(0.45, 0.70, 1.0)
const FITS := Color(0.45, 0.95, 0.45)
const NO_FIT := Color(0.98, 0.35, 0.30)

var mark_at := Vector2.INF     ## in world space
var mark_color := ATTACK_MARK
var mark_left := 0.0
var placing := ""              ## the kind of building being placed, "" for none
## Where a finger has put the outline of the building being placed (world), or
## INF: with the mouse the outline simply follows the pointer.
var ghost_at := Vector2.INF
const GHOST_GRACE := 20.0      ## how far outside the outline a tap still lays it out
## The rally button is armed: the next click or tap moves the gathering point.
var rally_armed := false
var hold_at := Vector2.INF     ## where a finger is being held (screen), for the ring
var hold_share := 0.0
const HOLD_RING := 26.0
## The body being looked at, or null. Anyone's: the enemy's too can be looked at.
var selected: PlayerBody = null
## Our soldiers picked to be given orders; empty for none (the whole army then).
var chosen: Array[Unit] = []
## Groups kept with ctrl+number: number -> the soldiers' instance ids.
var groups := {}
## A box being drawn (screen), from where the button went down.
var box_from := Vector2.INF
var box_to := Vector2.INF
var box_add := false
## A finger draws a box instead of moving the camera (the HUD's «Рамка»).
var box_mode := false
const BOX_MIN := 10.0          ## a drag shorter than this is a click
const RECALL_TIME := 0.45      ## the same group twice within this brings the camera
const CHOSEN := Color(0.55, 0.95, 0.55)
const BOX := Color(0.55, 0.95, 0.55)
var _last_group := -1
var _last_group_at := -10.0
const PICK_WIDE := 18.0        ## how far either side of a body a click still finds it
const PICK_TALL := 96.0        ## and how far up from its feet
const SELECTED := Color(1.0, 0.86, 0.35)

## Look at `body`, or at nobody.
func select(body: PlayerBody) -> void:
	selected = body
	picked.emit(body)
	queue_redraw()

# --- picking our soldiers ---------------------------------------------------------

## Picks `units` (or adds them, with `add`). One picked is also the one looked at.
func choose(units: Array, add: bool = false) -> void:
	var next: Array[Unit] = []
	if add:
		next.assign(chosen)
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive() and not next.has(unit):
			next.append(unit)
	chosen = next
	selected = chosen[0] if chosen.size() == 1 else (selected if add and chosen.is_empty() else null)
	chosen_changed.emit()
	picked.emit(selected)
	queue_redraw()

## Our soldiers on their feet.
func own_soldiers() -> Array[Unit]:
	var side: PlayerState = GameState.human()
	return side.squad.alive() if side != null else ([] as Array[Unit])

static func ids_of(units: Array[Unit]) -> Array:
	var ids := []
	for unit in units:
		ids.append(unit.get_instance_id())
	return ids

## Every soldier of ours: "all", the ones who close ("melee") or who shoot ("ranged").
func pick_all(which: String) -> void:
	var some: Array[Unit] = []
	for unit in own_soldiers():
		var shoots := Squad.rank_of(unit) == 2
		if which == "all" or (which == "ranged") == shoots:
			some.append(unit)
	choose(some)

## Keeps what is picked as group `number`.
func keep_group(number: int) -> void:
	if chosen.is_empty():
		groups.erase(number)
		note.emit(tr("Группа %d очищена") % number)
		return
	groups[number] = ids_of(chosen)
	note.emit(tr("Группа %d: %d бойцов") % [number, chosen.size()])

## Picks group `number`; the same group again at once brings the camera to it.
func recall_group(number: int) -> void:
	var ids: Array = groups.get(number, [])
	var some: Array[Unit] = []
	for unit in own_soldiers():
		if ids.has(unit.get_instance_id()):
			some.append(unit)
	var now := Time.get_ticks_msec() / 1000.0
	if number == _last_group and now - _last_group_at < RECALL_TIME and not some.is_empty():
		_look_at_units(some)
	_last_group = number
	_last_group_at = now
	choose(some)

func _look_at_units(some: Array[Unit]) -> void:
	var camera := get_viewport().get_camera_2d() as RtsCamera
	if camera == null or some.is_empty():
		return
	var middle := Vector2.ZERO
	for unit in some:
		middle += unit.global_position
	camera.global_position = middle / float(some.size())
	camera._clamp()

## Every soldier of ours whose body is inside the screen rectangle `box`.
func _soldiers_in(box: Rect2) -> Array[Unit]:
	var view := get_viewport().get_canvas_transform()
	var some: Array[Unit] = []
	for unit in own_soldiers():
		var at := view * (unit.global_position + Vector2(0.0, -30.0))
		if unit.visible and box.grow(12.0).has_point(at):
			some.append(unit)
	return some

## Every soldier of ours of the same kind as `unit` on the screen.
func _same_kind_on_screen(unit: Unit) -> Array[Unit]:
	var screen := get_viewport().get_visible_rect()
	var view := get_viewport().get_canvas_transform()
	var some: Array[Unit] = []
	for other in own_soldiers():
		if other.loadout == unit.loadout and screen.has_point(view * other.global_position):
			some.append(other)
	return some

## A click (or tap) at `point` in the world: our soldier is picked, anyone
## else only looked at, empty ground clears it all.
func _click(point: Vector2, add: bool) -> void:
	var body := body_at(point)
	var mine := body as Unit
	if mine != null and mine.team == GameState.human_team:
		choose([mine], add)
	elif body != null:
		if not add:
			chosen.clear()
			chosen_changed.emit()
		select(body)
	elif not add:
		choose([])

## The box a finger draws while «Рамка» is on (TouchInput).
func box_drag(from: Vector2, to: Vector2) -> void:
	box_from = from
	box_to = to
	queue_redraw()

func box_finish() -> void:
	if box_from != Vector2.INF:
		choose(_soldiers_in(Rect2(box_from, Vector2.ZERO).expand(box_to)), box_add)
	box_from = Vector2.INF
	box_to = Vector2.INF
	queue_redraw()

## Sends what is picked (or the whole army) at `point`, fighting on the way.
func _order_attack(point: Vector2) -> void:
	if chosen.is_empty():
		_attack(point)
		return
	GameState.order(GameState.human_team, ids_of(chosen), "attack", point)
	_mark(point, ATTACK_MARK)

## «Стой» / «Держать» for what is picked.
func stop_chosen(tight: bool) -> void:
	if not chosen.is_empty() and _may_order():
		GameState.order(GameState.human_team, ids_of(chosen), "hold" if tight else "stop")

## The living body under a point in the world, nearest the click, or null.
func body_at(point: Vector2) -> PlayerBody:
	var best: PlayerBody = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or body.is_dead or not body.visible:
			continue
		var off := point - body.global_position
		if absf(off.x) > PICK_WIDE or off.y > 10.0 or off.y < -PICK_TALL:
			continue
		var distance := point.distance_to(body.global_position + Vector2(0.0, -PICK_TALL * 0.4))
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

func begin_placing(kind: String) -> void:
	placing = kind
	rally_armed = false
	# with a finger there is no pointer to follow: start the outline mid-screen
	ghost_at = _to_world(get_viewport().get_visible_rect().size * 0.5) if TouchInput.in_use else Vector2.INF
	mode_changed.emit()
	queue_redraw()

func cancel_placing() -> void:
	placing = ""
	ghost_at = Vector2.INF
	mode_changed.emit()
	queue_redraw()

func arm_rally(on: bool) -> void:
	if on and placing != "":
		cancel_placing()
	rally_armed = on
	mode_changed.emit()

## Orders are taken only in a match being played, by its human side.
func _may_order() -> bool:
	return GameState.is_playing() and not GameState.spectating and not get_tree().paused

## Lays out the building being placed at `point`, or says why not. Placing
## ends unless `keep` asks for another.
func _put_down(point: Vector2, keep: bool) -> void:
	var problem: String = GameState.build_problem(GameState.human_team, placing, point)
	if problem != "":
		refused.emit(tr(problem), UiStyle.BAD)
	elif GameState.build(GameState.human_team, placing, point) and not keep:
		cancel_placing()

func _set_rally(point: Vector2) -> void:
	GameState.set_rally_point(GameState.human_team, point)
	_mark(point, RALLY_MARK)
	if rally_armed:
		arm_rally(false)

func _attack(point: Vector2) -> void:
	GameState.attack_move(GameState.human_team, point)
	_mark(point, ATTACK_MARK)

# --- fingers (TouchInput) ------------------------------------------------------

## A short tap at `screen`.
func tap(screen: Vector2) -> void:
	if not _may_order():
		return
	var point := _to_world(screen)
	if placing != "":
		if ghost_hit(screen):
			_put_down(ghost_at, false)
		else:
			ghost_at = point
			queue_redraw()
	elif rally_armed:
		_set_rally(point)
	else:
		_click(point, false)

## A long press at `screen`: the army goes there, fighting on the way (or the
## gathering point moves, when the rally button is armed).
func hold(screen: Vector2) -> void:
	if not _may_order():
		return
	var point := _to_world(screen)
	if placing != "":
		ghost_at = point
		queue_redraw()
	elif rally_armed:
		_set_rally(point)
	else:
		_order_attack(point)

## Whether `screen` is on (or just by) the outline a finger put down.
func ghost_hit(screen: Vector2) -> bool:
	if placing == "" or ghost_at == Vector2.INF:
		return false
	var half := GameState.footprint_of(placing) * 0.5 + Vector2(GHOST_GRACE, GHOST_GRACE)
	return Rect2(ghost_at - half, half * 2.0).has_point(_to_world(screen))

func move_ghost(screen: Vector2) -> void:
	if placing != "":
		ghost_at = _to_world(screen)
		queue_redraw()

## The ring that fills while a finger is held still; INF hides it.
func show_hold(screen: Vector2, share: float) -> void:
	hold_at = screen
	hold_share = share
	queue_redraw()

# --- the mouse -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return   # a finger, which TouchInput already reports
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _may_order() \
			and key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		var number: int = key.physical_keycode - KEY_0
		if key.ctrl_pressed:
			keep_group(number)
		else:
			recall_group(number)
		get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if event is InputEventMouseMotion and box_from != Vector2.INF:
		box_to = (event as InputEventMouseMotion).position
		queue_redraw()
	# the button coming up ends a box, or makes it a click
	if click != null and not click.pressed and click.button_index == MOUSE_BUTTON_LEFT and box_from != Vector2.INF:
		if box_from.distance_to(click.position) > BOX_MIN:
			box_to = click.position
			box_finish()
		else:
			box_from = Vector2.INF
			queue_redraw()
			if _may_order():
				_click(_to_world(click.position), box_add)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and placing != "":
		queue_redraw()
	if event is InputEventMouseMotion and ghost_at != Vector2.INF:
		ghost_at = Vector2.INF   # the mouse is back: the outline follows it again
	if click == null or not click.pressed:
		return
	if not _may_order():
		return
	var point := _to_world(click.position)
	if placing != "":
		if click.button_index == MOUSE_BUTTON_LEFT:
			_put_down(point, click.shift_pressed)
			get_viewport().set_input_as_handled()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placing()
			get_viewport().set_input_as_handled()
		return
	if rally_armed:
		if click.button_index == MOUSE_BUTTON_LEFT:
			_set_rally(point)
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			arm_rally(false)
		get_viewport().set_input_as_handled()
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		# a double click takes every one of that kind on the screen at once
		var mine := body_at(point) as Unit
		if click.double_click and mine != null and mine.team == GameState.human_team:
			choose(_same_kind_on_screen(mine), click.shift_pressed)
		else:
			# a click or the start of a box: which, the button coming up decides
			box_from = click.position
			box_to = click.position
			box_add = click.shift_pressed
		get_viewport().set_input_as_handled()
		return
	if click.button_index != MOUSE_BUTTON_RIGHT:
		return
	if click.shift_pressed:
		_set_rally(point)
	else:
		_order_attack(point)
	get_viewport().set_input_as_handled()

func _to_world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen

func _mark(point: Vector2, color: Color) -> void:
	mark_at = point
	mark_color = color
	mark_left = MARK_TIME

func _process(delta: float) -> void:
	if selected != null and (not is_instance_valid(selected) or selected.is_queued_for_deletion()):
		select(null)
	# the fallen drop out of what is picked
	var standing: Array[Unit] = []
	for unit in chosen:
		if is_instance_valid(unit) and unit.is_alive():
			standing.append(unit)
	if standing.size() != chosen.size():
		chosen = standing
		chosen_changed.emit()
	if not chosen.is_empty() or box_from != Vector2.INF:
		queue_redraw()
	if mark_left > 0.0:
		mark_left = maxf(0.0, mark_left - delta)
		queue_redraw()
	elif placing != "" or selected != null or hold_at != Vector2.INF:
		queue_redraw()

## Drawn on the HUD layer, so points are carried over to the screen by hand.
func _draw() -> void:
	if placing != "" and GameState.is_playing():
		_draw_placing()
	if not chosen.is_empty():
		var view := get_viewport().get_canvas_transform()
		var zoom := view.get_scale().x
		for unit in chosen:
			if not unit.visible:
				continue
			draw_set_transform(view * (unit.global_position + Vector2(0.0, 2.0)), 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, 17.0 * zoom, 0.0, TAU, 24, CHOSEN, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if box_from != Vector2.INF and box_from.distance_to(box_to) > BOX_MIN:
		var box := Rect2(box_from, Vector2.ZERO).expand(box_to)
		draw_rect(box, Color(BOX, 0.12))
		draw_rect(box, BOX, false, 1.5)
	if selected != null and is_instance_valid(selected) and not selected.is_dead:
		var view := get_viewport().get_canvas_transform()
		var feet := view * (selected.global_position + Vector2(0.0, 2.0))
		var zoom := view.get_scale().x
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, 20.0 * zoom, 0.0, TAU, 32, SELECTED, 2.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hold_at != Vector2.INF:
		var ink := RALLY_MARK if rally_armed else ATTACK_MARK
		draw_arc(hold_at, HOLD_RING, 0.0, TAU, 32, Color(ink, 0.25), 3.0, true)
		draw_arc(hold_at, HOLD_RING, -PI * 0.5, -PI * 0.5 + TAU * clampf(hold_share, 0.0, 1.0), 32, ink, 3.0, true)
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

## The building's outline where the mouse (or a finger's outline) is, and
## whether it may go there.
func _draw_placing() -> void:
	var view := get_viewport().get_canvas_transform()
	var world := ghost_at if ghost_at != Vector2.INF else _to_world(get_viewport().get_mouse_position())
	var problem: String = GameState.build_problem(GameState.human_team, placing, world)
	var tint := FITS if problem == "" else NO_FIT
	var zoom := view.get_scale().x
	var half := GameState.footprint_of(placing) * 0.5 * zoom
	var at := view * world
	draw_rect(Rect2(at - half, half * 2.0), Color(tint, 0.30))
	draw_rect(Rect2(at - half, half * 2.0), tint, false, 2.0)
	# the ground in front of its door or anvils, which has to stay open
	var front: Rect2 = GameState.apron_of(placing, world)
	if front.has_area():
		var shown := Rect2(view * front.position, front.size * zoom)
		draw_rect(shown, Color(tint, 0.10))
		draw_rect(shown, Color(tint, 0.55), false, 1.0)
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
		problem = tr(problem)
		var font := ThemeDB.fallback_font
		var wide_text := font.get_string_size(problem, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var spot := Vector2(at.x - wide_text * 0.5, at.y + half.y + 18.0)
		draw_rect(Rect2(spot + Vector2(-5.0, -14.0), Vector2(wide_text + 10.0, 19.0)), Color(0.08, 0.05, 0.04, 0.85))
		draw_string(font, spot, problem, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NO_FIT)
