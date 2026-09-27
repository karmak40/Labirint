extends SceneTree
# temporary: room 4 played with nobody at the controls, reported every 20 s

var frame := 0
var next_report := 20.0

func _initialize() -> void:
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _process(_delta: float) -> bool:
	frame += 1
	var campaign := root.get_node("Campaign")
	var gs := root.get_node("GameState")
	if frame == 10:
		for id in ["forest", "gorge", "siege"]:
			campaign.stars[id] = 2
		campaign.start(3)
	if frame > 20 and not gs.is_playing() and current_scene != null and current_scene.name == "Skirmish":
		print("match over at ", gs.match_time, " winner ", gs.winner)
		quit()
	# the simplest defence: warriors with whatever wood is spare, now and then
	if gs.is_playing() and frame % 300 == 0:
		while gs.human().economy.wood > 60 and gs.hire(gs.human_team, "warrior"):
			pass
	if gs.is_playing() and gs.match_time >= next_report:
		next_report += 20.0
		var rules = current_scene.get_node("RoomRules")
		var me = gs.human()
		print("t%3d sent %d alive %d castle %d workers %d army %d wood %d ore %d" % [gs.match_time, rules.sent, rules._wave_left(),
			me.base().health, me.workers().size(), me.squad.alive().size(), me.economy.wood, me.economy.ore])
		if gs.match_time > 560.0:
			quit()
	return false
