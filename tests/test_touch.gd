extends "res://tests/lib/test_case.gd"
## Fingers on a phone, pushed as real touch events: a drag moves the camera, a
## pinch zooms, a drag that starts on the HUD leaves the camera alone, a tap
## looks at a soldier, a long press sends the army, the flag button moves the
## gathering point, a building is placed with two taps, a held card shows what
## it is about without pressing it, and the back button closes, then pauses.

var stage := 0
var hud: Node
var input: Node
var camera: RtsCamera
var soldier: Unit
var was := Vector2.ZERO
var zoom_was := 1.0
var spot := Vector2.ZERO
var card: HudCard
var drafts_before := 0

func begin() -> void:
	time_limit = 60 * 60
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)

func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	root.push_input(event, true)

## The mouse the engine makes from a finger (what the HUD's buttons see).
func _finger_mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	root.push_input(event, true)

func _screen(world: Vector2) -> Vector2:
	return root.get_canvas_transform() * world

func _look_at(world: Vector2) -> void:
	camera.position = world
	camera._clamp()

func _back() -> void:
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing() or frame < 10:
				return false
			silence(Team.Id.ENEMY)
			raise_barracks(Team.Id.PLAYER)
			hud = current_scene.get_node("Hud")
			input = hud.input
			camera = root.get_viewport().get_camera_2d() as RtsCamera
			gs.human().economy.add("wood", 300)
			gs.human().economy.add("ore", 300)
			gs.hire(Team.Id.PLAYER, "warrior")
			_look_at(Vector2(1200.0, 300.0))
			stage = 1
			frame = 0
		1:
			# one finger dragged 120 px to the left: the view moves 120 px right
			if frame == 2:
				was = camera.get_screen_center_position()
				_touch(0, Vector2(500, 260), true)
				_drag(0, Vector2(500, 260), Vector2(470, 260))
				_drag(0, Vector2(470, 260), Vector2(420, 260))
				_drag(0, Vector2(420, 260), Vector2(380, 260))
				_touch(0, Vector2(380, 260), false)
			if frame == 4:
				var moved: Vector2 = (camera.get_screen_center_position() - was) * camera.zoom.x
				check(moved.distance_to(Vector2(120, 0)) < 1.5, "a one-finger drag pans the camera with the finger", moved.round())
				check(input.selected == null and TouchInput.in_use, "a drag is no tap, and the screen knows a finger is in use")
				# two fingers spread apart zoom in, about the point between them
				zoom_was = camera.zoom.x
				_touch(0, Vector2(430, 260), true)
				_touch(1, Vector2(530, 260), true)
				_drag(0, Vector2(430, 260), Vector2(410, 260))
				_drag(1, Vector2(530, 260), Vector2(550, 260))
			if frame == 6:
				check(is_equal_approx(camera.zoom.x, clampf(zoom_was * 1.4, RtsCamera.ZOOM_MIN, RtsCamera.ZOOM_MAX)),
					"a pinch zooms by how far the fingers spread", [zoom_was, camera.zoom.x])
				_touch(1, Vector2(550, 260), false)
				_touch(0, Vector2(410, 260), false)
				check(input.selected == null and input.mark_left <= 0.0, "a pinch neither taps nor orders")
				camera.zoom = Vector2.ONE
				_look_at(Vector2(1200.0, 300.0))
			if frame == 8:
				# a drag that starts on the bottom bar belongs to the HUD
				was = camera.get_screen_center_position()
				var bar: Control = hud.bottom_bar
				var on_bar: Vector2 = bar.get_global_rect().get_center() + Vector2(-150, 0)
				_touch(0, on_bar, true)
				_drag(0, on_bar, on_bar + Vector2(-80, 0))
				_touch(0, on_bar + Vector2(-80, 0), false)
			if frame == 10:
				check(camera.get_screen_center_position().distance_to(was) < 0.5, "a drag on the HUD does not move the camera",
					(camera.get_screen_center_position() - was).round())
				stage = 2
				frame = 0
		2:
			var army: Array = gs.human().squad.alive()
			if army.is_empty() or frame < 30:
				return false
			soldier = army[0]
			stage = 3
			frame = 0
		3:
			if frame == 1:
				_look_at(soldier.global_position)
			if frame == 3:
				var at := _screen(soldier.global_position + Vector2(0, -30))
				_touch(0, at, true)
				_touch(0, at, false)
			if frame == 5:
				check(input.selected == soldier, "a tap on a soldier looks at him")
				# a long press on open ground: the army goes there
				spot = soldier.global_position + Vector2(-220, 40)   # clear of the unit window on the right
				_touch(0, _screen(spot), true)
			if frame == 20:
				check(soldier.order != Unit.Order.ATTACK_MOVE, "a press held a quarter of a second is not yet an order")
				check(input.hold_at != Vector2.INF, "and a ring fills under the finger")
			if frame == 40:
				check(soldier.order == Unit.Order.ATTACK_MOVE and soldier.attack_goal.distance_to(spot) < 2.0,
					"a long press sends the army there", soldier.attack_goal.round())
				_touch(0, _screen(spot), false)
			if frame == 42:
				check(input.selected == soldier, "and lifting the finger after it is no tap")
				hud.rally_button.pressed.emit()
			if frame == 44:
				check(input.rally_armed and hud.mode_bar.visible, "the flag button arms the gathering point, with a way out on screen")
				spot = soldier.global_position + Vector2(-120, 60)
				_touch(0, _screen(spot), true)
				_touch(0, _screen(spot), false)
			if frame == 46:
				check(gs.human().rally_point.distance_to(spot) < 40.0, "a tap then moves the gathering point", gs.human().rally_point.round())
				check(not input.rally_armed and not hud.mode_bar.visible, "and the flag is put away")
				stage = 4
				frame = 0
		4:
			if frame == 1:
				spot = gs.human().base().global_position + Vector2(520, 160)
				_look_at(spot)
			if frame == 3:
				hud._place("tower")
				check(input.ghost_at != Vector2.INF and hud.mode_bar.visible, "with a finger the tower's outline starts mid-screen")
				_touch(0, _screen(spot), true)
				_touch(0, _screen(spot), false)
			if frame == 5:
				check(input.ghost_at.distance_to(spot) < 1.0 and input.placing == "tower",
					"a tap moves the outline there and does not lay it out", input.ghost_at.round())
				check(gs.build_problem(Team.Id.PLAYER, "tower", spot) == "", "(the spot is free)",
					gs.build_problem(Team.Id.PLAYER, "tower", spot))
				# drag the outline 40 px by a finger that starts on it
				_touch(0, _screen(spot), true)
				_drag(0, _screen(spot), _screen(spot + Vector2(20, 0)))
				_drag(0, _screen(spot + Vector2(20, 0)), _screen(spot + Vector2(40, 0)))
				_touch(0, _screen(spot + Vector2(40, 0)), false)
			if frame == 7:
				check(input.ghost_at.distance_to(spot + Vector2(40, 0)) < 1.0, "a finger that starts on the outline drags it",
					input.ghost_at.round())
				_touch(0, _screen(input.ghost_at), true)
				_touch(0, _screen(input.ghost_at), false)
			if frame == 9:
				var towers: Array = gs.human().buildings.filter(func(b: Building) -> bool: return b is Tower)
				check(towers.size() == 1 and towers[0].global_position.distance_to(spot + Vector2(40, 0)) < 2.0,
					"a tap on the outline lays the tower out there")
				check(input.placing == "" and not hud.mode_bar.visible, "and placing ends")
				hud._place("tower")
			if frame == 11:
				hud.mode_bar.find_children("", "Button", true, false)[0].pressed.emit()
			if frame == 13:
				check(input.placing == "", "the ✕ on screen cancels placing")
				stage = 5
				frame = 0
		5:
			if frame == 1:
				hud._select_tab(1)
				card = find_card(hud, "warrior")
				drafts_before = gs.human().drafts.size() + gs.human().barracks().queue.size()
			if frame == 3:
				check(not card.disabled, "(a warrior can be ordered)")
				_finger_mouse(card.get_global_rect().get_center(), true)
			if frame == 40:
				check(hud.card_info.visible and hud.card_info_title.text == card.title, "holding a card shows what it is about")
				_finger_mouse(card.get_global_rect().get_center(), false)
			if frame == 42:
				var now: int = gs.human().drafts.size() + gs.human().barracks().queue.size()
				check(now == drafts_before, "and lifting the finger does not order one", [drafts_before, now])
				check(hud.card_info.visible, "the window stays open")
				_back()
			if frame == 44:
				check(not hud.card_info.visible, "the back button closes it first")
				check(input.selected == soldier, "(the soldier is still looked at)")
				_finger_mouse(card.get_global_rect().get_center(), true)
				_finger_mouse(card.get_global_rect().get_center(), false)
			if frame == 46:
				var now: int = gs.human().drafts.size() + gs.human().barracks().queue.size()
				check(now == drafts_before + 1, "a short tap on the card orders a warrior", [drafts_before, now])
				hud._select_tab(1)
				card = find_card(hud, "spearman")
				_finger_mouse(card.get_global_rect().get_center(), true)
			if frame == 84:
				_finger_mouse(card.get_global_rect().get_center(), false)
				check(hud.card_info.visible and hud.card_info_alt.visible and hud.card_info_alt.text.contains("запас"),
					"a locked soldier's card still opens, with its Shift action as a button", hud.card_info_alt.text)
				_back()
				_back()
			if frame == 86:
				check(input.selected == null, "the back button then stops looking at the soldier")
				_back()
			if frame == 88:
				check(paused and hud.overlay.visible, "then pauses the match")
				_back()
			if frame == 90:
				check(not paused, "and once more goes on with it")
				return true
	return false
