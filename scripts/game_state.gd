extends Node
## The match as a whole, and the one place the menu and the HUD talk to (autoload
## `GameState`). It knows which map is being played, which side is whose, and
## whether anyone has won yet.
##
## It is also the whole command vocabulary a side has: hire, send the army,
## call it back. Every one takes the side's team and plain values -- a string,
## a point -- never a node, so it does not matter who is asking: the HUD for
## the human, the director for the AI, one day a message from another machine.

signal match_started
signal match_ended(winner: int)

enum Phase { MENU, PLAYING, WON, LOST }

const SKIRMISH_SCENE := "res://scenes/main/Skirmish.tscn"
const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const TESTBED_SCENE := "res://scenes/main/Main.tscn"
const DEFAULT_MAP := "res://resources/maps/skirmish_long.tres"

## What a side can put up in the field, what it costs and how long it takes.
const BUILDINGS := {
	"tower": {"title": "Башня", "about": "Стреляет по врагам вокруг. Хороша у ворот и у рудников.",
		"cost": {"wood": 40, "ore": 30}, "time": 20.0},
	"library": {"title": "Библиотека", "about": "Здесь изучают технологии: новых воинов и улучшения. Одна на сторону.",
		"cost": {"wood": 60, "ore": 20}, "time": 25.0, "limit": 1},
	"barracks": {"title": "Казарма", "about": "Здесь нанимают солдат. Без неё армии не будет. Одна на сторону.",
		"cost": {"wood": 40, "ore": 10}, "time": 20.0, "limit": 1},
	"forge": {"title": "Кузница", "about": "Куёт оружие для новобранцев, а ещё шлемы, латы и щиты. Две наковальни — два кузнеца. Не больше двух на сторону.",
		"cost": {"wood": 50, "ore": 40}, "time": 25.0, "limit": 2},
}
const BUILD_RANGE := 700.0     ## how far from its own buildings a side may build
const CLEARANCE := 18.0        ## room left between one building and the next

signal built(team: int, kind: String, building: Building)

## The map the next match is built from. Opening Skirmish.tscn directly (F6)
## leaves this empty and the scene uses its own.
var map: MapData
var phase := Phase.MENU
var human_team: int = Team.Id.PLAYER
## Both sides run by AIDirectors, and the human only watches.
var spectating := false
var winner: int = Team.Id.NEUTRAL
## Team -> PlayerState, for the match being played.
var states := {}
## How the enemy's head plays the next match (AIProfile): its strategy, or
## "random", and its difficulty. In AI against AI both sides pick at random.
var ai_strategy := "random"
var ai_difficulty := "normal"
## Seconds of play in the current match; stops while paused.
var match_time := 0.0

# --- the match ----------------------------------------------------------------

func start_match(map_path: String = DEFAULT_MAP, watch_only := false) -> void:
	map = load(map_path) as MapData
	spectating = watch_only
	_go_to(SKIRMISH_SCENE)

func restart_match() -> void:
	_go_to(SKIRMISH_SCENE)

func back_to_menu() -> void:
	phase = Phase.MENU
	_go_to(MENU_SCENE)

func open_testbed() -> void:
	phase = Phase.MENU
	_go_to(TESTBED_SCENE)

func _go_to(path: String) -> void:
	# the match being left no longer counts, whatever happened in it
	states.clear()
	if phase == Phase.PLAYING:
		phase = Phase.MENU
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)

func team_name(team: int) -> String:
	match team:
		Team.Id.PLAYER:
			return "синие"
		Team.Id.ENEMY:
			return "красные"
	return "никто"

## Called by MapBuilder once everything is standing.
func register_match(sides: Dictionary) -> void:
	states = sides.duplicate()
	winner = Team.Id.NEUTRAL
	match_time = 0.0
	phase = Phase.PLAYING
	for team in states:
		var state: PlayerState = states[team]
		var keep := state.base()
		if keep != null:
			keep.base_destroyed.connect(_on_base_destroyed)
		# every side nobody is playing gets a head of its own
		if spectating or team != human_team:
			var director := AIDirector.new()
			director.name = "AIDirector"
			director.strategy = "random" if spectating else ai_strategy
			director.difficulty = ai_difficulty
			state.add_child(director)
	match_started.emit()

func _on_base_destroyed(team: int) -> void:
	if phase != Phase.PLAYING:
		return
	# whoever still has a keep standing has won; with two sides that is the other one
	for other in states:
		if other != team:
			winner = other
	phase = Phase.WON if winner == human_team else Phase.LOST
	get_tree().paused = true
	match_ended.emit(winner)

func _physics_process(delta: float) -> void:
	if phase == Phase.PLAYING:
		match_time += delta

func is_playing() -> bool:
	return phase == Phase.PLAYING

func set_paused(on: bool) -> void:
	if is_playing():
		get_tree().paused = on

func side(team: int) -> PlayerState:
	# untyped on purpose: a side from a match that is being torn down is already
	# freed, and a freed object can not even be put in a typed variable
	var state = states.get(team)
	if state == null or not is_instance_valid(state):
		return null
	return state

func human() -> PlayerState:
	return side(human_team)

## Everyone but us. With two sides, the enemy.
func enemy_of(team: int) -> PlayerState:
	for other in states:
		if other != team:
			return side(other)
	return null

# --- commands -----------------------------------------------------------------

## Hire a labourer at the castle, or order a soldier: a man is hired for him,
## fetches his arms from the forge and trains in the barracks
## (PlayerState.order_soldier).
func hire(team: int, kind: String) -> bool:
	var state := side(team)
	if not is_playing() or state == null:
		return false
	if ProductionBuilding.SOLDIERS.has(kind):
		return state.order_soldier(kind)
	if state.producer_for(kind) == null:
		return false
	return state.producer_for(kind).queue_unit(kind)

## Move one labourer onto a trade: "wood", "ore" or "gold".
func assign_worker(team: int, job: String) -> bool:
	var state := side(team)
	return is_playing() and state != null and state.move_worker(job)

# --- building ---------------------------------------------------------------

static func _make(kind: String) -> Building:
	match kind:
		"tower":
			return Tower.new()
		"library":
			return Library.new()
		"forge":
			return Forge.new()
		"barracks":
			return ProductionBuilding.new()
	return null

static var _footprints := {}

## The ground a kind of building takes up, without putting one down.
static func footprint_of(kind: String) -> Vector2:
	if not _footprints.has(kind):
		var probe := _make(kind)
		_footprints[kind] = probe.footprint if probe != null else Vector2.ZERO
		if probe != null:
			probe.free()
	return _footprints[kind]

## Why `kind` can not go up at `point` for `team`, or "" if it can.
func build_problem(team: int, kind: String, point: Vector2) -> String:
	var state := side(team)
	if not is_playing() or state == null or not BUILDINGS.has(kind):
		return "Нельзя"
	var entry: Dictionary = BUILDINGS[kind]
	if entry.has("limit") and kind == "library" and state.has_library_site():
		return "Библиотека уже есть"
	if entry.has("limit") and kind == "forge" and state.forge_sites() >= int(entry["limit"]):
		return "Уже две кузницы"
	if entry.has("limit") and kind == "barracks" and state.has_barracks_site():
		return "Казарма уже есть"
	var ground := field()
	var half := footprint_of(kind) * 0.5
	if ground == null or point.x < half.x + 20.0 or point.x > ground.map.floor_size.x - half.x - 20.0 \
			or point.y < half.y + 40.0 or point.y > ground.map.floor_size.y - half.y - 12.0:
		return "За краем поля"
	var area := Rect2(point - half, half * 2.0)
	# only near what is already ours
	var near := false
	for building in state.buildings:
		if is_instance_valid(building) and building.is_alive() \
				and building.nearest_point(point).distance_to(point) <= BUILD_RANGE:
			near = true
			break
	if not near:
		return "Слишком далеко от своих построек"
	for node in get_tree().get_nodes_in_group("buildings"):
		var other := node as Building
		if other != null and Rect2(other.global_position - other.footprint * 0.5, other.footprint) \
				.grow(CLEARANCE).intersects(area):
			return "Мешает другая постройка"
	for node in get_tree().get_nodes_in_group("trees"):
		if _gap(area, (node as Node2D).global_position) < 28.0:
			return "Мешают деревья"
	for node in get_tree().get_nodes_in_group("veins"):
		if _gap(area, (node as Node2D).global_position) < 44.0:
			return "Мешает жила"
	for node in get_tree().get_nodes_in_group("boulders"):
		if _gap(area, (node as Node2D).global_position) < (node as Boulder).radius + 8.0:
			return "Мешают скалы"
	for node in get_tree().get_nodes_in_group("stockpiles"):
		if _gap(area, (node as Node2D).global_position) < Stockpile.RADIUS + 10.0:
			return "Мешает склад"
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body != null and body.is_alive() and _gap(area, body.global_position) < 16.0:
			return "Мешают люди"
	if not state.economy.can_afford(entry["cost"]):
		return "Недостаточно ресурсов"
	return ""

static func _gap(area: Rect2, point: Vector2) -> float:
	var nearest := Vector2(clampf(point.x, area.position.x, area.end.x), clampf(point.y, area.position.y, area.end.y))
	return nearest.distance_to(point)

## The map the match is being played on (the node that built it).
func field() -> MapBuilder:
	for team in states:
		var state := side(team)
		if state != null:
			return state.get_parent() as MapBuilder
	return null

## Lays out a site for `kind` at `point` and pays for it. It goes up on its own.
func build(team: int, kind: String, point: Vector2) -> bool:
	if build_problem(team, kind, point) != "":
		return false
	var state := side(team)
	var entry: Dictionary = BUILDINGS[kind]
	if not state.economy.spend(entry["cost"]):
		return false
	var building := _make(kind)
	building.team = team
	building.position = point
	building.start_construction(float(entry["time"]))
	var ground := field()
	ground.add_child(building)
	state.adopt(building)
	# the way round it is worked out again, off the main thread
	var nav := ground.get_node_or_null("NavFloor") as NavFloor
	if nav != null:
		nav.rebake(true)
	built.emit(team, kind, building)
	return true

## Start learning something (PlayerState.RESEARCH).
func research(team: int, id: String) -> bool:
	var state := side(team)
	return is_playing() and state != null and state.start_research(id)

## Order a piece at the forge (Forge.GEAR): kit, or a weapon into the store
## for recruits to come.
func forge(team: int, item: String) -> bool:
	var state := side(team)
	return is_playing() and state != null and state.order_gear(item)

## Put a labourer to a free anvil, or send a smith back to its trade.
func assign_smith(team: int) -> bool:
	var state := side(team)
	return is_playing() and state != null and state.assign_smith()

func release_smith(team: int) -> bool:
	var state := side(team)
	return is_playing() and state != null and state.release_smith()

## Send the army at a point, fighting whatever it meets on the way.
func attack_move(team: int, point: Vector2) -> void:
	var state := side(team)
	if is_playing() and state != null:
		state.squad.attack_move(point)

## Send the army at the enemy keep.
func attack_enemy_base(team: int) -> void:
	var foe := enemy_of(team)
	var me := side(team)
	if foe != null and foe.base() != null:
		# to the face of their castle that looks towards ours, not into its middle
		var from := me.base().global_position if me != null and me.base() != null else foe.base().global_position
		attack_move(team, foe.base().approach_from(from))

## Call the army back to its own rally point.
func rally_home(team: int) -> void:
	var state := side(team)
	if is_playing() and state != null and state.rally_point != Vector2.INF:
		state.squad.rally(state.rally_point)

## Where new recruits go and stand.
func set_rally_point(team: int, point: Vector2) -> void:
	var state := side(team)
	if is_playing() and state != null:
		state.rally_point = point
		if state.barracks() != null:
			state.barracks().set_rally_point(point)
