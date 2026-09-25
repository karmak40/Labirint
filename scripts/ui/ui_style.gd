class_name UiStyle
extends RefCounted
## The look of the match's interface in one place: dark oiled wood edged with
## old gold, parchment-coloured text. Everything on the HUD takes its colours
## and boxes from here, so the whole panel changes together.

const WOOD := Color(0.14, 0.10, 0.08, 0.94)
const WOOD_LIGHT := Color(0.24, 0.18, 0.13)
const WOOD_HOVER := Color(0.33, 0.25, 0.17)
const WOOD_PRESSED := Color(0.18, 0.13, 0.10)
const WOOD_OFF := Color(0.17, 0.15, 0.13, 0.92)
const GOLD_EDGE := Color(0.74, 0.58, 0.30)
const GOLD_BRIGHT := Color(0.96, 0.78, 0.40)
const GOLD_DIM := Color(0.46, 0.36, 0.20)
const TEXT := Color(0.96, 0.92, 0.83)
const DIM := Color(0.72, 0.67, 0.58)
const BAD := Color(0.96, 0.44, 0.36)
const GOOD := Color(0.58, 0.86, 0.46)
const BAR_BACK := Color(0.06, 0.05, 0.04, 0.85)
const BAR_FILL := Color(0.96, 0.78, 0.36)
const STUDY_FILL := Color(0.52, 0.76, 1.0)

static func box(fill: Color, edge: Color, width := 2, radius := 6, margin := 8.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

static func panel() -> StyleBoxFlat:
	return box(WOOD, GOLD_EDGE, 2, 7, 8.0)

## The theme every HUD control inherits: panels, buttons, tooltips.
static func theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("normal", "Button", box(WOOD_LIGHT, GOLD_DIM, 1, 5, 6.0))
	t.set_stylebox("hover", "Button", box(WOOD_HOVER, GOLD_BRIGHT, 2, 5, 6.0))
	t.set_stylebox("pressed", "Button", box(WOOD_PRESSED, GOLD_BRIGHT, 2, 5, 6.0))
	t.set_stylebox("disabled", "Button", box(WOOD_OFF, Color(0.30, 0.26, 0.20), 1, 5, 6.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", GOLD_BRIGHT)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("outline_size", "Label", 3)
	t.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.6))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.10, 0.08, 0.06, 0.97), GOLD_EDGE, 1, 4, 8.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	return t

## A thin progress bar, drawn onto any control.
static func bar(canvas: CanvasItem, rect: Rect2, share: float, fill := BAR_FILL) -> void:
	canvas.draw_rect(rect, BAR_BACK)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(share, 0.0, 1.0), rect.size.y)), fill)
