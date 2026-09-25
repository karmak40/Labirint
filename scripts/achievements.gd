extends Node
## Achievements (autoload `Achievements`): what the player has done, kept between
## sessions in a ConfigFile.
##
## Nothing here polls. At the start of each match it listens to the signals the
## game already gives -- a body going down, a building falling, a crate banked,
## a recruit hired, the match ending -- and counts only for the side the human
## plays. A match nobody plays (AI against AI) earns nothing.

signal unlocked(id: String)

const SAVE_PATH := "user://achievements.cfg"

## id -> [title, description]. The order is the order they are listed in.
const LIST := {
	"first_blood": ["Первая кровь", "Сразить врага"],
	"tower_down": ["Ломать — не строить", "Разрушить вражескую башню"],
	"victory": ["Крепость пала", "Победить в схватке"],
	"quick_win": ["Блицкриг", "Победить быстрее чем за 5 минут"],
	"untouched": ["Ни царапины", "Победить, не дав тронуть свою крепость"],
	"army_10": ["Легион", "Собрать армию из 10 воинов"],
	"wood_1000": ["Лесопилка", "Сдать на склад 1000 дерева за всё время"],
	"ore_500": ["Рудник", "Сдать на склад 500 руды за всё время"],
	"gold_100": ["Золотая лихорадка", "Сдать на склад 100 золота за всё время"],
	"veteran": ["Ветеран", "Победить 5 раз"],
}
const TOTAL_GOALS := {"wood": ["wood_1000", 1000], "ore": ["ore_500", 500], "gold": ["gold_100", 100]}
const QUICK_WIN := 300.0
const LEGION := 10
const VETERAN := 5

## Where it is kept. Tests point this elsewhere so a real save is never touched.
var save_path := SAVE_PATH
var done := {}                 ## id -> unix time it was unlocked
var totals := {"wood": 0, "ore": 0, "gold": 0, "wins": 0}
var game: Node

func _ready() -> void:
	# a test run says where to keep its score, so a real save is never touched
	var elsewhere := OS.get_environment("LABIRINT_ACHIEVEMENTS")
	load_from(elsewhere if elsewhere != "" else save_path)
	game = get_node_or_null("/root/GameState")
	if game != null:
		game.match_started.connect(_on_match_started)
		game.match_ended.connect(_on_match_ended)

func is_unlocked(id: String) -> bool:
	return done.has(id)

## Idempotent: the second time is nothing.
func unlock(id: String) -> void:
	if done.has(id) or not LIST.has(id):
		return
	done[id] = int(Time.get_unix_time_from_system())
	save()
	unlocked.emit(id)

## A counted thing happened: `event` is what, `amount` how much of it.
func track(event: String, amount: int = 1) -> void:
	totals[event] = int(totals.get(event, 0)) + amount
	if TOTAL_GOALS.has(event) and totals[event] >= TOTAL_GOALS[event][1]:
		unlock(TOTAL_GOALS[event][0])
	elif event == "wins" and totals[event] >= VETERAN:
		unlock("veteran")
	save()

# --- keeping it -------------------------------------------------------------------

func load_from(path: String) -> void:
	save_path = path
	done.clear()
	totals = {"wood": 0, "ore": 0, "gold": 0, "wins": 0}
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for id in file.get_section_keys("unlocked") if file.has_section("unlocked") else []:
		done[id] = file.get_value("unlocked", id)
	for key in totals.keys():
		totals[key] = int(file.get_value("totals", key, 0))

func save() -> void:
	var file := ConfigFile.new()
	for id in done:
		file.set_value("unlocked", id, done[id])
	for key in totals:
		file.set_value("totals", key, totals[key])
	file.save(save_path)

# --- listening to a match -------------------------------------------------------

func _counts() -> bool:
	return game != null and game.is_playing() and not game.spectating

func _on_match_started() -> void:
	if game.spectating:
		return
	var human: PlayerState = game.human()
	# everything already standing, then whatever comes into being later
	for node in get_tree().get_nodes_in_group("targets"):
		_listen_to(node)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group("stockpiles"):
		var pile := node as Stockpile
		if pile != null and human != null and pile.team == human.team:
			pile.received.connect(_on_banked)
	if human != null and human.barracks() != null:
		human.barracks().unit_ready.connect(_on_hired)

func _on_node_added(node: Node) -> void:
	# a recruit's _ready has not run yet here, so wait for it to join its groups
	if node is PlayerBody or node is Tower:
		node.ready.connect(_listen_to.bind(node), CONNECT_ONE_SHOT)

func _listen_to(node: Node) -> void:
	if node is PlayerBody and not node.died.is_connected(_on_body_died):
		node.died.connect(_on_body_died)
	elif node is Tower and not node.destroyed.is_connected(_on_building_down):
		node.destroyed.connect(_on_building_down)

func _on_body_died(body: PlayerBody) -> void:
	if _counts() and Team.hostile(game.human_team, body.team):
		unlock("first_blood")

func _on_building_down(building: Building) -> void:
	if _counts() and building is Tower and Team.hostile(game.human_team, building.team):
		unlock("tower_down")

func _on_banked(kind: String, amount: int) -> void:
	if _counts():
		track(kind, amount)

func _on_hired(_recruit: PlayerBody) -> void:
	if not _counts():
		return
	if game.human().squad.alive().size() >= LEGION:
		unlock("army_10")

func _on_match_ended(winner: int) -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if game.spectating or winner != game.human_team:
		return
	unlock("victory")
	if game.match_time <= QUICK_WIN:
		unlock("quick_win")
	var keep: Base = game.human().base() if game.human() != null else null
	if keep != null and keep.health >= keep.health_max:
		unlock("untouched")
	track("wins")
