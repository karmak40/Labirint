extends "res://tests/lib/test_case.gd"
## Squads. A box drawn with the left button picks our soldiers inside it; a
## right click sends only them, and they arrive in formation, the ones who
## close in front and the shooters behind, facing the way they went. Ctrl+1
## keeps them as group 1 and 1 picks them again; a double click picks every
## one of that kind on the screen; «Держать» holds them on a short leash.

var stage := 0
var hud: Node
var knights: Array[Unit] = []
var archers: Array[Unit] = []
var others: Array[Unit] = []
const GOAL := Vector2(1500, 300)

func begin() -> void:
	time_limit = 60 * 60
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(loadout: String, at: Vector2) -> Unit:
	var unit: Unit
	if loadout == "knight":
		unit = load("res://scenes/knight/Knight.tscn").instantiate()
		unit.team = Team.Id.PLAYER
	else:
		unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
		unit.loadout = loadout
		unit.team = Team.Id.PLAYER
	unit.position = at
	current_scene.add_child(unit)
	game().human().squad.add(unit)
	unit.set_rally(at)
	return unit

func _screen(world: Vector2) -> Vector2:
	return root.get_canvas_transform() * world

func _mouse(at: Vector2, button: MouseButton, pressed: bool, shift := false, double := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.double_click = double
	event.position = at
	event.global_position = at
	root.push_input(event, true)

func _drag_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func _key(code: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.ctrl_pressed = ctrl
	event.pressed = true
	root.push_input(event, true)

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			hud = current_scene.get_node("Hud")
			var home: Vector2 = gs.human().base().global_position + Vector2(420, -60)
			for i in 3:
				knights.append(_soldier("knight", home + Vector2(i * 30, 0)))
				archers.append(_soldier("archer", home + Vector2(i * 30, 40)))
			# two more, well away: they are not in the box
			others.append(_soldier("spearman", home + Vector2(0, 170)))
			others.append(_soldier("spearman", home + Vector2(40, 170)))
			var camera := root.get_camera_2d()
			camera.global_position = home + Vector2(30, 60)
			stage = 1
			frame = 0
		1:
			if frame == 5:
				var home: Vector2 = gs.human().base().global_position + Vector2(420, -60)
				_mouse(_screen(home + Vector2(-40, -80)), MOUSE_BUTTON_LEFT, true)
				_drag_to(_screen(home + Vector2(120, 70)))
				_mouse(_screen(home + Vector2(120, 70)), MOUSE_BUTTON_LEFT, false)
			if frame == 8:
				check(hud.input.chosen.size() == 6, "a box picks the six inside it", hud.input.chosen.size())
				check(not hud.input.chosen.has(others[0]), "and not the ones outside")
				check(hud.unit_panel.visible and hud.unit_title.text.contains("6"), "the window shows the squad", hud.unit_title.text)
				_key(KEY_1, true)
				_mouse(_screen(GOAL), MOUSE_BUTTON_RIGHT, true)
			if frame == 10:
				check(hud.input.groups.has(1), "ctrl+1 keeps them as group 1")
				stage = 2
				frame = 0
		2:
			var arrived := true
			for unit in knights + archers:
				# there, and standing still in its place
				if unit.global_position.distance_to(unit.attack_goal) > Unit.GOAL_SLACK or unit.velocity.length() > 5.0:
					arrived = false
			if not arrived and frame < 60 * 30:
				return false
			check(arrived, "the six got there")
			var home: Vector2 = gs.human().base().global_position + Vector2(420, -60)
			check(others[0].global_position.distance_to(home + Vector2(0, 170)) < 60.0, "the others stayed where they were")
			# facing the way they went: the shooters are further back along it
			var along := (GOAL - home).normalized()
			var front := 0.0
			var back := 0.0
			for unit in knights:
				front += unit.global_position.dot(along)
			for unit in archers:
				back += unit.global_position.dot(along)
			check(back / 3.0 < front / 3.0 - 20.0, "the archers stand behind the knights", "%.0f behind" % (front / 3.0 - back / 3.0))
			# nobody picked now; 1 picks the group again
			_mouse(_screen(GOAL + Vector2(0, 200)), MOUSE_BUTTON_LEFT, true)
			_mouse(_screen(GOAL + Vector2(0, 200)), MOUSE_BUTTON_LEFT, false)
			stage = 3
			frame = 0
		3:
			if frame == 3:
				check(hud.input.chosen.is_empty(), "a click on empty ground picks nobody")
				_key(KEY_1)
			if frame == 5:
				check(hud.input.chosen.size() == 6, "1 picks group 1 again", hud.input.chosen.size())
				root.get_camera_2d().global_position = GOAL
			if frame == 7:
				# a double click on an archer: every archer on the screen
				var at := _screen(archers[0].global_position + Vector2(0, -40))
				_mouse(at, MOUSE_BUTTON_LEFT, true, false, true)
			if frame == 9:
				var all_archers := true
				for unit in hud.input.chosen:
					if unit.loadout != "archer":
						all_archers = false
				check(all_archers and hud.input.chosen.size() == 3, "a double click picks every archer on the screen", hud.input.chosen.size())
				hud.input.stop_chosen(true)
			if frame == 11:
				check(archers[0].leash == Unit.HOLD_LEASH and archers[0].order == Unit.Order.HOLD, "«Держать» holds them on a short leash")
				return true
	return false
