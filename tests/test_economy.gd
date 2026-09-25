extends "res://tests/lib/test_case.gd"
## Four workers in EconomyTest.tscn fell every tree, empty every seam and bank
## all of it. The rule the whole economy stands on: the store moves only when
## something is set down on the stockpile, never when a piece is knocked loose.
## And a worker from the other side banks into its own store, not ours.

var scene: Node
var blue: PlayerState
var red: PlayerState
var loose := {"wood": 0, "ore": 0, "gold": 0}
var early := 0                 ## times the store moved as a piece came loose

func begin() -> void:
	time_limit = 60 * 140
	scene = load("res://scenes/tests/EconomyTest.tscn").instantiate()
	# a red worker with a stockpile of its own, working the same gold
	red = PlayerState.new()
	red.team = Team.Id.ENEMY
	scene.add_child(red)
	var pile := Stockpile.new()
	pile.team = Team.Id.ENEMY
	pile.position = Vector2(820, 300)
	scene.add_child(pile)
	var hand: Worker = load("res://scenes/worker/Worker.tscn").instantiate()
	hand.team = Team.Id.ENEMY
	hand.job = "gold"
	hand.position = Vector2(800, 260)
	scene.add_child(hand)
	root.add_child(scene)
	blue = scene.get_node("PlayerSide")
	scene.child_entered_tree.connect(_on_piece)

func _on_piece(node: Node) -> void:
	if not (node is Rock or node is Beam):
		return
	var kind := Stockpile.kind_of(node)
	loose[kind] += 1
	var before := blue.economy.amount(kind) + red.economy.amount(kind)
	await process_frame
	await process_frame
	if blue.economy.amount(kind) + red.economy.amount(kind) != before:
		early += 1

func step() -> bool:
	if frame < 60 * 110:
		return false
	var e := blue.economy
	check(early == 0, "the store never moved as a piece came loose", early)
	check(loose["wood"] == 8 and e.wood == 8, "every log was banked", "%d loose, %d banked" % [loose["wood"], e.wood])
	if not check(loose["ore"] == 6 and e.ore == 6, "every rock of ore was banked", "%d loose, %d banked" % [loose["ore"], e.ore]):
		_explain("ore")
	check(e.gold + red.economy.gold == 3, "the gold went into the two stores", "blue %d, red %d" % [e.gold, red.economy.gold])
	check(red.economy.gold >= 1, "the red worker banked into its own store", red.economy.gold)
	check(red.economy.wood == 0 and red.economy.ore == 0, "nothing of ours ended up in red's store")
	return true

## When something was left unworked: what each worker of that trade was doing,
## and what was left in the seams.
func _explain(job: String) -> void:
	for node in get_nodes_in_group("workers"):
		var hand := node as Worker
		if hand.job == job:
			print("        %s %s at %s  task=%s  source=%s  shunned=%d  carrying=%s" % [hand.name, hand.job,
				hand.global_position.round(), Worker.Task.keys()[hand.task],
				hand.source.name if is_instance_valid(hand.source) else "-", hand.shunned.size(), hand.carried_item])
	for vein in get_nodes_in_group("veins"):
		print("        %s %s taken %d/%d at %s" % [vein.name, vein.resource_kind, vein.taken, vein.rocks, vein.global_position])
	for node in get_nodes_in_group("carriables"):
		if node is Rock:
			print("        rock lying at %s free=%s" % [node.global_position.round(), node.can_be_taken()])
