class_name Weather
extends Node2D
## The sky over a match: day turning to night and back, and spells of rain.
##
## It is part of the game, not only of the picture. At night everyone sees
## less far (`sight()`), towers included; in the rain bowstrings go slack and
## torches smoulder (`shot_scale()`, `fire_scale()`). Both sides are under the
## same sky, and the rain comes when the map's own seed says it does, so a
## match played twice has the same weather.
##
## The picture is three layers over the whole field, above everything on it:
## a shade that darkens and tints it, the light of windows and torches through
## the dark (added on, so it glows), and the rain. The panel is on its own
## layer and stays as it is.
##
## One per match, made by MapBuilder; anything that asks with none about (the
## testbed) gets plain daylight.

signal phase_changed(phase: String)
signal rain_changed(raining: bool)

## The day, in seconds of play: day, dusk, night, dawn, and round again.
const DAY_END := 150.0
const DUSK_END := 175.0
const NIGHT_END := 265.0
const DAWN_END := 300.0

const NIGHT_SIGHT := 0.6       ## what the dark leaves of how far anyone sees
const RAIN_SIGHT := 0.9
const NIGHT_TOWER := 0.8       ## and of how far a tower sees to shoot
const RAIN_BOW := 0.7          ## a wet bowstring
const RAIN_CROSSBOW := 0.85    ## a crossbow minds less
const RAIN_FIRE := 0.5         ## a torch in the rain

const FIRST_RAIN := 100.0      ## nobody starts a match soaked
const RAIN_GAP := Vector2(90.0, 220.0)
const RAIN_LONG := Vector2(40.0, 80.0)
const RAIN_FADE := 5.0         ## seconds for the rain to come on or die away

const NIGHT_SHADE := Color(0.03, 0.05, 0.16, 0.58)
const DUSK_SHADE := Color(0.55, 0.22, 0.08, 0.22)
const RAIN_SHADE := Color(0.20, 0.23, 0.28, 0.28)
const DROP := Color(0.75, 0.82, 0.92, 0.45)
const WINDOW := Color(1.0, 0.72, 0.35)
const TORCH := Color(1.0, 0.60, 0.22)
const DROPS := 240
const DROP_FALL := 900.0       ## px a second
const DROP_LEAN := Vector2(-0.18, 1.0)

static var current: Weather = null

var clock := 0.0               ## seconds since the match began
var rain := 0.0                ## 0 dry to 1 pouring, fading between
var phase := "day"
var spells: Array[Vector2] = [] ## [start, end] of each rain, in seconds
var forced_rain := -1          ## tests: 1 always raining, 0 never, -1 as the sky says
var _raining := false
var _drops: PackedVector2Array = PackedVector2Array()
var _glow: Node2D
var _rain: Node2D

## Lays out the rain for the match from `seed_text` (the map's title).
func _init(seed_text: String = "") -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(seed_text)
	var at := FIRST_RAIN + dice.randf_range(0.0, 60.0)
	while at < 3600.0:
		var long := dice.randf_range(RAIN_LONG.x, RAIN_LONG.y)
		spells.append(Vector2(at, at + long))
		at += long + dice.randf_range(RAIN_GAP.x, RAIN_GAP.y)
	for i in DROPS:
		_drops.append(Vector2(dice.randf(), dice.randf()))

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

func _ready() -> void:
	z_index = 4000
	z_as_relative = false
	_glow = Node2D.new()
	_glow.z_index = 4001
	_glow.z_as_relative = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_rain = Node2D.new()
	_rain.z_index = 4002
	_rain.z_as_relative = false
	_rain.draw.connect(_draw_rain)
	add_child(_rain)

func _physics_process(delta: float) -> void:
	clock += delta
	var next := phase_at(clock)
	if next != phase:
		phase = next
		phase_changed.emit(phase)
	var wet := _wet_at(clock)
	if forced_rain >= 0:
		wet = forced_rain == 1
	rain = move_toward(rain, 1.0 if wet else 0.0, delta / RAIN_FADE)
	var raining := rain > 0.5
	if raining != _raining:
		_raining = raining
		rain_changed.emit(raining)

func _process(_delta: float) -> void:
	queue_redraw()
	_glow.queue_redraw()
	_rain.queue_redraw()

# --- the time of day -------------------------------------------------------------

static func phase_at(t: float) -> String:
	var hour := fmod(t, DAWN_END)
	if hour < DAY_END:
		return "day"
	if hour < DUSK_END:
		return "dusk"
	if hour < NIGHT_END:
		return "night"
	return "dawn"

## How dark it is at `t`: 0 in full day, 1 in the dead of night.
static func darkness_at(t: float) -> float:
	var hour := fmod(t, DAWN_END)
	if hour < DAY_END:
		return 0.0
	if hour < DUSK_END:
		return smoothstep(DAY_END, DUSK_END, hour)
	if hour < NIGHT_END:
		return 1.0
	return 1.0 - smoothstep(NIGHT_END, DAWN_END, hour)

func darkness() -> float:
	return darkness_at(clock)

## Whether a spell of rain is on at `t`.
func _wet_at(t: float) -> bool:
	for spell in spells:
		if t < spell.x:
			return false
		if t < spell.y:
			return true
	return false

func is_raining() -> bool:
	return _raining

## Seconds until the next change of the sky, for the panel.
func next_rain_after(t: float) -> float:
	for spell in spells:
		if spell.x > t:
			return spell.x - t
	return INF

# --- what it does to the fighting -------------------------------------------------

## The share of their usual sight anyone has now.
static func sight() -> float:
	if current == null:
		return 1.0
	var share := lerpf(1.0, NIGHT_SIGHT, current.darkness())
	return share * (RAIN_SIGHT if current.is_raining() else 1.0)

## The share of a tower's usual range it can see to shoot.
static func tower_sight() -> float:
	if current == null:
		return 1.0
	return lerpf(1.0, NIGHT_TOWER, current.darkness())

## What the rain leaves of a shot from `weapon`.
static func shot_scale(weapon: int) -> float:
	if current == null or not current.is_raining():
		return 1.0
	match weapon:
		PlayerBody.Weapon.BOW:
			return RAIN_BOW
		PlayerBody.Weapon.CROSSBOW:
			return RAIN_CROSSBOW
	return 1.0

## What the rain leaves of fire against a wall.
static func fire_scale() -> float:
	return RAIN_FIRE if current != null and current.is_raining() else 1.0

# --- the picture ---------------------------------------------------------------------

## The part of the field on screen, in world space.
func _view() -> Rect2:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport_rect().size
	return Rect2(inverse * Vector2.ZERO, inverse.basis_xform(size))

## The shade over everything: warm at dusk, deep blue at night, grey in rain.
func _draw() -> void:
	var dark := darkness()
	var hour := fmod(clock, DAWN_END)
	var warm := 0.0
	if hour >= DAY_END and hour < NIGHT_END:
		warm = 1.0 - absf(dark - 0.5) * 2.0
	elif hour >= NIGHT_END:
		warm = 1.0 - absf(dark - 0.5) * 2.0
	var view := _view().grow(40.0)
	if rain > 0.0:
		draw_rect(view, Color(RAIN_SHADE, RAIN_SHADE.a * rain))
	if warm > 0.0:
		draw_rect(view, Color(DUSK_SHADE, DUSK_SHADE.a * warm))
	if dark > 0.0:
		draw_rect(view, Color(NIGHT_SHADE, NIGHT_SHADE.a * dark))

## Windows lit in every building and torches in hand, brighter the darker it is.
func _draw_glow() -> void:
	var dark := darkness()
	if dark <= 0.02:
		return
	var view := _view().grow(80.0)
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or not building.is_alive() or not building.is_complete() or building.team == Team.Id.NEUTRAL 				or not building.visible:
			continue
		if not view.has_point(building.global_position):
			continue
		var wide := building.footprint.x * 0.5
		var lights := 3 if wide > 100.0 else 1
		for i in lights:
			var x := 0.0 if lights == 1 else lerpf(-wide * 0.6, wide * 0.6, float(i) / float(lights - 1))
			_halo(building.global_position + Vector2(x, -building.bar_height * 0.45), 40.0, WINDOW, dark)
	for node in get_tree().get_nodes_in_group("camps"):
		var camp := node as BanditCamp
		if not camp.is_cleared and camp.visible and view.has_point(camp.global_position):
			_halo(camp.fire_point(), 70.0, TORCH, dark)
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or body.is_dead or body.weapon != PlayerBody.Weapon.TORCH or not body.visible:
			continue
		if view.has_point(body.global_position):
			_halo(body.global_position + Vector2(body.facing_x * 12.0, -62.0), 40.0, TORCH, dark)

## A soft pool of light: rings laid over each other, so it brightens smoothly
## towards the middle.
const HALO_RINGS := 7

func _halo(at: Vector2, radius: float, tint: Color, strength: float) -> void:
	for k in HALO_RINGS:
		var share := 1.0 - float(k) / float(HALO_RINGS)
		_glow.draw_circle(at, radius * share, Color(tint, 0.05 * strength))

## Streaks of rain across the screen, in one batch.
func _draw_rain() -> void:
	if rain <= 0.01:
		return
	var view := _view()
	var count := int(DROPS * rain)
	var streak := DROP_LEAN * (14.0 / view.size.y * get_viewport_rect().size.y) * 1.0
	var lines := PackedVector2Array()
	lines.resize(count * 2)
	var fall := clock * DROP_FALL
	for i in count:
		var seed_at := _drops[i]
		var y := fmod(seed_at.y * view.size.y + fall * (0.8 + 0.4 * seed_at.x), view.size.y)
		var x := fmod(seed_at.x * view.size.x + y * absf(DROP_LEAN.x) + 4000.0, view.size.x)
		var top := view.position + Vector2(x, y)
		lines[i * 2] = top
		lines[i * 2 + 1] = top + streak
	_rain.draw_multiline(lines, Color(DROP, DROP.a * rain), 1.2)
