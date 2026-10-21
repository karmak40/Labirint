extends "res://tests/lib/test_case.gd"
## Houses and the market. The castle houses fifteen; everyone counts --
## labourers, soldiers, anyone in a queue -- and past that nobody can be hired,
## labourer or soldier, until a house is built (+8 each; a burnt one takes its
## room with it). The market trades one good for another at a loss, only once
## it stands, and at prices that move: sell the same thing again and again and
## it fetches less, until the price has had time to come back. And the enemy's head builds its own houses as it grows.

var stage := 0
var house: House
var stall: Market

func begin() -> void:
	time_limit = 60 * 300
	game().ai_strategy = "balanced"
	game().ai_difficulty = "hard"
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func _hand(at: Vector2) -> Worker:
	var worker: Worker = load("res://scenes/worker/Worker.tscn").instantiate()
	worker.team = Team.Id.PLAYER
	worker.job = "wood"
	worker.position = at
	current_scene.add_child(worker)
	return worker

func step() -> bool:
	var gs := game()
	var me: PlayerState = gs.human()
	var enemy: PlayerState = gs.side(Team.Id.ENEMY)
	match stage:
		0:
			if not playing():
				return false
			raise_barracks(Team.Id.PLAYER)
			me.economy.add("wood", 600)
			me.economy.add("ore", 600)
			me.economy.add("gold", 100)
			check(me.pop_cap() == PlayerState.POP_BASE, "the castle houses fifteen", me.pop_cap())
			for i in 14:
				_hand(me.base().door_point() + Vector2(-140 + (i % 7) * 40, 40 + (i / 7) * 30))
			check(me.population() == 14, "every labourer counts", me.population())
			check(gs.hire(1, "worker"), "one more fits")
			check(me.population() == 15, "and one in the queue counts too", me.population())
			check(not gs.hire(1, "worker"), "the sixteenth does not")
			check(me.order_problem("warrior") == "Нет места: постройте дом", "nor a soldier", me.order_problem("warrior"))
			var spot := Vector2.INF
			var why := ""
			for at in [Vector2(260, -170), Vector2(330, -120), Vector2(400, -170), Vector2(330, 170), Vector2(460, 0)]:
				why = gs.build_problem(1, "house", me.base().global_position + at)
				if why == "":
					spot = me.base().global_position + at
					break
			check(spot != Vector2.INF and gs.build(1, "house", spot), "a house is laid out", why)
			if spot == Vector2.INF:
				return true
			for b in me.buildings:
				if b is House: house = b
			stage = 1
			frame = 0
		1:
			if not house.is_complete():
				return false
			check(me.pop_cap() == PlayerState.POP_BASE + PlayerState.POP_HOUSE, "a finished house gives eight more", me.pop_cap())
			check(gs.hire(1, "warrior"), "and there is room to hire again")
			house.take_hit(Vector2.INF, 99999.0)
			check(me.pop_cap() == PlayerState.POP_BASE, "a burnt house takes its room with it", me.pop_cap())
			# the market
			check(not gs.trade(1, "wood_ore"), "no trading without a market")
			stall = Market.new()
			stall.team = Team.Id.PLAYER
			stall.position = me.base().global_position + Vector2(420, 170)
			gs.field().add_child(stall)
			me.adopt(stall)
			check(gs.build_problem(1, "market", me.base().global_position + Vector2(420, -170)) == "Рынок уже есть", "one market to a side")
			var wood: int = me.economy.wood
			var ore: int = me.economy.ore
			var first: int = me.quote("wood_ore")["get"]["ore"]
			check(first == Market.usual("wood_ore") and first < 20, "20 wood fetch less than 20 ore", first)
			check(gs.trade(1, "wood_ore") and me.economy.wood == wood - 20 and me.economy.ore == ore + first, "the deal is made at the quote")
			for i in 5:
				gs.trade(1, "wood_ore")
			var later: int = me.quote("wood_ore")["get"]["ore"]
			check(later < first, "selling wood again and again gets less for it", "%d -> %d" % [first, later])
			check(me.quote("ore_wood")["get"]["wood"] > Market.usual("ore_wood"), "and makes wood dear to buy back")
			me._settle_prices(240.0)
			check(me.quote("wood_ore")["get"]["ore"] >= first - 1, "left alone, the price comes back", me.quote("wood_ore")["get"]["ore"])
			var gold: int = me.economy.gold
			check(gs.trade(1, "gold_wood") and me.economy.gold == gold - 10, "10 gold for wood")
			me.economy.spend({"gold": me.economy.gold})
			check(not gs.trade(1, "gold_ore"), "nothing given for nothing")
			stage = 2
		2:
			# the enemy's head, growing against a side that does nothing, puts up its own
			if enemy.house_sites() == 0:
				return false
			check(true, "the enemy's head built a house", "at %.0f s, %d of %d people" % [gs.match_time, enemy.population(), enemy.pop_cap()])
			return true
	return false
