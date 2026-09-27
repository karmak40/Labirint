extends "res://tests/lib/test_case.gd"
## Filming mode (CinemaMode) driven by real keys: F10 hides the HUD and bars and
## takes the camera; Z slows time and Space freezes it; Ctrl+1 remembers a shot
## and 1 glides back to it; V lifts the fog; the camera keeps real time while
## the game is slowed; and F10 puts everything back as it was.

const SHOTS := "user://test_cinema_shots.cfg"

var stage := 0
var hud: Node
var cinema: Node   # untyped: its script needs the autoloads, which a test starts before
var camera: RtsCamera
var home := Vector2.ZERO

func begin() -> void:
	time_limit = 60 * 40
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOTS))
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _key(code: Key, ctrl := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	root.push_input(event, true)

func step() -> bool:
	match stage:
		0:
			if not playing() or frame < 10:
				return false
			silence(Team.Id.ENEMY)
			hud = current_scene.get_node("Hud")
			cinema = current_scene.get_node("Cinema")
			cinema.shots_file = SHOTS
			camera = root.get_camera_2d() as RtsCamera
			_key(KEY_F10)
			stage = 1
			frame = 0
		1:
			if frame == 2:
				check(cinema.active, "F10 turns filming on")
				check(not hud.visible, "the HUD is hidden")
				check(camera.steered, "the camera is steered by the filming mode")
				check(Pen.bare, "health bars are left off")
				home = camera.position
				_key(KEY_1, true)
			if frame == 4:
				check(cinema.shots.has(1), "Ctrl+1 remembers a shot")
				check(FileAccess.file_exists(SHOTS), "and keeps it in a file")
				camera.position += Vector2(600.0, 0.0)
				camera._clamp()
				_key(KEY_Z)
			if frame == 6:
				check(is_equal_approx(Engine.time_scale, 0.5), "Z slows time", Engine.time_scale)
				_key(KEY_1)
			if frame == 7:
				# a glide keeps real time: its 4 s are 240 frames even at half speed
				check(cinema._glide_left > 3.9, "1 starts a glide to the shot", cinema._glide_left)
			if frame == 6 + 60 * 4 + 10:
				check(camera.position.distance_to(home) < 2.0, "the glide lands on the shot in real time",
					camera.position.distance_to(home))
				_key(KEY_SPACE)
			if frame == 6 + 60 * 4 + 12:
				check(paused, "Space freezes the frame")
				_key(KEY_1)   # a key while filming does not reach the HUD's cards
				_key(KEY_V)
			if frame == 6 + 60 * 4 + 14:
				var fog := FogOfWar.current
				check(fog == null or fog.lifted, "V lifts the fog")
				_key(KEY_F10)
			if frame == 6 + 60 * 4 + 16:
				check(not cinema.active, "F10 turns filming off")
				check(hud.visible, "the HUD is back")
				check(not camera.steered, "the camera is the player's again")
				check(not Pen.bare, "health bars are back")
				check(not paused, "the frame is unfrozen")
				check(is_equal_approx(Engine.time_scale, 1.0), "time runs at its own pace again")
				var fog := FogOfWar.current
				check(fog == null or not fog.lifted, "the fog is back")
				check(hud.input.placing == "", "no card was pressed while filming")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOTS))
				return finish()
	return false
