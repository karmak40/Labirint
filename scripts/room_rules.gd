class_name RoomRules
extends Node
## What makes one campaign room different from a plain skirmish, put into the
## match by Campaign when a room starts. For now that is the siege: the enemy
## castle stays shut while waves of its soldiers come on at set times, and its
## gates open once the last wave has been beaten.
##
## Presentation-free and team-agnostic like the rest of the match: it spawns
## soldiers the way a barracks would and orders them through GameState.

signal gates_opened
signal wave_sent(index: int, count: int)

var room: Dictionary
var clock := 0.0
var sent := 0                  ## waves sent so far
var waves: Array = []
var alive_in_waves: Array[Unit] = []
var open := true
var game: Node

func _ready() -> void:
	game = get_node_or_null("/root/GameState")
	waves = room.get("waves", [])
	if not waves.is_empty():
		open = false
		_enemy_keep().shut = true
		_enemy_keep().queue_redraw()

func _enemy_keep() -> Base:
	return game.enemy_of(game.human_team).base()

## The line the HUD shows under the store: what to do now.
func objective() -> String:
	if waves.is_empty() or open:
		return room.get("goal", "")
	if sent < waves.size():
		var next: Dictionary = waves[sent]
		return "Волна %d из %d через %d с" % [sent + 1, waves.size(), maxi(0, int(next["at"] - clock))]
	return "Отбейте последнюю волну: осталось %d" % _wave_left()

func _wave_left() -> int:
	var left := 0
	for unit in alive_in_waves:
		if is_instance_valid(unit) and unit.is_alive():
			left += 1
	return left

func _physics_process(delta: float) -> void:
	if game == null or not game.is_playing() or open:
		return
	clock += delta
	if sent < waves.size() and clock >= float(waves[sent]["at"]):
		_send(waves[sent])
		sent += 1
	# the last wave is out and every one of it is down: the gates open
	if sent >= waves.size() and _wave_left() == 0:
		open = true
		_enemy_keep().shut = false
		_enemy_keep().queue_redraw()
		gates_opened.emit()

## A wave marches out of the enemy's gate and straight at our castle.
func _send(wave: Dictionary) -> void:
	var foe: PlayerState = game.enemy_of(game.human_team)
	var keep := _enemy_keep()
	var target: Vector2 = game.human().base().approach_from(keep.global_position)
	var out := keep.approach_from(target)
	var count := 0
	for kind in wave["units"]:
		var entry: Dictionary = ProductionBuilding.CATALOG[kind]
		for i in int(wave["units"][kind]):
			var soldier: Unit = (load(entry["scene"]) as PackedScene).instantiate()
			soldier.team = foe.team
			if entry.has("loadout"):
				soldier.loadout = entry["loadout"]
			soldier.position = out + Vector2(-float(count % 4) * 22.0 * signf(target.x - out.x), float(count / 4) * 26.0 - 30.0)
			game.field().add_child(soldier)
			foe.kit_out(soldier)
			soldier.set_attack_move(target)
			alive_in_waves.append(soldier)
			count += 1
	wave_sent.emit(sent, count)
