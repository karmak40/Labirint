extends Control
## The way in: start a skirmish, open the animation and combat testbed, or quit.

const BACKGROUND := Color(0.13, 0.14, 0.17)
const TEXT := Color(0.92, 0.92, 0.88)
const DIM := Color(0.66, 0.67, 0.70)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	var title := Label.new()
	title.text = "Labirint"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "база на базу"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(gap)

	var start := _button(column, "Схватка", func() -> void: GameState.start_match())
	_button(column, "ИИ против ИИ", func() -> void: GameState.start_match(GameState.DEFAULT_MAP, true))
	_button(column, "Достижения", _show_achievements)
	_button(column, "Тестовый стенд", GameState.open_testbed)
	_button(column, "Выход", func() -> void: get_tree().quit())
	start.grab_focus()

var list_panel: Control

## Everything there is to earn, the earned ones lit.
func _show_achievements() -> void:
	if list_panel != null:
		list_panel.visible = true
		return
	var achievements := get_node("/root/Achievements")
	list_panel = ColorRect.new()
	(list_panel as ColorRect).color = Color(0.0, 0.0, 0.0, 0.6)
	list_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(list_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	list_panel.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.12, 0.96)
	style.border_color = Color(0.30, 0.32, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var got := 0
	for id in achievements.LIST:
		var entry: Array = achievements.LIST[id]
		var earned: bool = achievements.is_unlocked(id)
		got += 1 if earned else 0
		var line := Label.new()
		line.text = "%s  %s — %s" % ["★" if earned else "☆", entry[0], entry[1]]
		line.add_theme_font_size_override("font_size", 15)
		line.add_theme_color_override("font_color", Color(0.98, 0.82, 0.30) if earned else DIM)
		column.add_child(line)
	var head := Label.new()
	head.text = "Достижения  %d / %d" % [got, achievements.LIST.size()]
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", TEXT)
	column.add_child(head)
	column.move_child(head, 0)
	var back := _button(column, "Назад", func() -> void: list_panel.visible = false)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240.0, 42.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
