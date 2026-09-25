extends "res://tests/lib/test_case.gd"
## Not a test: a measurement. N knights a side fight on the skirmish map, and
## the real time per frame is reported. Run it in a window, not headless -- the
## drawing is most of the cost:
##
##   godot --fixed-fps 60 --disable-vsync --path . -s res://tests/bench/bench_crowd.gd
##
## BENCH_N sets knights per side (default 40). Frame budget at 60 Hz is 16.7 ms.

var n := 40
var started := false
var last := 0
var samples: Array[float] = []

func begin() -> void:
	time_limit = 60 * 60
	var wanted := OS.get_environment("BENCH_N")
	if wanted != "":
		n = int(wanted)
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	if not started:
		if not playing():
			return false
		started = true
		frame = 0
		silence(Team.Id.PLAYER)
		silence(Team.Id.ENEMY)
		var knight := load("res://scenes/knight/Knight.tscn")
		for team in [Team.Id.PLAYER, Team.Id.ENEMY]:
			for i in n:
				var unit: Unit = knight.instantiate()
				unit.team = team
				var x := 1300.0 if team == Team.Id.PLAYER else 1700.0
				unit.position = Vector2(x + (i % 5) * 18.0 * (1.0 if team == Team.Id.PLAYER else -1.0),
					60.0 + (i / 5) * (400.0 / ceilf(n / 5.0)))
				current_scene.add_child(unit)
				game().side(team).squad.add(unit)
		game().attack_move(Team.Id.PLAYER, Vector2(1700, 280))
		game().attack_move(Team.Id.ENEMY, Vector2(1300, 280))
		return false
	var now := Time.get_ticks_usec()
	if last > 0 and frame > 30:
		samples.append((now - last) / 1000.0)
	last = now
	if frame < 60 * 20:
		return false
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	print("N=%d a side: frame mean %.2f ms, median %.2f, p95 %.2f, max %.2f; draw calls %d" % [n, total / samples.size(),
		samples[samples.size() / 2], samples[int(samples.size() * 0.95)], samples[-1],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	return true
