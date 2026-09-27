extends CanvasLayer
## The human side's panel.
##
##   top left    what is in the store, how big the army is, how many hands
##   top right   the whole field in miniature (Minimap)
##   bottom      tabs of cards -- hire, build, learn -- what is under way,
##               and the two orders for the army
##
## It reads the side through GameState and does everything through GameState's
## commands, so there is nothing here the enemy's head could not do as well.
## Placing a building is handed to the input adapter, which owns the mouse on
## the field; TouchInput, made here, turns fingers into the adapter's calls.
## For a finger, holding a card shows what it is about (with its Shift action),
## the top bar has a pause button, and the Android back button acts as Esc.

## The tabs of cards: what each holds, and whether its cards hire, build or learn.
## No more than six to a tab, which is what fits beside the status column.
const TABS := [
	{"title": "Рабочие", "does": "hire", "cards": ["worker", "wood", "ore", "gold", "repair"]},
	{"title": "Пехота", "does": "hire", "cards": ["warrior", "spearman", "axeman", "swordsman", "greatsword", "knight"]},
	{"title": "Особые", "does": "hire", "cards": ["archer", "crossbowman", "mage", "scout", "torchbearer"]},
	{"title": "Постройки", "does": "build", "cards": ["barracks", "tower", "library", "forge"]},
	{"title": "Кузница", "does": "forge", "cards": ["smith", "helm", "armour", "shield", "arms"]},
	{"title": "Оружие", "does": "learn", "cards": ["spears", "axes", "blades", "greatswords", "chivalry", "daggers"]},
	{"title": "Науки", "does": "learn", "cards": ["archery", "crossbows", "fire", "forging", "mail"]},
	{"title": "Магия", "does": "learn", "cards": ["magic", "healing"]},
]
const NAMES := {
	"worker": "Рабочий", "wood": "Лес", "ore": "Руда", "gold": "Золото", "repair": "Ремонт",
	"woodcutter": "Лесоруб", "miner": "Рудокоп", "gold_miner": "Старатель",
	"warrior": "Воин", "spearman": "Копейщик", "archer": "Лучник",
	"crossbowman": "Арбалетчик", "knight": "Рыцарь",
	"axeman": "Секироносец", "swordsman": "Мечник", "greatsword": "Двуручник",
	"scout": "Лазутчик", "torchbearer": "Поджигатель", "mage": "Маг",
}
const ABOUT := {
	"worker": "Нанимается в замке. Идёт туда, где рук меньше: на лес или на руду. Стоит 10 дерева или 10 руды — чего на складе больше.",
	"wood": "Переводит одного рабочего на лес: рубит деревья и носит брёвна на склад.",
	"ore": "Переводит одного рабочего на руду: добывает её в жилах и носит на склад.",
	"gold": "Переводит одного рабочего на золото: оно нужно для знаний.",
	"repair": "Ставит рабочего на ремонт: он обходит повреждённые постройки с молотом, начиная с самой разбитой. 1 дерево за удар (+12 прочности). Не чинит, пока рядом враг. Когда чинить нечего, собирает трофеи по всему полю и несёт в кузницу. Не больше четырёх.",
	"woodcutter": "Рубит деревья и носит брёвна на склад.",
	"miner": "Добывает руду в жилах и носит на склад.",
	"gold_miner": "Добывает золото: оно нужно для знаний.",
	"warrior": "Дешёвый боец с дубиной. Доступен сразу.",
	"spearman": "Копьё бьёт сильнее дубины, шлем бережёт голову.",
	"archer": "Стреляет издалека и отходит от тех, кто подбирается близко. Хрупкий.",
	"crossbowman": "Бьёт дальше и сильнее лучника, но между выстрелами взводит арбалет.",
	"knight": "Латы, меч и щит: крепче и сильнее всех.",
	"axeman": "Секира рубит сильнее меча и ломает стены в полтора раза быстрее. Без доспеха.",
	"swordsman": "Меч и шлем: крепкий, ровный боец, быстрее бьёт, чем секироносец.",
	"greatsword": "Двуручный меч и латы: самый тяжёлый удар, но медленный и быстро выдыхается.",
	"scout": "Быстрый и дешёвый, с кинжалом. Видит почти вдвое дальше других — глаза армии в тумане войны. Первым делом режет вражеских рабочих.",
	"torchbearer": "Слаб в бою, но факел жжёт постройки вчетверо быстрее.",
	"mage": "Посох бьёт молнией издалека, сильнее арбалета. Очень хрупкий. С «Исцелением» лечит своих.",
}
const STOCK_HINT := "Shift+клик — выковать оружие в запас."
const RETURN_HINT := "Shift+клик — вернуть одного к прежней работе."
const SMITH_ABOUT := "Кузнецы приходят сами: когда в кузнице есть заказ, к свободной наковальне идёт рабочий — с того промысла, где рук больше всего, ближайший к кузнице. Закончив работу, он через несколько секунд возвращается к прежнему делу. У кузницы две наковальни. Последнего добытчика к наковальне не берут."
const ARMS_ABOUT := "Склад кузницы: выкованное оружие и снаряжение. Новобранцы забирают своё оружие здесь. Сюда же рабочие приносят трофеи — оружие и доспехи павших, своих и чужих."
## How far along an order for a soldier is, for its card.
const DRAFT_STAGE := {Draft.Stage.HIRING: "найм", Draft.Stage.CARRYING: "несёт"}
## What each weapon is called in the unit window.
const WEAPON_NAMES := {
	PlayerBody.Weapon.NONE: "без оружия", PlayerBody.Weapon.AXE: "секира", PlayerBody.Weapon.SPEAR: "копьё",
	PlayerBody.Weapon.BOW: "лук", PlayerBody.Weapon.SWORD: "меч", PlayerBody.Weapon.SWORD_SHIELD: "меч и щит",
	PlayerBody.Weapon.GREATSWORD: "двуручный меч", PlayerBody.Weapon.PICKAXE: "кирка",
	PlayerBody.Weapon.DAGGER: "кинжал", PlayerBody.Weapon.STAFF: "посох", PlayerBody.Weapon.TORCH: "факел",
	PlayerBody.Weapon.CROSSBOW: "арбалет", PlayerBody.Weapon.CLUB: "дубина", PlayerBody.Weapon.HAMMER: "молот",
}
const JOB_NAMES := {"wood": "рубит лес", "ore": "добывает руду", "gold": "добывает золото", "build": "строит",
	"smith": "кузнец у наковальни", "repair": "чинит постройки", "recruit": "новобранец"}
const SKY_NAMES := {"day": "День", "dusk": "Сумерки", "night": "Ночь", "dawn": "Рассвет"}
const SKY_ABOUT := "Ночью все видят хуже: бойцы замечают врага на 40% ближе, башни стреляют на 20% ближе.\nВ дождь луки бьют на 30% слабее, арбалеты на 15%, факелы жгут вдвое хуже, и обзор ещё немного меньше."
const REFRESH := 0.1
const MESSAGE_TIME := 2.6
const TOAST_TIME := 3.5

var root: Control
var chips := {}                ## "wood" / "ore" / "gold" / "army" / "hands" -> Label
var watch_label: RichTextLabel
var minimap: Minimap
## Filming mode (F10): hides this whole layer and takes over the camera.
var cinema: CinemaMode
var bottom_bar: Control
var tab_buttons: Array[Button] = []
var cards_row: HBoxContainer
var cards := {}                ## tab index -> Array[HudCard]
var tab := 0
var status: StatusView
var message: Label
var message_left := 0.0
var toast: PanelContainer
var toast_label: Label
var toast_left := 0.0
var toast_queue: Array[String] = []
var overlay: Control
var overlay_title: Label
var overlay_note: Label
var resume_button: Button
var next_button: Button
var objective: Label
var rules: RoomRules
var sky_icon: Control
var sky_label: Label
var sky_kind := ""
var unit_panel: PanelContainer
var unit_title: Label
var unit_text: RichTextLabel
## What a held card is about, with its second action (what Shift+click does).
var card_info: PanelContainer
var card_info_title: Label
var card_info_text: Label
var card_info_alt: Button
var card_info_do := Callable()
## Under way on the field: placing a building or moving the gathering point,
## with a way out that needs no Esc or right button.
var mode_bar: PanelContainer
var mode_label: Label
var rally_button: OrderButton
var touch: TouchInput
## On a phone or a small tablet: bigger tabs, a smaller minimap, and what is
## under way moved from the bottom bar to under the minimap, so the whole panel
## can be drawn bigger (see _fit) and still fit across the screen.
var compact := false
var bar_height := 106.0        ## the bottom bar; windows over it stand above this
var ui_scale := 1.0
var refresh_left := 0.0
@onready var input: Node = get_node_or_null("PlayerInput")

## What is under way on our side: the barracks queue, the study, the sites.
class StatusView:
	extends Control
	var hud: Node
	func _init() -> void:
		custom_minimum_size = Vector2(164.0, 78.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var side: PlayerState = GameState.human()
		if side == null:
			return
		var font := get_theme_default_font()
		var y := 12.0
		# the values start past the widest heading, however long it is in this language
		var col := 56.0
		for heading in [tr("Найм"), tr("Знания"), tr("Стройка")]:
			col = maxf(col, font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0)
		var wide := size.x - col - 2.0
		# who is being hired: the castle's labourers, then the barracks' soldiers,
		# each first one with its bar
		draw_string(font, Vector2(0.0, y), tr("Найм"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		var qx := col
		for where in [side.base(), side.barracks()]:
			if where == null or where.queue.is_empty():
				continue
			for i in where.queue.size():
				if qx > size.x - 14.0:
					break
				Icons.draw(self, where.queue[i], Rect2(Vector2(qx, y - 11.0), Vector2(18.0, 18.0)))
				if i == 0:
					UiStyle.bar(self, Rect2(Vector2(qx, y + 8.0), Vector2(18.0, 3.0)), where.current_share())
				qx += 22.0
		if qx == col:
			var idle := tr("нет казармы") if side.barracks() == null else tr("никого")
			draw_string(font, Vector2(col, y), idle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		y += 26.0
		# the study, if there is a library to do it in
		draw_string(font, Vector2(0.0, y), tr("Знания"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		if side.researching != "":
			draw_string(font, Vector2(col, y), tr(PlayerState.RESEARCH[side.researching]["title"]), HORIZONTAL_ALIGNMENT_LEFT, wide, 11, UiStyle.TEXT)
			UiStyle.bar(self, Rect2(Vector2(col, y + 5.0), Vector2(wide, 3.0)), side.research_share(), UiStyle.STUDY_FILL)
		elif side.library() == null:
			draw_string(font, Vector2(col, y), tr("нужна библиотека") if not side.has_library_site() else tr("библиотека строится"),
				HORIZONTAL_ALIGNMENT_LEFT, wide, 11, UiStyle.DIM)
		else:
			draw_string(font, Vector2(col, y), tr("ничего не изучается"), HORIZONTAL_ALIGNMENT_LEFT, wide, 11, UiStyle.DIM)
		y += 26.0
		# sites still going up
		draw_string(font, Vector2(0.0, y), tr("Стройка"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		var x := col
		var any := false
		for building in side.buildings:
			if is_instance_valid(building) and building.is_alive() and not building.is_complete():
				Icons.draw(self, Icons.site_of(building), Rect2(Vector2(x, y - 11.0), Vector2(18.0, 18.0)))
				UiStyle.bar(self, Rect2(Vector2(x, y + 8.0), Vector2(18.0, 3.0)), building.built)
				x += 22.0
				any = true
		if not any:
			draw_string(font, Vector2(col, y), tr("нет"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)

## A big square order button: a picture and a word under it. A compact one is
## half as tall, so two stack beside a big one.
class OrderButton:
	extends Button
	var icon_kind := ""
	var caption := ""
	var compact := false
	func _init() -> void:
		custom_minimum_size = Vector2(60.0, 72.0)
		focus_mode = Control.FOCUS_NONE
	func make_compact() -> void:
		compact = true
		custom_minimum_size = Vector2(60.0, 44.0)
	func _draw() -> void:
		if button_pressed:
			draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), UiStyle.GOLD_BRIGHT, false, 2.0)
		var picture := 22.0 if compact else 34.0
		Icons.draw(self, icon_kind, Rect2(Vector2((size.x - picture) * 0.5, 4.0 if compact else 8.0), Vector2(picture, picture)))
		var font := get_theme_default_font()
		var font_size := 11 if compact else 12
		var wide := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2((size.x - wide) * 0.5, 38.0 if compact else 62.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.TEXT)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	compact = UiStyle.compact()
	bar_height = 118.0 if compact else 106.0
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)
	_build_top_bar()
	_build_minimap()
	_build_bottom_bar()
	_build_objective()
	_build_message()
	_build_toast()
	_build_overlay()
	_build_unit_panel()
	_build_card_info()
	_build_mode_bar()
	bottom_bar.visible = not GameState.spectating
	GameState.match_ended.connect(_on_match_ended)
	GameState.match_started.connect(_on_match_started)
	GameState.built.connect(_on_built)
	var achievements := get_node_or_null("/root/Achievements")
	if achievements != null:
		achievements.unlocked.connect(func(id: String) -> void: toast_queue.append(id))
	if input != null and input.has_signal("refused"):
		input.refused.connect(say)
	if input != null and input.has_signal("picked"):
		input.picked.connect(func(_body: PlayerBody) -> void: _refresh_unit())
	if input != null and input.has_signal("mode_changed"):
		input.mode_changed.connect(_refresh_mode)
	touch = TouchInput.new()
	touch.name = "Touch"
	touch.adapter = input
	add_child(touch)
	cinema = CinemaMode.new()
	cinema.name = "Cinema"
	cinema.hud = self
	get_parent().add_child.call_deferred(cinema)
	_select_tab(0)
	get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()

## Draws the panel as big as the screen wants (UiStyle.wanted_scale) but no
## bigger than lets the bottom bar fit across, inside the screen's safe area,
## and tells the camera how much of the field the bars now cover.
func _fit() -> void:
	var margins := UiStyle.safe_margins(get_viewport())
	var room := get_viewport().get_visible_rect().size - margins.position - margins.size
	var needed := bottom_bar.get_combined_minimum_size().x + 16.0
	ui_scale = clampf(minf(UiStyle.wanted_scale(), room.x / needed), 0.6, 3.0)
	UiStyle.fit(root, ui_scale)
	var camera := get_viewport().get_camera_2d() as RtsCamera
	if camera != null:
		camera.make_room(48.0 * ui_scale + margins.position.y, (bar_height - 16.0) * ui_scale + margins.size.y)

func _on_match_started() -> void:
	minimap.field = GameState.field()
	for node in get_tree().get_nodes_in_group("camps"):
		(node as BanditCamp).cleared.connect(_on_camp_cleared)
	var sky := GameState.field().get_node_or_null("Weather") as Weather
	if sky != null and not GameState.spectating:
		sky.phase_changed.connect(_on_sky_turned)
		sky.rain_changed.connect(func(raining: bool) -> void:
			say(tr("Дождь: луки и арбалеты бьют слабее, факелы хуже жгут") if raining else tr("Дождь кончился"), UiStyle.TEXT))
	rules = GameState.field().get_node_or_null("RoomRules") as RoomRules
	if rules != null:
		rules.gates_opened.connect(func() -> void: say(tr("Ворота вражеской крепости открыты — на штурм!"), UiStyle.GOLD_BRIGHT))
		rules.wave_sent.connect(func(i: int, n: int, line: String) -> void:
			say(tr("Волна %d: %d врагов идут на крепость!") % [i + 1, n] + ("\n" + tr(line) if line != "" else ""), UiStyle.BAD))
		rules.wave_beaten.connect(_on_wave_beaten)
	var side := GameState.human()
	if side == null or GameState.spectating:
		return
	side.research_done.connect(func(id: String) -> void: say(tr("Изучено: %s") % tr(PlayerState.RESEARCH[id]["title"]), UiStyle.GOOD))
	side.research_lost.connect(func(id: String) -> void: say(tr("Библиотека пала — «%s» потеряно") % tr(PlayerState.RESEARCH[id]["title"]), UiStyle.BAD))
	for building in side.buildings:
		_watch_building(building)

func _on_built(team: int, kind: String, building: Building) -> void:
	if team != GameState.human_team:
		return
	var side := GameState.human()
	if side != null and side.builder_of(building) == null:
		say(tr("Заложено: %s — нет свободных рабочих, стройка ждёт") % tr(GameState.BUILDINGS[kind]["title"]), UiStyle.BAD)
	else:
		say(tr("Заложено: %s — рабочий идёт строить") % tr(GameState.BUILDINGS[kind]["title"]))
	_watch_building(building)

func _watch_building(building: Building) -> void:
	if not building.completed.is_connected(_on_completed):
		building.completed.connect(_on_completed)

func _on_completed(building: Building) -> void:
	say(tr("Построено: %s") % tr(GameState.BUILDINGS[Icons.site_of(building)]["title"]), UiStyle.GOOD)

func _process(delta: float) -> void:
	_run_toast(delta)
	if message_left > 0.0:
		message_left -= delta
		message.modulate.a = clampf(message_left / 0.5, 0.0, 1.0)
		message.get_parent().visible = message_left > 0.0
	refresh_left -= delta
	if refresh_left <= 0.0:
		refresh_left = REFRESH
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_ESCAPE:
		_back(false)
		get_viewport().set_input_as_handled()
		return
	if GameState.spectating or get_tree().paused:
		return
	if key.physical_keycode == KEY_TAB:
		_select_tab((tab + 1) % TABS.size())
		get_viewport().set_input_as_handled()
		return
	var index: int = key.physical_keycode - KEY_1
	var row: Array = cards.get(tab, [])
	if index >= 0 and index < row.size():
		var card: HudCard = row[index]
		if not card.disabled:
			card.pressed.emit()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back(true)

## Esc, or the phone's back button: close whatever is open, one thing at a
## time, then pause. After the match the back button leaves for the menu.
func _back(leave_after_end: bool) -> void:
	if card_info.visible:
		card_info.visible = false
	elif input != null and input.placing != "":
		input.cancel_placing()
	elif input != null and input.rally_armed:
		input.arm_rally(false)
	elif input != null and input.selected != null and not get_tree().paused:
		input.select(null)
	elif GameState.is_playing():
		_show_pause(not get_tree().paused)
	elif leave_after_end and overlay.visible:
		GameState.back_to_menu()

## A short line over the field: what just happened, or why something could not.
func say(text: String, tint: Color = UiStyle.TEXT) -> void:
	message.text = text
	message.add_theme_color_override("font_color", tint)
	message.modulate.a = 1.0
	message.get_parent().visible = true
	message_left = MESSAGE_TIME

# --- reading the side ---------------------------------------------------------

func _refresh() -> void:
	_refresh_unit()
	_refresh_sky()
	objective.get_parent().visible = rules != null and not GameState.spectating
	if rules != null:
		objective.text = tr("Цель: %s") % rules.objective()
	if GameState.spectating:
		_refresh_watching()
		return
	var side := GameState.human()
	if side == null:
		return
	var e := side.economy
	chips["wood"].text = str(e.wood)
	chips["ore"].text = str(e.ore)
	chips["gold"].text = str(e.gold)
	chips["army"].text = str(side.squad.alive().size())
	chips["hands"].text = str(side.workers().size())
	var count := side.hands()
	for card in _cards_that("hire"):
		var kind: String = card.get_meta("kind")
		card.store = e
		card.locked = ""
		card.badge = ""
		card.progress = -1.0
		card.count = 0
		if kind == "repair":
			card.badge = tr("%d чел.") % int(count["repair"])
			card.disabled = side.workers().is_empty()
			card.refresh()
			continue
		if PlayerState.TRADES.has(kind):
			# a trade: how many are on it; a click moves one more onto it
			card.badge = tr("%d чел.") % int(count[kind])
			card.disabled = side.workers().size() - int(count[kind]) - int(count["smith"]) - int(count["repair"]) - int(count["build"]) <= 0
			card.refresh()
			continue
		if ProductionBuilding.SOLDIERS.has(kind):
			_refresh_soldier(card, side, kind)
			continue
		var where := side.producer_for(kind)
		if where == null:
			card.locked = tr("замок")
		if where != null:
			card.cost = where.price_for(kind)
			var waiting := where.queue.count(kind)
			if waiting > 0 and where.queue[0] == kind:
				card.progress = where.current_share()
			card.count = waiting
		card.disabled = where == null or not where.can_hire(kind)
		card.refresh()
	for card in _cards_that("build"):
		var kind: String = card.get_meta("kind")
		card.store = e
		card.badge = ""
		card.progress = -1.0
		card.locked = ""
		if kind == "barracks" and side.has_barracks_site():
			card.badge = tr("построена") if side.barracks().is_complete() else tr("строится")
			card.disabled = true
		elif kind == "library" and side.has_library_site():
			card.badge = tr("построена") if side.library() != null else tr("строится")
			card.disabled = true
		elif kind == "forge" and side.has_forge_site():
			card.badge = tr("построена") if side.forge() != null else tr("строится")
			card.disabled = true
		else:
			card.disabled = not e.can_afford(GameState.BUILDINGS[kind]["cost"])
		card.refresh()
	var smithy := side.forge()
	var hand := side.smith()
	for card in _cards_that("forge"):
		var item: String = card.get_meta("kind")
		if item == "smith":
			_refresh_smith(card, side, smithy, hand)
			continue
		if item == "arms":
			_refresh_store(card, side)
			continue
		card.store = e
		card.badge = ""
		card.locked = ""
		card.progress = -1.0
		card.count = 0
		if smithy == null:
			card.locked = tr("кузница")
		else:
			card.count = side.pending(item)
			if smithy.on_anvil.has(item):
				card.progress = smithy.current_share(item)
		var target := side.least_busy_forge()
		card.disabled = target == null or not target.can_forge(item)
		card.tooltip_text = card.get_meta("tip") + "\n" + tr("В запасе: %d. Без этого в строю: %d.") % [int(side.gear[item]), side.short_of(item)] \
			+ ("" if hand != null else "\n" + tr("Нет кузнеца: заказ ждёт, пока в кузницу не придёт рабочий."))
		card.refresh()
	for card in _cards_that("learn"):
		var id: String = card.get_meta("kind")
		card.store = e
		card.badge = ""
		card.locked = ""
		card.progress = -1.0
		if side.has_researched(id):
			card.badge = tr("изучено")
			card.disabled = true
		elif side.researching == id:
			card.progress = side.research_share()
			card.badge = "%d%%" % int(side.research_share() * 100.0)
			card.disabled = true
		else:
			if side.library() == null:
				card.locked = tr("библиотека")
			elif not side.prerequisite_met(id):
				card.locked = tr(PlayerState.RESEARCH[PlayerState.RESEARCH[id]["needs"]]["title"])
			card.disabled = not side.can_research(id)
		card.refresh()
	status.queue_redraw()

func _cards_that(does: String) -> Array:
	var found := []
	for i in TABS.size():
		if TABS[i]["does"] == does:
			found.append_array(cards[i])
	return found

## Both sides at a glance, blue then red, for a match nobody is playing.
func _refresh_watching() -> void:
	var lines := []
	for team in [Team.Id.PLAYER, Team.Id.ENEMY]:
		var side := GameState.side(team)
		if side == null:
			continue
		var e := side.economy
		var head: AIDirector = side.get_node_or_null("AIDirector")
		var style := (" (%s)" % tr(AIProfile.title(head.strategy))) if head != null else ""
		lines.append("[color=#%s]%s%s[/color]  " % [Team.color(team).lightened(0.2).to_html(false), tr(GameState.team_name(team)).capitalize(), style]
			+ tr("дерево %d · руда %d · золото %d · армия %d · рабочие %d") % [e.wood, e.ore, e.gold, side.squad.alive().size(), side.workers().size()])
	watch_label.text = "\n".join(lines)

# --- commands -----------------------------------------------------------------

func _hire(kind: String) -> void:
	var side := GameState.human()
	if ProductionBuilding.SOLDIERS.has(kind) and Input.is_key_pressed(KEY_SHIFT):
		_stock(kind)
	elif not GameState.hire(GameState.human_team, kind):
		var why := side.order_problem(kind) if side != null and ProductionBuilding.SOLDIERS.has(kind) else ""
		say(_why(kind, why) if why != "" else tr("Недостаточно ресурсов"), UiStyle.BAD)
	elif ProductionBuilding.SOLDIERS.has(kind) and not side.missing_for(kind).is_empty() and not _smith_coming(side):
		say(tr("Оружие ждёт кузнеца: нет свободных рабочих"), UiStyle.BAD)
	_refresh()

## Why ordering `kind` was refused (PlayerState.order_problem), in the language
## spoken; a study still to be made is named.
func _why(kind: String, problem: String) -> String:
	var side := GameState.human()
	if side != null and not side.kind_unlocked(kind):
		return tr("Нужно: %s") % tr(PlayerState.RESEARCH[ProductionBuilding.CATALOG[kind]["requires"]]["title"])
	return tr(problem)

## Shift+click on a soldier's card: his arms are made into the store, for later.
func _stock(kind: String) -> void:
	var made := []
	for item in ProductionBuilding.CATALOG[kind].get("arms", []):
		if Forge.GEAR.has(item) and GameState.forge(GameState.human_team, item):
			made.append(Lang.lower(tr(Forge.GEAR[item]["title"])))
	if made.is_empty():
		var side := GameState.human()
		say(tr("Нечего ковать") if ProductionBuilding.CATALOG[kind]["arms"] == ["club"]
			else (tr("Нет кузницы") if side.forge() == null else tr("Нельзя выковать: нет рецепта, ресурсов или места в очереди")), UiStyle.BAD)
	else:
		say(tr("Куётся в запас: %s") % ", ".join(made))

func _place(kind: String) -> void:
	if input != null:
		input.begin_placing(kind)

func _assign(job: String) -> void:
	if GameState.assign_worker(GameState.human_team, job):
		say({"wood": tr("Рабочий идёт на лес"), "ore": tr("Рабочий идёт на руду"), "gold": tr("Рабочий идёт на золото")}[job])
	_refresh()

func _forge(item: String) -> void:
	if not GameState.forge(GameState.human_team, item):
		say(tr("Недостаточно ресурсов"), UiStyle.BAD)
	elif not _smith_coming(GameState.human()):
		say(tr("Заказ ждёт кузнеца: нет свободных рабочих"), UiStyle.BAD)
	_refresh()

func _toggle_repair() -> void:
	var side := GameState.human()
	if Input.is_key_pressed(KEY_SHIFT):
		_release_repairer()
	elif GameState.assign_repairer(GameState.human_team):
		say(tr("Рабочий идёт чинить постройки") if side.anything_to_repair() else tr("Рабочий на ремонте: пока чинить нечего"), UiStyle.GOOD)
	elif side.repairers().size() >= PlayerState.REPAIRERS_MAX:
		say(tr("Ремонтников уже %d") % PlayerState.REPAIRERS_MAX, UiStyle.BAD)
	else:
		say(tr("Нет рабочих, чтобы поставить на ремонт"), UiStyle.BAD)
	_refresh()

func _release_repairer() -> void:
	if GameState.release_repairer(GameState.human_team):
		say(tr("Ремонтник вернулся к прежней работе"))
	else:
		say(tr("Никто не чинит"), UiStyle.BAD)
	_refresh()

## Whether anyone is, or can be, at an anvil: a smith, or a labourer to spare.
static func _smith_coming(side: PlayerState) -> bool:
	if side.smith() != null:
		return true
	var count := side.hands()
	return int(count["wood"]) + int(count["ore"]) + int(count["gold"]) > 1

func _refresh_smith(card: HudCard, side: PlayerState, smithy: Forge, hand: Worker) -> void:
	card.store = side.economy
	card.locked = ""
	card.progress = -1.0
	card.count = 0
	if smithy == null:
		card.locked = tr("кузница")
		card.badge = ""
		card.disabled = true
	elif hand == null:
		card.badge = tr("нет рабочих") if smithy.has_work() else tr("нет заказов")
		card.disabled = false
	else:
		var anvils := side.forges().size() * Forge.ANVILS.size()
		var working := 0
		for smith in side.smiths():
			if smith.at_anvil() and smith.my_forge().has_work(smith.anvil):
				working += 1
		card.badge = "%d/%d · %s" % [side.smiths().size(), anvils, tr("куёт") if working > 0 else tr("идёт")]
		card.disabled = false
	card.refresh()

## The store: how many pieces are in it, and what, in the tooltip.
func _refresh_store(card: HudCard, side: PlayerState) -> void:
	card.store = side.economy
	card.locked = ""
	card.progress = -1.0
	card.count = 0
	var lines := []
	var total := 0
	for item in Forge.GEAR:
		var have := int(side.gear[item])
		total += have
		if have > 0 or side.pending(item) > 0:
			lines.append("%s: %d%s" % [tr(Forge.GEAR[item]["title"]), have,
				(" " + tr("(куётся %d)") % side.pending(item)) if side.pending(item) > 0 else ""])
	card.badge = tr("%d шт.") % total
	card.disabled = true
	card.tooltip_text = "%s  [%s]\n%s\n%s" % [tr("Склад"), card.get_meta("key"), tr(ARMS_ABOUT),
		"\n".join(lines) if not lines.is_empty() else tr("Пусто.")]
	card.refresh()

## A soldier's card: what ordering one costs now (the man and whatever of his
## arms is not in store), what it is waiting for, and how far the orders are.
func _refresh_soldier(card: HudCard, side: PlayerState, kind: String) -> void:
	var entry: Dictionary = ProductionBuilding.CATALOG[kind]
	var why := side.order_problem(kind)
	if not side.kind_unlocked(kind):
		card.locked = tr(PlayerState.RESEARCH[entry["requires"]]["title"])
	elif side.barracks() == null:
		card.locked = tr("казарма")
	elif not side.barracks().is_complete():
		card.locked = tr("строится")
	elif why == "Нет кузницы":
		card.locked = tr("кузница")
	card.cost = side.draft_price(kind)
	# the furthest-on order of this kind says where things stand
	var training := side.barracks().queue.count(kind) if side.barracks() != null else 0
	card.count = side.drafts_of(kind) + training
	if training > 0 and side.barracks().queue[0] == kind:
		card.progress = side.barracks().current_share()
		card.badge = tr("обучается")
	else:
		for draft in side.drafts:
			if draft.kind != kind:
				continue
			if draft.stage == Draft.Stage.ARMING:
				var lacking := ""
				for item in draft.needs:
					if int(side.gear[item]) < draft.needs.count(item):
						lacking = Lang.lower(tr(Forge.GEAR[item]["title"]))
						break
				card.badge = (tr("ждёт: %s") % lacking) if lacking != "" else tr("за оружием")
			else:
				card.badge = tr(DRAFT_STAGE[draft.stage])
			break
	card.disabled = why != ""
	card.refresh()

func _learn(id: String) -> void:
	if GameState.research(GameState.human_team, id):
		say(tr("Изучается: %s") % tr(PlayerState.RESEARCH[id]["title"]), UiStyle.STUDY_FILL)
	_refresh()

func _select_tab(index: int) -> void:
	tab = index
	if card_info != null:
		card_info.visible = false
	for i in tab_buttons.size():
		tab_buttons[i].button_pressed = i == index
	for i in cards:
		for card in cards[i]:
			card.visible = i == index

# --- pause and the end of the match -------------------------------------------

func _show_pause(on: bool) -> void:
	GameState.set_paused(on)
	overlay.visible = on
	overlay_title.text = tr("Пауза")
	overlay_note.text = ""
	resume_button.visible = true

func _on_match_ended(winner: int) -> void:
	overlay.visible = true
	resume_button.visible = false
	next_button.visible = false
	call_deferred("_name_the_enemy")
	if input != null:
		input.cancel_placing()
	if GameState.spectating:
		overlay_title.text = tr("Победили %s") % tr(GameState.team_name(winner))
		overlay_note.text = tr("Крепость противника пала.")
	elif winner == GameState.human_team:
		overlay_title.text = tr("Победа")
		overlay_note.text = "" if rules != null and rules.after_waves == "win" else tr("Вражеская крепость пала.")
		if Campaign.current >= 0:
			var earned: int = Campaign.last_earned
			overlay_title.text = tr("Победа") + "  " + "★".repeat(earned) + "☆".repeat(3 - earned)
			overlay_note.text = tr("«%s» пройдена за %d:%02d.") % [tr(Campaign.ROOMS[Campaign.current]["title"]),
				int(GameState.match_time) / 60, int(GameState.match_time) % 60]
			next_button.visible = Campaign.next_room() >= 0
		if rules != null and rules.after_waves == "win":
			overlay_note.text = (overlay_note.text + "\n" + tr("Вы выстояли: все %d волн отбиты.") % rules.waves.size()).strip_edges()
	else:
		overlay_title.text = tr("Поражение")
		overlay_note.text = tr("Ваша крепость пала.")

## Once the verdict is on the screen: how the enemy was playing, now it can be told.
func _name_the_enemy() -> void:
	var foe := GameState.enemy_of(GameState.human_team)
	var head: AIDirector = foe.get_node_or_null("AIDirector") if foe != null else null
	if head != null and not GameState.spectating:
		overlay_note.text += "\n" + tr("Противник: %s, %s") % [tr(AIProfile.title(head.strategy)),
			Lang.lower(tr(AIProfile.DIFFICULTIES[head.difficulty]["title"]))]

# --- achievement toasts -------------------------------------------------------

func _run_toast(delta: float) -> void:
	if toast_left > 0.0:
		toast_left -= delta
		toast.modulate.a = clampf(toast_left / 0.4, 0.0, 1.0)
		if toast_left <= 0.0:
			toast.visible = false
		return
	if toast_queue.is_empty():
		return
	var id: String = toast_queue.pop_front()
	var entry: Array = get_node("/root/Achievements").LIST[id]
	toast_label.text = "★ " + tr("Достижение: %s") % tr(entry[0]) + "\n" + tr(entry[1])
	toast.visible = true
	toast.modulate.a = 1.0
	toast_left = TOAST_TIME

# --- building the panel -------------------------------------------------------

func _chip(row: HBoxContainer, kind: String, hint: String) -> void:
	var picture := Control.new()
	picture.custom_minimum_size = Vector2(22.0, 22.0)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.draw.connect(func() -> void: Icons.draw(picture, kind, Rect2(Vector2.ZERO, Vector2(22.0, 22.0))))
	row.add_child(picture)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 17)
	label.custom_minimum_size = Vector2(36.0, 0.0)
	label.tooltip_text = hint
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	chips[kind if kind != "worker" else "hands"] = label

func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 6.0)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	if GameState.spectating:
		watch_label = RichTextLabel.new()
		watch_label.bbcode_enabled = true
		watch_label.fit_content = true
		watch_label.custom_minimum_size = Vector2(560.0, 0.0)
		watch_label.add_theme_font_size_override("normal_font_size", 14)
		row.add_child(watch_label)
		_pause_button(row)
		return
	_pause_button(row)
	_chip(row, "wood", tr("Дерево"))
	_chip(row, "ore", tr("Руда"))
	_chip(row, "gold", tr("Золото"))
	var gap := VSeparator.new()
	row.add_child(gap)
	_chip(row, "army", tr("Армия"))
	_chip(row, "worker", tr("Рабочие"))
	row.add_child(VSeparator.new())
	sky_icon = Control.new()
	sky_icon.custom_minimum_size = Vector2(22.0, 22.0)
	sky_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_icon.draw.connect(func() -> void:
		if sky_kind != "":
			Icons.draw(sky_icon, sky_kind, Rect2(Vector2.ZERO, Vector2(22.0, 22.0))))
	row.add_child(sky_icon)
	sky_label = Label.new()
	sky_label.add_theme_font_size_override("font_size", 14)
	sky_label.mouse_filter = Control.MOUSE_FILTER_PASS
	sky_label.tooltip_text = tr(SKY_ABOUT)
	row.add_child(sky_label)

func _build_minimap() -> void:
	var panel := PanelContainer.new()
	var style := UiStyle.panel()
	style.set_content_margin_all(4.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -248.0 if compact else -318.0
	panel.offset_right = -8.0
	panel.offset_top = 6.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	minimap = Minimap.new()
	if compact:
		minimap.custom_minimum_size = Vector2(232.0, 48.0)
	panel.add_child(minimap)

func _build_bottom_bar() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_right = -8.0
	panel.offset_top = -bar_height - 6.0
	panel.offset_bottom = -6.0
	root.add_child(panel)
	bottom_bar = panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)

	# tabs over a row of cards
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	left.add_child(tabs)
	for i in TABS.size():
		var button := Button.new()
		button.text = tr(TABS[i]["title"])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(68.0, 36.0) if compact else Vector2(68.0, 24.0)
		button.add_theme_font_size_override("font_size", 12 if compact else 11)
		button.tooltip_text = tr("Tab — следующая вкладка")
		button.pressed.connect(_select_tab.bind(i))
		tabs.add_child(button)
		tab_buttons.append(button)
	cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 5)
	left.add_child(cards_row)
	for t in TABS.size():
		cards[t] = []
		var kinds: Array = TABS[t]["cards"]
		for i in kinds.size():
			var kind: String = kinds[i]
			var key := str(i + 1)
			var card: HudCard
			match TABS[t]["does"]:
				"hire" when kind == "repair":
					card = _card(kind, tr(NAMES[kind]), {}, key, tr(ABOUT[kind]) + " " + tr(RETURN_HINT))
					_when_pressed(card, _toggle_repair)
				"hire" when PlayerState.TRADES.has(kind):
					card = _card(kind, tr(NAMES[kind]), {}, key, tr(ABOUT[kind]))
					_when_pressed(card, _assign.bind(kind))
				"hire" when ProductionBuilding.SOLDIERS.has(kind):
					card = _card(kind, tr(NAMES[kind]), _full_price(kind), key, "%s\n%s" % [tr(ABOUT[kind]), _arms_line(kind)])
					_when_pressed(card, _hire.bind(kind))
				"hire":
					card = _card(kind, tr(NAMES[kind]), ProductionBuilding.CATALOG[kind]["cost"], key, tr(ABOUT[kind]))
					_when_pressed(card, _hire.bind(kind))
				"build":
					var entry: Dictionary = GameState.BUILDINGS[kind]
					card = _card(kind, tr(entry["title"]), entry["cost"], key, tr(entry["about"]))
					_when_pressed(card, _place.bind(kind))
				"forge" when kind == "smith":
					card = _card(kind, tr("Кузнец"), {}, key, tr(SMITH_ABOUT))
					_when_pressed(card, func() -> void: say(tr("Кузнецы приходят сами, когда в кузнице есть заказ")))
				"forge" when kind == "arms":
					card = _card(kind, tr("Склад"), {}, key, tr(ARMS_ABOUT))
				"forge":
					var entry: Dictionary = Forge.GEAR[kind]
					card = _card(kind, tr(entry["title"]), entry["cost"], key,
						"%s\n%s" % [tr(entry["about"]), tr("Кузнецу работы у наковальни: около %d с.") % int(entry["work"])])
					card.set_meta("tip", card.tooltip_text)
					_when_pressed(card, _forge.bind(kind))
				"learn":
					var entry: Dictionary = PlayerState.RESEARCH[kind]
					var after := ""
					if entry.has("needs"):
						after = "\n" + tr("Сначала: %s.") % tr(PlayerState.RESEARCH[entry["needs"]]["title"])
					card = _card(kind, tr(entry["title"]), entry["cost"], key,
						"%s%s\n%s" % [tr(entry["about"]), after, tr("Изучается %d с в библиотеке.") % int(entry["time"])])
					_when_pressed(card, _learn.bind(kind))
			cards[t].append(card)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	status = StatusView.new()
	status.hud = self
	if compact:
		# under the minimap instead, to leave the bar room to be drawn bigger
		var holder := PanelContainer.new()
		holder.anchor_left = 1.0
		holder.anchor_right = 1.0
		holder.offset_left = -190.0
		holder.offset_right = -8.0
		holder.offset_top = 72.0
		holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.visible = not GameState.spectating
		root.add_child(holder)
		holder.add_child(status)
	else:
		row.add_child(VSeparator.new())
		row.add_child(status)
	row.add_child(VSeparator.new())
	# the big attack button, then the gathering pair stacked beside it
	var pair := VBoxContainer.new()
	pair.add_theme_constant_override("separation", 4)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec in [["attack", "В атаку", "Вся армия — на вражескую крепость", func() -> void: GameState.attack_enemy_base(GameState.human_team)],
			["rally", "Сбор", "Вся армия — к точке сбора", func() -> void: GameState.rally_home(GameState.human_team)],
		["rally_point", "Флаг", "Перенести точку сбора: нажмите, потом укажите место на поле (или Shift+ПКМ)",
			func() -> void: input.arm_rally(not input.rally_armed)]]:
		var order := OrderButton.new()
		order.icon_kind = spec[0]
		order.caption = tr(spec[1])
		order.tooltip_text = tr(spec[2])
		order.pressed.connect(spec[3])
		if spec[0] == "attack":
			row.add_child(order)
			row.add_child(pair)
			continue
		order.make_compact()
		pair.add_child(order)
		if spec[0] == "rally_point":
			order.toggle_mode = true
			rally_button = order

## A soldier with nothing in store: the man, and all his arms.
static func _full_price(kind: String) -> Dictionary:
	var price := {"wood": int(ProductionBuilding.CATALOG["recruit"]["pay_any"])}
	for item in ProductionBuilding.CATALOG[kind].get("arms", []):
		if Forge.GEAR.has(item):
			for resource in Forge.GEAR[item]["cost"]:
				price[resource] = int(price.get(resource, 0)) + int(Forge.GEAR[item]["cost"][resource])
	return price

## What a soldier's card says about his arms.
static func _arms_line(kind: String) -> String:
	var arms: Array = ProductionBuilding.CATALOG[kind].get("arms", [])
	if arms == ["club"]:
		return TranslationServer.translate("Дубину выдают в замке. Нужна только казарма.")
	var names := []
	for item in arms:
		names.append(Lang.lower(TranslationServer.translate(Forge.GEAR[item]["title"])))
	return TranslationServer.translate("Новобранец забирает в кузнице: %s, и обучается в казарме.") % ", ".join(names) \
		+ " " + TranslationServer.translate(STOCK_HINT) + "\n" + TranslationServer.translate("Цена ниже, если оружие уже есть на складе.")

## `action` when the card is pressed, but not on the release of a hold, which
## showed what the card is about instead.
func _when_pressed(card: HudCard, action: Callable) -> void:
	card.pressed.connect(func() -> void:
		if not card.take_hold():
			card_info.visible = false
			action.call())

func _card(kind: String, title: String, cost: Dictionary, key: String, about: String) -> HudCard:
	var card := HudCard.new()
	card.held.connect(_show_card_info.bind(card))
	card.icon_kind = kind
	card.title = title
	card.cost = cost
	card.hotkey = key
	card.set_meta("kind", kind)
	card.set_meta("key", key)
	var price := []
	for resource in cost:
		price.append(tr({"wood": "дерево %d", "ore": "руда %d", "gold": "золото %d"}[resource]) % cost[resource])
	card.tooltip_text = "%s  [%s]\n%s%s" % [title, key, about, ("\n" + tr("Цена: %s") % ", ".join(price)) if not price.is_empty() else ""]
	cards_row.add_child(card)
	return card

# --- for fingers: what a card is about, and what is under way on the field ------

func _pause_button(row: HBoxContainer) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(30.0, 26.0)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tr("Пауза (Esc)")
	button.draw.connect(func() -> void:
		var mid := button.size * 0.5
		for dx in [-4.5, 1.5]:
			button.draw_rect(Rect2(mid + Vector2(dx, -7.0), Vector2(3.0, 14.0)), UiStyle.TEXT))
	button.pressed.connect(func() -> void:
		if GameState.is_playing():
			_show_pause(true))
	row.add_child(button)

func _build_card_info() -> void:
	card_info = PanelContainer.new()
	card_info.anchor_left = 0.5
	card_info.anchor_right = 0.5
	card_info.anchor_top = 1.0
	card_info.anchor_bottom = 1.0
	card_info.offset_bottom = -bar_height - 14.0
	card_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card_info.visible = false
	root.add_child(card_info)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card_info.add_child(column)
	card_info_title = Label.new()
	card_info_title.add_theme_font_size_override("font_size", 16)
	card_info_title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	column.add_child(card_info_title)
	card_info_text = Label.new()
	card_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_info_text.custom_minimum_size = Vector2(360.0, 0.0)
	card_info_text.add_theme_font_size_override("font_size", 13)
	column.add_child(card_info_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	card_info_alt = Button.new()
	card_info_alt.focus_mode = Control.FOCUS_NONE
	card_info_alt.custom_minimum_size = Vector2(0.0, 40.0)
	card_info_alt.pressed.connect(func() -> void:
		card_info.visible = false
		if card_info_do.is_valid():
			card_info_do.call())
	buttons.add_child(card_info_alt)
	var close := Button.new()
	close.text = tr("Закрыть")
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(96.0, 40.0)
	close.pressed.connect(func() -> void: card_info.visible = false)
	buttons.add_child(close)

## A held card: its whole tooltip, and the button for what Shift+click does.
func _show_card_info(card: HudCard) -> void:
	var kind: String = card.get_meta("kind")
	card_info_title.text = card.title
	var lines := card.tooltip_text.split("\n")
	card_info_text.text = "\n".join(lines.slice(1)).replace(" " + tr(STOCK_HINT), "").replace(" " + tr(RETURN_HINT), "")
	card_info_do = Callable()
	if kind == "repair":
		card_info_alt.text = tr("Вернуть одного")
		card_info_do = _release_repairer
	elif ProductionBuilding.SOLDIERS.has(kind) and ProductionBuilding.CATALOG[kind].get("arms", []) != ["club"]:
		card_info_alt.text = tr("Выковать оружие в запас")
		card_info_do = _stock.bind(kind)
	card_info_alt.visible = card_info_do.is_valid()
	card_info_alt.disabled = GameState.spectating or not GameState.is_playing()
	card_info.visible = true

func _build_mode_bar() -> void:
	mode_bar = PanelContainer.new()
	mode_bar.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.06, 0.05, 0.88), UiStyle.GOLD_EDGE, 1, 5, 6.0))
	mode_bar.anchor_top = 1.0
	mode_bar.anchor_bottom = 1.0
	mode_bar.offset_left = 8.0
	mode_bar.offset_bottom = -bar_height - 14.0
	mode_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mode_bar.visible = false
	root.add_child(mode_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	mode_bar.add_child(row)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 13)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.custom_minimum_size = Vector2(300.0, 0.0)
	mode_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mode_label)
	var cancel := Button.new()
	cancel.text = "✕ " + tr("Отмена")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(96.0, 40.0)
	cancel.pressed.connect(func() -> void:
		if input.placing != "":
			input.cancel_placing()
		else:
			input.arm_rally(false))
	row.add_child(cancel)

## Placing or moving the gathering point: say how, for a finger or the mouse.
func _refresh_mode() -> void:
	var finger := TouchInput.in_use
	if rally_button != null:
		rally_button.set_pressed_no_signal(input.rally_armed)
		rally_button.queue_redraw()
	if input.placing != "":
		mode_label.text = (tr("%s: коснитесь поля — контур встанет там, коснитесь контура (или перетащите его) — заложить") if finger
			else tr("%s: ЛКМ — поставить, Shift — ещё одну, ПКМ или Esc — отмена")) % tr(GameState.BUILDINGS[input.placing]["title"])
	elif input.rally_armed:
		mode_label.text = tr("Точка сбора: коснитесь поля, где собираться новобранцам") if finger \
			else tr("Точка сбора: щёлкните по полю, где собираться новобранцам")
	mode_bar.visible = input.placing != "" or input.rally_armed
	if mode_bar.visible:
		card_info.visible = false   # they share the space over the bottom bar

## A wave of a room is down: say so, with what it left us.
func _on_wave_beaten(index: int, reward: Dictionary) -> void:
	if GameState.spectating or not GameState.is_playing():
		return
	if reward.is_empty():
		say(tr("Волна %d отбита") % (index + 1), UiStyle.GOOD)
		return
	say(tr("Волна %d отбита! Трофеи: %s") % [index + 1, ", ".join(_goods(reward))], UiStyle.GOLD_BRIGHT)

## "+40 дерева, +30 руды": what a chest or a beaten wave gives.
func _goods(amounts: Dictionary) -> Array:
	var got := []
	for resource in amounts:
		got.append(tr({"wood": "+%d дерева", "ore": "+%d руды", "gold": "+%d золота"}[resource]) % int(amounts[resource]))
	return got

func _on_camp_cleared(team: int, bounty: Dictionary) -> void:
	if GameState.spectating:
		return
	if team == GameState.human_team:
		say(tr("Лагерь разбойников разгромлен! Добыча: %s") % ", ".join(_goods(bounty)), UiStyle.GOLD_BRIGHT)
	elif team != Team.Id.NEUTRAL:
		say(tr("Противник разгромил лагерь разбойников"), UiStyle.BAD)

func _on_sky_turned(phase: String) -> void:
	if phase == "dusk":
		say(tr("Смеркается: скоро ночь, бойцы будут видеть хуже"), UiStyle.GOLD_BRIGHT)
	elif phase == "dawn":
		say(tr("Рассвет"), UiStyle.GOLD_BRIGHT)

## The time of day and the rain, in the top bar.
func _refresh_sky() -> void:
	if sky_label == null:
		return
	var sky := Weather.current
	sky_icon.visible = sky != null
	sky_label.visible = sky != null
	if sky == null:
		return
	var kind := "rain" if sky.is_raining() else sky.phase
	var text: String = (tr("%s, дождь") if sky.is_raining() else "%s") % tr(SKY_NAMES[sky.phase])
	if kind != sky_kind:
		sky_kind = kind
		sky_icon.queue_redraw()
	sky_label.text = text

# --- the unit window ------------------------------------------------------------

func _build_unit_panel() -> void:
	unit_panel = PanelContainer.new()
	unit_panel.anchor_left = 1.0
	unit_panel.anchor_right = 1.0
	unit_panel.anchor_top = 1.0
	unit_panel.anchor_bottom = 1.0
	unit_panel.offset_left = -262.0
	unit_panel.offset_right = -8.0
	unit_panel.offset_bottom = -bar_height - 14.0
	unit_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	unit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	unit_panel.visible = false
	root.add_child(unit_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	unit_panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	unit_title = Label.new()
	unit_title.add_theme_font_size_override("font_size", 16)
	unit_title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	unit_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(unit_title)
	var close := Button.new()
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = tr("Закрыть (Esc)")
	close.pressed.connect(func() -> void:
		if input != null:
			input.select(null))
	head.add_child(close)
	unit_text = RichTextLabel.new()
	unit_text.bbcode_enabled = true
	unit_text.fit_content = true
	unit_text.scroll_active = false
	unit_text.custom_minimum_size = Vector2(238.0, 0.0)
	unit_text.add_theme_font_size_override("normal_font_size", 13)
	unit_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(unit_text)

## Fills the window from whoever is being looked at, or hides it.
func _refresh_unit() -> void:
	var body: PlayerBody = input.selected if input != null else null
	if body == null or not is_instance_valid(body):
		unit_panel.visible = false
		return
	unit_panel.visible = true
	var lines := []
	var side := "[color=#%s]%s[/color]" % [Team.color(body.team).lightened(0.25).to_html(false), tr(GameState.team_name(body.team))]
	if body is Unit:
		var unit := body as Unit
		unit_title.text = "%s  %s" % [tr(NAMES.get(unit.loadout, "Боец")), "★".repeat(unit.stars) + "☆".repeat(Unit.STARS_AT.size() - unit.stars)]
		lines.append(side + "  ·  " + (("[color=#e06050]%s[/color]" % tr("пал в бою")) if unit.is_dead else _doing(unit)))
		lines.append(tr("Здоровье: [b]%d[/b] / %d") % [ceili(unit.health), roundi(unit.health_max)])
		lines.append(tr("Выносливость: %d / %d") % [roundi(unit.stamina), roundi(PlayerBody.STAMINA_MAX)])
		lines.append(tr("Оружие: %s, навык %d / %d") % [tr(WEAPON_NAMES.get(unit.weapon, "?")), unit.skill_in(unit.weapon), PlayerBody.SKILL_MAX])
		lines.append(tr("Удар: [b]%.0f[/b] урона, %.0f выносливости") % [unit.strike_harm(), unit.strike_cost()])
		if unit.is_shooter():
			var wet := Weather.shot_scale(unit.weapon)
			lines.append(tr("Стреляет на %d") % roundi(unit.reach()) + ((" · " + tr("дождь: урон −%d%%") % roundi((1.0 - wet) * 100.0)) if wet < 1.0 else ""))
		if FogOfWar.current != null and unit.team == GameState.human_team:
			lines.append(tr("Обзор: %d") % roundi(FogOfWar.vision_of(unit)))
		if Weather.sight() < 0.99:
			lines.append(tr("Видит на %d из %d (%s)") % [roundi(unit._sight()), roundi(Unit.SIGHT),
				tr("ночь") if Weather.current.darkness() > 0.5 else (tr("дождь") if Weather.current.is_raining() else tr("сумерки"))])
		lines.append(tr("Защита: %s") % _guard_line(unit))
		var next := unit.kills_to_next_star()
		lines.append(tr("Убито: [b]%d[/b]") % unit.kills + (("  ·  " + tr("построек: %d") % unit.razed) if unit.razed > 0 else "")
			+ "  ·  " + ((tr("до звезды: %d") % next) if next > 0 else tr("ветеран")))
		if unit.stars > 0:
			lines.append("[color=#%s]%s[/color]" % [UiStyle.GOLD_BRIGHT.to_html(false), tr("За звёзды: +%d%% к удару, +%d%% к здоровью, навык +%d") % [
				roundi(Unit.STAR_HARM * 100.0 * unit.stars), roundi(Unit.STAR_HEALTH * 100.0 * unit.stars), unit.stars]])
	else:
		var hand := body as Worker
		unit_title.text = tr("Новобранец") if hand != null and hand.job == "recruit" else tr("Рабочий")
		var job: String = tr(JOB_NAMES.get(hand.job, hand.job)) if hand != null else ""
		if hand != null and hand.job == "recruit" and hand.draft != null:
			job = tr("идёт стать: %s") % Lang.lower(tr(NAMES.get(hand.draft.kind, hand.draft.kind)))
		if hand != null and hand.job == "build" and hand.site != null and is_instance_valid(hand.site):
			job = tr("строит: %s (%d%%)") % [Lang.lower(tr(GameState.BUILDINGS[Icons.site_of(hand.site)]["title"])), roundi(hand.site.built * 100.0)]
		if hand != null and hand.carried_item is Trophy:
			job = tr("несёт трофей: %s") % Lang.lower(tr(Forge.GEAR[(hand.carried_item as Trophy).item]["title"]))
		lines.append(side + "  ·  " + (("[color=#e06050]%s[/color]" % tr("погиб")) if body.is_dead else job))
		lines.append(tr("Здоровье: [b]%d[/b] / %d") % [ceili(body.health), roundi(body.health_max)])
		lines.append(tr("В руках: %s") % tr(WEAPON_NAMES.get(body.weapon, "?")))
	unit_text.text = "\n".join(lines)

func _doing(unit: Unit) -> String:
	if unit.watch == Unit.Watch.FIGHTING:
		return tr("в бою")
	if unit.order == Unit.Order.ATTACK_MOVE:
		return tr("идёт в атаку")
	return tr("держит позицию")

## Its kit, and what share of a blow gets through from in front and from behind.
func _guard_line(unit: Unit) -> String:
	var kit := []
	if unit.helm == PlayerBody.Helm.WORN:
		kit.append(tr("шлем"))
	if unit.wears_armour():
		kit.append(tr("латы"))
	if unit.has_shield():
		kit.append(tr("щит"))
	if kit.is_empty():
		return tr("нет")
	var front := unit.guard_against(unit.global_position + Vector2(unit.facing_x * 50.0, 0.0))
	var back := unit.guard_against(unit.global_position - Vector2(unit.facing_x * 50.0, 0.0))
	var line := tr("%s, −%d%% урона") % [", ".join(kit), roundi((1.0 - back) * 100.0)]
	if not is_equal_approx(front, back):
		line += " " + tr("(спереди −%d%%)") % roundi((1.0 - front) * 100.0)
	return line

func _build_objective() -> void:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.06, 0.05, 0.8), UiStyle.GOLD_DIM, 1, 5, 6.0))
	holder.position = Vector2(8.0, 50.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	root.add_child(holder)
	objective = Label.new()
	objective.add_theme_font_size_override("font_size", 13)
	objective.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	holder.add_child(objective)

func _build_message() -> void:
	var holder := PanelContainer.new()
	var style := UiStyle.box(Color(0.08, 0.06, 0.05, 0.82), UiStyle.GOLD_DIM, 1, 5, 6.0)
	holder.add_theme_stylebox_override("panel", style)
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.offset_top = 84.0
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	root.add_child(holder)
	message = Label.new()
	message.add_theme_font_size_override("font_size", 15)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(message)

func _build_toast() -> void:
	toast = PanelContainer.new()
	var style := UiStyle.panel()
	style.border_color = UiStyle.GOLD_BRIGHT
	toast.add_theme_stylebox_override("panel", style)
	toast.anchor_left = 1.0
	toast.anchor_right = 1.0
	toast.offset_left = -290.0
	toast.offset_right = -8.0
	toast.offset_top = 84.0
	toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	root.add_child(toast)
	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 14)
	toast_label.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	toast.add_child(toast_label)

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var style := UiStyle.panel()
	style.set_content_margin_all(26.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 36)
	overlay_title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(overlay_title)
	overlay_note = Label.new()
	overlay_note.add_theme_color_override("font_color", UiStyle.DIM)
	overlay_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(overlay_note)
	resume_button = _overlay_button(column, tr("Продолжить"), func() -> void: _show_pause(false))
	next_button = _overlay_button(column, tr("Следующая комната"), func() -> void: Campaign.start(Campaign.next_room()))
	next_button.visible = false
	_overlay_button(column, tr("Заново"), GameState.restart_match)
	_overlay_button(column, tr("В меню"), GameState.back_to_menu)

func _overlay_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
