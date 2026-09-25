extends CanvasLayer
## Test panel for triggering animations on demand.
##
## To add an action later, append one row: [button label, method on PlayerBody,
## shortcut key or KEY_NONE]. The buttons are built from this list, so nothing
## else needs touching.

const ACTIONS := [
	["Прыжок (Space)", "jump", KEY_NONE],
	["Пригнуться (C)", "toggle_crouch", KEY_C],
	["Не разворачиваться (V)", "toggle_facing_lock", KEY_V],
	["Уклонение-перекат (X)", "roll", KEY_X],
	["Доспехи (P)", "toggle_armour", KEY_P],
	["Шлем (O)", "toggle_helm", KEY_O],
	["Взять топор (1)", "equip_axe", KEY_1],
	["Взять копьё (2)", "equip_spear", KEY_2],
	["Взять лук (3)", "equip_bow", KEY_3],
	["Взять меч (4)", "equip_sword", KEY_4],
	["Меч и щит (5)", "equip_sword_shield", KEY_5],
	["Двуручный меч (6)", "equip_greatsword", KEY_6],
	["Кирка (7)", "equip_pickaxe", KEY_7],
	["Кинжал (8)", "equip_dagger", KEY_8],
	["Посох мага (9)", "equip_staff", KEY_9],
	["Факел (0)", "equip_torch", KEY_0],
	["Арбалет (Z)", "equip_crossbow", KEY_Z],
	["Удар оружием (F)", "attack", KEY_F],
	["Рубить дерево (G)", "chop_tree", KEY_G],
	["Поднять (E)", "pick_up", KEY_E],
	["Бросить (T)", "throw_rock", KEY_T],
	["Положить (U)", "put_down_rock", KEY_U],
	["Положить оружие (Y)", "put_down_weapon", KEY_Y],
	["Поднять чучела (B)", "reset_targets", KEY_B],
	["Навык +1 (N)", "train_current", KEY_N],
	["Получить удар (H)", "take_hit", KEY_H],
	["Смерть вперёд (K)", "die", KEY_K],
	["Смерть от выстрела (L)", "die_shot", KEY_L],
	["Смерть от удара (J)", "die_cut", KEY_J],
	["Оживить (R)", "revive", KEY_R],
]

# deliberately untyped: the same panel drives the 2D and 3D players, which share
# method names but no class
@export var player_path: NodePath
@onready var player: Node = get_node(player_path)

const PANEL_WIDTH := 168.0
const PANEL_MARGIN := 12.0

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(PANEL_MARGIN))
	margin.add_theme_constant_override("margin_top", int(PANEL_MARGIN))
	add_child(margin)

	# the list outgrew the viewport, so it scrolls rather than running off the
	# bottom; sized explicitly because nothing here is anchored to the screen
	var scroll := ScrollContainer.new()
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(
		PANEL_WIDTH,
		get_viewport().get_visible_rect().size.y - PANEL_MARGIN * 2.0
	)
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	scroll.add_child(column)

	for action in ACTIONS:
		var button := Button.new()
		button.text = action[0]
		button.custom_minimum_size = Vector2(PANEL_WIDTH - 14.0, 0.0)
		# without this the button keeps keyboard focus and swallows movement keys
		button.focus_mode = Control.FOCUS_NONE
		# actions this player does not implement stay visible but greyed out
		button.disabled = not player.has_method(action[1])
		button.pressed.connect(_run.bind(action[1]))
		column.add_child(button)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or not key.pressed:
		return
	for action in ACTIONS:
		if action[2] != KEY_NONE and key.physical_keycode == action[2]:
			_run(action[1])

func _run(method: String) -> void:
	if player.has_method(method):
		player.call(method)
