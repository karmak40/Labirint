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

## How well it goes about its strategy. Every number is here, so the levels
## are balanced in one place:
##   think         × seconds between thoughts (slower is weaker)
##   hires_cap     at most this many hires a thought (0 for the strategy's own)
##   hires_bonus   + hires a thought
##   hands         labourers more (+) or fewer (-) on each trade at full strength
##   waves         × the biggest wave;  wave_bonus  + to it after that
##   first_wave    + to the first wave
##   spent_bonus   + to how many left counts as spent (pulls back sooner)
##   counter       whether it strikes back after beating off an attack
##   studies       how many of its studies it gets to (0 for all)
##   towers        + towers
##   attack_later  seconds added before its first attack;  attack_scale  × that time
##   react         seconds it takes to notice someone at its walls
##   muster        seconds a ready wave waits before it goes
##   retreat       seconds a spent wave fights on before it is called back
##   study_pause   seconds between one study finishing and the next begun
## No level cheats: every one plays by the same rules and pays the same prices.
const DIFFICULTIES := {
	"easy": {"title": "Лёгкий", "about": "Думает медленно, долго собирается, армии меньше, не контратакует, учится немногому.",
		"think": 1.8, "hires_cap": 1, "hires_bonus": 0, "hands": -1, "waves": 0.6, "wave_bonus": 0, "first_wave": -1, "spent_bonus": 0,
		"counter": false, "studies": 3, "towers": -1, "attack_later": 180.0, "attack_scale": 1.0,
		"react": 4.0, "muster": 20.0, "retreat": 6.0, "study_pause": 30.0},
	"normal": {"title": "Обычный", "about": "Играет свою стратегию, но не спешит: реагирует и собирается с задержкой.",
		"think": 1.3, "hires_cap": 0, "hires_bonus": 0, "hands": 0, "waves": 0.85, "wave_bonus": 0, "first_wave": 0, "spent_bonus": 0,
		"counter": true, "studies": 0, "towers": 0, "attack_later": 60.0, "attack_scale": 1.0,
		"react": 2.0, "muster": 10.0, "retreat": 3.0, "study_pause": 12.0},
	"hard": {"title": "Сложный", "about": "Быстро решает, больше рабочих и войск, бережёт уцелевших.",
		"think": 0.6, "hires_cap": 0, "hires_bonus": 1, "hands": 1, "waves": 1.0, "wave_bonus": 3, "first_wave": 0, "spent_bonus": 1,
		"counter": true, "studies": 0, "towers": 1, "attack_later": 0.0, "attack_scale": 0.75,
		"react": 0.5, "muster": 3.0, "retreat": 0.0, "study_pause": 0.0},
}

## The strategy and difficulty put together. "random" picks a strategy.
static func make(strategy: String, difficulty: String) -> Dictionary:
	if strategy == "random" or not STRATEGIES.has(strategy):
		strategy = STRATEGIES.keys()[randi() % STRATEGIES.size()]
	var plan: Dictionary = STRATEGIES[strategy].duplicate(true)
	plan["strategy"] = strategy
	plan["difficulty"] = difficulty if DIFFICULTIES.has(difficulty) else "normal"
	var level: Dictionary = DIFFICULTIES[plan["difficulty"]]
	plan["think"] = float(plan["think"]) * float(level["think"])
	plan["hires"] = int(plan["hires"]) + int(level["hires_bonus"])
	if int(level["hires_cap"]) > 0:
		plan["hires"] = mini(int(plan["hires"]), int(level["hires_cap"]))
	for trade in plan["workers_full"]:
		plan["workers_full"][trade] = maxi(1, int(plan["workers_full"][trade]) + int(level["hands"]))
	plan["wave_max"] = maxi(3, roundi(float(plan["wave_max"]) * float(level["waves"]))) + int(level["wave_bonus"])
	plan["first_wave"] = maxi(2, int(plan["first_wave"]) + int(level["first_wave"]))
	plan["spent_at"] = int(plan["spent_at"]) + int(level["spent_bonus"])
	if not bool(level["counter"]):
		plan["counter_share"] = 99.0
	if int(level["studies"]) > 0:
		plan["studies"] = (plan["studies"] as Array).slice(0, int(level["studies"]))
	if int(plan["towers"]) > 0 or int(level["towers"]) < 0:
		plan["towers"] = maxi(0, int(plan["towers"]) + int(level["towers"]))
	plan["attack_after"] = float(plan["attack_after"]) * float(level["attack_scale"]) + float(level["attack_later"])
	for delay in ["react", "muster", "retreat", "study_pause"]:
		plan[delay] = float(level[delay])
	return plan

static func title(strategy: String) -> String:
	return STRATEGIES[strategy]["title"] if STRATEGIES.has(strategy) else "Случайная"
