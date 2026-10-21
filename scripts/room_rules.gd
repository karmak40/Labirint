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
## A cleared bandit camp sent men to join us (RoomRules, "camp_men").
signal reinforced(count: int, from: Vector2)
## The room's boss (see "boss") fell.
signal boss_down

## A room may also have:
##   "known": ["magic", "healing"]  studies our side starts with
##   "army": 0.5                    (Campaign) the share of our starting army to
##                                  keep for the third star; with no castle of
##                                  ours, losing the whole army loses the room
##   "tutorial": true               the HUD shows its step-by-step lessons (Tutorial)
##   "camp_men": {"spearman": 2}    men who join us where a bandit camp falls to
##                                  us (a room with no store to pay a chest into)
##   "boss": {                      one strong man of the enemy's, at its rally
##       "kind": "greatsword", "epithet": "Вождь",
##       "health": 3.5, "harm": 1.4, "size": 1.25,
##       "kit": ["helm", "armour"], "guards": {"knight": 2}}
var army_at_start := -1

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

var boss: Unit
var camps_total := 0
var camps_cleared := 0

func _ready() -> void:
	game = get_node_or_null("/root/GameState")
	_know.call_deferred()
	_set_field.call_deferred()
	var difficulty: String = game.ai_difficulty if game != null else "normal"
	waves = expand(room, difficulty)
	after_waves = room.get("after_waves", "open_gates" if _enemy_keep() != null else "win")
	if not waves.is_empty():
		open = false
		if after_waves == "open_gates" and _enemy_keep() != null:
			_enemy_keep().shut = true
			_enemy_keep().queue_redraw()

## What a room puts on the field beyond its map: the boss, and a watch on the
## camps, whose fall may bring us men.
func _set_field() -> void:
	if game == null or game.field() == null:
		return
	for node in get_tree().get_nodes_in_group("camps"):
		camps_total += 1
		(node as BanditCamp).cleared.connect(_on_camp_cleared.bind(node))
	if room.has("boss"):
		_raise_boss(room["boss"])

func _on_camp_cleared(team: int, _bounty: Dictionary, camp: BanditCamp) -> void:
	if game == null or team != game.human_team:
		return
	camps_cleared += 1
	var us: PlayerState = game.human()
	var men: Dictionary = room.get("camp_men", {})
	if us == null or men.is_empty():
		return
	var count := 0
	for kind: String in men:
		for i in int(men[kind]):
			var soldier := _soldier(kind, us.team)
			soldier.position = camp.global_position + Vector2(-70.0 - 30.0 * float(count / 3), 28.0 * (float(count % 3) - 1.0))
			game.field().add_child(soldier)
			us.squad.add(soldier)
			us.kit_out(soldier)
			soldier.set_rally(soldier.position)
			count += 1
	reinforced.emit(count, camp.global_position)

## A soldier of `kind` for `team`, not yet on the field.
func _soldier(kind: String, team: int) -> Unit:
	var entry: Dictionary = ProductionBuilding.CATALOG[kind]
	var soldier: Unit = (load(entry["scene"]) as PackedScene).instantiate()
	soldier.team = team
	if entry.has("loadout"):
		soldier.loadout = entry["loadout"]
	return soldier

## The enemy's strong man and his bodyguard, standing at its rally point.
func _raise_boss(spec: Dictionary) -> void:
	var foe: PlayerState = game.enemy_of(game.human_team)
	if foe == null:
		return
	var spot: Vector2 = game.field().map.enemy.rally
	boss = (load("res://scenes/warrior/Warrior.tscn") as PackedScene).instantiate()
	boss.team = foe.team
	boss.loadout = spec.get("kind", "greatsword")
	boss.position = spot
	game.field().add_child(boss)
	foe.squad.add(boss)
	foe.kit_out(boss)
	for item: String in spec.get("kit", []):
		if boss.can_wear(item):
			boss.wear(item)
	boss.set_scales(boss.harm_scale * float(spec.get("harm", 1.0)), boss.health_scale * float(spec.get("health", 1.0)))
	boss.epithet = spec.get("epithet", "")
	boss.plumed = true
	var size := float(spec.get("size", 1.0))
	boss.scale = Vector2(size, size)
	boss.set_rally(spot)
	boss.died.connect(func(_body: PlayerBody) -> void: boss_down.emit())
	var index := 0
	var guards: Dictionary = spec.get("guards", {})
	for kind: String in guards:
		for i in int(guards[kind]):
			var guard := _soldier(kind, foe.team)
			guard.position = spot + Vector2(-50.0, 60.0 * (1.0 if index % 2 == 0 else -1.0) * float(1 + index / 2))
			game.field().add_child(guard)
			foe.squad.add(guard)
			foe.kit_out(guard)
			guard.set_rally(guard.position)
			index += 1

## The studies the room gives us, known from the start.
func _know() -> void:
	var us: PlayerState = game.human() if game != null else null
	if us == null:
		return
	for id in room.get("known", []):
		us.researched[id] = true
	for unit in us.squad.alive():
		us.kit_out(unit)

## How much of the army we started with is still standing (1 before any count).
func army_share() -> float:
	var us: PlayerState = game.human() if game != null else null
	if us == null or army_at_start <= 0:
		return 1.0
	return float(us.squad.alive().size()) / float(army_at_start)

## With no castle of ours, the army is all there is: when it is gone, so is the room.
func _watch_army() -> void:
	var us: PlayerState = game.human() if game != null else null
	if us == null or us.base() != null:
		return
	var standing := us.squad.alive().size()
	if army_at_start < 0:
		if standing > 0:
			army_at_start = standing
			_know()
		return
	if standing == 0 and game.is_playing():
		var foe: PlayerState = game.enemy_of(game.human_team)
		game.end_match(foe.team if foe != null else Team.Id.ENEMY)

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
		var goal: String = tr(room["goal"]) if room.has("goal") else ""
		if camps_total > 0 and room.has("camp_men"):
			goal += "  " + tr("Лагерей разгромлено: %d из %d") % [camps_cleared, camps_total]
		return goal
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
	_watch_army()
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
