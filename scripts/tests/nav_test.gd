extends Node2D
## M2 check: two units of the same side swap places across a stand of trees.
## Straight lines would walk them into the trunks; they should go round.
## Click anywhere to send both to that point instead.

@export var left_path: NodePath
@export var right_path: NodePath

@onready var left: Unit = get_node(left_path)
@onready var right: Unit = get_node(right_path)

func _ready() -> void:
	# a beat for the floor to bake before anyone asks it the way
	await get_tree().physics_frame
	await get_tree().physics_frame
	left.set_rally(right.global_position)
	right.set_rally(left.global_position)

func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		left.set_rally(point)
		right.set_rally(point + Vector2(0.0, 40.0))
