class_name Pen
extends RefCounted
## Draws the way CanvasItem's draw_* functions do, but as triangles gathered into
## one list and handed to the renderer in a single call.
##
## A procedural figure is sixty-odd strokes -- lines, joints, plates, a blade --
## and drawn stroke by stroke every change of kind or of transform breaks the
## renderer's batch, so a figure cost thirty draw calls. A crowd of them was
## thirty times that. Gathered like this a figure is one draw call, whatever it
## is made of, and still sorts in depth with everything else as one item.
##
## The shapes are the same shapes; only the edge is different. There is no
## per-stroke antialiasing here -- a scene using this smooths edges with the
## viewport's MSAA instead, which costs nothing per stroke.
##
## Written for speed in GDScript, since it runs for every figure every frame:
## the arrays grow once and are then written by index, and circles come from
## tables worked out once per segment count.

## True while a scene full of figures is up (MapBuilder raises it): rigs made
## meanwhile draw through a Pen. Anything made outside such a scene -- the
## testbed -- draws stroke by stroke as it always did.
static var crowd_mode := false

## How wide a soft edge each stroke and disc gets, in pixels: the same trick the
## renderer's own antialiasing uses, a strip fading from the colour to nothing.
## 0 turns it off -- sharper edges, fewer triangles, for a weak device.
static var feather := 1.0

const MIN_SEGMENTS := 8
const MAX_SEGMENTS := 20

## Segment count -> unit circle points, shared by every pen.
static var _rings := {}

var points := PackedVector2Array()
var colors := PackedColorArray()
var count := 0                   ## vertices written this frame
var xf := Transform2D.IDENTITY

func begin() -> void:
	count = 0
	xf = Transform2D.IDENTITY

## Everything gathered since begin(), onto `item` in one go.
func flush(item: CanvasItem) -> void:
	if count == 0:
		return
	# trimmed copies: the arrays themselves are kept at their high-water mark
	RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), PackedInt32Array(),
		points.slice(0, count), colors.slice(0, count))

func set_transform(position: Vector2, rotation: float, scale: Vector2) -> void:
	xf = Transform2D(rotation, scale, 0.0, position)

func _room(extra: int) -> void:
	var need := count + extra
	if need > points.size():
		var grow := maxi(need, points.size() * 2 + 96)
		points.resize(grow)
		colors.resize(grow)

## Three points already in canvas space.
func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_room(3)
	points[count] = a
	points[count + 1] = b
	points[count + 2] = c
	colors[count] = color
	colors[count + 1] = color
	colors[count + 2] = color
	count += 3

func line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	var along := to - from
	if along.length_squared() < 0.0001:
		return
	# half the width across the stroke in its own space, then carried through the
	# transform like everything else -- so a squashed shadow squashes its strokes
	var side := xf.basis_xform(along.normalized().orthogonal() * (maxf(width, 1.0) * 0.5))
	var a := xf * from
	var b := xf * to
	if feather > 0.0:
		# the solid core gives up half the feather, so the stroke keeps its weight
		var half := side.length()
		var unit := side / half
		var core := unit * maxf(half - feather * 0.5, 0.35)
		var edge := unit * (half + feather * 0.5)
		_quad_raw(a + core, b + core, b - core, a - core, color)
		_fringe(a + core, b + core, a + edge, b + edge, color)
		_fringe(a - core, b - core, a - edge, b - edge, color)
		return
	_quad_raw(a + side, b + side, b - side, a - side, color)

func _quad_raw(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_room(6)
	var w := count
	points[w] = a
	points[w + 1] = b
	points[w + 2] = c
	points[w + 3] = a
	points[w + 4] = c
	points[w + 5] = d
	for i in 6:
		colors[w + i] = color
	count += 6

## A strip from an inner edge in full colour out to an outer edge in none.
func _fringe(in_a: Vector2, in_b: Vector2, out_a: Vector2, out_b: Vector2, color: Color) -> void:
	var clear := Color(color, 0.0)
	_room(6)
	var w := count
	points[w] = in_a
	points[w + 1] = in_b
	points[w + 2] = out_b
	points[w + 3] = in_a
	points[w + 4] = out_b
	points[w + 5] = out_a
	colors[w] = color
	colors[w + 1] = color
	colors[w + 2] = clear
	colors[w + 3] = color
	colors[w + 4] = clear
	colors[w + 5] = clear
	count += 6

func polyline(pts: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	for i in range(pts.size() - 1):
		line(pts[i], pts[i + 1], color, width)
	# a small cap at each inner corner, so a bend does not show a notch
	if width > 1.5:
		for i in range(1, pts.size() - 1):
			circle(pts[i], width * 0.5, color, 6)

static func _ring(n: int) -> PackedVector2Array:
	var ring: PackedVector2Array = _rings.get(n, PackedVector2Array())
	if ring.is_empty():
		for i in n + 1:
			ring.append(Vector2.from_angle(TAU * float(i) / float(n)))
		_rings[n] = ring
	return ring

func circle(center: Vector2, radius: float, color: Color, segments: int = 0) -> void:
	if radius <= 0.0:
		return
	var n := segments if segments > 0 else clampi(int(radius * 1.4), MIN_SEGMENTS, MAX_SEGMENTS)
	var ring := _ring(n)
	var c := xf * center
	# the circle's axes once, then each rim point is a sum instead of a transform
	var ax := xf.x * radius
	var ay := xf.y * radius
	_room(n * 3)
	var w := count
	var prev := c + ax
	for i in range(1, n + 1):
		var u := ring[i]
		var next := c + ax * u.x + ay * u.y
		points[w] = c
		points[w + 1] = prev
		points[w + 2] = next
		w += 3
		prev = next
	for i in range(count, w):
		colors[i] = color
	count = w
	if feather > 0.0 and radius > 1.0:
		# a soft rim round the disc, outwards from its edge
		var grow := 1.0 + feather / radius
		var bx := ax * grow
		var by := ay * grow
		var inner := c + ax
		var outer := c + bx
		for i in range(1, n + 1):
			var u := ring[i]
			var inner_next := c + ax * u.x + ay * u.y
			var outer_next := c + bx * u.x + by * u.y
			_fringe(inner, inner_next, outer, outer_next, color)
			inner = inner_next
			outer = outer_next

func arc(center: Vector2, radius: float, start: float, end: float, steps: int, color: Color, width: float = 1.0) -> void:
	var pts := PackedVector2Array()
	pts.resize(steps)
	for i in steps:
		pts[i] = center + Vector2.from_angle(lerpf(start, end, float(i) / float(maxi(steps - 1, 1)))) * radius
	polyline(pts, color, width)

## Any simple polygon, convex or not, the way draw_colored_polygon takes it.
func colored_polygon(pts: PackedVector2Array, color: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var moved := xf * pts
	if n == 3:
		_tri(moved[0], moved[1], moved[2], color)
		return
	var order := Geometry2D.triangulate_polygon(pts)
	if order.is_empty():
		# degenerate this frame (a plate folded flat): a fan is close enough
		for i in range(1, n - 1):
			_tri(moved[0], moved[i], moved[i + 1], color)
		return
	_room(order.size())
	for i in order.size():
		points[count + i] = moved[order[i]]
		colors[count + i] = color
	count += order.size()

## A quad shaded from `top` along a-b to `bottom` along d-c: skies, banks, fades.
func gradient_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, top: Color, bottom: Color) -> void:
	_room(6)
	var w := count
	points[w] = xf * a
	points[w + 1] = xf * b
	points[w + 2] = xf * c
	points[w + 3] = xf * a
	points[w + 4] = xf * c
	points[w + 5] = xf * d
	colors[w] = top
	colors[w + 1] = top
	colors[w + 2] = bottom
	colors[w + 3] = top
	colors[w + 4] = bottom
	colors[w + 5] = bottom
	count += 6

## A filled ellipse: a circle carried through a squash.
func ellipse(center: Vector2, radii: Vector2, color: Color, segments: int = 0) -> void:
	var keep := xf
	# drawn as a unit circle squashed out to size, where a pixel of soft edge
	# would be a whole radius -- so no soft edge on this one
	var soft := feather
	feather = 0.0
	xf = xf * Transform2D(0.0, Vector2(radii.x, radii.y), 0.0, center)
	circle(Vector2.ZERO, 1.0, color, segments if segments > 0 else clampi(int(maxf(radii.x, radii.y) * 0.9), 10, 28))
	xf = keep
	feather = soft

func rect(r: Rect2, color: Color) -> void:
	var a := xf * r.position
	var b := xf * Vector2(r.end.x, r.position.y)
	var c := xf * r.end
	var d := xf * Vector2(r.position.x, r.end.y)
	_tri(a, b, c, color)
	_tri(a, c, d, color)
