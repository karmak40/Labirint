extends CanvasLayer
## The human side's panel.
##
##   top left    what is in the store, how big the army is, how many hands
##   top right   the whole field in miniature (Minimap)
##   bottom      three tabs of cards -- hire, build, learn -- what is under way,
##               and the two orders for the army
##
## It reads the side through GameState and does everything through GameState's
## commands, so there is nothing here the enemy's head could not do as well.
## Placing a building is handed to the input adapter, which owns the mouse on
## the field.

const WORKERS := ["woodcutter", "miner", "gold_miner"]
const TROOPS := ["warrior", "spearman", "archer", "crossbowman", "knight"]
const BUILD := ["tower", "library"]
const LEARN := ["spears", "archery", "crossbows", "chivalry", "forging", "mail"]
const TABS := [["Рабочие", "worker"], ["Войска", "army"], ["Постройки", "build"], ["Знания", "book"]]
const NAMES := {
	"woodcutter": "Лесоруб", "miner": "Рудокоп", "gold_miner": "Старатель",
	"warrior": "Воин", "spearman": "Копейщик", "archer": "Лучник",
	"crossbowman": "Арбалетчик", "knight": "Рыцарь",
}
const ABOUT := {
	"woodcutter": "Рубит деревья и носит брёвна на склад.",
	"miner": "Добывает руду в жилах и носит на склад.",
	"gold_miner": "Добывает золото: оно нужно для знаний.",
	"warrior": "Дешёвый боец с дубиной. Доступен сразу.",
	"spearman": "Копьё бьёт сильнее дубины, шлем бережёт голову.",
	"archer": "Стреляет издалека и отходит от тех, кто подбирается близко. Хрупкий.",
	"crossbowman": "Бьёт дальше и сильнее лучника, но между выстрелами взводит арбалет.",
	"knight": "Латы, меч и щит: крепче и сильнее всех.",
}
const REFRESH := 0.1
const MESSAGE_TIME := 2.6
const TOAST_TIME := 3.5

var root: Control
var chips := {}                ## "wood" / "ore" / "gold" / "army" / "hands" -> Label
var watch_label: RichTextLabel
var minimap: Minimap
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
		# the barracks' queue: the one being trained with its bar, then the rest
		var barracks := side.barracks()
		draw_string(font, Vector2(0.0, y), "Казарма", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		if barracks == null:
			draw_string(font, Vector2(56.0, y), "разрушена", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.BAD)
		elif barracks.queue.is_empty():
			draw_string(font, Vector2(56.0, y), "свободна", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		else:
			for i in barracks.queue.size():
				Icons.draw(self, barracks.queue[i], Rect2(Vector2(56.0 + i * 22.0, y - 11.0), Vector2(18.0, 18.0)))
			UiStyle.bar(self, Rect2(Vector2(56.0, y + 8.0), Vector2(18.0, 3.0)), barracks.current_share())
		y += 26.0
		# the study, if there is a library to do it in
		draw_string(font, Vector2(0.0, y), "Знания", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		if side.researching != "":
			draw_string(font, Vector2(56.0, y), PlayerState.RESEARCH[side.researching]["title"], HORIZONTAL_ALIGNMENT_LEFT, 106.0, 11, UiStyle.TEXT)
			UiStyle.bar(self, Rect2(Vector2(56.0, y + 5.0), Vector2(104.0, 3.0)), side.research_share(), UiStyle.STUDY_FILL)
		elif side.library() == null:
			draw_string(font, Vector2(56.0, y), "нужна библиотека" if not side.has_library_site() else "библиотека строится",
				HORIZONTAL_ALIGNMENT_LEFT, 106.0, 11, UiStyle.DIM)
		else:
			draw_string(font, Vector2(56.0, y), "ничего не изучается", HORIZONTAL_ALIGNMENT_LEFT, 106.0, 11, UiStyle.DIM)
		y += 26.0
		# sites still going up
		draw_string(font, Vector2(0.0, y), "Стройка", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)
		var x := 56.0
		var any := false
		for building in side.buildings:
			if is_instance_valid(building) and building.is_alive() and not building.is_complete():
				Icons.draw(self, "tower" if building is Tower else "library", Rect2(Vector2(x, y - 11.0), Vector2(18.0, 18.0)))
				UiStyle.bar(self, Rect2(Vector2(x, y + 8.0), Vector2(18.0, 3.0)), building.built)
				x += 22.0
				any = true
		if not any:
			draw_string(font, Vector2(56.0, y), "нет", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.DIM)

## A big square order button: a picture and a word under it.
class OrderButton:
	extends Button
	var icon_kind := ""
	var caption := ""
	func _init() -> void:
		custom_minimum_size = Vector2(60.0, 72.0)
		focus_mode = Control.FOCUS_NONE
	func _draw() -> void:
		Icons.draw(self, icon_kind, Rect2(Vector2((size.x - 34.0) * 0.5, 8.0), Vector2(34.0, 34.0)))
		var font := get_theme_default_font()
		var wide := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - wide) * 0.5, 62.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.TEXT)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	bottom_bar.visible = not GameState.spectating
	GameState.match_ended.connect(_on_match_ended)
	GameState.match_started.connect(_on_match_started)
	GameState.built.connect(_on_built)
	var achievements := get_node_or_null("/root/Achievements")
	if achievements != null:
		achievements.unlocked.connect(func(id: String) -> void: toast_queue.append(id))
	if input != null and input.has_signal("refused"):
		input.refused.connect(say)
	_select_tab(0)

func _on_match_started() -> void:
	minimap.field = GameState.field()
	rules = GameState.field().get_node_or_null("RoomRules") as RoomRules
	if rules != null:
		rules.gates_opened.connect(func() -> void: say("Ворота вражеской крепости открыты — на штурм!", UiStyle.GOLD_BRIGHT))
		rules.wave_sent.connect(func(i: int, n: int) -> void: say("Волна %d: %d врагов идут на крепость!" % [i + 1, n], UiStyle.BAD))
	var side := GameState.human()
	if side == null or GameState.spectating:
		return
	side.research_done.connect(func(id: String) -> void: say("Изучено: %s" % PlayerState.RESEARCH[id]["title"], UiStyle.GOOD))
	side.research_lost.connect(func(id: String) -> void: say("Библиотека пала — «%s» потеряно" % PlayerState.RESEARCH[id]["title"], UiStyle.BAD))
	for building in side.buildings:
		_watch_building(building)

func _on_built(team: int, kind: String, building: Building) -> void:
	if team != GameState.human_team:
		return
	say("Заложено: %s" % GameState.BUILDINGS[kind]["title"])
	_watch_building(building)

func _watch_building(building: Building) -> void:
	if not building.completed.is_connected(_on_completed):
		building.completed.connect(_on_completed)

func _on_completed(building: Building) -> void:
	say("Построено: %s" % ("Башня" if building is Tower else "Библиотека"), UiStyle.GOOD)

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
		if input != null and input.placing != "":
			input.cancel_placing()
		elif GameState.is_playing():
			_show_pause(not get_tree().paused)
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

## A short line over the field: what just happened, or why something could not.
func say(text: String, tint: Color = UiStyle.TEXT) -> void:
	message.text = text
	message.add_theme_color_override("font_color", tint)
	message.modulate.a = 1.0
	message.get_parent().visible = true
	message_left = MESSAGE_TIME

# --- reading the side ---------------------------------------------------------

func _refresh() -> void:
	objective.get_parent().visible = rules != null and not GameState.spectating
	if rules != null:
		objective.text = "Цель: " + rules.objective()
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
	var barracks := side.barracks()
	for card in cards[0] + cards[1]:
		var kind: String = card.get_meta("kind")
		var entry: Dictionary = ProductionBuilding.CATALOG[kind]
		card.store = e
		card.locked = ""
		card.badge = ""
		card.progress = -1.0
		if barracks != null and not barracks.is_unlocked(kind):
			card.locked = PlayerState.RESEARCH[entry["requires"]]["title"]
		if barracks != null:
			var waiting := barracks.queue.count(kind)
			if waiting > 0 and barracks.queue[0] == kind:
				card.progress = barracks.current_share()
			card.count = waiting
		card.disabled = barracks == null or not barracks.can_hire(kind)
		card.refresh()
	for card in cards[2]:
		var kind: String = card.get_meta("kind")
		card.store = e
		card.badge = ""
		card.progress = -1.0
		card.locked = ""
		if kind == "library" and side.has_library_site():
			card.badge = "построена" if side.library() != null else "строится"
			card.disabled = true
		else:
			card.disabled = not e.can_afford(GameState.BUILDINGS[kind]["cost"])
		card.refresh()
	for card in cards[3]:
		var id: String = card.get_meta("kind")
		card.store = e
		card.badge = ""
		card.locked = ""
		card.progress = -1.0
		if side.has_researched(id):
			card.badge = "изучено"
			card.disabled = true
		elif side.researching == id:
			card.progress = side.research_share()
			card.badge = "%d%%" % int(side.research_share() * 100.0)
			card.disabled = true
		else:
			if side.library() == null:
				card.locked = "библиотека"
			elif not side.prerequisite_met(id):
				card.locked = PlayerState.RESEARCH[PlayerState.RESEARCH[id]["needs"]]["title"]
			card.disabled = not side.can_research(id)
		card.refresh()
	status.queue_redraw()

## Both sides at a glance, blue then red, for a match nobody is playing.
func _refresh_watching() -> void:
	var lines := []
	for team in [Team.Id.PLAYER, Team.Id.ENEMY]:
		var side := GameState.side(team)
		if side == null:
			continue
		var e := side.economy
		var head: AIDirector = side.get_node_or_null("AIDirector")
		var style := (" (%s)" % AIProfile.title(head.strategy)) if head != null else ""
		lines.append("[color=#%s]%s%s[/color]  дерево %d · руда %d · золото %d · армия %d · рабочие %d" % [
			Team.color(team).lightened(0.2).to_html(false), GameState.team_name(team).capitalize(), style,
			e.wood, e.ore, e.gold, side.squad.alive().size(), side.workers().size()])
	watch_label.text = "\n".join(lines)

# --- commands -----------------------------------------------------------------

func _hire(kind: String) -> void:
	if not GameState.hire(GameState.human_team, kind):
		say("Недостаточно ресурсов", UiStyle.BAD)
	_refresh()

func _place(kind: String) -> void:
	if input != null:
		input.begin_placing(kind)
		say("%s: ЛКМ — поставить, Shift — ещё одну, ПКМ или Esc — отмена" % GameState.BUILDINGS[kind]["title"])

func _learn(id: String) -> void:
	if GameState.research(GameState.human_team, id):
		say("Изучается: %s" % PlayerState.RESEARCH[id]["title"], UiStyle.STUDY_FILL)
	_refresh()

func _select_tab(index: int) -> void:
	tab = index
	for i in tab_buttons.size():
		tab_buttons[i].button_pressed = i == index
	for i in cards:
		for card in cards[i]:
			card.visible = i == index

# --- pause and the end of the match -------------------------------------------

func _show_pause(on: bool) -> void:
	GameState.set_paused(on)
	overlay.visible = on
	overlay_title.text = "Пауза"
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
		overlay_title.text = "Победили %s" % GameState.team_name(winner)
		overlay_note.text = "Крепость противника пала."
	elif winner == GameState.human_team:
		overlay_title.text = "Победа"
		overlay_note.text = "Вражеская крепость пала."
		if Campaign.current >= 0:
			var earned: int = Campaign.last_earned
			overlay_title.text = "Победа  " + "★".repeat(earned) + "☆".repeat(3 - earned)
			overlay_note.text = "%s пройдена за %d:%02d." % [Campaign.ROOMS[Campaign.current]["title"],
				int(GameState.match_time) / 60, int(GameState.match_time) % 60]
			next_button.visible = Campaign.next_room() >= 0
	else:
		overlay_title.text = "Поражение"
		overlay_note.text = "Ваша крепость пала."

## Once the verdict is on the screen: how the enemy was playing, now it can be told.
func _name_the_enemy() -> void:
	var foe := GameState.enemy_of(GameState.human_team)
	var head: AIDirector = foe.get_node_or_null("AIDirector") if foe != null else null
	if head != null and not GameState.spectating:
		overlay_note.text += "\nПротивник: %s, %s" % [AIProfile.title(head.strategy),
			AIProfile.DIFFICULTIES[head.difficulty]["title"].to_lower()]

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
	toast_label.text = "★ Достижение: %s\n%s" % [entry[0], entry[1]]
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
		return
	_chip(row, "wood", "Дерево")
	_chip(row, "ore", "Руда")
	_chip(row, "gold", "Золото")
	var gap := VSeparator.new()
	row.add_child(gap)
	_chip(row, "army", "Армия")
	_chip(row, "worker", "Рабочие")

func _build_minimap() -> void:
	var panel := PanelContainer.new()
	var style := UiStyle.panel()
	style.set_content_margin_all(4.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -318.0
	panel.offset_right = -8.0
	panel.offset_top = 6.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	minimap = Minimap.new()
	panel.add_child(minimap)

func _build_bottom_bar() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_right = -8.0
	panel.offset_top = -112.0
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
		button.text = TABS[i][0]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(86.0, 24.0)
		button.add_theme_font_size_override("font_size", 12)
		button.tooltip_text = "Tab — следующая вкладка"
		button.pressed.connect(_select_tab.bind(i))
		tabs.add_child(button)
		tab_buttons.append(button)
	cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 5)
	left.add_child(cards_row)
	for group in [[0, WORKERS], [1, TROOPS]]:
		cards[group[0]] = []
		for i in group[1].size():
			var kind: String = group[1][i]
			var card := _card(kind, NAMES[kind], ProductionBuilding.CATALOG[kind]["cost"], str(i + 1), ABOUT[kind])
			card.pressed.connect(_hire.bind(kind))
			cards[group[0]].append(card)
	cards[2] = []
	for i in BUILD.size():
		var kind: String = BUILD[i]
		var entry: Dictionary = GameState.BUILDINGS[kind]
		var card := _card(kind, entry["title"], entry["cost"], str(i + 1), entry["about"])
		card.pressed.connect(_place.bind(kind))
		cards[2].append(card)
	cards[3] = []
	for i in LEARN.size():
		var id: String = LEARN[i]
		var entry: Dictionary = PlayerState.RESEARCH[id]
		var after := ""
		if entry.has("needs"):
			after = "\nСначала: %s." % PlayerState.RESEARCH[entry["needs"]]["title"]
		var card := _card(id, entry["title"], entry["cost"], str(i + 1),
			"%s%s\nИзучается %d с в библиотеке." % [entry["about"], after, int(entry["time"])])
		card.pressed.connect(_learn.bind(id))
		cards[3].append(card)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(VSeparator.new())
	status = StatusView.new()
	status.hud = self
	row.add_child(status)
	row.add_child(VSeparator.new())
	for spec in [["attack", "В атаку", "Вся армия — на вражескую крепость", func() -> void: GameState.attack_enemy_base(GameState.human_team)],
			["rally", "Сбор", "Вся армия — к точке сбора (Shift+ПКМ — перенести её)", func() -> void: GameState.rally_home(GameState.human_team)]]:
		var order := OrderButton.new()
		order.icon_kind = spec[0]
		order.caption = spec[1]
		order.tooltip_text = spec[2]
		order.pressed.connect(spec[3])
		row.add_child(order)

func _card(kind: String, title: String, cost: Dictionary, key: String, about: String) -> HudCard:
	var card := HudCard.new()
	card.icon_kind = kind
	card.title = title
	card.cost = cost
	card.hotkey = key
	card.set_meta("kind", kind)
	card.set_meta("key", key)
	var price := []
	for resource in cost:
		price.append("%s %d" % [{"wood": "дерево", "ore": "руда", "gold": "золото"}[resource], cost[resource]])
	card.tooltip_text = "%s  [%s]\n%s\nЦена: %s" % [title, key, about, ", ".join(price)]
	cards_row.add_child(card)
	return card

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
	resume_button = _overlay_button(column, "Продолжить", func() -> void: _show_pause(false))
	next_button = _overlay_button(column, "Следующая комната", func() -> void: Campaign.start(Campaign.next_room()))
	next_button.visible = false
	_overlay_button(column, "Заново", GameState.restart_match)
	_overlay_button(column, "В меню", GameState.back_to_menu)

func _overlay_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
