extends "res://tests/lib/test_case.gd"
## Esc pauses and Esc again resumes; our castle falling ends the match as a
## defeat and nothing can be ordered after it; «Заново» starts a fresh match.

var stage := 0
var hud: Node

func begin() -> void:
	time_limit = 60 * 30
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if playing() and frame > 10:
				hud = current_scene.get_node("Hud")
				_key(KEY_ESCAPE)
				stage = 1
				frame = 0
		1:
			if frame == 3:
				check(paused and hud.overlay.visible and hud.overlay_title.text == "Пауза", "Esc pauses")
				_key(KEY_ESCAPE)
			if frame == 6:
				check(not paused and not hud.overlay.visible, "Esc again resumes")
				gs.human().base().take_hit(Vector2.ZERO, 99999.0)
			if frame == 9:
				check(gs.phase == gs.Phase.LOST and gs.winner == Team.Id.ENEMY, "our castle falling is a defeat")
				check(hud.overlay_title.text == "Поражение" and not hud.resume_button.visible, "the defeat screen is up, with no «Продолжить»")
				check(not gs.hire(Team.Id.PLAYER, "warrior"), "nothing can be hired after the end")
				find_button(hud, "Заново").pressed.emit()
				stage = 2
				frame = 0
		2:
			if playing() and frame > 5:
				check(not paused, "the new match is not paused")
				check(gs.human().base().health == gs.human().base().health_max, "and our castle stands whole again")
				return true
	return false
