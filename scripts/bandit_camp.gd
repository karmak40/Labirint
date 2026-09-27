class_name BanditCamp
extends Node2D
## A camp of bandits by something worth having: a few tents, a fire, a chest,
## and men with whatever arms they could steal, standing guard. They belong to
## neither side and fight both (Team.Id.BANDITS). They do not raid; they keep
## to their camp, and fall on anyone who comes near it.
##
## Clear it and the chest is yours: the side with a man nearest the camp when
## the last bandit falls takes the bounty straight into its store. Their arms
## are left lying as trophies like anyone's. Until then, labourers keep clear of
## whatever it guards (`guards_point`).

signal cleared(team: int, bounty: Dictionary)

const GUARD := 160.0           ## how far round it a labourer will not go to work
const POST_SPREAD := 46.0      ## how far from the fire each bandit stands
const CLAIM_REACH := 480.0     ## how near a man must be to claim the chest

const CANVAS := Color(0.56, 0.49, 0.38)
const CANVAS_DARK := Color(0.38, 0.32, 0.24)
const POLE := Color(0.30, 0.22, 0.14)
const STONE := Color(0.40, 0.39, 0.37)
const EMBER := Color(0.30, 0.12, 0.05)
const FIRE := Color(1.0, 0.55, 0.15)
const FIRE_CORE := Color(1.0, 0.88, 0.45)
const CHEST := Color(0.46, 0.30, 0.16)
const CHEST_BAND := Color(0.85, 0.68, 0.25)
const GOLD := Color(1.0, 0.82, 0.30)
const RAG := Color(0.20, 0.18, 0.16)

## Who stands guard (Unit.LOADOUTS kinds), and what the chest holds.
var loadouts := PackedStringArray(["warrior", "warrior", "spearman", "archer"])
var bounty := {"wood": 40, "ore": 30, "gold": 20}

var bandits: Array[Unit] = []
var is_cleared := false
var claimed_by: int = Team.Id.NEUTRAL
var _flicker := 0.0

func _ready() -> void:
	add_to_group("camps")
	# the bandits are put down once the camp is on the field, round the fire
	_muster.call_deferred()

func _muster() -> void:
	var scene := load("res://scenes/warrior/Warrior.tscn") as PackedScene
	for i in loadouts.size():
		var bandit: Unit = scene.instantiate()
		bandit.loadout = loadouts[i]
		bandit.team = Team.Id.BANDITS
		var angle := TAU * float(i) / float(loadouts.size()) + 0.4
		bandit.position = position + Vector2(cos(angle), sin(angle) * 0.6) * POST_SPREAD
		get_parent().add_child(bandit)
		# a hood, not a helm: a bandit is known by it
		bandit.helm = PlayerBody.Helm.NONE
		bandit.hooded = true
		bandit.set_rally(bandit.position)
		bandit.died.connect(_on_bandit_down)
		bandits.append(bandit)

## Bandits still on their feet.
func alive() -> int:
	var count := 0
	for bandit in bandits:
		if is_instance_valid(bandit) and bandit.is_alive():
			count += 1
	return count

func is_guarded() -> bool:
	return not is_cleared and alive() > 0

## Whether `point` is under this camp's eye, while anyone still guards it.
func guards_point(point: Vector2) -> bool:
	return is_guarded() and point.distance_to(global_position) < GUARD

## Whether any camp on the field still guards `point`.
static func guarded(tree: SceneTree, point: Vector2) -> bool:
	for node in tree.get_nodes_in_group("camps"):
		if (node as BanditCamp).guards_point(point):
			return true
	return false

func _on_bandit_down(_body: PlayerBody) -> void:
	if is_cleared or alive() > 0:
		return
	is_cleared = true
	claimed_by = _nearest_side()
	var state: PlayerState = PlayerState.of_team(get_tree(), claimed_by) if claimed_by != Team.Id.NEUTRAL else null
	if state != null:
		for resource in bounty:
			state.economy.add(resource, int(bounty[resource]))
	queue_redraw()
	cleared.emit(claimed_by, bounty)

## The side with a living man nearest the camp, within reach of the chest.
func _nearest_side() -> int:
	var best: int = Team.Id.NEUTRAL
	var best_distance := CLAIM_REACH
	for node in get_tree().get_nodes_in_group("targets"):
		var body := node as PlayerBody
		if body == null or body.is_dead or body.team == Team.Id.BANDITS or body.team == Team.Id.NEUTRAL:
			continue
		var distance := body.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = body.team
	return best

## Where the fire is, for the light it gives at night.
func fire_point() -> Vector2:
	return global_position + Vector2(0.0, -4.0)

func _process(delta: float) -> void:
	if is_cleared:
		return
	_flicker += delta
	queue_redraw()

func _draw() -> void:
	# trodden ground
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 92.0, Color(0.36, 0.31, 0.22, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_tent(Vector2(-64.0, -24.0), 1.0)
	_tent(Vector2(58.0, -30.0), 0.85)
	_tent(Vector2(-8.0, -52.0), 0.75)
	# a ragged banner on a pole
	draw_line(Vector2(84.0, 10.0), Vector2(84.0, -62.0), POLE, 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(84.0, -62.0), Vector2(104.0, -56.0),
		Vector2(96.0, -52.0), Vector2(103.0, -46.0), Vector2(84.0, -44.0)]), RAG)
	# the fire in its ring of stones, out once the camp is taken
	for k in 7:
		var at := Vector2.from_angle(TAU * k / 7.0) * Vector2(12.0, 6.0)
		draw_circle(at + Vector2(0.0, 2.0), 3.2, STONE)
	draw_circle(Vector2(0.0, 1.0), 7.0, EMBER)
	if not is_cleared:
		var lick := 0.8 + 0.2 * sin(_flicker * 13.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6.0, 1.0), Vector2(0.0, -16.0 * lick),
			Vector2(6.0, 1.0)]), FIRE)
		draw_colored_polygon(PackedVector2Array([Vector2(-3.0, 1.0), Vector2(0.0, -9.0 * lick),
			Vector2(3.0, 1.0)]), FIRE_CORE)
	# the chest: shut and full, or flung open and empty
	var chest := Rect2(Vector2(26.0, 6.0), Vector2(20.0, 12.0))
	draw_rect(chest, CHEST)
	draw_rect(chest, CHEST_BAND, false, 1.5)
	if is_cleared:
		draw_colored_polygon(PackedVector2Array([chest.position, chest.position + Vector2(20.0, 0.0),
			chest.position + Vector2(24.0, -9.0), chest.position + Vector2(4.0, -9.0)]), CHEST)
	else:
		draw_rect(Rect2(chest.position + Vector2(0.0, -5.0), Vector2(20.0, 5.0)), CHEST)
		draw_line(chest.position + Vector2(0.0, -5.0), chest.position + Vector2(20.0, -5.0), CHEST_BAND, 1.5)
		draw_circle(chest.position + Vector2(10.0, 1.0), 1.8, GOLD)

func _tent(at: Vector2, size: float) -> void:
	var w := 30.0 * size
	var h := 34.0 * size
	var tent := PackedVector2Array([at + Vector2(-w, 0.0), at + Vector2(0.0, -h), at + Vector2(w, 0.0)])
	draw_colored_polygon(tent, CANVAS if not is_cleared else CANVAS.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-6.0 * size, 0.0), at + Vector2(0.0, -h * 0.55),
		at + Vector2(6.0 * size, 0.0)]), CANVAS_DARK)
	tent.append(tent[0])
	draw_polyline(tent, CANVAS_DARK, 1.4, true)
	draw_line(at + Vector2(0.0, -h), at + Vector2(0.0, -h - 6.0), POLE, 2.0)
