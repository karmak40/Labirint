class_name TouchInput
extends Node
## Fingers on the field, for phones and tablets. It sits next to the input
## adapter and turns gestures into the same calls the mouse makes:
##
##   one finger, dragged       move the camera (or, while placing a building,
##                             drag its outline if the finger started on it)
##   two fingers               pinch to zoom, about the point between them,
##                             and move the camera with them
##   a short tap               the adapter's tap: look at a body, put the
##                             outline of a building there / lay it out
##   a long press              the adapter's hold: the army attacks there
##
## Touches that land on the HUD never get here: the viewport hands them to the
## control under the finger and marks them handled. The mouse the engine
## emulates from a touch is ignored by the adapter, so a tap is seen once.

## Set by the last real pointer: true after a finger, false once a real mouse
## moves. The camera's screen-edge scroll and the adapter's hints read it.
static var in_use := false

const SLOP := 12.0             ## how far a finger may wander and still tap
const HOLD := 0.5              ## seconds of a still finger that make a long press
const HOLD_SHOWN := 0.12       ## the press ring shows up after this much

var adapter: Node              ## the PlayerInput adapter
var fingers := {}              ## touch index -> Finger
var pinch_span := 0.0          ## the distance between two fingers when the pinch began
var pinch_zoom := 1.0          ## and the zoom then
var pinch_mid := Vector2.ZERO  ## where their midpoint was last
var dragging_ghost := false

class Finger:
	var start := Vector2.ZERO
	var at := Vector2.ZERO
	var age := 0.0
	var moved := false         ## it has become a drag
	var spent := false         ## a pinch or a long press has used it: no tap on release

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the camera still moves while paused

func _camera() -> RtsCamera:
	var camera := get_viewport().get_camera_2d() as RtsCamera
	return camera if camera != null and not camera.steered else null

func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.device != InputEvent.DEVICE_ID_EMULATION and motion.relative != Vector2.ZERO:
		in_use = false

func _unhandled_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		var camera := _camera()
		if camera != null:
			camera.zoom_about(camera.zoom.x * magnify.factor, magnify.position)
		get_viewport().set_input_as_handled()

func _on_touch(touch: InputEventScreenTouch) -> void:
	in_use = true
	if touch.pressed:
		var finger := Finger.new()
		finger.start = touch.position
		finger.at = touch.position
		fingers[touch.index] = finger
		if fingers.size() == 1:
			dragging_ghost = adapter != null and adapter.ghost_hit(touch.position)
		else:
			_begin_pinch()
		return
	var finger: Finger = fingers.get(touch.index)
	fingers.erase(touch.index)
	if adapter != null:
		adapter.show_hold(Vector2.INF, 0.0)
	if finger == null:
		return
	if fingers.is_empty():
		dragging_ghost = false
		if not touch.canceled and not finger.moved and not finger.spent and adapter != null:
			adapter.tap(touch.position)
	elif fingers.size() == 1:
		# one finger left after a pinch: it pans on from where it is, but never taps
		var rest: Finger = fingers.values()[0]
		rest.start = rest.at
		rest.moved = true
	else:
		_begin_pinch()

func _begin_pinch() -> void:
	var pair := _pair()
	pinch_span = maxf(1.0, pair[0].distance_to(pair[1]))
	pinch_mid = (pair[0] + pair[1]) * 0.5
	var camera := _camera()
	pinch_zoom = camera.zoom.x if camera != null else 1.0
	dragging_ghost = false
	for finger: Finger in fingers.values():
		finger.spent = true
	if adapter != null:
		adapter.show_hold(Vector2.INF, 0.0)

## The first two fingers down.
func _pair() -> Array[Vector2]:
	var keys := fingers.keys()
	keys.sort()
	return [(fingers[keys[0]] as Finger).at, (fingers[keys[1]] as Finger).at]

func _on_drag(drag: InputEventScreenDrag) -> void:
	in_use = true
	var finger: Finger = fingers.get(drag.index)
	if finger == null:
		return
	finger.at = drag.position
	var camera := _camera()
	if fingers.size() >= 2:
		var pair := _pair()
		var mid := (pair[0] + pair[1]) * 0.5
		if camera != null:
			camera.zoom_about(pinch_zoom * pair[0].distance_to(pair[1]) / pinch_span, mid)
			camera.pan_by(mid - pinch_mid)
		pinch_mid = mid
		return
	if not finger.moved:
		if finger.start.distance_to(finger.at) <= SLOP:
			return
		finger.moved = true
		if adapter != null:
			adapter.show_hold(Vector2.INF, 0.0)
		# the whole way from where it went down, so the ground stays under the finger
		if dragging_ghost:
			adapter.move_ghost(finger.at)
		elif camera != null:
			camera.pan_by(finger.at - finger.start)
		return
	if dragging_ghost:
		adapter.move_ghost(finger.at)
	elif camera != null:
		camera.pan_by(drag.relative)

func _process(delta: float) -> void:
	if fingers.size() != 1 or adapter == null:
		return
	var finger: Finger = fingers.values()[0]
	if finger.moved or finger.spent or dragging_ghost:
		return
	finger.age += delta
	if finger.age >= HOLD:
		finger.spent = true
		adapter.show_hold(Vector2.INF, 0.0)
		adapter.hold(finger.at)
	elif finger.age >= HOLD_SHOWN:
		adapter.show_hold(finger.at, (finger.age - HOLD_SHOWN) / (HOLD - HOLD_SHOWN))
