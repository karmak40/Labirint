class_name Building
extends StaticBody2D
## Anything a side has put up: a keep, a barracks, a tower.
##
## It is a target on exactly the terms the straw dummy set -- `is_alive`,
## `take_hit`, `exposed_back_to` -- and nothing more, so every blade and arrow
## that already knows how to hit a man knows how to hit a wall. It does not
## inherit the body: a wall has no legs, no wind and no back to be stabbed in.
##
## Its node position is the middle of its footprint on the floor, the same as a
## man's feet; everything is drawn upwards from there. The footprint is kept
## small on purpose: a blow reaches for the middle, so a wall a swordsman could
## not get within a sword's length of could never be knocked down.

signal destroyed(building: Building)
## Fired once, when a building that was put up in the match is finished.
signal completed(building: Building)

const FLASH_TIME := 0.18
const BAR_BACK := Color(0.08, 0.08, 0.09, 0.8)
const BAR_HURT := Color(0.85, 0.30, 0.22)
const BAR_WELL := Color(0.40, 0.78, 0.36)
const SHADOW := Color(0.0, 0.0, 0.0, 0.2)
const RUBBLE := Color(0.36, 0.35, 0.34)
const RUBBLE_DARK := Color(0.25, 0.24, 0.24)
const SITE_EARTH := Color(0.42, 0.34, 0.24)
const SCAFFOLD := Color(0.55, 0.42, 0.27)
const SCAFFOLD_DARK := Color(0.36, 0.27, 0.17)
const SITE_STONE := Color(0.55, 0.54, 0.51)
const BUILD_BAR := Color(0.95, 0.80, 0.35)
const SITE_START := 0.15       ## share of its health a site has the moment it is laid out

@export var team: int = Team.Id.NEUTRAL

## Set by each kind of building in _init; kept as plain fields rather than exports
## so a scene can not quietly give one keep more walls than another.
var health_max := 400.0
var footprint := Vector2(60.0, 30.0)   ## size on the floor, which is also what blocks
var bar_height := 90.0                 ## how far up its health is shown
var bar_width := 56.0

## Seconds it takes to put up, when it is put up in the match; 0 for anything
## the map stands up whole.
var build_time := 0.0
var built := 1.0               ## 0 a marked-out site, 1 finished

var health := 0.0
var flash := 0.0
## The side that owns it, handed over by that side (PlayerState._claim_field).
var side: PlayerState

func _ready() -> void:
	health = health_max if is_complete() else health_max * SITE_START
	add_to_group("targets")
	add_to_group("buildings")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = footprint
	shape.shape = box
	add_child(shape)
	queue_redraw()

## Marks it as a site to be built over `seconds`. Call before it is added.
func start_construction(seconds: float) -> void:
	build_time = maxf(seconds, 0.1)
	built = 0.0

func is_complete() -> bool:
	return built >= 1.0

## Raises it a little. True while it is still going up -- a site does nothing
## else until it is finished. Its walls rise with it, and so does its health.
func _tick_construction(delta: float) -> bool:
	if is_complete():
		return false
	if not is_alive():
		return true
	var step := delta / build_time
	built = minf(1.0, built + step)
	health = minf(health_max, health + health_max * (1.0 - SITE_START) * step)
	queue_redraw()
	if is_complete():
		completed.emit(self)
	return not is_complete()

func _physics_process(delta: float) -> void:
	_tick_construction(delta)

## The point of the footprint nearest `from`: what a blade reaches for, and where
## anyone attacking it has to get to.
func nearest_point(from: Vector2) -> Vector2:
	var half := footprint * 0.5
	var local := from - global_position
	return global_position + Vector2(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y))

## A place to stand in front of it, seen from `from`: just off the nearest wall.
func approach_from(from: Vector2) -> Vector2:
	var wall := nearest_point(from)
	var out := from - wall
	return wall + (out.normalized() if out.length() > 1.0 else Vector2.RIGHT) * 36.0

func team_of() -> int:
	return team

func is_alive() -> bool:
	return health > 0.0

## A wall has no back to be caught from.
func exposed_back_to(_from: Vector2) -> bool:
	return false

func take_backstab(_from: Vector2) -> void:
	pass

func take_hit(_from: Vector2 = Vector2.INF, damage: float = 10.0) -> void:
	if not is_alive():
		return
	health = maxf(0.0, health - damage)
	flash = FLASH_TIME
	if health <= 0.0:
		_fall()
		destroyed.emit(self)
	queue_redraw()

## What happens when it goes. The ruin stays where it was, and keeps blocking.
func _fall() -> void:
	pass

func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		queue_redraw()

func _draw() -> void:
	_draw_shadow()
	if is_alive() and not is_complete():
		_draw_site()
	elif is_alive():
		_draw_standing()
		_draw_health()
	else:
		_draw_ruin()

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, footprint.y / footprint.x))
	draw_circle(Vector2.ZERO, footprint.x * 0.62, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Each kind draws itself standing; this is only a placeholder block.
func _draw_standing() -> void:
	draw_rect(Rect2(-footprint.x * 0.5, -bar_height * 0.7, footprint.x, bar_height * 0.7), _tint(RUBBLE))

## A building going up: its footprint dug out, walls rising to as far as the
## work has got, scaffolding round them, and how far along it is.
func _draw_site() -> void:
	var w := footprint.x * 0.5
	var d := footprint.y * 0.5
	draw_rect(Rect2(-w - 4.0, -d * 0.6, footprint.x + 8.0, d * 1.6), SITE_EARTH)
	var tall := bar_height * 0.8
	var up := tall * built
	draw_rect(Rect2(-w, d - up, footprint.x, up), _tint(SITE_STONE))
	for i in range(1, 6):
		var y := d - up * float(i) / 6.0
		draw_line(Vector2(-w, y), Vector2(w, y), RUBBLE_DARK, 1.0)
	# poles at the corners and through the middle, planks every so often
	var poles := [-w - 3.0, 0.0, w + 3.0]
	for x in poles:
		draw_line(Vector2(x, d + 2.0), Vector2(x, d - tall - 6.0), SCAFFOLD_DARK, 2.5)
	var level := d - 10.0
	while level > d - tall:
		draw_line(Vector2(-w - 6.0, level), Vector2(w + 6.0, level), SCAFFOLD, 2.5)
		level -= 26.0
	draw_line(Vector2(-w - 3.0, d), Vector2(w + 3.0, d - tall), SCAFFOLD_DARK, 1.5)
	var at := Vector2(-bar_width * 0.5, -bar_height - 10.0)
	draw_rect(Rect2(at, Vector2(bar_width, 5.0)), BAR_BACK)
	draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2((bar_width - 2.0) * built, 3.0)), BUILD_BAR)

func _draw_ruin() -> void:
	var w := footprint.x * 0.5
	for i in range(7):
		var x := lerpf(-w, w, float(i) / 6.0)
		var r := 5.0 + float((i * 7) % 5)
		draw_circle(Vector2(x, -r * 0.4 + float((i * 3) % 4) - 2.0), r, RUBBLE if i % 2 == 0 else RUBBLE_DARK)

func _draw_health() -> void:
	if health >= health_max:
		return
	var at := Vector2(-bar_width * 0.5, -bar_height - 10.0)
	draw_rect(Rect2(at, Vector2(bar_width, 5.0)), BAR_BACK)
	var share := health / health_max
	draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2((bar_width - 2.0) * share, 3.0)),
		BAR_HURT.lerp(BAR_WELL, share))

## A colour, whitened for a moment after each blow, so a hit reads on a wall
## that does not flinch.
func _tint(base: Color) -> Color:
	return base.lerp(Color.WHITE, 0.55 * flash / FLASH_TIME) if flash > 0.0 else base
