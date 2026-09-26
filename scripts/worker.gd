class_name Worker
extends PlayerBody
## A labourer: the same body again, with a head that only knows one trade.
##
## Everything it does with its hands already exists -- the felling stroke, the
## pick, stooping for a log, setting it down -- so all this adds is the round:
## find work, do it, pick up what comes of it, carry it home, set it down. The
## stockpile does the counting, which is why nothing here ever touches Economy.

const SEARCH := 1600.0         ## how far afield it will go for a tree or a seam: half a long field
const LOOSE_SEARCH := 280.0    ## and how far for something already cut and lying about
const TREE_REACH := 56.0       ## where it stands to swing an axe (inside CHOP_RANGE)
const VEIN_REACH := 52.0       ## and a pick (inside MINE_RANGE)
const LIFT_REACH := 26.0       ## close enough that the nearest thing to hand is the one it came for
const DROP_REACH := 28.0       ## how far into the stockpile it walks before setting down
const STAND_CLEAR := 30.0      ## an idle hand keeps this far off the heap's edge, out of the carriers' way
const WORK_SPEED := 0.8
const GIVE_UP := 9.0           ## seconds after which an errand that is going nowhere is dropped

## "wood", "ore" or "gold": what it goes for, and what it bothers to carry.
## Or "smith": it stands at an anvil of its side's forge and beats out arms
## and kit. Or "recruit": a man hired for a soldier on order (`draft`), who
## fetches his arms from the forge and takes them to the barracks to train.
@export var job := "wood"
## What it did before it was put to the anvil, to go back to afterwards.
var former_job := ""
## For a smith: whose anvil, and which of its two.
var smithy: Forge = null
var anvil := 0
## For a recruit: the order he is filling.
var draft: Draft = null

const RECRUIT_PACE := 1.0      ## a recruit walks, he does not trudge like a man carrying logs
const COLLECT_REACH := 14.0    ## how near where he waits for his arms
const DOOR_REACH := 20.0       ## and the barracks door

const ANVIL_REACH := 8.0       ## how near the smith's spot it has to stand
const WORKER_LAYER := 2        ## a physics layer of their own (see _ready)

enum Task { IDLE, TO_SOURCE, GATHERING, FETCHING, DELIVERING }

var task := Task.IDLE
var task_time := 0.0
var wish := Vector2.ZERO
var source: Node2D = null      ## the tree or vein being worked
var fetching: Carriable = null ## the piece it is on its way to pick up
var home: Stockpile = null
var shunned := {}              ## instance id -> true: errands that went nowhere
var path: Pathfinder

func _ready() -> void:
	super()
	add_to_group("workers")
	# Labourers bump into the world -- trunks, walls, veins -- but not into
	# bodies: in a crowded wood five of them shoving each other between the
	# trunks wedge fast, logs and all. The crowd's steering still keeps them apart.
	collision_layer = WORKER_LAYER
	collision_mask = 1
	_take_tools()
	path = Pathfinder.new(speed)
	add_child(path)
	set_process_unhandled_key_input(false)   # a head, not a keyboard, drives it

func _take_tools() -> void:
	match job:
		"wood":
			weapon = Weapon.AXE
		"smith":
			weapon = Weapon.HAMMER
		"recruit":
			weapon = draft.carried_weapon() if draft != null and draft.stage == Draft.Stage.CARRYING else Weapon.NONE
		_:
			weapon = Weapon.PICKAXE

## A new trade: whatever it was doing is dropped, and it takes up the tools.
func set_job(next: String) -> void:
	if next == job:
		return
	if next == "smith" and job != "recruit":
		former_job = job
	if next != "smith":
		smithy = null
	job = next
	source = null
	fetching = null
	home = null
	shunned.clear()
	_take_tools()
	_set_task(Task.IDLE)

func is_smith() -> bool:
	return job == "smith"

func _get_input_vector() -> Vector2:
	return wish

## The side's colour under its feet while it lives; a corpse is nobody's.
var ring_drawn_alive := true
## Only in a match: the testbed's knight is drawn exactly as it always was.
var show_ring := Pen.crowd_mode

func _draw() -> void:
	if show_ring and not is_dead:
		Team.draw_foot_ring(self, team)

func _refresh_ring() -> void:
	if ring_drawn_alive != (not is_dead):
		ring_drawn_alive = not is_dead
		queue_redraw()

func _physics_process(delta: float) -> void:
	_refresh_ring()
	_decide(delta)
	if path.has_floor_plan():
		wish = path.settle(wish, task == Task.IDLE and not is_attacking())
	super(delta)

func _decide(delta: float) -> void:
	task_time += delta
	wish = Vector2.ZERO
	# hands busy or knocked about: stand, the rig is doing the work
	if is_dead or is_flinching() or is_attacking():
		return

	if carried_item != null:
		if Stockpile.kind_of(carried_item) == "" or is_smith():
			put_down_rock()   # picked up the wrong thing: not ours to carry
			return
		_deliver()
		return

	if is_smith():
		_smith()
		return

	if job == "recruit":
		_enlist()
		return

	var loose := _loose_piece(LOOSE_SEARCH)
	if loose != null:
		_fetch(loose)
		return

	_gather()

## To its anvil, and hammer while there is work on it. With the forge gone it
## goes back to what it did before.
func _smith() -> void:
	fetching = null
	var forge := my_forge()
	if forge == null:
		if smithy != null and (not is_instance_valid(smithy) or not smithy.is_alive()):
			set_job(former_job if former_job != "" else "wood")
			return
		_set_task(Task.IDLE)
		_stand_clear()
		return
	if not _walk_to(forge.smith_spot(anvil), ANVIL_REACH, WORK_SPEED):
		_set_task(Task.TO_SOURCE)
		return
	var dx := forge.anvil_point(anvil).x - global_position.x
	if absf(dx) > 1.0:
		facing_x = signf(dx)
	if not forge.has_work(anvil):
		_set_task(Task.IDLE)
		return
	_set_task(Task.GATHERING)
	# may refuse for want of breath; it simply tries again next frame
	attack()

## The forge it smiths at, while it stands finished.
func my_forge() -> Forge:
	if smithy != null and is_instance_valid(smithy) and smithy.is_alive() and smithy.is_complete():
		return smithy
	return null

## Whether it is at its anvil, facing it.
func at_anvil() -> bool:
	var forge := my_forge()
	return is_smith() and forge != null and global_position.distance_to(forge.smith_spot(anvil)) <= ANVIL_REACH * 1.5

## At the anvil the hammer comes down on the work, not on whoever is near.
func land_strike() -> void:
	if at_anvil():
		my_forge().hammer_blow(anvil)
		return
	super()

## A recruit's errand: to the forge for his arms, then to the barracks with
## them. Where there is nowhere to go yet he waits out of the way.
func _enlist() -> void:
	fetching = null
	if draft == null or draft.side == null:
		_set_task(Task.IDLE)
		_stand_clear()
		return
	var side := draft.side
	if draft.stage == Draft.Stage.ARMING:
		var spot := side.collect_point(self)
		if spot == Vector2.INF:
			_set_task(Task.IDLE)
			return
		_set_task(Task.TO_SOURCE)
		if _walk_to(spot, COLLECT_REACH, RECRUIT_PACE):
			_set_task(Task.IDLE)
			if side.hand_out_arms(draft):
				_take_tools()
		return
	var barracks := side.barracks()
	if barracks == null or not barracks.is_complete():
		_set_task(Task.IDLE)
		_stand_clear()
		return
	_set_task(Task.DELIVERING)
	if _walk_to(barracks.door_point(), DOOR_REACH, RECRUIT_PACE):
		side.send_to_train(draft, barracks)

func _set_task(next: Task) -> void:
	if task != next:
		task = next
		task_time = 0.0

## Home with it, and set it down in the middle of the heap.
func _deliver() -> void:
	fetching = null
	if home == null or not is_instance_valid(home):
		home = _nearest_home()
		if home == null:
			_set_task(Task.IDLE)
			return
	_set_task(Task.DELIVERING)
	if _walk_to(home.global_position, DROP_REACH, WORK_SPEED):
		put_down_rock()

func _fetch(piece: Carriable) -> void:
	if piece != fetching:
		fetching = piece
		task_time = 0.0
	_set_task(Task.FETCHING)
	if task_time > GIVE_UP:
		_shun(piece)
		return
	if _walk_to(piece.global_position, LIFT_REACH, WORK_SPEED):
		pick_up()

func _gather() -> void:
	fetching = null
	if not _still_worth_working(source):
		source = _nearest_source()
		task_time = 0.0
	if source == null:
		# nothing left standing to work: sweep up whatever is still lying about
		var straggler := _loose_piece(SEARCH)
		if straggler != null:
			_fetch(straggler)
			return
		_set_task(Task.IDLE)
		_stand_clear()
		return

	var reach := TREE_REACH if source is ChopTree else VEIN_REACH
	if not _walk_to(source.global_position, reach, WORK_SPEED):
		_set_task(Task.TO_SOURCE)
		if task_time > GIVE_UP * 2.0:
			_shun(source)
			source = null
		return

	_set_task(Task.GATHERING)
	var dx := source.global_position.x - global_position.x
	if absf(dx) > 1.0:
		facing_x = signf(dx)
	# either may refuse for want of breath; it simply tries again next frame
	if source is ChopTree:
		chop_tree()
	else:
		equip_pickaxe()
		attack()

func _still_worth_working(thing: Node2D) -> bool:
	if thing == null or not is_instance_valid(thing):
		return false
	if thing is ChopTree:
		# keep minding a falling tree: its logs are about to land at our feet
		return (thing as ChopTree).state != ChopTree.State.DOWN
	var vein := thing as OreVein
	return vein != null and vein.has_ore() and vein.resource_kind == job

## The nearest tree or seam nobody else is already at, or failing that the nearest
## at all: two to a trunk only get in each other's way.
func _nearest_source() -> Node2D:
	var free := _nearest_source_among(false)
	return free if free != null else _nearest_source_among(true)

func _nearest_source_among(shared: bool) -> Node2D:
	var group := "trees" if job == "wood" else "veins"
	var best: Node2D = null
	var best_distance := SEARCH
	for node in get_tree().get_nodes_in_group(group):
		var candidate := node as Node2D
		if candidate == null or shunned.has(candidate.get_instance_id()):
			continue
		if candidate is ChopTree and not (candidate as ChopTree).is_standing():
			continue
		if candidate is OreVein and not _still_worth_working(candidate):
			continue
		if not shared and _worked_by_another(candidate):
			continue
		# a trunk under the other side's tower is not worth the walk
		if _under_hostile_tower(candidate.global_position):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

## The nearest piece of our trade lying loose that nobody else is already going
## for. Anything already on a stockpile is left to it.
func _loose_piece(within: float) -> Carriable:
	var best: Carriable = null
	var best_distance := within
	for node in get_tree().get_nodes_in_group("carriables"):
		var piece := node as Carriable
		if piece == null or not piece.can_be_taken() or piece.is_queued_for_deletion():
			continue
		if Stockpile.kind_of(piece) != job or shunned.has(piece.get_instance_id()):
			continue
		if _claimed_by_another(piece) or _on_a_stockpile(piece):
			continue
		var distance := global_position.distance_to(piece.global_position)
		if distance < best_distance:
			best_distance = distance
			best = piece
	return best

func _under_hostile_tower(point: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("buildings"):
		var tower := node as Tower
		if tower != null and tower.is_alive() and Team.hostile(team, tower.team) 				and point.distance_to(tower.global_position) < Tower.RANGE + 20.0:
			return true
	return false

func _worked_by_another(thing: Node2D) -> bool:
	for node in get_tree().get_nodes_in_group("workers"):
		if node != self and (node as Worker).source == thing and (node as Worker).is_alive():
			return true
	return false

func _claimed_by_another(piece: Carriable) -> bool:
	for node in get_tree().get_nodes_in_group("workers"):
		if node != self and (node as Worker).fetching == piece:
			return true
	return false

func _on_a_stockpile(piece: Node2D) -> bool:
	for node in get_tree().get_nodes_in_group("stockpiles"):
		if piece.global_position.distance_to((node as Node2D).global_position) <= Stockpile.RADIUS:
			return true
	return false

func _nearest_home() -> Stockpile:
	var best: Stockpile = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("stockpiles"):
		var pile := node as Stockpile
		if pile == null or pile.team != team:
			continue
		var distance := global_position.distance_to(pile.global_position)
		if distance < best_distance:
			best_distance = distance
			best = pile
	return best

## Nothing to do: at least not stood on the heap where the others set things down.
func _stand_clear() -> void:
	for node in get_tree().get_nodes_in_group("stockpiles"):
		var pile := node as Node2D
		var off := global_position - pile.global_position
		if off.length() < Stockpile.RADIUS + STAND_CLEAR:
			var away := off.normalized() if off.length() > 1.0 else Vector2.RIGHT
			wish = away * WORK_SPEED * 0.6
			return

func _shun(thing: Node) -> void:
	shunned[thing.get_instance_id()] = true
	if thing == fetching:
		fetching = null
	task_time = 0.0

## Walks at a point until within `stop_within` of it, and says whether it is.
func _walk_to(there: Vector2, stop_within: float, effort: float) -> bool:
	if global_position.distance_to(there) <= stop_within:
		return true
	if path.has_floor_plan():
		wish = path.heading_to(there) * effort
	else:
		wish = (there - global_position).normalized() * effort
	return false
