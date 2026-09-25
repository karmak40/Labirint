class_name Squad
extends Node
## A handful of units told the same thing at once. This, plus hiring, is the
## whole vocabulary a side has for its army: plain points in, nothing about
## mice or keys, so whoever is giving the orders -- a HUD, an AI, one day a
## remote player -- says it the same way.

var units: Array[Unit] = []

func add(unit: Unit) -> void:
	if unit != null and not units.has(unit):
		units.append(unit)
		unit.tree_exiting.connect(remove.bind(unit))

func remove(unit: Unit) -> void:
	units.erase(unit)

## The ones still standing: the dead keep their place on the floor, not in the ranks.
func alive() -> Array[Unit]:
	var standing: Array[Unit] = []
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive():
			standing.append(unit)
	return standing

func rally(point: Vector2) -> void:
	for unit in alive():
		unit.set_rally(point)

func attack_move(point: Vector2) -> void:
	for unit in alive():
		unit.set_attack_move(point)
