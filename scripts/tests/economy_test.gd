extends Node2D
## M3 check: workers fell, mine, carry and bank. The label is the side's store,
## which should only ever move when something is set down on the stockpile.

@export var side_path: NodePath

@onready var side: PlayerState = get_node(side_path)
@onready var label: Label = $Hud/Store

func _ready() -> void:
	side.economy.changed.connect(func(_k: String, _a: int) -> void: _show())
	_show()

func _show() -> void:
	var e := side.economy
	label.text = "wood %d   ore %d   gold %d" % [e.wood, e.ore, e.gold]
