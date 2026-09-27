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
## one bigger, and turn out to meet anyone who comes too close to home.
##
## No two matches against it go quite the same (`_vary`): each head rolls its
## own habits once, when it starts -- where round its castle it likes to put
## each kind of building, the order it takes its studies in (prerequisites
## kept), how much it favours each kind of soldier, which trade it leans on,
## how big its first wave is and when it first means to go, the order it wants
## kit in. Within a match it keeps to them, so it still plays like itself.

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
## The delays its difficulty puts on it (AIProfile): when it first saw someone
## at its walls, when its wave was first ready, when the wave was first spent,
## and when its last study finished. -1 for not now.
var intruder_since := -1.0
var ready_since := -1.0
var spent_since := -1.0
var studied_at := -INF

func _ready() -> void:
	var side := get_parent() as PlayerState
	if side != null:
		team = side.team
	plan = AIProfile.make(strategy, difficulty)
	strategy = plan["strategy"]
	difficulty = plan["difficulty"]
	rng.randomize()
	_vary()
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
	if me.researching != "":
		studied_at = game.match_time
	# a pause after each study, the longer the easier the head
	if study != "" and not _saving_for_forge(me) and game.match_time - studied_at >= float(plan.get("study_pause", 0.0)):
		game.research(team, study)
	_rebalance(me)
	_mend(me)
	_hire(me)
	_arm(me)
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
	# no soldier without a barracks: until it stands, only hands for its price
	if not me.has_barracks_site():
		return _hands_for(me, hands, game.BUILDINGS["barracks"]["cost"])
	# a library comes first: without one nothing can ever be learned, and wood
	# spent on clubs as fast as it comes in never adds up to one
	if _saving_for_library(me):
		return _hands_for(me, hands, game.BUILDINGS["library"]["cost"])
	# the next study's price is being put by instead of spent on one more club
	# so is a forge's, once the first study is in
	if _saving_for_forge(me):
		return _hands_for(me, hands, game.BUILDINGS["forge"]["cost"])
	if _saving_for_study(me):
		return _hands_for(me, hands, PlayerState.RESEARCH[_next_study(me)]["cost"])
	# once there is an army or a library, somebody starts on the gold it will want
	if (attacking or wave_size > int(plan["first_wave"]) or me.library() != null) and _wants_gold(me) \
			and hands["gold"] < int(plan["gold_hands"]):
		return TRADE_KIND["gold"]
	# short of what a soldier costs: more hands on that, rather than waiting on
	# a trickle for ever while the other store piles up
	var price := me.draft_price(soldier)
	for resource in price:
		if me.economy.amount(resource) < int(price[resource]) \
				and full.has(resource) and hands[resource] < full[resource]:
			return TRADE_KIND[resource]
	# then soldiers, as long as the next wave is not yet up to strength --
	# counting the ones already on order, on their way from the forge
	if _at_home(me).size() + _coming(me) < wave_size:
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
	return _time_for_library(me) and not me.economy.can_afford(game.BUILDINGS["library"]["cost"])

## Something to learn, enough hands at work, and no library yet -- and for a
## head that means to strike first (`library_after_wave`), its first wave out.
func _time_for_library(me: PlayerState) -> bool:
	if (plan["studies"] as Array).is_empty() or me.has_library_site() or not me.has_barracks_site():
		return false
	if me.workers().size() < int(plan["library_after"]):
		return false
	return not bool(plan.get("library_after_wave", false)) or attacking or wave_size > int(plan["first_wave"])

## Kept under its old name too, for anything that asked it.
func _saving_for_chivalry(me: PlayerState) -> bool:
	return _saving_for_study(me)

## A forge comes after the first study -- every soldier past the warrior
## carries arms made there -- and is put by for like one.
func _wants_forge(me: PlayerState) -> bool:
	return me.library() != null and not me.researched.is_empty() and not me.has_forge_site()

func _saving_for_forge(me: PlayerState) -> bool:
	return _wants_forge(me) and not me.economy.can_afford(game.BUILDINGS["forge"]["cost"])

func _saving_for_study(me: PlayerState) -> bool:
	if _saving_for_forge(me):
		return false
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
	# a barracks before anything: without it there is no army at all
	if not me.has_barracks_site():
		if me.workers().size() >= _first_hands() and me.economy.can_afford(game.BUILDINGS["barracks"]["cost"]):
			_build_near(me, "barracks", 230.0)
		return
	if _time_for_library(me):
		_build_near(me, "library", 420.0)
		return
	# then a forge, after the first study
	if _wants_forge(me) and me.economy.can_afford(game.BUILDINGS["forge"]["cost"]):
		_build_near(me, "forge", 300.0)
		return
	var towers := _towers(me)
	if _wants_towers(me):
		# the first two either side of the way in, any more out in front of them
		_build_near(me, "tower", 540.0 + 110.0 * float(towers / 2))

## Towers it means to have and has not put up yet: a cautious head wants them
## as soon as the library stands, the rest once there is an army to spare.
func _wants_towers(me: PlayerState) -> bool:
	var time_for_towers: bool = me.library() != null \
		and (bool(plan["towers_early"]) or wave_size > int(plan["first_wave"]))
	return time_for_towers and _towers(me) < int(plan["towers"])

## Kit for the ranks in the order its plan likes,
## one piece a thought -- only what somebody could wear, and never out of a
## price being put by, nor out of towers still to be put up -- and with the
## forge idle and the store full, a few weapons made ahead for the next wave.
func _arm(me: PlayerState) -> void:
	# smiths come to the anvils by themselves when there is work (PlayerState)
	var smithy := me.forge()
	if smithy == null or smithy.all_pending().size() >= 2 or _saving_for_library(me) or _saving_for_study(me) \
			or _wants_towers(me):
		return
	for item in plan["gear"]:
		if me.short_of(item) > me.spare(item) + me.pending(item):
			if game.forge(team, item):
				return
	# arms ahead, for the kind it will want next, while it can afford two of him
	var next := _soldier_kind(me)
	if smithy.all_pending().is_empty() and me.economy.can_afford(_twice(me.draft_price(next))):
		for item in ProductionBuilding.CATALOG[next].get("arms", []):
			if Forge.GEAR.has(item) and me.spare(item) < STOCK:
				game.forge(team, item)
				return

## How many of each weapon it likes to keep made ahead.
const STOCK := 2

static func _twice(price: Dictionary) -> Dictionary:
	var double := {}
	for resource in price:
		double[resource] = int(price[resource]) * 2
	return double

## Soldiers on order or training: on their way to the ranks.
func _coming(me: PlayerState) -> int:
	var barracks := me.barracks()
	return me.drafts.size() + (barracks.queue.size() if barracks != null else 0)

## A hand goes round with a hammer while anything of ours is hurt, and back
## to its trade once all is mended.
const MEND_WOOD := 30          ## wood it keeps for mending before it bothers

func _mend(me: PlayerState) -> void:
	var at_it := me.repairers().size()
	if me.anything_to_repair() and me.economy.wood >= MEND_WOOD:
		if at_it == 0 and me.workers().size() > _first_hands():
			game.assign_repairer(team)
	elif at_it > 0:
		game.release_repairer(team)

## Labourers are all alike, so a store piling up while the other runs dry
## is put right by moving a hand across, rather than by hiring another.
const GLUT := 80               ## how far ahead one store has to be

func _rebalance(me: PlayerState) -> void:
	var count := me.hands()
	var e := me.economy
	if e.ore > e.wood + GLUT and int(count["ore"]) > 1:
		game.assign_worker(team, "wood")
	elif e.wood > e.ore + GLUT and int(count["wood"]) > 1:
		game.assign_worker(team, "ore")

## How many hands its plan puts to work before anything else.
func _first_hands() -> int:
	var total := 0
	for trade in plan["workers_first"]:
		total += int(plan["workers_first"][trade])
	return total

func _towers(me: PlayerState) -> int:
	var count := 0
	for building in me.buildings:
		if building is Tower and is_instance_valid(building) and building.is_alive():
			count += 1
	return count

## Tries a handful of spots out towards the field, `ahead` from the castle.
## Tries a handful of spots out towards the field, about `ahead` from the
## castle, starting where this head likes that kind of building (`_vary`).
func _build_near(me: PlayerState, kind: String, ahead: float) -> bool:
	var keep := me.base()
	if keep == null:
		return false
	var toward := 1.0 if keep.global_position.x < _field_middle() else -1.0
	var habit: Vector2 = sites.get(kind, Vector2.ZERO)
	# the rows nearest the one it likes first, then out from there
	var rows := [-170.0, -90.0, 0.0, 90.0, 170.0]
	rows.sort_custom(func(a: float, b: float) -> bool: return absf(a - habit.y) < absf(b - habit.y))
	# and if nothing near will do (a forge wants room for its anvils), further out
	for further in [0.0, 150.0, 300.0]:
		for dy in rows:
			for dx in [0.0, 60.0, -60.0, 120.0, -120.0]:
				var spot := keep.global_position + Vector2(toward * (ahead + further + habit.x + dx), dy)
				if _in_the_way(kind, spot):
					continue
				if game.build_problem(team, kind, spot) == "":
					return game.build(team, kind, spot)
	return false

## Nothing goes up close by its own stockpile: every load of wood and ore is
## carried in there, and a building on the way jams the carriers at its corner.
const STOCK_CLEAR := 150.0

func _in_the_way(kind: String, spot: Vector2) -> bool:
	var half: Vector2 = game.footprint_of(kind) * 0.5
	var area := Rect2(spot - half, half * 2.0)
	for node in get_tree().get_nodes_in_group("stockpiles"):
		var pile := node as Stockpile
		if pile != null and pile.team == team and game._gap(area, pile.global_position) < STOCK_CLEAR:
			return true
	return false

# --- its own habits -----------------------------------------------------------

var rng := RandomNumberGenerator.new()
## Where it likes each kind of building: x further out (+) or nearer in, and
## the row (y) it tries first.
var sites := {}

## Rolls this head's habits for the match, within what its strategy allows.
func _vary() -> void:
	for kind in ["barracks", "library", "forge", "tower"]:
		sites[kind] = Vector2(rng.randf_range(-50.0, 90.0), [-170.0, -90.0, 0.0, 90.0, 170.0][rng.randi() % 5])
	# studies: a few neighbours swapped, never one before what it needs, and
	# never one that costs gold past one that does not -- a head that starts on
	# a gold study stands waiting for gold and spends everything else on clubs
	var studies: Array = (plan["studies"] as Array).duplicate()
	for i in studies.size() - 1:
		if _costs_gold(studies[i]) != _costs_gold(studies[i + 1]):
			continue
		if rng.randf() < 0.4:
			var swapped := studies.duplicate()
			var held = swapped[i]
			swapped[i] = swapped[i + 1]
			swapped[i + 1] = held
			if _in_order(swapped):
				studies = swapped
	plan["studies"] = studies
	# how much it favours each kind of soldier
	for kind in plan["mix"]:
		plan["mix"][kind] = float(plan["mix"][kind]) * rng.randf_range(0.6, 1.4)
	# which trade it leans on
	var lean: String = ["wood", "ore"][rng.randi() % 2]
	plan["workers_full"][lean] = int(plan["workers_full"][lean]) + rng.randi_range(0, 1)
	plan["first_wave"] = maxi(2, int(plan["first_wave"]) + rng.randi_range(-1, 1))
	if float(plan["attack_after"]) > 0.0:
		plan["attack_after"] = float(plan["attack_after"]) * rng.randf_range(0.85, 1.2)
	if int(plan["towers"]) >= 2:
		plan["towers"] = int(plan["towers"]) + rng.randi_range(-1, 1)
	var gear: Array = (plan["gear"] as Array).duplicate()
	for i in range(gear.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held = gear[i]
		gear[i] = gear[j]
		gear[j] = held
	plan["gear"] = gear

static func _costs_gold(study: String) -> bool:
	return PlayerState.RESEARCH[study]["cost"].has("gold")

## Whether every study in `order` comes after the one it needs, if that is there.
static func _in_order(order: Array) -> bool:
	for i in order.size():
		var needs: String = PlayerState.RESEARCH[order[i]].get("needs", "")
		if needs != "" and order.has(needs) and order.find(needs) > i:
			return false
	return true

func _field_middle() -> float:
	var foe: PlayerState = game.enemy_of(team)
	var me: PlayerState = game.side(team)
	if foe == null or me == null or foe.base() == null or me.base() == null:
		return 0.0
	return (foe.base().global_position.x + me.base().global_position.x) * 0.5

## The soldier its army is shortest of, going by the mix its plan likes, of those
## it knows how to field -- and can arm: without a forge only clubs; clubs also
## if the plan wants them or nothing better is open.
func _soldier_kind(me: PlayerState) -> String:
	var barracks := me.barracks()
	if barracks == null:
		return "warrior"
	var have := {}
	for unit in me.squad.alive():
		have[unit.loadout] = int(have.get(unit.loadout, 0)) + 1
	for kind in barracks.queue:
		have[kind] = int(have.get(kind, 0)) + 1
	for draft in me.drafts:
		have[draft.kind] = int(have.get(draft.kind, 0)) + 1
	var armed := me.forge() != null
	var mix: Dictionary = plan["mix"]
	var best := "warrior"
	var best_share := INF
	for kind in mix:
		if not me.kind_unlocked(kind):
			continue
		if not armed and not me.missing_for(kind).is_empty():
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
	var keep := me.base()
	if keep != null:
		for kind in keep.queue:
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
		# it takes a moment to notice, and to call the men out
		if intruder_since < 0.0:
			intruder_since = game.match_time
		if game.match_time - intruder_since < float(plan.get("react", 0.0)):
			return false
		defending = true
		game.attack_move(team, intruder.global_position)
		return true
	intruder_since = -1.0
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

## A bandit camp on our half of the field is cleared as soon as there are men
## enough at home for it -- half as many again as it has bandits, and never
## fewer than four -- for its chest and for the ground it guards.
var raiding: BanditCamp = null
const RAID_MIN := 4
const RAID_SHARE := 1.5

## True while the army is out after a camp.
func _raid_camps(me: PlayerState) -> bool:
	if raiding != null:
		if not is_instance_valid(raiding) or not raiding.is_guarded():
			raiding = null
			game.rally_home(team)
			return false
		game.attack_move(team, raiding.global_position)
		return true
	var camp := _camp_to_clear(me)
	if camp == null:
		return false
	var ready := _at_home(me).size()
	if ready >= maxi(RAID_MIN, ceili(camp.alive() * RAID_SHARE)):
		raiding = camp
		game.attack_move(team, camp.global_position)
		return true
	return false

## The nearest camp still guarded that lies nearer our keep than theirs.
func _camp_to_clear(me: PlayerState) -> BanditCamp:
	var keep := me.base()
	var foe: PlayerState = game.enemy_of(team)
	if keep == null:
		return null
	var best: BanditCamp = null
	for node in get_tree().get_nodes_in_group("camps"):
		var camp := node as BanditCamp
		if camp == null or not camp.is_guarded():
			continue
		var ours := camp.global_position.distance_to(keep.global_position)
		if foe != null and foe.base() != null and ours > camp.global_position.distance_to(foe.base().global_position):
			continue
		if best == null or ours < best.global_position.distance_to(keep.global_position):
			best = camp
	return best

func _wage_war(me: PlayerState) -> void:
	if not attacking and _raid_camps(me):
		return
	if attacking:
		if _wave_left() <= int(plan["spent_at"]):
			# spent -- though it takes a while to see it and sound the retreat
			if spent_since < 0.0:
				spent_since = game.match_time
			if game.match_time - spent_since < float(plan.get("retreat", 0.0)):
				return
			spent_since = -1.0
			# bring back whoever is left, and make the next one bigger
			attacking = false
			wave.clear()
			wave_size = mini(wave_size + int(plan["wave_growth"]), int(plan["wave_max"]))
			game.rally_home(team)
		return
	var ready := _at_home(me)
	if ready.size() >= wave_size and _may_attack(me):
		# a wave is mustered before it goes
		if ready_since < 0.0:
			ready_since = game.match_time
		if game.match_time - ready_since >= float(plan.get("muster", 0.0)):
			ready_since = -1.0
			_launch(ready)
	else:
		ready_since = -1.0

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
