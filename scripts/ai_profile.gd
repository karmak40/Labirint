class_name AIProfile
extends RefCounted
## How an AIDirector plays, as plain numbers: a strategy (what it wants -- rush,
## sit tight, learn first, or a bit of everything) shaped by a difficulty (how
## well it goes about it). No difficulty cheats: every level plays by the same
## rules and pays the same prices; an easy head is slow and timid, a hard one
## quick and thorough.

const STRATEGIES := {
	"balanced": {
		"title": "Ровный", "about": "Всего понемногу: рабочие, знания, башни и смешанная армия.",
		"think": 2.0, "hires": 2,
		"workers_first": {"wood": 2, "ore": 2}, "workers_full": {"wood": 5, "ore": 3}, "gold_hands": 1,
		"first_wave": 4, "wave_growth": 2, "wave_max": 12, "spent_at": 1,
		"home_guard": 260.0, "counter_share": 0.5,
		"studies": ["forging", "spears", "archery", "blades", "chivalry", "mail", "crossbows", "magic", "healing"],
		"mix": {"knight": 3.0, "swordsman": 2.0, "spearman": 2.0, "archer": 2.0, "crossbowman": 1.5, "mage": 1.0},
		"towers": 2, "towers_early": false, "library_after": 3,
		"gear": ["helm", "shield", "armour"], "attack_after": 0.0, "attack_needs": [],
	},
	"rush": {
		"title": "Натиск", "about": "Рано и часто нападает дешёвыми бойцами: копейщики, воины, секироносцы, лазутчики и поджигатели. Башен не строит.",
		"think": 2.0, "hires": 3,
		"workers_first": {"wood": 2, "ore": 1}, "workers_full": {"wood": 4, "ore": 2}, "gold_hands": 0,
		"first_wave": 3, "wave_growth": 1, "wave_max": 10, "spent_at": 0,
		"home_guard": 260.0, "counter_share": 0.3,
		"studies": ["spears", "axes", "forging", "daggers", "fire"],
		"mix": {"spearman": 3.0, "warrior": 2.0, "axeman": 2.0, "archer": 1.0, "scout": 1.0, "torchbearer": 1.0},
		"towers": 0, "towers_early": false, "library_after": 5, "library_after_wave": true,
		"gear": ["shield", "helm"], "attack_after": 0.0, "attack_needs": [],
	},
	"turtle": {
		"title": "Оборона", "about": "Сидит за башнями, лучниками, арбалетчиками и магами. Выходит поздно и большой армией.",
		"think": 2.0, "hires": 2,
		"workers_first": {"wood": 2, "ore": 2}, "workers_full": {"wood": 5, "ore": 3}, "gold_hands": 1,
		"first_wave": 8, "wave_growth": 2, "wave_max": 14, "spent_at": 3,
		"home_guard": 450.0, "counter_share": 0.8,
		"studies": ["archery", "mail", "forging", "crossbows", "spears", "magic", "healing", "chivalry"],
		"mix": {"crossbowman": 3.0, "archer": 3.0, "spearman": 2.0, "mage": 1.5, "knight": 1.0},
		"towers": 4, "towers_early": true, "library_after": 3,
		"gear": ["helm", "armour", "shield"], "attack_after": 480.0, "attack_needs": [],
	},
	"tech": {
		"title": "Знания", "about": "Копит, строит хозяйство и учится. Идёт в бой рыцарями, двуручниками, арбалетчиками и магами, когда всё изучит.",
		"think": 2.0, "hires": 2,
		"workers_first": {"wood": 2, "ore": 2}, "workers_full": {"wood": 6, "ore": 4}, "gold_hands": 2,
		"first_wave": 6, "wave_growth": 2, "wave_max": 12, "spent_at": 1,
		"home_guard": 300.0, "counter_share": 0.5,
		"studies": ["forging", "chivalry", "mail", "blades", "greatswords", "archery", "crossbows", "magic", "healing"],
		"mix": {"knight": 4.0, "greatsword": 2.0, "crossbowman": 2.0, "mage": 1.5, "archer": 1.0},
		"towers": 1, "towers_early": true, "library_after": 3,
		"gear": ["armour", "helm", "shield"], "attack_after": 0.0, "attack_needs": ["chivalry", "forging"],
	},
}

const DIFFICULTIES := {
	"easy": {"title": "Лёгкий", "about": "Думает медленно, армии меньше, не контратакует, учится немногому."},
	"normal": {"title": "Обычный", "about": "Играет свою стратегию как есть."},
	"hard": {"title": "Сложный", "about": "Быстро решает, больше рабочих и войск, бережёт уцелевших."},
}

## The strategy and difficulty put together. "random" picks a strategy.
static func make(strategy: String, difficulty: String) -> Dictionary:
	if strategy == "random" or not STRATEGIES.has(strategy):
		strategy = STRATEGIES.keys()[randi() % STRATEGIES.size()]
	var plan: Dictionary = STRATEGIES[strategy].duplicate(true)
	plan["strategy"] = strategy
	plan["difficulty"] = difficulty if DIFFICULTIES.has(difficulty) else "normal"
	match plan["difficulty"]:
		"easy":
			plan["think"] = float(plan["think"]) * 1.8
			plan["hires"] = 1
			for trade in plan["workers_full"]:
				plan["workers_full"][trade] = maxi(1, int(plan["workers_full"][trade]) - 1)
			plan["wave_max"] = maxi(3, roundi(float(plan["wave_max"]) * 0.6))
			plan["first_wave"] = maxi(2, int(plan["first_wave"]) - 1)
			plan["counter_share"] = 99.0
			plan["studies"] = (plan["studies"] as Array).slice(0, 3)
			plan["towers"] = maxi(0, int(plan["towers"]) - 1)
			plan["attack_after"] = float(plan["attack_after"]) + 180.0
		"hard":
			plan["think"] = float(plan["think"]) * 0.6
			plan["hires"] = int(plan["hires"]) + 1
			for trade in plan["workers_full"]:
				plan["workers_full"][trade] = int(plan["workers_full"][trade]) + 1
			plan["wave_max"] = int(plan["wave_max"]) + 3
			plan["spent_at"] = int(plan["spent_at"]) + 1
			plan["attack_after"] = float(plan["attack_after"]) * 0.75
			if int(plan["towers"]) > 0:
				plan["towers"] = int(plan["towers"]) + 1
	return plan

static func title(strategy: String) -> String:
	return STRATEGIES[strategy]["title"] if STRATEGIES.has(strategy) else "Случайная"
