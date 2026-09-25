extends Node2D
## M4 check: a hand-placed enemy keep, guarded by a tower, and a blue squad to
## knock it down. Blue starts with some stock, so hiring can be tried too.
##
##   A        send the blue squad at the red keep (attack-move)
##   click    send it to a point instead
##   1..4     hire a woodcutter / miner / gold miner / knight at the blue barracks

const HIRE_KEYS := {KEY_1: "woodcutter", KEY_2: "miner", KEY_3: "gold_miner", KEY_4: "knight"}

@onready var blue: PlayerState = $BlueSide
@onready var red: PlayerState = $RedSide
@onready var label: Label = $Hud/Info

var log_lines: Array[String] = []

func _ready() -> void:
	await get_tree().physics_frame
	blue.economy.add("wood", 12)
	blue.economy.add("ore", 6)
	blue.economy.changed.connect(func(_k: String, _a: int) -> void: _show())
	for side in [blue, red]:
		var keep: Base = side.base()
		keep.base_destroyed.connect(func(team: int) -> void: _note("%s keep destroyed" % _name(team)))
	blue.barracks().unit_ready.connect(func(u: PlayerBody) -> void: _note("hired %s" % u.name))
	_show()

func _name(team: int) -> String:
	return "blue" if team == Team.Id.PLAYER else "red"

func _note(line: String) -> void:
	log_lines.append(line)
	print(line)
	_show()

func _show() -> void:
	var e := blue.economy
	label.text = "blue: wood %d  ore %d  gold %d   squad %d\nA attack keep | click move | 1-4 hire\n%s" % [
		e.wood, e.ore, e.gold, blue.squad.alive().size(), "\n".join(log_lines.slice(-4))]

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.physical_keycode == KEY_A:
			blue.squad.attack_move(red.base().global_position)
		elif HIRE_KEYS.has(key.physical_keycode):
			var kind: String = HIRE_KEYS[key.physical_keycode]
			if not blue.barracks().queue_unit(kind):
				_note("can not hire %s" % kind)
		_show()
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		blue.squad.attack_move(get_global_mouse_position())
