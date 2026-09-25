class_name RtsCamera
extends Camera2D
## The player's eye on the match: arrows / WASD or the screen edge to scroll,
## the wheel to zoom. Presentation only -- where the camera looks never changes
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
const SKY_VIEW := 180.0        ## how much of the sky over the far edge can be looked at

var floor_size := Vector2(900.0, 560.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # still looks round while paused
	limit_left = -20
	limit_right = int(floor_size.x) + 20
	limit_top = -int(HUD_TOP + SKY_VIEW)
	limit_bottom = int(floor_size.y + HUD_BOTTOM)
	limit_smoothed = false

func _process(delta: float) -> void:
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
	if DisplayServer.window_is_focused() and Rect2(Vector2.ZERO, window).has_point(mouse):
		if mouse.x < EDGE: push.x -= 1.0
		if mouse.x > window.x - EDGE: push.x += 1.0
		if mouse.y < EDGE: push.y -= 1.0
		if mouse.y > window.y - EDGE: push.y += 1.0
	if push != Vector2.ZERO:
		position += push.normalized() * SCROLL_SPEED * delta / zoom.x
		_clamp()

func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(ZOOM_STEP)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(-ZOOM_STEP)

func _zoom_by(step: float) -> void:
	var next := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(next, next)
	_clamp()

## Keeps the centre where the limits would anyway put the view, so scrolling
## back from past an edge starts at once instead of after a dead stretch.
func _clamp() -> void:
	var half := get_viewport().get_visible_rect().size * 0.5 / zoom
	var lo := Vector2(limit_left, limit_top) + half
	var hi := Vector2(limit_right, limit_bottom) - half
	position.x = clampf(position.x, lo.x, maxf(lo.x, hi.x)) if lo.x <= hi.x else (limit_left + limit_right) * 0.5
	position.y = clampf(position.y, lo.y, maxf(lo.y, hi.y)) if lo.y <= hi.y else (limit_top + limit_bottom) * 0.5
