class_name AIDirector
extends Node
## The enemy's head: a side run by a loop of decisions instead of by a person.
##
## It never touches the field. Every order it gives is one of GameState's
## commands, the same ones the HUD sends for the human -- hire, build, learn,
## send the army, call it back -- and what it knows about the other side it
## learns by looking at what is standing on the field, the same way anyone
## would. That is what would let a remote player take its place without
## anything below it changing.
##
## How it plays is its plan (AIProfile): a strategy -- rush with cheap troops,
## sit tight behind towers and bows, learn everything first, or a bit of each --
## shaped by a difficulty. The loop is the same for all of them: keep enough
## hands on each trade, save up for the library and the next study, put up
## towers, build soldiers to the mix it likes, go when the wave is big enough
## (and the plan says it is time), fall back when it is spent and make the next
## one bigger, and turn out to meet anyone who comes too close to home. Its
## only randomness is in when it thinks, and in which strategy "random" picks.

const THINK_JITTER := 0.4
const TRADE_KIND := {"wood": "woodcutter", "ore": "miner", "gold": "gold_miner"}

## Which way it plays and how well (AIProfile). Set before it is added.
var strategy := "balanced"
var difficulty := "normal"
## Everything it decides by, from the profile: see AIProfile.STRATEGIES.
var plan := {}

var team: int = Team.Id.ENEMY
## GameState, looked up rather than named: it is GameState that makes directors,
## so naming it here would have each waiting on the other to exist first.
var game: Node
var think_left := 0.0
var wave_size := 4
var wave: Array[Unit] = []     ## the soldiers sent in the current attack
var attacking := false
var defending := false

func _ready() -> void:
	var side := get_parent() as PlayerState
	if side != null:
		team = side.team
	plan = AIProfile.make(strategy, difficulty)
	strategy = plan["strategy"]
	difficulty = plan["difficulty"]
	wave_size = int(plan["first_wave"])
	think_left = randf() * float(plan["think"])
	game = get_node_or_null("/root/GameState")

func _physics_process(delta: float) -> void:
	if game == null or not game.is_playing():
		return
	think_left -= delta
	if think_left <= 0.0:
		think_left = float(plan["think"]) + randf_range(-THINK_JITTER, THINK_JITTER)
		_think()

func _think() -> void:
	var me: PlayerState = game.side(team)
	if me == null:
		return
	_put_up(me)
	# learning comes before hiring: it is the one thing it cannot catch up on later
	var study := _next_study(me)
	if study != "":
		game.research(team, study)
	_hire(me)
	if _guard_home(me):
		return
	_wage_war(me)

# --- hiring -------------------------------------------------------------------

func _hire(me: PlayerState) -> void:
	for i in int(plan["hires"]):
		var kind := _next_hire(me)
		if kind == "" or not game.hire(team, kind):
			return

## What is most wanted right now, or "" for nothing.
func _next_hire(me: PlayerState) -> String:
	var hands := _hands(me)
	var first: Dictionary = plan["workers_first"]
	var full: Dictionary = plan["workers_full"]
	# the first hands before anything else: without them there is nothing to pay with
	for trade in first:
		if hands[trade] < first[trade]:
			return TRADE_KIND[trade]
	var soldier := _soldier_kind(me)
	# a library comes first: without one nothing can ever be learned, and wood
	# spent on clubs as fast as it comes in never adds up to one
	if _saving_for_library(me):
		return _hands_for(me, hands, game.BUILDINGS["library"]["cost"])
	# the next study's price is being put by instead of spent on one more club
	if _saving_for_study(me):
		return _hands_for(me, hands, PlayerState.RESEARCH[_next_study(me)]["cost"])
	# once there is an army or a library, somebody starts on the gold it will want
	if (attacking or wave_size > int(plan["first_wave"]) or me.library() != null) and _wants_gold(me) \
			and hands["gold"] < int(plan["gold_hands"]):
		return TRADE_KIND["gold"]
	# short of what a soldier costs: more hands on that, rather than waiting on
	# a trickle for ever while the other store piles up
	var price: Dictionary = ProductionBuilding.CATALOG[soldier]["cost"]
	for resource in price:
		if me.economy.amount(resource) < int(price[resource]) \
				and full.has(resource) and hands[resource] < full[resource]:
			return TRADE_KIND[resource]
	# then soldiers, as long as the next wave is not yet up to strength
	if _at_home(me).size() < wave_size:
		return soldier
	for trade in full:
		if hands[trade] < full[trade]:
			return TRADE_KIND[trade]
	return soldier

## While putting a price by: more hands on whatever it is short of -- they are
## paid in the other goods, so hiring them does not eat into the saving -- and
## nothing else.
func _hands_for(me: PlayerState, hands: Dictionary, price: Dictionary) -> String:
	var full: Dictionary = plan["workers_full"]
	for resource in price:
		if me.economy.amount(resource) < int(price[resource]) and full.has(resource) \
				and hands[resource] < full[resource]:
			return TRADE_KIND[resource]
	return ""

## Whether anything it still means to learn costs gold.
func _wants_gold(me: PlayerState) -> bool:
	for study in plan["studies"]:
		if not me.has_researched(study) and PlayerState.RESEARCH[study]["cost"].has("gold"):
			return true
	return false

func _saving_for_library(me: PlayerState) -> bool:
	return not (plan["studies"] as Array).is_empty() and me.workers().size() >= int(plan["library_after"]) \
		and not me.has_library_site() and not me.economy.can_afford(game.BUILDINGS["library"]["cost"])

## Kept under its old name too, for anything that asked it.
func _saving_for_chivalry(me: PlayerState) -> bool:
	return _saving_for_study(me)

func _saving_for_study(me: PlayerState) -> bool:
	var study := _next_study(me)
	if study == "" or me.researching != "" or me.library() == null:
		return false
	# the gold is the slow part; once it is in, put the rest by instead of spending it
	var price: Dictionary = PlayerState.RESEARCH[study]["cost"]
	return me.economy.gold >= int(price.get("gold", 0)) and not me.economy.can_afford(price)

func _next_study(me: PlayerState) -> String:
	for study in plan["studies"]:
		if not me.has_researched(study):
			return study
	return ""

# --- building -----------------------------------------------------------------

## A library once enough hands are at work (if there is anything to learn),
## then towers in front of the castle: straight away for a cautious head, once
## there is an army to spare the wood for the rest.
func _put_up(me: PlayerState) -> void:
	if not (plan["studies"] as Array).is_empty() and me.workers().size() >= int(plan["library_after"]) \
			and not me.has_library_site():
		_build_near(me, "library", 420.0)
		return
	var towers := _towers(me)
	var time_for_towers: bool = me.library() != null \
		and (bool(plan["towers_early"]) or wave_size > int(plan["first_wave"]))
	if time_for_towers and towers < int(plan["towers"]):
		# the first two either side of the way in, any more out in front of them
		_build_near(me, "tower", 540.0 + 110.0 * float(towers / 2))

func _towers(me: PlayerState) -> int:
	var count := 0
	for building in me.buildings:
		if building is Tower and is_instance_valid(building) and building.is_alive():
			count += 1
	return count

## Tries a handful of spots out towards the field, `ahead` from the castle.
func _build_near(me: PlayerState, kind: String, ahead: float) -> bool:
	var keep := me.base()
	if keep == null:
		return false
	var toward := 1.0 if keep.global_position.x < _field_middle() else -1.0
	for dy in [0.0, -90.0, 90.0, -170.0, 170.0]:
		for dx in [0.0, 60.0, -60.0, 120.0]:
			var spot := keep.global_position + Vector2(toward * (ahead + dx), dy)
			if game.build_problem(team, kind, spot) == "":
				return game.build(team, kind, spot)
	return false

func _field_middle() -> float:
	var foe: PlayerState = game.enemy_of(team)
	var me: PlayerState = game.side(team)
	if foe == null or me == null or foe.base() == null or me.base() == null:
		return 0.0
	return (foe.base().global_position.x + me.base().global_position.x) * 0.5

## The soldier its army is shortest of, going by the mix its plan likes, of those
## it knows how to field; clubs only if the plan wants them or nothing better is open.
func _soldier_kind(me: PlayerState) -> String:
	var barracks := me.barracks()
	if barracks == null:
		return "warrior"
	var have := {}
	for unit in me.squad.alive():
		have[unit.loadout] = int(have.get(unit.loadout, 0)) + 1
	for kind in barracks.queue:
		have[kind] = int(have.get(kind, 0)) + 1
	var mix: Dictionary = plan["mix"]
	var best := "warrior"
	var best_share := INF
	for kind in mix:
		if not barracks.is_unlocked(kind):
			continue
		var share := float(have.get(kind, 0)) / float(mix[kind])
		if share < best_share:
			best_share = share
			best = kind
	return best

func _hands(me: PlayerState) -> Dictionary:
	var count := {"wood": 0, "ore": 0, "gold": 0}
	for hand in me.workers():
		count[hand.job] = count.get(hand.job, 0) + 1
	# the ones still in the queue count too, or it would hire the same hand twice
	var barracks := me.barracks()
	if barracks != null:
		for kind in barracks.queue:
			var job: String = ProductionBuilding.CATALOG[kind].get("job", "")
			if job != "":
				count[job] = count.get(job, 0) + 1
	return count

# --- fighting -----------------------------------------------------------------

## Soldiers standing and not already off in the current attack.
func _at_home(me: PlayerState) -> Array[Unit]:
	var home: Array[Unit] = []
	for unit in me.squad.alive():
		if not wave.has(unit):
			home.append(unit)
	return home

func _wave_left() -> int:
	var left := 0
	for unit in wave:
		if is_instance_valid(unit) and unit.is_alive():
			left += 1
	return left

## Someone of theirs close to our keep: everyone at home goes to meet them.
## True while that is what the army is doing.
func _guard_home(me: PlayerState) -> bool:
	var keep := me.base()
	if keep == null or attacking:
		return false
	var intruder := _nearest_foe_to_keep(keep)
	if intruder != null:
		defending = true
		game.attack_move(team, intruder.global_position)
		return true
	if defending:
		defending = false
		# they came and they are gone: strike back while they are weak, or stand down
		var left := _at_home(me)
		if _may_attack(me) and left.size() >= ceili(wave_size * float(plan["counter_share"])):
			_launch(left)
		else:
			game.rally_home(team)
		return true
	return false

## Whether the plan lets it go out yet: not before its time, nor before it has
## learned what it wants to go out with.
func _may_attack(me: PlayerState) -> bool:
	if game.match_time < float(plan["attack_after"]):
		return false
	for study in plan["attack_needs"]:
		if not me.has_researched(study):
			return false
	return true

func _wage_war(me: PlayerState) -> void:
	if attacking:
		if _wave_left() <= int(plan["spent_at"]):
			# spent: bring back whoever is left, and make the next one bigger
			attacking = false
			wave.clear()
			wave_size = mini(wave_size + int(plan["wave_growth"]), int(plan["wave_max"]))
			game.rally_home(team)
		return
	var ready := _at_home(me)
	if ready.size() >= wave_size and _may_attack(me):
		_launch(ready)

func _launch(soldiers: Array[Unit]) -> void:
	attacking = true
	wave = soldiers
	game.attack_enemy_base(team)

## The nearest living soldier or labourer of any other side within the plan's
## guard distance of the keep's walls, seen the way anyone sees the field.
func _nearest_foe_to_keep(keep: Base) -> Node2D:
	var best: Node2D = null
	var best_distance := float(plan["home_guard"])
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or not body.is_alive() or not Team.hostile(team, body.team):
			continue
		var distance := keep.nearest_point(body.global_position).distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best
