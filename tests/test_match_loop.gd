extends "res://tests/lib/test_case.gd"
## The whole loop through the real screens and buttons: the menu's "Схватка",
## hiring warriors with the HUD's cards, "В атаку" on the HUD, the enemy castle
## falling, the victory screen, and "В меню" back to the menu. The enemy's head
## is taken off: this is about the screens, not about beating the AI.

var stage := 0
var hud: Node

func begin() -> void:
	time_limit = 60 * 240
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if current_scene != null and current_scene.name == "MainMenu" and frame > 5:
				var start := find_button(current_scene, "Схватка")
				check(start != null, "the menu has «Схватка»")
				start.pressed.emit()
				stage = 10
		10:
			# «Схватка» opens the setup: difficulty and the enemy's strategy, then «Начать»
			var go := find_button(current_scene, "Начать")
			if go != null:
				check(find_button(current_scene, "Сложный") != null and find_button(current_scene, "Оборона") != null,
					"the setup offers difficulty and strategy")
				go.pressed.emit()
				stage = 1
		1:
			if playing():
				silence(Team.Id.ENEMY)
				hud = current_scene.get_node("Hud")
				var e: Economy = gs.human().economy
				e.add("wood", 200)
				e.add("ore", 200)
				var card := find_card(hud, "warrior")
				check(card != null, "the HUD has a warrior card")
				for i in 5:
					card.pressed.emit()
				check(gs.human().barracks().queue.count("warrior") == 5, "five warriors hired from the card", gs.human().barracks().queue)
				hud._refresh()
				check(find_card(hud, "knight").disabled, "the knight card is locked until chivalry is learned")
				stage = 2
				frame = 0
		2:
			if gs.human().barracks().queue.is_empty() and gs.human().squad.alive().size() >= 5:
				var attack := find_button(hud, "В атаку")
				check(attack != null, "the HUD has «В атаку»")
				attack.pressed.emit()
				stage = 3
		3:
			if not gs.is_playing():
				check(gs.phase == gs.Phase.WON, "the enemy castle fell and we won", gs.Phase.keys()[gs.phase])
				check(paused, "the game is paused on the end screen")
				check(hud.overlay.visible and hud.overlay_title.text == "Победа", "the victory screen is up", hud.overlay_title.text)
				find_button(hud, "В меню").pressed.emit()
				stage = 4
				frame = 0
		4:
			if current_scene != null and current_scene.name == "MainMenu" and frame > 3:
				check(gs.phase == gs.Phase.MENU and not paused, "back in the menu, unpaused")
				return true
	return false
