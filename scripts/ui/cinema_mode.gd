class_name CinemaMode
extends CanvasLayer
## Filming mode, for trailers and clips. F10 turns it on and off (Esc also
## turns it off). While it is on:
##
##   the HUD, the selection ring and the health bars are gone, and the cursor
##   hides once the mouse has been still for a moment
##   WASD / arrows      the camera glides (Shift: slowly), C keeps it drifting
##   wheel, Q / E       smooth zoom, further in and out than in play
##   left click         follow that body (on empty ground: stop following)
##   F                  follow the one looked at, or whoever is nearest the middle
##   Ctrl+1..9          remember this shot (kept per map between runs)
##   1..9               glide to a remembered shot, Shift+1..9 cut straight to it
##   [ ]                how long a glide takes
##   Z / X              slower / faster time, Space freezes the frame
##   B                  wide-screen bars      V  fog of war off / on
##   N                  on to the next time of day
##   R                  rain: always / never / as the sky says
##   U                  health bars back      H  no hints at all      F1  the keys
##
## Everything here is for the eye, except N and R, which change the sky and so
## how far everyone sees. The right button still gives orders, so the army can
## be directed with nothing on the screen.
##
## Made by the HUD for its match. It drives the RtsCamera itself (`steered`),
## and it keeps time by real seconds, so the camera does not slow with the
## game.

const TOGGLE_KEY := KEY_F10
const PAN_SPEED := 380.0          ## screen px a second at full speed
const SLOW := 0.3                 ## with Shift held
const PAN_EASE := 3.5             ## how quickly the glide picks up and dies away
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.6
const ZOOM_NOTCH := 1.12          ## one wheel click
const ZOOM_HOLD := 0.9            ## per second with Q / E held, as a power of e
const ZOOM_EASE := 5.0
const FOLLOW_EASE := 2.5
const FOLLOW_LIFT := Vector2(0.0, -40.0)   ## frame the body, not its feet
const GLIDES := [2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0, 20.0]
const SPEEDS := [0.1, 0.25, 0.5, 1.0, 1.5, 2.0]
const BAR_SHARE := 0.12           ## each wide-screen bar, of the screen's height
const HIDE_CURSOR_AFTER := 1.2
const SAY_TIME := 1.6
const HINT_TIME := 5.0
const SHOTS_FILE := "user://cinema_shots.cfg"

var hud: Node = null              ## the HUD that made us, hidden while filming
var active := false
var camera: RtsCamera = null
var velocity := Vector2.ZERO
var cruising := false
var target_zoom := 1.0
var following: Node2D = null
var shots := {}                   ## slot (1..9) -> [position, zoom]
var glide := 2                    ## index into GLIDES
var speed := 3                    ## index into SPEEDS
var bars := false
var bars_shown := 0.0             ## 0..1, eased
var quiet := false                ## no hints and no notes at all
var show_keys := false
var shots_file := SHOTS_FILE      ## tests point this elsewhere

var _glide_from := Vector3.ZERO   ## x, y, zoom
var _glide_to := Vector3.ZERO
var _glide_time := 0.0
var _glide_left := 0.0
var _froze := false
var _fog_was := false
var _still := 0.0                 ## seconds since the mouse last moved
var _note := ""
var _note_left := 0.0
var _hint_left := 0.0
var _screen: Control

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.draw.connect(_draw_screen)
	add_child(_screen)

func _exit_tree() -> void:
	if active:
		stop()

# --- on and off ------------------------------------------------------------------

func start() -> void:
	camera = get_viewport().get_camera_2d() as RtsCamera
	if camera == null or active:
		return
	active = true
	camera.steered = true
	target_zoom = camera.zoom.x
	velocity = Vector2.ZERO
	cruising = false
	_froze = false
	Pen.bare = true
	_redraw_buildings()
	if hud != null:
		hud.visible = false
	_fog_was = FogOfWar.current != null and FogOfWar.current.lifted
	_load_shots()
	_hint_left = HINT_TIME
	_still = 0.0

func stop() -> void:
	if not active:
		return
	active = false
	Engine.time_scale = 1.0
	speed = SPEEDS.find(1.0)
	if _froze and is_inside_tree():
		get_tree().paused = false
	_froze = false
	following = null
	Pen.bare = false
	_redraw_buildings()
	if FogOfWar.current != null:
		FogOfWar.current.set_lifted(_fog_was)
	if hud != null and is_instance_valid(hud):
		hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if camera != null and is_instance_valid(camera):
		camera.steered = false
		var z := clampf(camera.zoom.x, RtsCamera.ZOOM_MIN, RtsCamera.ZOOM_MAX)
		camera.zoom = Vector2(z, z)
		camera._clamp()
	bars_shown = 0.0
	_screen.queue_redraw()

func _redraw_buildings() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("buildings"):
		(node as CanvasItem).queue_redraw()

# --- input -----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		if active:
			stop()
		elif GameState.phase != GameState.Phase.MENU:
			start()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventMouseMotion:
		_still = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	var click := event as InputEventMouseButton
	if click != null:
		_on_click(click)
		return
	if key != null:
		# every key is ours while filming, so none reaches the HUD's cards
		get_viewport().set_input_as_handled()
		if key.pressed and not key.echo:
			_on_key(key)

func _on_click(click: InputEventMouseButton) -> void:
	if not click.pressed:
		return
	match click.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_to(target_zoom * ZOOM_NOTCH)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_to(target_zoom / ZOOM_NOTCH)
		MOUSE_BUTTON_LEFT:
			var body := _body_at(_to_world(click.position))
			following = body
			_glide_left = 0.0
			_say(tr("Слежу") if body != null else tr("Свободная камера"))
		_:
			return   # the right button goes on to the orders
	get_viewport().set_input_as_handled()

func _on_key(key: InputEventKey) -> void:
	var code := key.physical_keycode
	var slot: int = code - KEY_0
	if slot >= 1 and slot <= 9:
		if key.ctrl_pressed:
			_remember(slot)
		else:
			_go_to_shot(slot, key.shift_pressed)
		return
	match code:
		KEY_ESCAPE:
			stop()
		KEY_F:
			_toggle_follow()
		KEY_C:
			cruising = not cruising and velocity.length() > 5.0
			_say(tr("Дрейф") if cruising else tr("Дрейф выключен"))
		KEY_BRACKETLEFT:
			glide = maxi(0, glide - 1)
			_say(tr("Перелёт: %s с") % _num(GLIDES[glide]))
		KEY_BRACKETRIGHT:
			glide = mini(GLIDES.size() - 1, glide + 1)
			_say(tr("Перелёт: %s с") % _num(GLIDES[glide]))
		KEY_Z:
			_set_speed(speed - 1)
		KEY_X:
			_set_speed(speed + 1)
		KEY_SPACE:
			_toggle_freeze()
		KEY_B:
			bars = not bars
		KEY_V:
			_toggle_fog()
		KEY_N:
			_next_time_of_day()
		KEY_R:
			_cycle_rain()
		KEY_U:
			Pen.bare = not Pen.bare
			_redraw_buildings()
			_say(tr("Полоски здоровья: скрыты") if Pen.bare else tr("Полоски здоровья: видны"))
		KEY_H:
			quiet = not quiet
			show_keys = false
			_note_left = 0.0
			_hint_left = 0.0
		KEY_F1:
			show_keys = not show_keys
			quiet = false

# --- the camera ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		if bars_shown > 0.0:
			bars_shown = 0.0
			_screen.queue_redraw()
		return
	if camera == null or not is_instance_valid(camera):
		stop()
		return
	# _process is handed game time; the camera and the notes keep real time
	var real := delta / maxf(Engine.time_scale, 0.001)
	_still += real
	if _still > HIDE_CURSOR_AFTER and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
			and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_note_left = maxf(0.0, _note_left - real)
	_hint_left = maxf(0.0, _hint_left - real)
	bars_shown = move_toward(bars_shown, 1.0 if bars else 0.0, real * 2.5)
	_steer(real)
	_screen.queue_redraw()

func _steer(real: float) -> void:
	var push := _keys_push()
	if push != Vector2.ZERO:
		following = null
		_glide_left = 0.0
		cruising = false
	var zoom_hold := 0.0
	if Input.is_physical_key_pressed(KEY_E):
		zoom_hold += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		zoom_hold -= 1.0
	if zoom_hold != 0.0:
		_zoom_to(target_zoom * exp(zoom_hold * ZOOM_HOLD * real))
		_glide_left = 0.0

	if _glide_left > 0.0:
		_glide_left = maxf(0.0, _glide_left - real)
		var t := smoothstep(0.0, 1.0, 1.0 - _glide_left / _glide_time)
		camera.position = Vector2(lerpf(_glide_from.x, _glide_to.x, t), lerpf(_glide_from.y, _glide_to.y, t))
		# zoom moves evenly to the eye when it moves evenly in scale
		var z := exp(lerpf(log(_glide_from.z), log(_glide_to.z), t))
		camera.zoom = Vector2(z, z)
		target_zoom = z
		velocity = Vector2.ZERO
		camera._clamp()
		return

	var blend := 1.0 - exp(-ZOOM_EASE * real)
	var z := lerpf(camera.zoom.x, target_zoom, blend)
	camera.zoom = Vector2(z, z)

	if following != null and (not is_instance_valid(following) or following.is_queued_for_deletion()):
		following = null
	if following != null:
		var goal := following.global_position + FOLLOW_LIFT
		camera.position = camera.position.lerp(goal, 1.0 - exp(-FOLLOW_EASE * real))
		velocity = Vector2.ZERO
	else:
		var wish := velocity if cruising else push.normalized() * PAN_SPEED / z
		if push != Vector2.ZERO and Input.is_physical_key_pressed(KEY_SHIFT):
			wish *= SLOW
		velocity = velocity.lerp(wish, 1.0 - exp(-PAN_EASE * real))
		if velocity.length() < 0.5 and push == Vector2.ZERO:
			velocity = Vector2.ZERO
		camera.position += velocity * real
	camera._clamp()

func _keys_push() -> Vector2:
	var push := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		push.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		push.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		push.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		push.y += 1.0
	return push

## Zooming out stops where the view would outgrow the field and its sky.
func _zoom_to(z: float) -> void:
	var window := get_viewport().get_visible_rect().size
	var tall := float(camera.limit_bottom - camera.limit_top)
	var wide := float(camera.limit_right - camera.limit_left)
	var least := maxf(ZOOM_MIN, maxf(window.y / tall, window.x / wide))
	target_zoom = clampf(z, least, ZOOM_MAX)

func _toggle_follow() -> void:
	if following != null:
		following = null
		_say(tr("Свободная камера"))
		return
	var picked: Node2D = null
	var input: Node = hud.get("input") if hud != null else null
	if input != null and input.get("selected") != null and is_instance_valid(input.selected):
		picked = input.selected
	if picked == null:
		picked = _nearest_body(camera.position)
	following = picked
	_glide_left = 0.0
	_say(tr("Слежу") if picked != null else tr("Некого снимать"))

func _body_at(point: Vector2) -> Node2D:
	var input: Node = hud.get("input") if hud != null else null
	if input != null and input.has_method("body_at"):
		return input.body_at(point)
	return null

func _nearest_body(point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or body.is_dead or not body.visible:
			continue
		var distance := point.distance_squared_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

func _to_world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen

# --- shots -----------------------------------------------------------------------

func _remember(slot: int) -> void:
	shots[slot] = [camera.position, camera.zoom.x]
	_save_shots()
	_say(tr("Кадр %d запомнен") % slot)

func _go_to_shot(slot: int, cut: bool) -> void:
	if not shots.has(slot):
		_say(tr("Кадр %d пуст: Ctrl+%d — запомнить") % [slot, slot])
		return
	var shot: Array = shots[slot]
	following = null
	cruising = false
	velocity = Vector2.ZERO
	if cut:
		camera.position = shot[0]
		camera.zoom = Vector2(shot[1], shot[1])
		target_zoom = shot[1]
		_glide_left = 0.0
		camera._clamp()
		return
	_glide_from = Vector3(camera.position.x, camera.position.y, camera.zoom.x)
	_glide_to = Vector3(shot[0].x, shot[0].y, shot[1])
	_glide_time = GLIDES[glide]
	_glide_left = _glide_time

func _shots_section() -> String:
	var field: MapBuilder = GameState.field() if GameState.has_method("field") else null
	if field != null and field.map != null and field.map.title != "":
		return field.map.title
	return "map"

func _load_shots() -> void:
	shots.clear()
	var file := ConfigFile.new()
	if file.load(shots_file) != OK:
		return
	var section := _shots_section()
	for slot in range(1, 10):
		var shot: Variant = file.get_value(section, str(slot), null)
		if shot is Array and (shot as Array).size() == 2:
			shots[slot] = shot

func _save_shots() -> void:
	var file := ConfigFile.new()
	file.load(shots_file)
	var section := _shots_section()
	for slot in shots:
		file.set_value(section, str(slot), shots[slot])
	file.save(shots_file)

# --- time and the sky ------------------------------------------------------------

func _set_speed(index: int) -> void:
	speed = clampi(index, 0, SPEEDS.size() - 1)
	Engine.time_scale = SPEEDS[speed]
	_say(tr("Скорость ×%s") % _num(SPEEDS[speed]))

func _toggle_freeze() -> void:
	if not GameState.is_playing():
		return
	if _froze:
		get_tree().paused = false
		_froze = false
		_say(tr("Пуск"))
	elif not get_tree().paused:
		get_tree().paused = true
		_froze = true
		_say(tr("Стоп-кадр"))

func _toggle_fog() -> void:
	var fog := FogOfWar.current
	if fog == null:
		_say(tr("Тумана нет"))
		return
	fog.set_lifted(not fog.lifted)
	_say(tr("Туман войны: снят") if fog.lifted else tr("Туман войны: есть"))

## Sets the clock a little before the next change of the sky, so the change
## itself is seen.
func _next_time_of_day() -> void:
	var sky := Weather.current
	if sky == null:
		_say(tr("Погоды нет"))
		return
	var hour := fmod(sky.clock, Weather.DAWN_END)
	var day_start := sky.clock - hour
	var marks := [Weather.DAY_END, Weather.DUSK_END, Weather.NIGHT_END, Weather.DAWN_END]
	var names := ["Скоро: сумерки", "Скоро: ночь", "Скоро: рассвет", "Скоро: день"]
	for i in marks.size():
		if hour < marks[i] - 3.0:
			sky.clock = day_start + marks[i] - 2.0
			_say(tr(names[i]))
			return
	sky.clock = day_start + Weather.DAWN_END + Weather.DAY_END - 2.0
	_say(tr("Скоро: сумерки"))

func _cycle_rain() -> void:
	var sky := Weather.current
	if sky == null:
		_say(tr("Погоды нет"))
		return
	sky.forced_rain = 1 if sky.forced_rain == -1 else (0 if sky.forced_rain == 1 else -1)
	_say(tr({-1: "Дождь: как по небу", 1: "Дождь: всегда", 0: "Дождь: никогда"}[sky.forced_rain]))

# --- what is drawn over the picture ----------------------------------------------

func _say(text: String) -> void:
	_note = text
	_note_left = SAY_TIME

static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)

func _draw_screen() -> void:
	if not active:
		return
	var size := _screen.size
	if bars_shown > 0.0:
		var tall := size.y * BAR_SHARE * smoothstep(0.0, 1.0, bars_shown)
		_screen.draw_rect(Rect2(0.0, 0.0, size.x, tall), Color.BLACK)
		_screen.draw_rect(Rect2(0.0, size.y - tall, size.x, tall), Color.BLACK)
	if quiet:
		return
	var font := ThemeDB.fallback_font
	if show_keys:
		_draw_keys(font, size)
	elif _hint_left > 0.0:
		var fade := clampf(_hint_left, 0.0, 1.0)
		_text(font, Vector2(16.0, size.y - 20.0),
			tr("Режим съёмки · F1 — клавиши · H — без подсказок · F10 — выход"), 14, fade)
	if _note_left > 0.0:
		var fade := clampf(_note_left / 0.4, 0.0, 1.0)
		var wide := font.get_string_size(_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_text(font, Vector2((size.x - wide) * 0.5, 40.0), _note, 16, fade)

const KEY_LINES := [
	"WASD / стрелки — камера (Shift — медленно),  C — дрейф",
	"колесо, Q / E — приближение",
	"ЛКМ по бойцу — следить,  F — следить за выбранным / ближайшим",
	"Ctrl+1..9 — запомнить кадр,  1..9 — перелёт,  Shift+1..9 — склейка",
	"[ ] — длительность перелёта",
	"Z / X — медленнее / быстрее,  Пробел — стоп-кадр",
	"B — широкий экран,  V — туман войны,  U — полоски здоровья",
	"N — следующее время суток,  R — дождь",
	"ПКМ — приказ армии,  H — скрыть всё,  F10 / Esc — выход",
]

func _draw_keys(font: Font, size: Vector2) -> void:
	var line := 20.0
	var bottom := size.y - size.y * BAR_SHARE * smoothstep(0.0, 1.0, bars_shown) - 10.0
	var box := Rect2(12.0, bottom - 14.0 - line * KEY_LINES.size(), 520.0, line * KEY_LINES.size() + 14.0)
	_screen.draw_rect(box, Color(0.05, 0.04, 0.03, 0.78))
	for i in KEY_LINES.size():
		_text(font, box.position + Vector2(10.0, 18.0 + line * i), tr(KEY_LINES[i]), 13, 1.0)
	var state := tr("скорость ×%s · перелёт %s с · кадров: %d") % [_num(SPEEDS[speed]), _num(GLIDES[glide]), shots.size()]
	_text(font, box.position + Vector2(10.0, -8.0), state, 13, 1.0)

func _text(font: Font, at: Vector2, text: String, size: int, fade: float) -> void:
	_screen.draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * fade))
	_screen.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.93, 0.78, fade))
