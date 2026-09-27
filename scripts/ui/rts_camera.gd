class_name RtsCamera
extends Camera2D
## The player's eye on the match: arrows / WASD or the screen edge to scroll,
## the wheel to zoom; on a touch screen TouchInput drags and pinches it through
## pan_by and zoom_about. Presentation only -- where the camera looks never changes
## what happens on the field, so it is free to read the keyboard directly.
##
## The limits take in the floor plus room for the HUD's bars, so whatever is
## under a bar can always be scrolled out from under it.

const SCROLL_SPEED := 420.0    ## screen pixels a second
const EDGE := 12.0             ## how close to the window edge the mouse scrolls
const ZOOM_STEP := 0.08
const ZOOM_MIN := 0.7          ## furthest out
const ZOOM_MAX := 1.3
const HUD_TOP := 48.0          ## room for the resource bar
const HUD_BOTTOM := 90.0       ## and for the hiring bar

var floor_size := Vector2(900.0, 560.0)
## True while something else moves the camera (CinemaMode): the keys, the
## screen edge and the wheel are left alone.
var steered := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # still looks round while paused
	limit_left = -20
	limit_right = int(floor_size.x) + 20
	make_room(HUD_TOP, HUD_BOTTOM)
	limit_smoothed = false

## How far past the floor the view may go at the top and bottom, so whatever
## is under the HUD's bars can be scrolled out; the HUD calls it once it knows
## how big it is drawn.
func make_room(top: float, bottom: float) -> void:
	limit_top = -int(top)
	limit_bottom = int(floor_size.y + bottom)
	if is_inside_tree():
		_clamp()

func _process(delta: float) -> void:
	if steered:
		return
	var push := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		push.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		push.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		push.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		push.y += 1.0
	var window := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	# after a finger the "mouse" is just where it last lifted, so no edge scroll
	if not TouchInput.in_use and DisplayServer.window_is_focused() and Rect2(Vector2.ZERO, window).has_point(mouse):
		if mouse.x < EDGE: push.x -= 1.0
		if mouse.x > window.x - EDGE: push.x += 1.0
		if mouse.y < EDGE: push.y -= 1.0
		if mouse.y > window.y - EDGE: push.y += 1.0
	if push != Vector2.ZERO:
		position += push.normalized() * SCROLL_SPEED * delta / zoom.x
		_clamp()

func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or steered:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(ZOOM_STEP)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(-ZOOM_STEP)

func _zoom_by(step: float) -> void:
	var next := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(next, next)
	_clamp()

## Moves the view with a finger: the ground follows it by `screen` pixels.
func pan_by(screen: Vector2) -> void:
	position -= screen / zoom.x
	_clamp()

## Zooms to `next` keeping the spot under `screen` (a point in the window) in place.
func zoom_about(next: float, screen: Vector2) -> void:
	next = clampf(next, ZOOM_MIN, ZOOM_MAX)
	var from_centre := screen - get_viewport().get_visible_rect().size * 0.5
	var spot := get_screen_center_position() + from_centre / zoom.x
	zoom = Vector2(next, next)
	position = spot - from_centre / next
	_clamp()

## Keeps the centre where the limits would anyway put the view, so scrolling
## back from past an edge starts at once instead of after a dead stretch.
func _clamp() -> void:
	var half := get_viewport().get_visible_rect().size * 0.5 / zoom
	var lo := Vector2(limit_left, limit_top) + half
	var hi := Vector2(limit_right, limit_bottom) - half
	position.x = clampf(position.x, lo.x, maxf(lo.x, hi.x)) if lo.x <= hi.x else (limit_left + limit_right) * 0.5
	position.y = clampf(position.y, lo.y, maxf(lo.y, hi.y)) if lo.y <= hi.y else (limit_top + limit_bottom) * 0.5
