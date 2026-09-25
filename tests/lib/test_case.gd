extends SceneTree
## The base every test under tests/ extends. A test is a SceneTree script run
## headless (see run_tests.ps1):
##
##   godot --headless --fixed-fps 60 --path . -s res://tests/test_something.gd
##
## It overrides `begin()` to set up and `step()` to be called once per physics
## frame -- return true when finished. `check()` records a result; the process
## exits 0 if every check held and 1 if any failed, so a runner needs nothing
## but the exit code. `--fixed-fps 60` makes the frames come as fast as the
## machine allows, with game time still advancing 1/60 s per frame.
##
## Every test keeps its achievements in a file of its own, so no run can ever
## write into the player's real save.

const ACHIEVEMENTS_FILE := "user://test_achievements.cfg"
const CAMPAIGN_FILE := "user://test_campaign.cfg"

## Frames before the test gives up and fails, whatever it was waiting for.
var time_limit := 60 * 180
var frame := 0
var checks := 0
var failures := 0
var _finished := false
var _closing := -1             ## frames left before quitting, once finished

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACHIEVEMENTS_FILE))
	var achievements := root.get_node_or_null("Achievements")
	if achievements != null:
		achievements.load_from(ACHIEVEMENTS_FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMPAIGN_FILE))
	var campaign := root.get_node_or_null("Campaign")
	if campaign != null:
		campaign.load_from(CAMPAIGN_FILE)
		campaign.leave()
	begin()

## Set up. Loading a scene with `change_scene_to_file` is safest: autoloads are
## already in place, and the scene is there from the next frames on.
func begin() -> void:
	pass

## Once per physics frame. Return true when the test is done.
func step() -> bool:
	return true

func _physics_process(_delta: float) -> bool:
	if _finished:
		# the stage has been cleared; quit once it has actually gone
		_closing -= 1
		if _closing <= 0:
			quit(1 if failures > 0 else 0)
			return true
		return false
	frame += 1
	if frame > time_limit:
		check(false, "finished within %d s of game time" % (time_limit / 60))
		return finish()
	if step():
		return finish()
	return false

## Records one expectation. `what` says what should be true, in plain words.
func check(ok: bool, what: String, detail: Variant = null) -> bool:
	checks += 1
	var tail := "" if detail == null else "  (%s)" % str(detail)
	if ok:
		print("  ok    ", what, tail)
	else:
		failures += 1
		print("  FAIL  ", what, tail)
	return ok

func finish() -> bool:
	if _finished:
		return true
	_finished = true
	print("%s: %d checks, %d failed" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	# Take down what the test put on the stage first and quit a couple of frames
	# later, so the engine is not asked to tear down a live match in one go.
	# (Even so, a test process now and then crashes on the way out, after every
	# check -- the engine's own shutdown, never seen in the game. The verdict line
	# above is printed first, and run_tests.ps1 goes by it; see there.)
	for node in root.get_children():
		if not ProjectSettings.has_setting("autoload/" + node.name):
			node.queue_free()
	_closing = 3
	return false

## Game time since the test started, in seconds.
func seconds() -> float:
	return frame / 60.0

# --- helpers shared by the match tests ------------------------------------------

func game() -> Node:
	return root.get_node("GameState")

## The match scene, once it is up and the match registered.
func playing() -> bool:
	return current_scene != null and current_scene.name == "Skirmish" and game().is_playing()

## Takes the enemy's head off, for tests that want a quiet opponent.
func silence(team: int) -> void:
	var side = game().side(team)
	if side != null and side.has_node("AIDirector"):
		side.get_node("AIDirector").queue_free()

func find_button(under: Node, text: String) -> Button:
	for node in under.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text or button.get("caption") == text:
			return button
	return null

func find_card(hud: Node, kind: String) -> Button:
	for node in hud.find_children("*", "Button", true, false):
		if node.has_meta("kind") and node.get_meta("kind") == kind:
			return node
	return null
