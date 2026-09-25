class_name AIDirector
extends Node
## The enemy's head: a side run by a loop of decisions instead of by a person.
##
## It never touches the field. Every order it gives is one of GameState's
## commands, the same ones the HUD sends for the human -- hire, send the army,
## call it back -- and what it knows about the other side it learns by looking
## at what is standing on the field, the same way anyone would. That is what
## would let a remote player take its place without anything below it changing.
##
## The plan is deliberately plain: keep enough hands on wood and ore, build
## soldiers, go when the wave is big enough, fall back when it is spent and make
## the next one bigger, and turn out to meet anyone who comes too close to home.
## Its only randomness is in when it thinks, so two directors do not act in step.

const THINK_EVERY := 2.0
const THINK_JITTER := 0.4
const WORKERS_FIRST := {"wood": 2, "ore": 2}   ## before any soldier is hired
const WORKERS_FULL := {"wood": 5, "ore": 3}    ## what it builds up to: beams are slow to carry, so more on wood
const TRADE_KIND := {"wood": "woodcutter", "ore": "miner", "gold": "gold_miner"}
const GOLD_HANDS := 1          ## one on gold once the first wave is out: knights need learning
const FIRST_WAVE := 4
const WAVE_GROWTH := 2
const WAVE_MAX := 12
const SPENT_AT := 1            ## a wave down to this many goes home
const HOME_GUARD := 260.0      ## how near the keep an enemy has to come to be met
const HIRES_PER_THOUGHT := 2
const COUNTER_SHARE := 0.5     ## after beating off an attack, go back at them with this share of a wave
const STUDIES := ["chivalry", "forging", "mail"]   ## what it learns, in this order
const TOWERS_WANTED := 2

var team: int = Team.Id.ENEMY
## GameState, looked up rather than named: it is GameState that makes directors,
## so naming it here would have each waiting on the other to exist first.
var game: Node
var think_left := 0.0
var wave_size := FIRST_WAVE
var wave: Array[Unit] = []     ## the soldiers sent in the current attack
var attacking := false
var defending := false

func _ready() -> void:
	var side := get_parent() as PlayerState
	if side != null:
		team = side.team
	think_left = randf() * THINK_EVERY
	game = get_node_or_null("/root/GameState")

func _physics_process(delta: float) -> void:
	if game == null or not game.is_playing():
		return
	think_left -= delta
	if think_left <= 0.0:
		think_left = THINK_EVERY + randf_range(-THINK_JITTER, THINK_JITTER)
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
	for i in HIRES_PER_THOUGHT:
		var kind := _next_hire(me)
		if kind == "" or not game.hire(team, kind):
			return

## What is most wanted right now, or "" for nothing.
func _next_hire(me: PlayerState) -> String:
	var hands := _hands(me)
	# the first hands before anything else: without them there is nothing to pay with
	for trade in WORKERS_FIRST:
		if hands[trade] < WORKERS_FIRST[trade]:
			return TRADE_KIND[trade]
	var soldier := _soldier_kind(me)
	# the gold for knighthood is in: put the rest of its price by instead of
	# spending it on one more club
	if _saving_for_chivalry(me):
		return ""
	# once there is an army, somebody starts on the gold that knighthood costs
	if (attacking or wave_size > FIRST_WAVE) and not me.has_researched("chivalry") \
			and hands["gold"] < GOLD_HANDS:
		return TRADE_KIND["gold"]
	# short of what a soldier costs: more hands on that, rather than waiting on
	# a trickle for ever while the other store piles up
	var price: Dictionary = ProductionBuilding.CATALOG[soldier]["cost"]
	for resource in price:
		if me.economy.amount(resource) < int(price[resource]) \
				and WORKERS_FULL.has(resource) and hands[resource] < WORKERS_FULL[resource]:
			return TRADE_KIND[resource]
	# then soldiers, as long as the next wave is not yet up to strength
	if _at_home(me).size() < wave_size:
		return soldier
	for trade in WORKERS_FULL:
		if hands[trade] < WORKERS_FULL[trade]:
			return TRADE_KIND[trade]
	return soldier

func _saving_for_chivalry(me: PlayerState) -> bool:
	var study := _next_study(me)
	if study == "" or me.researching != "" or me.library() == null:
		return false
	# the gold is the slow part; once it is in, put the rest by instead of spending it
	var price: Dictionary = PlayerState.RESEARCH[study]["cost"]
	return me.economy.gold >= int(price.get("gold", 0)) and not me.economy.can_afford(price)

func _next_study(me: PlayerState) -> String:
	for study in STUDIES:
		if not me.has_researched(study):
			return study
	return ""

# --- building -----------------------------------------------------------------

## A library once the first hands are at work, then a couple of towers in front
## of the castle once there is an army to spare the wood.
func _put_up(me: PlayerState) -> void:
	if me.workers().size() >= 3 and not me.has_library_site():
		_build_near(me, "library", 420.0)
		return
	if me.library() != null and wave_size > FIRST_WAVE and _towers(me) < TOWERS_WANTED:
		_build_near(me, "tower", 560.0 + 90.0 * _towers(me))

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

## The best soldier it knows how to field.
func _soldier_kind(me: PlayerState) -> String:
	return "knight" if me.has_researched("chivalry") else "warrior"

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
		if left.size() >= ceili(wave_size * COUNTER_SHARE):
			_launch(left)
		else:
			game.rally_home(team)
		return true
	return false

func _wage_war(me: PlayerState) -> void:
	if attacking:
		if _wave_left() <= SPENT_AT:
			# spent: bring back whoever is left, and make the next one bigger
			attacking = false
			wave.clear()
			wave_size = mini(wave_size + WAVE_GROWTH, WAVE_MAX)
			game.rally_home(team)
		return
	var ready := _at_home(me)
	if ready.size() >= wave_size:
		_launch(ready)

func _launch(soldiers: Array[Unit]) -> void:
	attacking = true
	wave = soldiers
	game.attack_enemy_base(team)

## The nearest living soldier or labourer of any other side within HOME_GUARD of
## the keep's walls, seen the way anyone sees the field: through what is on it.
func _nearest_foe_to_keep(keep: Base) -> Node2D:
	var best: Node2D = null
	var best_distance := HOME_GUARD
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or not body.is_alive() or not Team.hostile(team, body.team):
			continue
		var distance := keep.nearest_point(body.global_position).distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best
