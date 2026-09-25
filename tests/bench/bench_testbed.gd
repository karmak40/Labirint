extends "res://tests/lib/test_case.gd"
## Not a test: the testbed's frame time, to see that nothing done for the RTS
## has made Main.tscn slower. Run in a window:
##
##   godot --fixed-fps 60 --disable-vsync --path . -s res://tests/bench/bench_testbed.gd
##
## About 4.2-4.6 ms on the development PC.

var last := 0
var samples: Array[float] = []

func begin() -> void:
	change_scene_to_file("res://scenes/main/Main.tscn")

func step() -> bool:
	var now := Time.get_ticks_usec()
	if last > 0 and frame > 30:
		samples.append((now - last) / 1000.0)
	last = now
	if frame < 600:
		return false
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	print("Main.tscn: frame mean %.2f ms, median %.2f, p95 %.2f" % [total / samples.size(),
		samples[samples.size() / 2], samples[int(samples.size() * 0.95)]])
	return true
