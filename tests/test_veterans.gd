extends "res://tests/lib/test_case.gd"
## Experience: the blow or the shot that brings a man down counts as a kill for
## whoever struck it; kills earn stars (2, 5, 10), and each star is a level of
## skill in the weapon in hand, a harder blow and more health. A left click on
## a soldier opens his window with all of this in it; Esc closes it.

var stage := 0
var spear: Unit
var archer: Unit
var foes: Array[Unit] = []
var hud: Node

func begin() -> void:
	time_limit = 60 * 60
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _soldier(loadout: String, team: int, at: Vector2) -> Unit:
	var unit: Unit = load("res://scenes/warrior/Warrior.tscn").instantiate()
	unit.loadout = loadout
	unit.team = team
	unit.guards = false
	unit.position = at
	current_scene.add_child(unit)
	return unit

func _click(at_world: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = root.get_canvas_transform() * at_world
	event.global_position = event.position
	root.push_input(event, true)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func step() -> bool:
	var gs := game()
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			hud = current_scene.find_child("Hud", true, false)
			spear = _soldier("spearman", Team.Id.PLAYER, Vector2(900, 300))
			archer = _soldier("archer", Team.Id.PLAYER, Vector2(1700, 450))
			check(spear.earns_stars and spear.stars == 0 and spear.kills == 0, "a new soldier has no stars")
			# a weak man in front of each: one falls to the spear, one to an arrow
			for at in [Vector2(950, 300), Vector2(1880, 450)]:
				var foe := _soldier("warrior", Team.Id.ENEMY, at)
				foe.health = 1.0
				foes.append(foe)
			stage = 1
			frame = 0
		1:
			if foes[0].is_alive() or foes[1].is_alive():
				return false
			check(spear.kills == 1, "the spear's kill is the spearman's", spear.kills)
			check(archer.kills == 1, "the arrow's kill is the archer's", archer.kills)
			check(spear.stars == 0, "one kill is no star yet")
			# a few more for the spearman, straight to his tally
			var skill := spear.skill_in(spear.weapon)
			var harm := spear.strike_harm()
			var health := spear.health_max
			spear.felled(foes[0])
			check(spear.stars == 1, "two kills make a star", spear.stars)
			check(spear.skill_in(spear.weapon) == skill + 1, "a level of skill with it", spear.skill_in(spear.weapon))
			check(spear.strike_harm() > harm * 1.07, "a harder blow", "%.1f -> %.1f" % [harm, spear.strike_harm()])
			check(is_equal_approx(spear.health_max, health * 1.1), "and more health", spear.health_max)
			for i in 8:
				spear.felled(foes[0])
			check(spear.stars == 3 and spear.kills == 10, "ten kills make three stars", [spear.stars, spear.kills])
			spear.felled(foes[0])
			check(spear.stars == 3 and spear.kills_to_next_star() == 0, "and no more than three")
			stage = 2
			frame = 0
		2:
			if frame == 5:
				_click(spear.global_position + Vector2(0, -40), MOUSE_BUTTON_LEFT)
			if frame == 10:
				var panel: Control = hud.unit_panel
				check(hud.input.selected == spear, "a left click picks the spearman")
				check(panel.visible, "and opens his window")
				check(hud.unit_title.text.contains("Копейщик") and hud.unit_title.text.contains("★★★"), "named, with his stars", hud.unit_title.text)
				var text: String = hud.unit_text.get_parsed_text()
				check(text.contains("Убито: 11"), "his kills are in it", text)
				check(text.contains("навык") and text.contains("Защита: шлем"), "and his skill and kit", text)
				_key(KEY_ESCAPE)
			if frame == 15:
				check(hud.input.selected == null and not hud.unit_panel.visible, "Esc closes it")
				check(not paused, "without pausing the game")
				_click(Vector2(1300, 150), MOUSE_BUTTON_LEFT)
			if frame == 20:
				check(hud.input.selected == null, "a click on empty ground picks nobody")
				return true
	return false
