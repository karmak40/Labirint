class_name Market
extends Building
## Where one good is traded for another. Each side's market has its own
## prices (PlayerState.prices): a deal is worth what the goods are worth right
## now, less a cut (FEE), and every deal moves the prices -- what is sold gets
## cheaper, what is bought dearer -- so a side that sells the same thing over
## and over gets less for it each time. Left alone, the prices drift back to
## what they were (PlayerState._settle_prices). One to a side
## (GameState.BUILDINGS); the command is GameState.trade(team, deal).

## Each deal: which good is given and how much of it, and which is got.
const DEALS := {
	"wood_ore": {"give": "wood", "lot": 20, "get": "ore"},
	"ore_wood": {"give": "ore", "lot": 20, "get": "wood"},
	"wood_gold": {"give": "wood", "lot": 40, "get": "gold"},
	"ore_gold": {"give": "ore", "lot": 40, "get": "gold"},
	"gold_wood": {"give": "gold", "lot": 10, "get": "wood"},
	"gold_ore": {"give": "gold", "lot": 10, "get": "ore"},
}
## What each good is worth when nobody has been trading.
const BASE_PRICE := {"wood": 1.0, "ore": 1.0, "gold": 3.2}
const FEE := 0.6               ## the share of the value that comes back
const STEP := 0.08             ## how much one deal moves both prices
const LOW := 0.35              ## prices stay within these shares of the base
const HIGH := 2.5
const RECOVER := 0.012         ## the share of the way back to the base covered a second

## What a deal would take and give at `prices`: {"give": {..}, "get": {..}}.
static func quote(deal: String, prices: Dictionary) -> Dictionary:
	var entry: Dictionary = DEALS[deal]
	var worth := float(entry["lot"]) * float(prices[entry["give"]])
	var got := int(floor(worth / float(prices[entry["get"]]) * FEE))
	return {"give": {entry["give"]: int(entry["lot"])}, "get": {entry["get"]: got}}

## And what it gives when the prices are where they settle.
static func usual(deal: String) -> int:
	var entry: Dictionary = DEALS[deal]
	return int(quote(deal, BASE_PRICE)["get"][entry["get"]])

## Makes a deal at `prices` out of `store`, and moves the prices. False, and
## nothing taken, if it can not (or it would give nothing back).
func trade(deal: String, store: Economy, prices: Dictionary) -> bool:
	if not is_alive() or not is_complete() or store == null or not DEALS.has(deal):
		return false
	var entry: Dictionary = DEALS[deal]
	var offer := quote(deal, prices)
	if int(offer["get"][entry["get"]]) < 1 or not store.spend(offer["give"]):
		return false
	store.add(entry["get"], int(offer["get"][entry["get"]]))
	var sold: String = entry["give"]
	var bought: String = entry["get"]
	prices[sold] = maxf(float(BASE_PRICE[sold]) * LOW, float(prices[sold]) * (1.0 - STEP))
	prices[bought] = minf(float(BASE_PRICE[bought]) * HIGH, float(prices[bought]) * (1.0 + STEP))
	return true

const PLANK := Color(0.55, 0.41, 0.26)
const PLANK_DARK := Color(0.38, 0.27, 0.16)
const AWNINGS := [Color(0.80, 0.30, 0.25), Color(0.90, 0.78, 0.40), Color(0.35, 0.55, 0.75)]
const STRIPE := Color(0.96, 0.93, 0.85)
const GOODS := [Color(0.52, 0.39, 0.25), Color(0.58, 0.57, 0.54), Color(0.98, 0.80, 0.22)]

const STALL_TALL := 22.0
const AWNING_TALL := 14.0

func _init() -> void:
	health_max = 450.0
	footprint = Vector2(84.0, 30.0)
	bar_height = 64.0
	bar_width = 70.0

func _ready() -> void:
	super()
	add_to_group("markets")

func debris_colors() -> Array[Color]:
	return [PLANK, PLANK_DARK, STRIPE]

func _draw_standing() -> void:
	var w := footprint.x * 0.5
	var foot := footprint.y * 0.5
	# three stalls side by side, each under its own striped awning, with its goods
	for i in 3:
		var x := -w + w * 2.0 * float(i) / 3.0
		var wide := w * 2.0 / 3.0 - 4.0
		var top := foot - STALL_TALL
		draw_rect(Rect2(x + 2.0, top + 6.0, wide, STALL_TALL - 6.0), _tint(PLANK))
		draw_rect(Rect2(x + 2.0, top + 6.0, wide, STALL_TALL - 6.0), PLANK_DARK, false, 1.2)
		draw_line(Vector2(x + 3.0, top), Vector2(x + 3.0, foot), PLANK_DARK, 2.0)
		draw_line(Vector2(x + wide + 1.0, top), Vector2(x + wide + 1.0, foot), PLANK_DARK, 2.0)
		var awning := PackedVector2Array([Vector2(x, top + 2.0), Vector2(x + 6.0, top - AWNING_TALL),
			Vector2(x + wide - 2.0, top - AWNING_TALL), Vector2(x + wide + 4.0, top + 2.0)])
		draw_colored_polygon(awning, _tint(AWNINGS[i]))
		for s in 3:
			var sx := x + 6.0 + (wide - 8.0) * (float(s) + 0.5) / 3.0
			draw_line(Vector2(sx - 1.0, top + 2.0), Vector2(sx + 1.5, top - AWNING_TALL), STRIPE, 2.0)
		# a heap of what it sells on the counter
		for g in 3:
			draw_circle(Vector2(x + 8.0 + g * 6.0, top + 5.0), 3.2, GOODS[i])
	draw_circle(Vector2(0.0, foot - STALL_TALL - AWNING_TALL - 6.0), 4.0, Team.color(team))
