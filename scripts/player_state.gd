class_name PlayerState
extends Node
## Everything one side owns: its store, its army, its buildings. Only this side
## changes any of it; the other side learns about it the way anyone would, by
## looking at what is standing on the field.

@export var team: int = Team.Id.PLAYER

var economy := Economy.new()
var squad := Squad.new()
var buildings: Array[Building] = []

signal research_done(id: String)
signal research_lost(id: String)

## What can be learned, what it costs, how long it takes and what it gives. One
## study at a time, and only in a finished library (Library).
const RESEARCH := {
	"spears": {"title": "Копья", "about": "Кузница учится ковать оружие для копейщиков.",
		"cost": {"wood": 40, "ore": 30}, "time": 20.0},
	"archery": {"title": "Луки", "about": "Кузница учится ковать оружие для лучников: бьют издалека, но хрупкие.",
		"cost": {"wood": 60, "ore": 20}, "time": 25.0},
	"crossbows": {"title": "Арбалеты", "about": "Кузница учится ковать оружие для арбалетчиков: бьют сильнее и дальше лука, но медленно перезаряжают.",
		"cost": {"ore": 60, "gold": 20}, "time": 25.0, "needs": "archery"},
	"chivalry": {"title": "Рыцарство", "about": "Учит ковать рыцарский комплект: меч, щит, шлем и латы. Открывает рыцарей.",
		"cost": {"ore": 60, "gold": 40}, "time": 30.0},
	"forging": {"title": "Кузнечное дело", "about": "+25% к урону всех воинов, и тех, что уже в строю.",
		"cost": {"ore": 80, "wood": 40}, "time": 25.0, "harm": 1.25},
	"mail": {"title": "Кольчуга", "about": "+25% к здоровью всех воинов, и тех, что уже в строю.",
		"cost": {"ore": 60, "gold": 20}, "time": 25.0, "health": 1.25},
	"axes": {"title": "Секиры", "about": "Кузница учится ковать оружие для секироносцев: рубят сильно и ломают стены в полтора раза быстрее.",
		"cost": {"wood": 50, "ore": 20}, "time": 20.0},
	"blades": {"title": "Клинки", "about": "Кузница учится ковать оружие для мечников: крепкие и ровные бойцы в шлемах.",
		"cost": {"wood": 40, "ore": 50}, "time": 25.0},
	"greatswords": {"title": "Двуручные мечи", "about": "Кузница учится ковать оружие для двуручников: самый тяжёлый удар в игре, но медленный и утомительный.",
		"cost": {"ore": 80, "gold": 30}, "time": 30.0, "needs": "blades"},
	"daggers": {"title": "Кинжалы", "about": "Кузница учится ковать оружие для лазутчиков: быстрые и дешёвые, охотятся на рабочих.",
		"cost": {"wood": 50}, "time": 15.0},
	"fire": {"title": "Поджог", "about": "Кузница учится ковать оружие для поджигателей: слабы в бою, но жгут постройки вчетверо быстрее.",
		"cost": {"wood": 60, "ore": 20}, "time": 20.0},
	"magic": {"title": "Магия", "about": "Кузница учится ковать оружие для магов: посох бьёт молнией издалека и сильнее арбалета.",
		"cost": {"ore": 60, "gold": 50}, "time": 35.0},
	"healing": {"title": "Исцеление", "about": "Маги лечат своих: вне боя всех раненых, в бою — только тех, кто при смерти.",
		"cost": {"ore": 40, "gold": 40}, "time": 25.0, "needs": "magic"},
}

var researched := {}          ## id -> true
var researching := ""         ## the study under way, "" for none
var research_left := 0.0
## What everything learned so far does to our soldiers' blows and constitution.
var harm_scale := 1.0
var health_scale := 1.0
var _claimed := false

func _ready() -> void:
	add_to_group("player_states")
	squad.name = "Squad"
	add_child(squad)
	# the map puts its pieces down in its own _ready; take ours once it has
	_claim_field.call_deferred()

## Stockpiles bank into our store, and soldiers already on the field join the ranks.
func _claim_field() -> void:
	if _claimed:
		return
	_claimed = true
	for node in get_tree().get_nodes_in_group("stockpiles"):
		var pile := node as Stockpile
		if pile != null and pile.team == team:
			pile.economy = economy
	for node in get_tree().get_nodes_in_group("targets"):
		var unit := node as Unit
		if unit != null and unit.team == team:
			squad.add(unit)
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Building
		if building != null and building.team == team:
			building.side = self
			buildings.append(building)

func has_researched(id: String) -> bool:
	return researched.has(id)

func can_research(id: String) -> bool:
	return RESEARCH.has(id) and not researched.has(id) and researching == "" \
		and library() != null and prerequisite_met(id) and economy.can_afford(RESEARCH[id]["cost"])

## Whether whatever it builds on has been learned first.
func prerequisite_met(id: String) -> bool:
	var needs: String = RESEARCH[id].get("needs", "")
	return needs == "" or researched.has(needs)

## Pays and starts it. False, and nothing taken, if it can not be started.
func start_research(id: String) -> bool:
	if not can_research(id) or not economy.spend(RESEARCH[id]["cost"]):
		return false
	researching = id
	research_left = float(RESEARCH[id]["time"])
	return true

## How far through the current study, 0 to 1.
func research_share() -> float:
	if researching == "":
		return 0.0
	var total: float = RESEARCH[researching]["time"]
	return clampf(1.0 - research_left / total, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	_supply_left -= delta
	if _supply_left <= 0.0:
		_supply_left = SUPPLY_EVERY
		_supply()
	if researching == "":
		return
	# the scholars and their notes go with the building
	if library() == null:
		var lost := researching
		researching = ""
		research_lost.emit(lost)
		return
	research_left -= delta
	if research_left <= 0.0:
		var done := researching
		researched[done] = true
		researching = ""
		_apply(done)
		research_done.emit(done)

func _apply(id: String) -> void:
	var entry: Dictionary = RESEARCH[id]
	harm_scale *= float(entry.get("harm", 1.0))
	health_scale *= float(entry.get("health", 1.0))
	# the ones already in the ranks get it too
	for unit in squad.alive():
		kit_out(unit)

## Brings a soldier up to everything learned so far.
func kit_out(unit: Unit) -> void:
	unit.set_scales(harm_scale, health_scale)
	unit.set_mending(has_researched("healing"))
	_fit_gear(unit)

# --- the forge's store ----------------------------------------------------------

## Pieces made and not yet taken or worn: item -> how many (every Forge.GEAR item).
var gear := _empty_store()

static func _empty_store() -> Dictionary:
	var store := {}
	for item in Forge.GEAR:
		store[item] = 0
	return store

## A piece off an anvil into the store. Kit nobody has on order goes straight
## onto whoever lacks it, nearest the forge first; weapons wait for recruits.
func receive_gear(item: String) -> void:
	gear[item] = int(gear.get(item, 0)) + 1
	if not Forge.KIT.has(item):
		return
	var from := forge().global_position if forge() != null else Vector2.ZERO
	var ranks := squad.alive()
	ranks.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	for unit in ranks:
		if spare(item) <= 0:
			return
		_fit_gear(unit)

func _fit_gear(unit: Unit) -> void:
	for item in Forge.KIT:
		if spare(item) > 0 and unit.can_wear(item):
			unit.wear(item)
			gear[item] = int(gear[item]) - 1

## Pieces in store that no order has put by.
func spare(item: String) -> int:
	return int(gear.get(item, 0)) - reserved(item)

## How many soldiers in the ranks could still use one.
func short_of(item: String) -> int:
	var count := 0
	for unit in squad.alive():
		if unit.can_wear(item):
			count += 1
	return count

## Whether `item` may be made: kit always, a weapon once some soldier who
## carries it can be fielded.
func knows_recipe(item: String) -> bool:
	if Forge.KIT.has(item):
		return true
	for kind in ProductionBuilding.SOLDIERS:
		if ProductionBuilding.CATALOG[kind].get("arms", []).has(item) and kind_unlocked(kind):
			return true
	return false

## Whether this side knows how to field `kind` at all, whatever it can afford.
func kind_unlocked(kind: String) -> bool:
	var needs: String = ProductionBuilding.CATALOG[kind].get("requires", "")
	return needs == "" or has_researched(needs)

## Our finished forge, if one is standing (the first of them).
func forge() -> Forge:
	var all := forges()
	return all[0] if not all.is_empty() else null

## Every finished forge of ours still standing.
func forges() -> Array[Forge]:
	_claim_field()
	var found: Array[Forge] = []
	for building in buildings:
		if building is Forge and is_instance_valid(building) and building.is_alive() and building.is_complete():
			found.append(building)
	return found

## Of `item`, how many are on a list or an anvil in any of our forges.
func pending(item: String) -> int:
	var count := 0
	for smithy in forges():
		count += smithy.pending(item)
	return count

## The forge with the shortest list, for the next piece.
func least_busy_forge() -> Forge:
	var best: Forge = null
	for smithy in forges():
		if best == null or smithy.all_pending().size() < best.all_pending().size():
			best = smithy
	return best

## Orders a piece by hand, at the forge with the shortest list.
func order_gear(item: String) -> bool:
	var smithy := least_busy_forge()
	return smithy != null and smithy.queue_gear(item)

# --- smiths ---------------------------------------------------------------------

## The hands at our anvils.
func smiths() -> Array[Worker]:
	var found: Array[Worker] = []
	for hand in workers():
		if hand.is_smith():
			found.append(hand)
	return found

## The first of them, if there is one.
func smith() -> Worker:
	var all := smiths()
	return all[0] if not all.is_empty() else null

## An anvil in a finished forge with nobody at it: [forge, index], or [] for none.
func free_anvil() -> Array:
	var at := smiths()
	for smithy in forges():
		for i in Forge.ANVILS.size():
			var taken := false
			for hand in at:
				if hand.smithy == smithy and hand.anvil == i:
					taken = true
			if not taken:
				return [smithy, i]
	return []

## Puts a labourer to a free anvil: from whichever of wood and ore has the
## most hands, the one nearest the forge. False if there is no free anvil or
## nobody to spare.
func assign_smith() -> bool:
	var spot := free_anvil()
	if spot.is_empty():
		return false
	var smithy: Forge = spot[0]
	var counts := hands()
	var best: Worker = null
	var best_score := INF
	for hand in workers():
		if not TRADES.has(hand.job):
			continue
		# the trade with the most hands gives one up first; gold is scarce
		var score := hand.global_position.distance_to(smithy.global_position) - 10000.0 * float(counts[hand.job])
		if hand.job == "gold":
			score += 100000.0
		if score < best_score:
			best_score = score
			best = hand
	if best == null:
		return false
	best.set_job("smith")
	best.smithy = smithy
	best.anvil = spot[1]
	return true

## Sends a smith back to what it did before: the last one put to an anvil.
func release_smith() -> bool:
	var all := smiths()
	if all.is_empty():
		return false
	var hand: Worker = all[all.size() - 1]
	hand.set_job(hand.former_job if hand.former_job != "" else "wood")
	return true

func has_forge_site() -> bool:
	return forge_sites() > 0

## Forges of ours standing or going up.
func forge_sites() -> int:
	var count := 0
	for building in buildings:
		if building is Forge and is_instance_valid(building) and building.is_alive():
			count += 1
	return count

# --- soldiers on order --------------------------------------------------------

## Orders under way: a recruit is hired for each, collects the arms it needs
## from the forge and takes them to the barracks to train (Draft).
var drafts: Array[Draft] = []
const DRAFT_MAX := 10
const SUPPLY_EVERY := 0.5
var _supply_left := 0.0

## Of `item`, how many the orders still waiting for their arms have put by.
func reserved(item: String) -> int:
	var count := 0
	for draft in drafts:
		if draft.stage != Draft.Stage.CARRYING:
			count += draft.needs.count(item)
	return count

## The pieces an order for `kind` placed now would have to have made: what is
## neither in the store nor on its way without being put by already.
func missing_for(kind: String) -> Array[String]:
	var missing: Array[String] = []
	var counted := {}
	for item in ProductionBuilding.CATALOG[kind].get("arms", []):
		if not Forge.GEAR.has(item):
			continue
		counted[item] = int(counted.get(item, 0)) + 1
		var free := int(gear[item]) + pending(item) - reserved(item)
		if int(counted[item]) > free:
			missing.append(item)
	return missing

## What ordering one `kind` costs right now: the man, and whatever of his arms
## has still to be made.
func draft_price(kind: String) -> Dictionary:
	var price := {}
	var keep := base()
	var man: Dictionary = keep.price_for("recruit") if keep != null else ProductionBuilding.CATALOG["recruit"]["cost"]
	for resource in man:
		price[resource] = int(price.get(resource, 0)) + int(man[resource])
	for item in missing_for(kind):
		var cost: Dictionary = Forge.GEAR[item]["cost"]
		for resource in cost:
			price[resource] = int(price.get(resource, 0)) + int(cost[resource])
	return price

## Why `kind` can not be ordered now, or "" if it can.
func order_problem(kind: String) -> String:
	if not ProductionBuilding.SOLDIERS.has(kind):
		return "Нельзя"
	if not kind_unlocked(kind):
		return "Нужно: %s" % RESEARCH[ProductionBuilding.CATALOG[kind]["requires"]]["title"]
	var keep := base()
	if keep == null or not keep.is_alive():
		return "Нет замка"
	if barracks() == null:
		return "Нет казармы"
	if not barracks().is_complete():
		return "Казарма строится"
	if drafts.size() >= DRAFT_MAX:
		return "Слишком много заказов"
	if not missing_for(kind).is_empty() and forges().is_empty():
		return "Нет кузницы"
	if not economy.can_afford(draft_price(kind)):
		return "Недостаточно ресурсов"
	return ""

## Orders one soldier: pays for the man and for whatever arms are missing,
## puts those on the forge's list and the man on the castle's. False, and
## nothing taken, if it can not.
func order_soldier(kind: String) -> bool:
	if order_problem(kind) != "":
		return false
	var missing := missing_for(kind)
	if not economy.spend(draft_price(kind)):
		return false
	for item in missing:
		least_busy_forge().queue_paid(item)
	base().queue_paid("recruit")
	drafts.append(Draft.new(self, kind))
	return true

## How many orders for `kind` are under way (not yet in training).
func drafts_of(kind: String) -> int:
	var count := 0
	for draft in drafts:
		if draft.kind == kind:
			count += 1
	return count

## A man the castle has turned out for an order: the oldest order still
## waiting for one gets him. With none waiting he becomes a labourer.
func take_recruit(man: Worker) -> void:
	for draft in drafts:
		if draft.man == null:
			draft.man = man
			draft.stage = Draft.Stage.CARRYING if draft.needs.is_empty() else Draft.Stage.ARMING
			man.draft = draft
			man._take_tools()
			man.died.connect(_on_recruit_died.bind(draft), CONNECT_ONE_SHOT)
			return
	man.set_job(least_staffed_job())

## The man is lost, and his order with him; whatever he had not collected yet
## stays in the store for the next.
func _on_recruit_died(_body: PlayerBody, draft: Draft) -> void:
	drafts.erase(draft)

## Where a recruit waits for his arms: the nearest finished forge, or the
## castle gate while there is none.
func collect_point(man: Worker) -> Vector2:
	var slot := maxi(0, drafts.find(man.draft))
	var best := Vector2.INF
	for smithy in forges():
		var spot := smithy.collect_point(slot)
		if best == Vector2.INF or man.global_position.distance_squared_to(spot) < man.global_position.distance_squared_to(best):
			best = spot
	if best == Vector2.INF and base() != null:
		best = base().door_point() + Vector2(float(slot % 5 - 2) * 16.0, 40.0)
	return best

## A recruit at the forge takes his pieces, if every one of them is in store.
func hand_out_arms(draft: Draft) -> bool:
	if draft.stage != Draft.Stage.ARMING:
		return draft.stage == Draft.Stage.CARRYING
	for item in draft.needs:
		if int(gear[item]) < draft.needs.count(item):
			return false
	for item in draft.needs:
		gear[item] = int(gear[item]) - 1
	draft.stage = Draft.Stage.CARRYING
	return true

## An armed recruit at the barracks door goes in to train; his order is done.
func send_to_train(draft: Draft, barracks: ProductionBuilding) -> void:
	drafts.erase(draft)
	barracks.train(draft.kind)
	if draft.man != null and is_instance_valid(draft.man):
		draft.man.queue_free()

## Orders whose pieces were lost with a forge have them made again, paid for
## again, as soon as there is a forge and the price of them.
func _supply() -> void:
	if drafts.is_empty() or forges().is_empty():
		return
	for item in Forge.GEAR:
		var short := reserved(item) - int(gear[item]) - pending(item)
		while short > 0 and economy.spend(Forge.GEAR[item]["cost"]):
			least_busy_forge().queue_paid(item)
			short -= 1

## A building put up in the match becomes ours to use.
func adopt(building: Building) -> void:
	building.side = self
	if not buildings.has(building):
		buildings.append(building)
	# a new barracks sends its recruits where the side has asked for them
	if building is ProductionBuilding and not (building is Base) and rally_point != Vector2.INF:
		building.set_rally_point(rally_point)

## Our finished library, if one is standing.
func library() -> Library:
	_claim_field()
	for building in buildings:
		if building is Library and is_instance_valid(building) and building.is_alive() and building.is_complete():
			return building
	return null

## Any library of ours at all, finished or still going up.
func has_library_site() -> bool:
	for building in buildings:
		if building is Library and is_instance_valid(building) and building.is_alive():
			return true
	return false

## Our first production building still standing, if any: where hiring happens.
func barracks() -> ProductionBuilding:
	_claim_field()
	for building in buildings:
		if building is ProductionBuilding and not (building is Base) and is_instance_valid(building) and building.is_alive():
			return building
	return null

## A barracks standing or going up.
func has_barracks_site() -> bool:
	return barracks() != null

## Where hiring `kind` happens: labourers at the castle, soldiers in the barracks.
func producer_for(kind: String) -> ProductionBuilding:
	if not ProductionBuilding.CATALOG.has(kind):
		return null
	return base() if ProductionBuilding.CATALOG[kind].has("job") else barracks()

## Where hired soldiers go and stand; the barracks takes it over once built.
var rally_point := Vector2.INF

# --- labourers ----------------------------------------------------------------

const TRADES := ["wood", "ore", "gold"]

## How many hands on each trade (and at the anvil).
func hands() -> Dictionary:
	var count := {"wood": 0, "ore": 0, "gold": 0, "smith": 0}
	for hand in workers():
		count[hand.job] = int(count.get(hand.job, 0)) + 1
	return count

## A new hand goes where it is most wanted: whichever of wood and ore has fewer.
func least_staffed_job() -> String:
	var count := hands()
	return "ore" if int(count["ore"]) < int(count["wood"]) else "wood"

## Moves one labourer onto `job`: from whichever other trade has the most
## hands, the one nearest the castle. False if there is nobody to move.
func move_worker(job: String) -> bool:
	if not TRADES.has(job):
		return false
	var count := hands()
	var from := ""
	for trade in TRADES:
		if trade != job and int(count[trade]) > 0 and (from == "" or int(count[trade]) > int(count[from])):
			from = trade
	if from == "":
		return false
	var home := base().global_position if base() != null else Vector2.ZERO
	var best: Worker = null
	for hand in workers():
		if hand.job == from and (best == null or hand.global_position.distance_squared_to(home) < best.global_position.distance_squared_to(home)):
			best = hand
	best.set_job(job)
	return true

## Our labourers (and smiths) still on their feet.
func workers() -> Array[Worker]:
	var found: Array[Worker] = []
	for node in get_tree().get_nodes_in_group("workers"):
		var hand := node as Worker
		# a recruit on his way to be a soldier is no labourer
		if hand != null and hand.team == team and hand.is_alive() and hand.job != "recruit":
			found.append(hand)
	return found

func base() -> Base:
	_claim_field()
	for building in buildings:
		if building is Base:
			return building
	return null

## The side's state, looked up by team: for the few things that need it and are
## not handed it directly.
static func of_team(tree: SceneTree, side: int) -> PlayerState:
	for node in tree.get_nodes_in_group("player_states"):
		if (node as PlayerState).team == side:
			return node
	return null
