class_name Economy
extends RefCounted
## What one side has in the store. Nothing in here happens at the moment of a
## blow: a rock knocked out of a vein is a rock on the floor, and only becomes
## ore once somebody has carried it to a stockpile and set it down (Stockpile).

signal changed(kind: String, amount: int)

const KINDS: Array[String] = ["wood", "ore", "gold"]

var wood := 0
var ore := 0
var gold := 0

func amount(kind: String) -> int:
	return get(kind) if KINDS.has(kind) else 0

func can_afford(cost: Dictionary) -> bool:
	for kind in cost:
		if amount(kind) < int(cost[kind]):
			return false
	return true

## All or nothing: a price that cannot be met takes nothing at all.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for kind in cost:
		_set_amount(kind, amount(kind) - int(cost[kind]))
	return true

func add(kind: String, count: int) -> void:
	if not KINDS.has(kind):
		push_warning("Economy: no such resource '%s'" % kind)
		return
	_set_amount(kind, amount(kind) + count)

func _set_amount(kind: String, value: int) -> void:
	set(kind, value)
	changed.emit(kind, value)
