extends SceneTree
## Draws the app's icons, like everything else in the game, and saves them as
## PNGs: the project icon (icon.png, used by desktop exports and as the
## fallback), the Android launcher set in res://icons/ (the legacy square
## and the adaptive foreground and background), and Google Play's feature
## graphic (1024x500, the banner on the store page). Run it with a window, since a
## headless run renders nothing:
##
##   godot --path . -s res://tools/make_icons.gd
##
## An evening sky over hills and a dark castle with lit windows and blue
## flags, the menu's backdrop told in one picture.

const SKY_HIGH := Color(0.20, 0.27, 0.45)
const SKY_LOW := Color(0.86, 0.62, 0.42)
const SUN := Color(1.0, 0.86, 0.62)
const HILLS_FAR := Color(0.36, 0.34, 0.42)
const HILLS_NEAR := Color(0.24, 0.30, 0.25)
const CASTLE := Color(0.12, 0.12, 0.15)
const CASTLE_EDGE := Color(0.20, 0.19, 0.24)
const WINDOW := Color(0.98, 0.78, 0.40)
const FLAG := Color(0.36, 0.56, 0.90)
const FRAME := Color(0.74, 0.58, 0.30)

## [file, size, what]; "full" is sky and castle together, "back" the sky alone,
## "fore" the castle alone, kept inside the adaptive icon's safe circle, and
## "banner" the castle to one side with the name beside it.
const OUTPUTS := [
	["res://icon.png", 512, "full"],
	["res://icons/android_192.png", 192, "full"],
	["res://icons/android_fore_432.png", 432, "fore"],
	["res://icons/android_back_432.png", 432, "back"],
	["res://icons/play_feature_1024x500.png", Vector2i(1024, 500), "banner"],
]

var jobs: Array = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://icons"))
	for output in OUTPUTS:
		var box: Vector2i = output[1] if output[1] is Vector2i else Vector2i(output[1], output[1])
		var port := SubViewport.new()
		port.size = box
		port.transparent_bg = true
		port.render_target_update_mode = SubViewport.UPDATE_ONCE
		var canvas := Control.new()
		canvas.size = Vector2(box)
		canvas.draw.connect(_paint.bind(canvas, Vector2(box), output[2]))
		port.add_child(canvas)
		root.add_child(port)
		jobs.append([port, output[0]])

var frames := 0

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 4:
		return false
	for job in jobs:
		var image: Image = (job[0] as SubViewport).get_texture().get_image()
		image.save_png(job[1])
		print("saved ", job[1], " ", image.get_size())
	return true

func _paint(c: Control, box: Vector2, what: String) -> void:
	var size := box.y
	if what != "fore":
		_sky(c, box)
	if what == "banner":
		_castle(c, Vector2(box.x * 0.24, box.y * 0.84), box.y * 0.62 / 32.0)
		var font := ThemeDB.fallback_font
		for line in [["Labirint", 128, Color(0.96, 0.78, 0.40), 0.52], ["база на базу", 46, Color(0.96, 0.92, 0.83), 0.70]]:
			var wide := font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1]).x
			var at := Vector2(box.x * 0.70 - wide * 0.5, box.y * line[3])
			c.draw_string_outline(font, at, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1], int(line[1] / 10), Color(0.08, 0.06, 0.05, 0.8))
			c.draw_string(font, at, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1], line[2])
	elif what == "fore":
		# the adaptive icon shows the middle 66%, and some launchers cut a circle
		_castle(c, Vector2(size * 0.5, size * 0.70), size * 0.44 / 32.0)
	elif what == "full":
		_castle(c, Vector2(size * 0.5, size * 0.86), size * 0.72 / 32.0)
		var edge := maxf(2.0, size / 64.0)
		c.draw_rect(Rect2(Vector2.ONE * edge * 0.5, Vector2.ONE * (size - edge)), FRAME, false, edge)

func _sky(c: Control, box: Vector2) -> void:
	var size := box.y
	var horizon := size * 0.66
	c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(box.x, 0.0), Vector2(box.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([SKY_HIGH, SKY_HIGH, SKY_LOW, SKY_LOW]))
	c.draw_circle(Vector2(box.x * 0.76, horizon - size * 0.06), size * 0.10, Color(SUN, 0.9))
	for band in [[HILLS_FAR, 0.0, 0.14, 11.0], [HILLS_NEAR, 0.05, 0.09, 17.0]]:
		var line := PackedVector2Array([Vector2(0.0, size)])
		for i in 65:
			var x := box.x * i / 64.0
			line.append(Vector2(x, horizon + size * band[1] - size * band[2] * (0.55 + 0.45 * sin(x / size * band[3] + band[1] * 40.0))))
		line.append(Vector2(box.x, size))
		c.draw_colored_polygon(line, band[0])

## The castle on a 32-unit grid, `u` pixels a unit, standing on `feet`.
func _castle(c: Control, feet: Vector2, u: float) -> void:
	var at := func(x: float, y: float) -> Vector2: return feet + Vector2(x, -y) * u
	var box := func(x: float, y: float, w: float, h: float, color: Color) -> void:
		c.draw_rect(Rect2(at.call(x, y + h), Vector2(w, h) * u), color)
	# the wall with its battlements
	box.call(-13.0, 0.0, 26.0, 11.0, CASTLE)
	for i in 6:
		box.call(-12.5 + i * 4.5, 11.0, 2.5, 1.8, CASTLE)
	# the keep
	box.call(-4.5, 0.0, 9.0, 20.0, CASTLE)
	for i in 4:
		box.call(-4.5 + i * 2.5, 20.0, 1.6, 1.8, CASTLE)
	# two towers with pointed roofs and flags
	for x in [-16.0, 11.0]:
		box.call(x, 0.0, 5.0, 17.0, CASTLE)
		c.draw_colored_polygon(PackedVector2Array([at.call(x - 1.0, 17.0), at.call(x + 2.5, 23.5), at.call(x + 6.0, 17.0)]), CASTLE_EDGE)
		c.draw_line(at.call(x + 2.5, 23.5), at.call(x + 2.5, 27.5), CASTLE, maxf(1.0, u * 0.45))
		c.draw_colored_polygon(PackedVector2Array([at.call(x + 2.7, 27.5), at.call(x + 6.5, 26.4), at.call(x + 2.7, 25.2)]), FLAG)
		box.call(x + 1.8, 11.0, 1.4, 2.4, WINDOW)
	# the gate, and lamps in the keep and on the wall
	c.draw_colored_polygon(PackedVector2Array([at.call(-2.2, 0.0), at.call(-2.2, 5.0), at.call(0.0, 6.6), at.call(2.2, 5.0), at.call(2.2, 0.0)]),
		Color(0.06, 0.05, 0.06))
	for spot in [Vector2(-2.6, 15.0), Vector2(1.2, 15.0), Vector2(-0.7, 10.0), Vector2(-9.5, 6.0), Vector2(8.1, 6.0)]:
		box.call(spot.x, spot.y, 1.4, 2.4, WINDOW)
