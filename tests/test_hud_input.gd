extends "res://tests/lib/test_case.gd"
## The HUD and the field driven by real input events, the way a player's keys
## and mouse would: Tab through the tabs, a number key to start placing a
## building, a left click to put it down, a refused spot saying why, Esc and
## the right button cancelling a placement (not pausing), a right click on the
## field ordering the army, and a click on the minimap moving the camera.
## Events are pushed in viewport coordinates, so it works headless too.

var stage := 0
var hud: Node
var said: Array[String] = []

func begin() -> void:
	time_limit = 60 * 40
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func _click(at_world: Vector2, button: MouseButton, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.shift_pressed = shift
	event.position = root.get_canvas_transform() * at_world
	event.global_position = event.position
	root.push_input(event, true)

func _click_screen(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.global_position = at
	root.push_input(event, true)

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing() or frame < 10:
				return false
			silence(Team.Id.ENEMY)
			hud = current_scene.get_node("Hud")
			hud.input.refused.connect(func(reason: String, _t: Color) -> void: said.append(reason))
			gs.human().economy.add("wood", 300)
			gs.human().economy.add("ore", 300)
			_key(KEY_TAB)
			_key(KEY_TAB)
			stage = 1
			frame = 0
		1:
			if frame == 2:
				check(hud.tab == 2, "Tab twice moves to «Постройки»", hud.tab)
				_key(KEY_2)
			if frame == 4:
				check(hud.input.placing == "library", "key 2 there starts placing a library", hud.input.placing)
				_key(KEY_ESCAPE)
			if frame == 6:
				check(hud.input.placing == "" and not paused, "Esc cancels the placing and does not pause")
				_key(KEY_2)
			if frame == 8:
				# the castle is in the way here
				_click(gs.human().base().global_position, MOUSE_BUTTON_LEFT)
			if frame == 10:
				check(said.has("Мешает другая постройка"), "a refused spot says why", said)
				check(hud.input.placing == "library", "and placing carries on")
				_click(Vector2(620, 180), MOUSE_BUTTON_LEFT)
			if frame == 12:
				check(gs.human().has_library_site(), "a left click on open ground lays out the library")
				check(hud.input.placing == "", "and ends the placing")
				_key(KEY_1)
			if frame == 14:
				check(hud.input.placing == "tower", "key 1 starts placing a tower")
				_click(Vector2(760, 330), MOUSE_BUTTON_LEFT, true)
			if frame == 16:
				check(hud.input.placing == "tower", "with Shift held it carries on placing")
				_click(Vector2(760, 330), MOUSE_BUTTON_RIGHT)
			if frame == 18:
				check(hud.input.placing == "", "the right button cancels it")
				for i in 4:
					_key(KEY_TAB)
			if frame == 20:
				check(hud.tab == 2, "Tab goes round all four tabs", hud.tab)
				gs.hire(1, "warrior")
				stage = 2
				frame = 0
		2:
			var army: Array = gs.human().squad.alive()
			if army.is_empty():
				return false
			if frame < 30:
				return false
			var soldier: Unit = army[0]
			_click(Vector2(1200, 300), MOUSE_BUTTON_RIGHT)
			await_order(soldier)
			return false
		3:
			var camera: Camera2D = root.get_viewport().get_camera_2d()
			if frame == 1:
				var map_panel: Control = hud.minimap
				var at: Vector2 = map_panel.get_global_rect().position + Vector2(map_panel.size.x * 0.8, map_panel.size.y * 0.5)
				_click_screen(at)
			if frame == 4:
				check(camera.get_screen_center_position().x > 1800.0, "a click on the minimap moves the camera there",
					camera.get_screen_center_position().round())
				return true
	return false

func await_order(soldier: Unit) -> void:
	stage = 99
	await process_frame
	await process_frame
	check(soldier.order == Unit.Order.ATTACK_MOVE and soldier.attack_goal.distance_to(Vector2(1200, 300)) < 2.0,
		"a right click on the field sends the army there", soldier.attack_goal.round())
	stage = 3
	frame = 0
