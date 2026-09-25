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
	"chivalry": {"title": "Рыцарство", "about": "Открывает найм рыцарей: латы, меч и щит.",
		"cost": {"ore": 60, "gold": 40}, "time": 30.0},
	"forging": {"title": "Кузнечное дело", "about": "+25% к урону всех воинов, и тех, что уже в строю.",
		"cost": {"ore": 80, "wood": 40}, "time": 25.0, "harm": 1.25},
	"mail": {"title": "Кольчуга", "about": "+25% к здоровью всех воинов, и тех, что уже в строю.",
		"cost": {"ore": 60, "gold": 20}, "time": 25.0, "health": 1.25},
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
		and library() != null and economy.can_afford(RESEARCH[id]["cost"])

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

## A building put up in the match becomes ours to use.
func adopt(building: Building) -> void:
	building.side = self
	if not buildings.has(building):
		buildings.append(building)

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
		if building is ProductionBuilding and is_instance_valid(building) and building.is_alive():
			return building
	return null

## Our labourers still on their feet.
func workers() -> Array[Worker]:
	var hands: Array[Worker] = []
	for node in get_tree().get_nodes_in_group("workers"):
		var hand := node as Worker
		if hand != null and hand.team == team and hand.is_alive():
			hands.append(hand)
	return hands

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
