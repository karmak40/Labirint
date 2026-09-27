class_name FogOfWar
extends Node2D
## What the human side can see of the field, and what it has seen.
##
## The field is cut into CELL-sized squares, each unexplored, explored or in
## sight right now. Every LOOK seconds everything of ours -- soldiers, labourers,
## buildings -- lights up the squares within its vision (`vision_of`): a scout's
## reaches furthest, and the dark and the rain close in on anyone on foot
## (Weather.sight). Whatever of anybody else's is not in sight is hidden: their
## men the moment they step out of it, their buildings and camps only until
## they have been found once, since walls do not walk away.
##
## Drawn as one small texture laid over the whole field and smoothed, so its
## edges are soft: black where nobody has been, a veil where somebody has.
## It is the human's view only; the enemy's head decides by what its own men
## would see anyway (see AIDirector).

const CELL := 40.0
const LOOK := 0.2              ## seconds between looks round
const UNSEEN := 0.94           ## how dark a square nobody has been to is
const REMEMBERED := 0.5        ## and one somebody has, out of sight now
const FADE := 0.45             ## how far a square moves to its new darkness each look
const SHROUD := Color(0.02, 0.03, 0.05)

## How far each of ours sees. Men by kind; a scout is the eyes of an army.
const UNIT_VISION := 260.0
const KIND_VISION := {"scout": 460.0, "archer": 300.0, "crossbowman": 300.0, "mage": 320.0}
const WORKER_VISION := 180.0
const BASE_VISION := 420.0
const TOWER_VISION := 320.0
const BUILDING_VISION := 220.0

static var current: FogOfWar = null

var team: int = Team.Id.PLAYER
## Filming (CinemaMode): the shroud is off and everything is shown. The
## squares are still worked out, so it comes back as it would have been.
var lifted := false
var size_cells := Vector2i.ONE
var explored := PackedByteArray()
var seen := PackedByteArray()
var shade := PackedFloat32Array()
var _image: Image
var _texture: ImageTexture
var _floor := Vector2.ONE
var _look_left := 0.0

func setup(floor_size: Vector2, side: int) -> void:
	team = side
	_floor = floor_size
	size_cells = Vector2i(ceili(floor_size.x / CELL), ceili(floor_size.y / CELL))
	var n := size_cells.x * size_cells.y
	explored.resize(n)
	explored.fill(0)
	seen.resize(n)
	seen.fill(0)
	shade.resize(n)
	shade.fill(UNSEEN)
	_image = Image.create(size_cells.x, size_cells.y, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

func _ready() -> void:
	z_index = 3990
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_look(true)

func _physics_process(delta: float) -> void:
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = LOOK
		_look(false)

func _cell(point: Vector2) -> int:
	var x := clampi(int(point.x / CELL), 0, size_cells.x - 1)
	var y := clampi(int(point.y / CELL), 0, size_cells.y - 1)
	return y * size_cells.x + x

## Whether the human side sees `point` right now. Everything is seen with no fog.
static func sees(point: Vector2) -> bool:
	return current == null or current.seen[current._cell(point)] == 1

## Whether it has ever seen `point`.
static func knows(point: Vector2) -> bool:
	return current == null or current.explored[current._cell(point)] == 1

## Whether `node` (a body, a building, a camp, a trophy) is shown to the human.
static func shows(node: Node2D) -> bool:
	if current == null or node == null or current.lifted:
		return true
	if Team.of(node) == current.team:
		return true
	if node is Building or node is BanditCamp:
		return knows(node.global_position)
	return sees(node.global_position)

## How far `node` of ours sees just now.
static func vision_of(node: Node) -> float:
	if node is Base:
		return BASE_VISION
	if node is Tower:
		return TOWER_VISION
	if node is Building:
		return BUILDING_VISION
	var sight := Weather.sight()
	if node is Unit:
		return float(KIND_VISION.get((node as Unit).loadout, UNIT_VISION)) * sight
	return WORKER_VISION * sight

## One look round: what is in sight now, what that has uncovered, who is hidden.
func _look(at_once: bool) -> void:
	seen.fill(0)
	for node in get_tree().get_nodes_in_group("targets"):
		var thing := node as Node2D
		if thing == null or Team.of(thing) != team:
			continue
		if not thing.has_method("is_alive") or not thing.is_alive():
			continue
		_light(thing.global_position, vision_of(thing))
	_hide_the_unseen()
	_paint(at_once)

func set_lifted(on: bool) -> void:
	lifted = on
	visible = not on
	_hide_the_unseen()

func _light(from: Vector2, radius: float) -> void:
	var reach := ceili(radius / CELL)
	var centre := Vector2i(int(from.x / CELL), int(from.y / CELL))
	var r2 := radius * radius
	for y in range(maxi(0, centre.y - reach), mini(size_cells.y, centre.y + reach + 1)):
		for x in range(maxi(0, centre.x - reach), mini(size_cells.x, centre.x + reach + 1)):
			var middle := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			if middle.distance_squared_to(from) <= r2:
				var i := y * size_cells.x + x
				seen[i] = 1
				explored[i] = 1

## Everybody else's men out of sight, and their buildings and camps not yet
## found, are not drawn -- nor picked, nor shown on the map.
func _hide_the_unseen() -> void:
	for group in ["targets", "camps", "trophies"]:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node2D
			if thing != null:
				thing.visible = shows(thing)

func _paint(at_once: bool) -> void:
	for i in shade.size():
		var target := 0.0 if seen[i] == 1 else (REMEMBERED if explored[i] == 1 else UNSEEN)
		shade[i] = target if at_once else lerpf(shade[i], target, FADE)
		if absf(shade[i] - target) < 0.01:
			shade[i] = target
		_image.set_pixel(i % size_cells.x, i / size_cells.x, Color(SHROUD, shade[i]))
	_texture.update(_image)
	queue_redraw()

func _draw() -> void:
	# a little past the edges, so the smoothing does not leave a lit rim
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(size_cells) * CELL), false)
