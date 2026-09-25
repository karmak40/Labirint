extends Node
## The campaign (autoload `Campaign`): three rooms played in turn, each its own
## map with its own twist. Winning a room opens the next; how well it was won
## is kept as one to three stars, in a ConfigFile of its own.
##
## A room is started through GameState like any match. While one is being
## played, its rules (RoomRules) are put into the match, and the result is
## scored and saved when the match ends.

signal room_finished(index: int, stars: int)

const SAVE_PATH := "user://campaign.cfg"

## The rooms, in order. `fast` is the time (s) to win within for the second
## star, `castle` the share of the castle's health to keep for the third.
const ROOMS := [
	{
		"id": "forest", "title": "Лесной рубеж", "map": "res://resources/maps/campaign_forest.tres",
		"brief": "Враг встал лагерем на другом конце долины. Нарубите леса, добудьте руды, соберите войско и сожгите их крепость.",
		"goal": "Разрушить вражескую крепость.",
		"fast": 900.0, "castle": 0.75, "ai": "balanced",
	},
	{
		"id": "gorge", "title": "Золотое ущелье", "map": "res://resources/maps/campaign_gorge.tres",
		"brief": "Всё золото долины — в узком ущелье посередине, и враг перекрыл его выход двумя башнями. Без золота не будет ни рыцарей, ни арбалетов.",
		"goal": "Прорваться через ущелье и разрушить вражескую крепость.",
		"fast": 1080.0, "castle": 0.75, "ai": "turtle",
	},
	{
		"id": "siege", "title": "Осада", "map": "res://resources/maps/campaign_siege.tres",
		"brief": "Враг заперся в крепости за тремя башнями и шлёт на вас волну за волной. Выстойте — после последней волны их ворота откроются.",
		"goal": "Отбить 5 волн, затем разрушить вражескую крепость.",
		"fast": 1200.0, "castle": 0.6, "ai": "tech",
		"waves": [
			{"at": 60.0, "units": {"warrior": 4}},
			{"at": 150.0, "units": {"warrior": 4, "spearman": 2}},
			{"at": 240.0, "units": {"spearman": 4, "archer": 3}},
			{"at": 330.0, "units": {"spearman": 4, "archer": 3, "knight": 2}},
			{"at": 420.0, "units": {"knight": 4, "archer": 4, "crossbowman": 2}},
		],
	},
]

var save_path := SAVE_PATH
var stars := {}                ## room id -> best stars (0..3)
var current := -1              ## the room being played, -1 for none
var last_earned := 0           ## stars the room just finished was worth (0 for a loss)
## GameState, found when first wanted rather than at start-up: autoloads come
## up one after another, and this one must not depend on the order.
var game: Node:
	get:
		if _game == null or not is_instance_valid(_game):
			_game = get_node_or_null("/root/GameState")
			if _game != null and not _game.match_started.is_connected(_on_match_started):
				_game.match_started.connect(_on_match_started)
				_game.match_ended.connect(_on_match_ended)
		return _game
var _game: Node

func _ready() -> void:
	var elsewhere := OS.get_environment("LABIRINT_CAMPAIGN")
	load_from(elsewhere if elsewhere != "" else save_path)
	# hook onto the match as soon as GameState is there
	(func() -> void: var _g := game).call_deferred()

func load_from(path: String) -> void:
	save_path = path
	stars.clear()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for room in ROOMS:
		stars[room["id"]] = int(file.get_value("stars", room["id"], 0))

func save() -> void:
	var file := ConfigFile.new()
	for id in stars:
		file.set_value("stars", id, stars[id])
	file.save(save_path)

func stars_of(index: int) -> int:
	return int(stars.get(ROOMS[index]["id"], 0))

## The first room is always open; each later one once the one before is won.
func is_open(index: int) -> bool:
	return index == 0 or (index > 0 and index < ROOMS.size() and stars_of(index - 1) > 0)

func start(index: int) -> void:
	if not is_open(index):
		return
	current = index
	# each room's enemy plays its own way; how well is the player's choice
	game.ai_strategy = ROOMS[index].get("ai", "balanced")
	game.start_match(ROOMS[index]["map"])

## The next room after the current one, if there is one and it is open.
func next_room() -> int:
	var next := current + 1
	return next if next < ROOMS.size() and is_open(next) else -1

## Leaving the campaign for a skirmish or the menu.
func leave() -> void:
	current = -1

func _on_match_started() -> void:
	if current < 0 or game.spectating:
		return
	var rules := RoomRules.new()
	rules.name = "RoomRules"
	rules.room = ROOMS[current]
	game.field().add_child(rules)

## What a win was worth: a star for winning, one for winning quickly, one for
## keeping the castle whole enough.
func score(match_time: float, castle_share: float) -> int:
	var room: Dictionary = ROOMS[current]
	var earned := 1
	if match_time <= float(room["fast"]):
		earned += 1
	if castle_share >= float(room["castle"]):
		earned += 1
	return earned

func _on_match_ended(winner: int) -> void:
	if current < 0 or game.spectating:
		return
	var earned := 0
	if winner == game.human_team:
		var keep: Base = game.human().base() if game.human() != null else null
		var share := keep.health / keep.health_max if keep != null else 0.0
		earned = score(game.match_time, share)
		var id: String = ROOMS[current]["id"]
		stars[id] = maxi(int(stars.get(id, 0)), earned)
		save()
	last_earned = earned
	room_finished.emit(current, earned)
