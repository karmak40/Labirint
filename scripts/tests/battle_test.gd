extends Node2D
## M3 check: two sides of three meet in the middle. Each side should only ever
## hit the other; the survivors hold the far side. Click to send the blue side
## to a point (attack-move).

@onready var blue: PlayerState = $BlueSide
@onready var red: PlayerState = $RedSide

func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	blue.squad.attack_move(Vector2(760, 280))
	red.squad.attack_move(Vector2(140, 280))

func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		blue.squad.attack_move(get_global_mouse_position())
