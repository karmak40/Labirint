class_name RoomRules
extends Node
## What makes one campaign room different from a plain skirmish, put into the
## match by Campaign when a room starts: waves of enemy soldiers that come on
## at set times, and what happens once the last of them is beaten.
##
##   the siege    the enemy castle stays shut (it takes no harm) while its waves
##                march out of its gate; its gates open after the last one
##   a holdout    the enemy has no castle on the field; the waves come in from
##                the map's spawn points, and beating the last one wins
##
## A room describes its waves as data (Campaign.ROOMS):
##
##   "waves": [ {wave}, ... ]      in any order; sorted by "at"
##   "after_waves": "open_gates" or "win"
##                                 default: "open_gates" if the enemy has a
##                                 castle, "win" if not
##   "wave_scale": {"easy": 0.7, "normal": 1.0, "hard": 1.3}
##                                 how many men per wave, by the difficulty
##                                 chosen (GameState.ai_difficulty); default 1
##
## and a wave is
##
##   "at": 120.0                   seconds from the start of the match
##   "units": {"spearman": 4}      who comes (ProductionBuilding.CATALOG kinds)
##   "from": "west" or ["west", "east"]
##                                 MapData.spawn_points by name, or "castle"
##                                 for the enemy's gate; the men are dealt out
##                                 among them in turn. Default: the enemy's
##                                 gate, or every spawn point if it has none
##   "target": "castle" or Vector2 where they attack-move to (default: our castle)
##   "kit": ["helm", "shield"]     extra pieces put on everyone who can wear them
##   "reward": {"wood": 40}        paid to us once the whole wave is down
##   "say": "Поджигатели!"         shown when the wave comes (Russian, translated)
##   "repeat": 2, "every": 60.0, "grow": 0.25
##                                 two more copies of the wave, 60 s apart, each
##                                 25% bigger than the one before
##
## Presentation-free and team-agnostic like the rest of the match: it spawns
## soldiers the way a barracks would and orders them through their squad moves.

signal gates_opened
signal wave_sent(index: int, count: int, say: String)
signal wave_beaten(index: int, reward: Dictionary)
## Every wave of a holdout is beaten: the match is won.
signal held

const FORMATION := Vector2(26.0, 26.0)   ## between men in a wave's ranks and files
const FILES := 5                         ## men abreast

var room: Dictionary
var clock := 0.0
var sent := 0                  ## waves sent so far
var waves: Array = []          ## the room's waves, copies spelled out, by time
var alive_in_waves: Array[Unit] = []
var after_waves := "open_gates"
var open := true
var game: Node
## One per wave sent: {"index", "units": Array[Unit], "reward", "beaten"}.
var outs: Array = []

func _ready() -> void:
	game = get_node_or_null("/root/GameState")
	var difficulty: String = game.ai_difficulty if game != null else "normal"
	waves = expand(room, difficulty)
	after_waves = room.get("after_waves", "open_gates" if _enemy_keep() != null else "win")
	if not waves.is_empty():
		open = false
		if after_waves == "open_gates" and _enemy_keep() != null:
			_enemy_keep().shut = true
			_enemy_keep().queue_redraw()

## The room's waves as they will come: repeats spelled out, men scaled by the
## difficulty and by growth, sorted by time.
static func expand(of_room: Dictionary, difficulty: String) -> Array:
	var scale := float(of_room.get("wave_scale", {}).get(difficulty, 1.0))
	var list := []
	for wave: Dictionary in of_room.get("waves", []):
		for copy in int(wave.get("repeat", 0)) + 1:
			var one := wave.duplicate(true)
			one.erase("repeat")
			one["at"] = float(wave["at"]) + float(wave.get("every", 0.0)) * copy
			var grown := scale * (1.0 + float(wave.get("grow", 0.0)) * copy)
			var units := {}
			for kind in wave["units"]:
				var count := int(wave["units"][kind])
				if count > 0:
					units[kind] = maxi(1, roundi(count * grown))
			one["units"] = units
			list.append(one)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	return list

func _enemy_keep() -> Base:
	var foe: PlayerState = game.enemy_of(game.human_team) if game != null else null
	return foe.base() if foe != null else null

## The line the HUD shows under the store: what to do now.
func objective() -> String:
	if waves.is_empty() or open:
		return tr(room["goal"]) if room.has("goal") else ""
	if sent < waves.size():
		var next: Dictionary = waves[sent]
		return tr("Волна %d из %d через %d с") % [sent + 1, waves.size(), maxi(0, int(next["at"] - clock))]
	return tr("Отбейте последнюю волну: осталось %d") % _wave_left()

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
	while sent < waves.size() and clock >= float(waves[sent]["at"]):
		_send(waves[sent])
		sent += 1
	_count_the_beaten()
	# the last wave is out and every one of it is down
	if sent >= waves.size() and _wave_left() == 0:
		open = true
		if after_waves == "open_gates" and _enemy_keep() != null:
			_enemy_keep().shut = false
			_enemy_keep().queue_redraw()
			gates_opened.emit()
		elif after_waves == "win":
			held.emit()
			game.end_match(game.human_team)

## A wave all of whose men are down pays its reward, once.
func _count_the_beaten() -> void:
	for out: Dictionary in outs:
		if out["beaten"]:
			continue
		var standing := false
		for unit in out["units"]:
			if is_instance_valid(unit) and unit.is_alive():
				standing = true
				break
		if standing:
			continue
		out["beaten"] = true
		var reward: Dictionary = out["reward"]
		var ours: PlayerState = game.human()
		if ours != null:
			for kind in reward:
				ours.economy.add(kind, int(reward[kind]))
		wave_beaten.emit(out["index"], reward)

## Where a wave comes in: the points its "from" names.
func _gates_of(wave: Dictionary) -> Array[Vector2]:
	var names: Array = []
	var from: Variant = wave.get("from", [])
	if from is String:
		names = [from]
	elif from is Array:
		names = from
	var spawns: Dictionary = game.field().map.spawn_points
	if names.is_empty():
		names = ["castle"] if _enemy_keep() != null else spawns.keys()
	var gates: Array[Vector2] = []
	for name: String in names:
		if name == "castle" and _enemy_keep() != null:
			gates.append(_enemy_keep().approach_from(game.human().base().global_position))
		elif spawns.has(name):
			gates.append(spawns[name])
		else:
			push_warning("RoomRules: no spawn point '%s'" % name)
	return gates

## A wave comes in at its gates and attack-moves on our castle (or its target).
func _send(wave: Dictionary) -> void:
	var foe: PlayerState = game.enemy_of(game.human_team)
	var gates := _gates_of(wave)
	if gates.is_empty() or foe == null or game.human() == null or game.human().base() == null:
		return
	var men: Array[String] = []
	for kind: String in wave["units"]:
		for i in int(wave["units"][kind]):
			men.append(kind)
	var size: Vector2 = game.field().map.floor_size
	var dealt := {}                ## gate index -> men placed there so far
	var squad: Array[Unit] = []
	for i in men.size():
		var g := i % gates.size()
		var at_gate := int(dealt.get(g, 0))
		dealt[g] = at_gate + 1
		var out: Vector2 = gates[g]
		var target := _target_of(wave, out)
		var entry: Dictionary = ProductionBuilding.CATALOG[men[i]]
		var soldier: Unit = (load(entry["scene"]) as PackedScene).instantiate()
		soldier.team = foe.team
		if entry.has("loadout"):
			soldier.loadout = entry["loadout"]
		# ranks FILES abreast across the way, the later ones further in
		var ahead := signf(target.x - out.x) if not is_zero_approx(target.x - out.x) else 1.0
		var spot := out + Vector2(ahead * FORMATION.x * float(at_gate / FILES),
			FORMATION.y * (float(at_gate % FILES) - float(FILES - 1) * 0.5))
		soldier.position = spot.clamp(Vector2(30.0, 60.0), size - Vector2(30.0, 30.0))
		game.field().add_child(soldier)
		foe.kit_out(soldier)
		for item: String in wave.get("kit", []):
			if soldier.can_wear(item):
				soldier.wear(item)
		soldier.set_attack_move(target)
		alive_in_waves.append(soldier)
		squad.append(soldier)
	outs.append({"index": sent, "units": squad, "reward": wave.get("reward", {}), "beaten": false})
	wave_sent.emit(sent, squad.size(), wave.get("say", ""))

func _target_of(wave: Dictionary, from: Vector2) -> Vector2:
	var aim: Variant = wave.get("target", "castle")
	if aim is Vector2:
		return aim
	return game.human().base().approach_from(from)
