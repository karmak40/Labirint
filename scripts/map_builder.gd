class_name MapBuilder
extends Node2D
## Stands a match up from a MapData: floor, walls, trees, seams, and for each side
## its keep, barracks, stockpile, towers, workers and store. Everything it puts
## down is an ordinary node doing what it already does in the test scenes; this
## only decides where.
##
## Order matters in one place only: the navigation floor bakes on the frame after
## everything is standing, so every trunk and wall is already there to be walked
## round.

const WALL := 20.0
const FLOOR_COLOR := Color(0.3373, 0.3647, 0.4275)
const BORDER_COLOR := Color(0.1255, 0.1373, 0.1647)
const VOID_COLOR := Color(0.12, 0.10, 0.08)
const VOID := 1200.0
const WORKER_SCENE := "res://scenes/worker/Worker.tscn"
const WORKER_SPREAD := 34.0   ## how far apart the starting hands stand round their stockpile

## The map this scene builds when opened on its own. A match started from the
## menu brings its own (GameState.map), which wins.
@export var map: MapData

## Team -> PlayerState, for whoever runs the match (GameState, from M6).
var states := {}

var _msaa_before := Viewport.MSAA_DISABLED

## A match is a crowd: every figure made while it stands draws in one call, and
## the viewport smooths the edges the figures no longer smooth themselves.
func _enter_tree() -> void:
	Pen.crowd_mode = true
	# GL Compatibility (the phone renderer) has no 2D MSAA; the others do
	if _has_msaa_2d():
		_msaa_before = get_viewport().msaa_2d
		get_viewport().msaa_2d = Viewport.MSAA_4X

func _exit_tree() -> void:
	Pen.crowd_mode = false
	if _has_msaa_2d():
		get_viewport().msaa_2d = _msaa_before

static func _has_msaa_2d() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

func _ready() -> void:
	y_sort_enabled = true
	# looked up rather than named: the match runner sits above the map, and a map
	# built without one (a test, a tool) should still stand up
	var game := get_node_or_null("/root/GameState")
	if game != null and game.map != null:
		map = game.map
	if map == null:
		push_error("MapBuilder: no map to build")
		return
	_lay_floor()
	for spot in map.tree_positions:
		var tree := ChopTree.new()
		tree.position = spot
		tree.regrow_time = map.regrow_time
		tree.logs = map.tree_logs
		tree.log_worth = map.log_worth
		add_child(tree)
	for spot in map.vein_positions:
		_add_vein(spot, "ore")
	for spot in map.gold_positions:
		_add_vein(spot, "gold")
	for layout in map.sides():
		_set_up_side(layout)
	if game != null:
		game.register_match(states)

func state_of(team: int) -> PlayerState:
	return states.get(team)

func _lay_floor() -> void:
	var size := map.floor_size
	# far behind everything, for whatever the land does not reach
	var void_rect := ColorRect.new()
	void_rect.position = Vector2(-VOID, -VOID)
	void_rect.size = size + Vector2(VOID, VOID) * 2.0
	void_rect.color = VOID_COLOR
	void_rect.z_index = -4
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(void_rect)
	# the land itself: grass, road, sky -- drawn once, presentation only
	var land := Terrain.new()
	land.name = "Terrain"
	add_child(land)
	land.build(map)

	# four walls just outside the floor, the same as the testbed's
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	for piece in [
			[Vector2(size.x * 0.5, -WALL * 0.5), Vector2(size.x + WALL * 2.0, WALL)],
			[Vector2(size.x * 0.5, size.y + WALL * 0.5), Vector2(size.x + WALL * 2.0, WALL)],
			[Vector2(-WALL * 0.5, size.y * 0.5), Vector2(WALL, size.y + WALL * 2.0)],
			[Vector2(size.x + WALL * 0.5, size.y * 0.5), Vector2(WALL, size.y + WALL * 2.0)]]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = piece[1]
		shape.shape = box
		shape.position = piece[0]
		walls.add_child(shape)
	add_child(walls)

	var nav := NavFloor.new()
	nav.name = "NavFloor"
	nav.floor_size = size
	add_child(nav)

	var camera := RtsCamera.new()
	camera.floor_size = size
	camera.position = size * 0.5
	# a long field opens on your own castle, not on the middle of nowhere
	var game := get_node_or_null("/root/GameState")
	var home: SideLayout = map.player
	if game != null and not game.spectating and map.enemy != null and map.enemy.team == game.human_team:
		home = map.enemy
	if home != null and (game == null or not game.spectating):
		camera.position = Vector2(home.base.x, size.y * 0.5)
	add_child(camera)
	camera.make_current()
	camera._clamp.call_deferred()

func _add_vein(spot: Vector2, kind: String) -> void:
	var vein := OreVein.new()
	vein.position = spot
	vein.resource_kind = kind
	vein.refill_time = map.refill_time
	vein.rocks = map.gold_rocks if kind == "gold" else map.ore_rocks
	vein.rock_worth = map.gold_rock_worth if kind == "gold" else map.ore_rock_worth
	add_child(vein)

func _set_up_side(layout: SideLayout) -> void:
	var team := layout.team
	var keep := Base.new()
	keep.team = team
	keep.position = layout.base
	add_child(keep)

	var barracks := ProductionBuilding.new()
	barracks.team = team
	barracks.position = layout.barracks
	add_child(barracks)
	barracks.set_rally_point(layout.rally)

	var pile := Stockpile.new()
	pile.team = team
	pile.position = layout.stockpile
	add_child(pile)

	for spot in layout.towers:
		var tower := Tower.new()
		tower.team = team
		tower.position = spot
		add_child(tower)

	var worker_scene := load(WORKER_SCENE) as PackedScene
	var count := layout.start_workers.size()
	for i in count:
		var hand: Worker = worker_scene.instantiate()
		hand.team = team
		hand.job = layout.start_workers[i]
		# in a ring round the heap, so none of them starts stood on it
		var angle := TAU * float(i) / float(maxi(count, 1))
		hand.position = layout.stockpile + Vector2.from_angle(angle) * (Stockpile.RADIUS + WORKER_SPREAD)
		add_child(hand)

	# the side itself last: it claims whatever of its own is already standing
	var state := PlayerState.new()
	state.name = "Side%d" % team
	state.team = team
	add_child(state)
	for kind in layout.start_stock:
		state.economy.add(kind, int(layout.start_stock[kind]))
	states[team] = state
