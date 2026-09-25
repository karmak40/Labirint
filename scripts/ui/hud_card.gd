class_name HudCard
extends Button
## One thing the side can do -- hire, build, learn -- as a card: a picture, a
## name, a price in little resource pictures (red where the store falls short),
## the key that does it, and a bar while it is under way.

const ICON := 30.0
const RESOURCE_ORDER := ["wood", "ore", "gold"]

var icon_kind := ""
var title := ""
var cost := {}
var hotkey := ""
var count := 0                 ## how many are waiting, shown in the corner when more than one
var progress := -1.0           ## 0..1 while under way, -1 when not
var badge := ""                ## a short word over the card: "изучено", a count
var locked := ""               ## what it is waiting for; "" when open
var store: Economy             ## to show what can not be afforded

func _init() -> void:
	custom_minimum_size = Vector2(106.0, 64.0)
	focus_mode = Control.FOCUS_NONE
	text = ""

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var dim := disabled
	var ink := UiStyle.DIM if dim else UiStyle.TEXT
	Icons.draw(self, icon_kind, Rect2(Vector2(5.0, 5.0), Vector2(ICON, ICON)))
	if dim:
		draw_rect(Rect2(Vector2(5.0, 5.0), Vector2(ICON, ICON)), Color(0.1, 0.08, 0.06, 0.45))
	# the name beside the picture, over two lines if it needs them
	var room := size.x - 41.0
	# the largest size at which the name, or each word of it, fits
	var font_size := 12
	var longest := ""
	for word in title.split(" "):
		if word.length() > longest.length():
			longest = word
	while font_size > 9 and font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	var one_line := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room
	if one_line:
		draw_string(font, Vector2(38.0, 20.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	else:
		draw_multiline_string(font, Vector2(38.0, 15.0), title, HORIZONTAL_ALIGNMENT_LEFT, room + 1.0, font_size, 2, ink)
	# the key that does it, tucked into the picture's corner
	if hotkey != "":
		draw_rect(Rect2(Vector2(2.0, 2.0), Vector2(12.0, 13.0)), Color(0.08, 0.06, 0.04, 0.8))
		draw_string(font, Vector2(4.5, 12.5), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.GOLD_EDGE)
	if count > 1:
		draw_string(font, Vector2(size.x - 24.0, 55.0), "×%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.GOLD_BRIGHT)
	if badge != "":
		draw_string(font, Vector2(38.0, 38.0) if one_line else Vector2(38.0, 44.0), badge, HORIZONTAL_ALIGNMENT_LEFT, room, 11, UiStyle.GOOD)
	if locked != "":
		Icons.draw(self, "lock", Rect2(Vector2(6.0, 42.0), Vector2(14.0, 14.0)))
		draw_string(font, Vector2(22.0, 54.0), locked, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 10, UiStyle.DIM)
	elif badge == "":
		_draw_cost(font)
	if progress >= 0.0:
		UiStyle.bar(self, Rect2(Vector2(4.0, size.y - 6.0), Vector2(size.x - 8.0, 3.0)), progress,
			UiStyle.STUDY_FILL if icon_kind in ["chivalry", "forging", "mail"] else UiStyle.BAR_FILL)

func _draw_cost(font: Font) -> void:
	var x := 6.0
	for kind in RESOURCE_ORDER:
		if not cost.has(kind):
			continue
		var need := int(cost[kind])
		Icons.draw(self, kind, Rect2(Vector2(x, 42.0), Vector2(14.0, 14.0)))
		var short := store != null and store.amount(kind) < need
		var label := str(need)
		draw_string(font, Vector2(x + 15.0, 54.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			UiStyle.BAD if short else UiStyle.TEXT)
		x += 17.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 5.0
