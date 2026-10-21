class_name Tutorial
extends PanelContainer
## The lessons of the training room, one at a time, in a panel at the top left.
## Each waits for what it teaches to be done -- the camera moved, a soldier
## picked, a box drawn, a group kept, the army sent, a tower found and brought
## down, a wound healed -- then says so and moves on. «Дальше» skips a lesson,
## «Скрыть» puts the whole thing away. It only reads the match and the HUD's
## input; it never gives an order itself.

## Each lesson: what it says (Russian, translated where shown) and what ends it.
const STEPS := [
	{"done": "camera", "text": "Осмотритесь. Камеру двигают клавиши WASD или стрелки, колесо мыши приближает. На телефоне тяните поле пальцем, а двумя пальцами меняйте масштаб."},
	{"done": "pick", "text": "Щёлкните по своему бойцу: внизу справа откроется его окно — здоровье, оружие, защита. На телефоне коснитесь бойца."},
	{"done": "box", "text": "Выберите нескольких: зажмите левую кнопку и обведите бойцов рамкой. На телефоне включите «Рамку» над панелью. Кнопки «Все», «Пехота» и «Стрелки» выбирают сразу многих."},
	{"done": "group", "text": "Запомните выбранных как группу: Ctrl+1. Клавиша 1 снова выберет их, двойное нажатие покажет. На телефоне удержите кнопку «1»."},
	{"done": "advance", "text": "Ведите армию вперёд: правый клик по полю (на телефоне долгое касание). Отряд встанет строем: пехота впереди, лучники и маг позади."},
	{"done": "scout", "text": "Туман скрывает врага. Лазутчик видит дальше всех: выберите его двойным кликом и пошлите вперёд, пока не покажутся башни."},
	{"done": "tower", "text": "Башня бьёт на 150 шагов, а лучник на 220. Выберите стрелков и прикажите им бить башню издалека. Поджигатель жжёт постройки вчетверо быстрее, но в бою слаб."},
	{"done": "heal", "text": "Маг сам лечит раненых рядом с собой. Держите его позади строя, и потрёпанные бойцы снова встанут в строй."},
	{"done": "", "text": "На штурм! «В атаку» ведёт всю армию на замок. Разрушьте его — и победа за вами."},
]
const LOOK := 0.25             ## how often it checks whether the lesson is done

var hud: Node
var step := 0
var _look_left := 0.0
var _camera_from := Vector2.INF
var _zoom_from := 1.0
var _army_from := Vector2.INF
var _towers_at_start := -1
var _title: Label
var _text: Label

func _ready() -> void:
	position = Vector2(8.0, 84.0)
	custom_minimum_size = Vector2(380.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	column.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(364.0, 0.0)
	_text.add_theme_font_size_override("font_size", 14)
	column.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	for spec in [["Дальше", "Пропустить этот шаг", _next], ["Скрыть", "Убрать обучение до конца боя", func() -> void: visible = false]]:
		var button := Button.new()
		button.text = tr(spec[0])
		button.tooltip_text = tr(spec[1])
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(spec[2])
		row.add_child(button)
	_show()

## GameState, looked up rather than named: this class can be compiled before
## the autoloads are there (a test's script).
func _game() -> Node:
	return get_node("/root/GameState")

func _show() -> void:
	_title.text = tr("Обучение · шаг %d из %d") % [step + 1, STEPS.size()]
	_text.text = tr(STEPS[step]["text"])

## On to the next lesson (the last stays up until the match ends).
func _next() -> void:
	if step < STEPS.size() - 1:
		step += 1
		_show()

func _process(delta: float) -> void:
	if not visible or not _game().is_playing():
		return
	_look_left -= delta
	if _look_left > 0.0:
		return
	_look_left = LOOK
	# how many towers they had, counted at the start, whatever lesson is up
	if _towers_at_start < 0:
		_towers_at_start = _enemy_towers().size()
	if _done(STEPS[step]["done"]):
		if hud != null:
			hud.say(tr("Готово!"), UiStyle.GOOD)
		_next()

## Whether what lesson `what` teaches has been done.
func _done(what: String) -> bool:
	var input: Node = hud.input if hud != null else null
	var us: PlayerState = _game().human()
	var camera := get_viewport().get_camera_2d()
	match what:
		"camera":
			if camera == null:
				return false
			if _camera_from == Vector2.INF:
				_camera_from = camera.global_position
				_zoom_from = camera.zoom.x
				return false
			return camera.global_position.distance_to(_camera_from) > 150.0 or absf(camera.zoom.x - _zoom_from) > 0.05
		"pick":
			return input != null and input.chosen.size() == 1
		"box":
			return input != null and input.chosen.size() >= 3
		"group":
			return input != null and not input.groups.is_empty()
		"advance":
			var middle := _army_middle(us)
			if _army_from == Vector2.INF:
				_army_from = middle
				return false
			return middle.x - _army_from.x > 250.0
		"scout":
			for tower in _enemy_towers():
				if FogOfWar.knows(tower.global_position):
					return true
			return false
		"tower":
			return _enemy_towers().size() < _towers_at_start
		"heal":
			return not get_tree().get_nodes_in_group("mend_glows").is_empty()
	return false

func _army_middle(us: PlayerState) -> Vector2:
	if us == null or us.squad.alive().is_empty():
		return Vector2.ZERO
	var middle := Vector2.ZERO
	for unit in us.squad.alive():
		middle += unit.global_position
	return middle / float(us.squad.alive().size())

func _enemy_towers() -> Array[Tower]:
	var found: Array[Tower] = []
	for node in get_tree().get_nodes_in_group("buildings"):
		var tower := node as Tower
		if tower != null and tower.is_alive() and Team.hostile(_game().human_team, tower.team):
			found.append(tower)
	return found
