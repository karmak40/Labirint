extends Control
## The way in: start a skirmish, watch two heads play, see the achievements,
## open the animation and combat testbed, or quit. Dressed like the match's
## HUD (UiStyle), in front of a drawn view: an evening sky, far hills, a castle.

const SKY_HIGH := Color(0.20, 0.27, 0.45)
const SKY_LOW := Color(0.86, 0.62, 0.42)
const HILLS_FAR := Color(0.36, 0.34, 0.42)
const HILLS_NEAR := Color(0.24, 0.30, 0.25)
const GROUND := Color(0.17, 0.22, 0.16)
const CASTLE := Color(0.12, 0.12, 0.15)
const WINDOW := Color(0.98, 0.78, 0.40)

var list_panel: Control

## The picture behind the menu, scaled to whatever the window is.
class Backdrop:
	extends Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var horizon := h * 0.68
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, horizon), Vector2(0.0, horizon)]),
			PackedColorArray([SKY_HIGH, SKY_HIGH, SKY_LOW, SKY_LOW]))
		# a low sun behind the hills
		draw_circle(Vector2(w * 0.72, horizon - 20.0), 46.0, Color(1.0, 0.86, 0.62, 0.9))
		for band in [[HILLS_FAR, 0.0, 70.0, 0.006], [HILLS_NEAR, 24.0, 44.0, 0.011]]:
			var line := PackedVector2Array([Vector2(0.0, h)])
			var x := 0.0
			while x <= w + 20.0:
				line.append(Vector2(x, horizon + band[1] - band[2] * (0.55 + 0.45 * sin(x * band[3] + band[1]))))
				x += 20.0
			line.append(Vector2(w, h))
			draw_colored_polygon(line, band[0])
		draw_rect(Rect2(0.0, horizon + 34.0, w, h), GROUND)
		# a castle on the far rise, lamps lit
		var base := Vector2(w * 0.20, horizon + 4.0)
		draw_rect(Rect2(base + Vector2(-70.0, -70.0), Vector2(140.0, 70.0)), CASTLE)
		for tower in [-70.0, 58.0]:
			draw_rect(Rect2(base + Vector2(tower, -110.0), Vector2(22.0, 110.0)), CASTLE)
			draw_colored_polygon(PackedVector2Array([base + Vector2(tower - 4.0, -110.0), base + Vector2(tower + 11.0, -140.0),
				base + Vector2(tower + 26.0, -110.0)]), CASTLE)
		draw_rect(Rect2(base + Vector2(-22.0, -130.0), Vector2(44.0, 130.0)), CASTLE)
		for i in 5:
			draw_rect(Rect2(base + Vector2(-22.0 + i * 10.0, -138.0), Vector2(6.0, 8.0)), CASTLE)
		for spot in [Vector2(-8.0, -100.0), Vector2(4.0, -100.0), Vector2(-50.0, -44.0), Vector2(40.0, -44.0), Vector2(-62.0, -90.0), Vector2(64.0, -90.0)]:
			draw_rect(Rect2(base + spot, Vector2(4.0, 7.0)), WINDOW)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	add_child(Backdrop.new())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := UiStyle.panel()
	style.set_content_margin_all(26.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Labirint"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "база на базу"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", UiStyle.DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 10.0)
	column.add_child(gap)

	var start := _button(column, "Кампания", _show_campaign)
	_button(column, "Схватка", _show_skirmish_setup)
	_button(column, "ИИ против ИИ", func() -> void:
		Campaign.leave()
		GameState.start_match(GameState.DEFAULT_MAP, true))
	_button(column, "Достижения", _show_achievements)
	_button(column, "Тестовый стенд", GameState.open_testbed)
	_button(column, "Выход", func() -> void: get_tree().quit())
	start.grab_focus()
	# back from a campaign room: straight to the list of rooms
	if Campaign.current >= 0:
		Campaign.leave()
		_show_campaign()

var campaign_panel: Control

## Before a skirmish: how hard the enemy is and how it plays.
func _show_skirmish_setup() -> void:
	var panel := _overlay()
	var column := _overlay_column(panel, "Схватка")
	_difficulty_row(column)
	var strategies := [["random", "Случайная", "Стратегия выбирается в начале боя и не раскрывается до конца."]]
	for id in AIProfile.STRATEGIES:
		strategies.append([id, AIProfile.STRATEGIES[id]["title"], AIProfile.STRATEGIES[id]["about"]])
	_choice_row(column, "Противник", strategies, GameState.ai_strategy,
		func(id: String) -> void: GameState.ai_strategy = id)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_button(buttons, "Начать", func() -> void:
		Campaign.leave()
		GameState.start_match())
	_button(buttons, "Назад", func() -> void: panel.queue_free())

func _difficulty_row(column: Control) -> void:
	var levels := []
	for id in AIProfile.DIFFICULTIES:
		levels.append([id, AIProfile.DIFFICULTIES[id]["title"], AIProfile.DIFFICULTIES[id]["about"]])
	_choice_row(column, "Сложность", levels, GameState.ai_difficulty,
		func(id: String) -> void: GameState.ai_difficulty = id)

## A labelled row of buttons of which one is picked; `pick` is told the id.
func _choice_row(column: Control, heading: String, options: Array, current: String, pick: Callable) -> void:
	var label := Label.new()
	label.text = heading
	label.add_theme_color_override("font_color", UiStyle.DIM)
	label.add_theme_font_size_override("font_size", 14)
	column.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var group := ButtonGroup.new()
	for option in options:
		var button := Button.new()
		button.text = option[1]
		button.tooltip_text = option[2]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(100.0, 34.0)
		button.add_theme_font_size_override("font_size", 14)
		button.button_pressed = option[0] == current
		button.pressed.connect(pick.bind(option[0]))
		row.add_child(button)
	var about := Label.new()
	about.add_theme_color_override("font_color", UiStyle.DIM)
	about.add_theme_font_size_override("font_size", 12)
	about.custom_minimum_size = Vector2(540.0, 0.0)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for option in options:
		if option[0] == current:
			about.text = option[2]
	for i in row.get_child_count():
		var button := row.get_child(i) as Button
		button.pressed.connect(func() -> void: about.text = options[i][2])
	column.add_child(about)

## The three rooms: open ones with their stars, locked ones greyed; pressing one
## shows its briefing.
func _show_campaign() -> void:
	if campaign_panel != null:
		campaign_panel.queue_free()
	campaign_panel = _overlay()
	var column := _overlay_column(campaign_panel, "Кампания")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	for i in Campaign.ROOMS.size():
		var room: Dictionary = Campaign.ROOMS[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(190.0, 120.0)
		card.focus_mode = Control.FOCUS_NONE
		var open: bool = Campaign.is_open(i)
		var earned: int = Campaign.stars_of(i)
		card.text = "Комната %d\n%s\n%s" % [i + 1, room["title"], ("★".repeat(earned) + "☆".repeat(3 - earned)) if open else "закрыта"]
		card.add_theme_font_size_override("font_size", 16)
		card.disabled = not open
		card.tooltip_text = room["goal"] if open else "Сначала пройдите комнату %d" % i
		card.pressed.connect(_show_briefing.bind(i))
		row.add_child(card)
	var back := _button(column, "Назад", func() -> void: campaign_panel.visible = false)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

## What a room is about, what it asks, and what earns its stars; then into it.
func _show_briefing(index: int) -> void:
	var room: Dictionary = Campaign.ROOMS[index]
	var panel := _overlay()
	var column := _overlay_column(panel, "Комната %d · %s" % [index + 1, room["title"]])
	for line in [[room["brief"], UiStyle.TEXT, 15], ["Цель: " + room["goal"], UiStyle.GOLD_BRIGHT, 15],
			["★ победа   ★ быстрее %d мин   ★ крепость цела хотя бы на %d%%" % [int(room["fast"] / 60.0), int(room["castle"] * 100.0)], UiStyle.DIM, 13]]:
		var label := Label.new()
		label.text = line[0]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(520.0, 0.0)
		label.add_theme_color_override("font_color", line[1])
		label.add_theme_font_size_override("font_size", line[2])
		column.add_child(label)
	var enemy := Label.new()
	enemy.text = "Противник играет: %s" % AIProfile.title(room.get("ai", "balanced"))
	enemy.add_theme_color_override("font_color", UiStyle.DIM)
	enemy.add_theme_font_size_override("font_size", 13)
	column.add_child(enemy)
	_difficulty_row(column)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_button(buttons, "В бой", func() -> void: Campaign.start(index))
	_button(buttons, "Назад", func() -> void: panel.queue_free())

func _overlay() -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	return shade

func _overlay_column(shade: Control, heading: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	var style := UiStyle.panel()
	style.set_content_margin_all(20.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var head := Label.new()
	head.text = heading
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	column.add_child(head)
	return column

## Everything there is to earn, the earned ones lit.
func _show_achievements() -> void:
	if list_panel != null:
		list_panel.queue_free()
	var achievements := get_node("/root/Achievements")
	list_panel = ColorRect.new()
	(list_panel as ColorRect).color = Color(0.0, 0.0, 0.0, 0.55)
	list_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(list_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	list_panel.add_child(center)
	var panel := PanelContainer.new()
	var style := UiStyle.panel()
	style.set_content_margin_all(20.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var got := 0
	for id in achievements.LIST:
		got += 1 if achievements.is_unlocked(id) else 0
	var head := Label.new()
	head.text = "Достижения   %d / %d" % [got, achievements.LIST.size()]
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	column.add_child(head)
	for id in achievements.LIST:
		var entry: Array = achievements.LIST[id]
		var earned: bool = achievements.is_unlocked(id)
		var line := Label.new()
		line.text = "%s  %s — %s" % ["★" if earned else "☆", entry[0], entry[1]]
		line.add_theme_font_size_override("font_size", 15)
		line.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT if earned else UiStyle.DIM)
		column.add_child(line)
	var back := _button(column, "Назад", func() -> void: list_panel.visible = false)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250.0, 40.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
