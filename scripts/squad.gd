class_name Squad
extends Node
## A handful of units told the same thing at once. This, plus hiring, is the
## whole vocabulary a side has for its army: plain points in, nothing about
## mice or keys, so whoever is giving the orders -- a HUD, an AI, one day a
## remote player -- says it the same way.

var units: Array[Unit] = []

func add(unit: Unit) -> void:
	if unit != null and not units.has(unit):
		units.append(unit)
		unit.tree_exiting.connect(remove.bind(unit))

func remove(unit: Unit) -> void:
	units.erase(unit)

## The ones still standing: the dead keep their place on the floor, not in the ranks.
func alive() -> Array[Unit]:
	var standing: Array[Unit] = []
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive():
			standing.append(unit)
	return standing

## Everyone to `point`, each to a place of his own round it, so the ranks
## stand still instead of shoving for one spot.
func rally(point: Vector2) -> void:
	var ranks := alive()
	var places := _deal(ranks, point)
	for i in ranks.size():
		ranks[i].set_rally(places[i])

func attack_move(point: Vector2) -> void:
	var ranks := alive()
	var places := _deal(ranks, point)
	for i in ranks.size():
		ranks[i].set_attack_move(places[i])

## Places for `ranks` round `point`, in the same order as `ranks`. Those in
## front take the far places and those behind the near ones, so nobody has to
## get through men already standing to reach his own.
func _deal(ranks: Array[Unit], point: Vector2) -> Array[Vector2]:
	var places := places_near(point, ranks.size(), [])
	if ranks.is_empty():
		return places
	var middle := Vector2.ZERO
	for unit in ranks:
		middle += unit.global_position
	middle /= float(ranks.size())
	var along := (point - middle).normalized()
	if along == Vector2.ZERO:
		along = Vector2.RIGHT
	var order := range(ranks.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return ranks[a].global_position.dot(along) > ranks[b].global_position.dot(along))
	var deep := places.duplicate()
	deep.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.dot(along) > b.dot(along))
	var dealt: Array[Vector2] = []
	dealt.resize(ranks.size())
	for i in order.size():
		dealt[order[i]] = deep[i]
	return dealt

## A free place round `point` for one more man (a new recruit), clear of
## where the others already hold: the nearest the point, leaning to his own
## side of it, so he stops at the edge of the ranks rather than going through.
func place_for(unit: Unit, point: Vector2) -> Vector2:
	var taken: Array[Vector2] = []
	for other in alive():
		if other != unit and other.order == Unit.Order.HOLD:
			taken.append(other.post)
	var free := places_near(point, 6, taken)
	var best := free[0]
	var best_score := INF
	for place in free:
		var score := place.distance_to(point) + LEAN * place.distance_to(unit.global_position)
		if score < best_score:
			best_score = score
			best = place
	return best

# --- places in the ranks ---------------------------------------------------------

## between neighbours, across and front to back: a man is 28 px wide, so
## this leaves room to walk between the ranks
const SPACING := Vector2(42.0, 36.0)
const GRID := 12                        ## rows and columns each way from the point
const LEAN := 0.6                       ## how much a recruit prefers his own side of the ranks

static var _offsets: Array[Vector2] = []

## Offsets round a point, nearest first, on staggered rows, a little wider than
## deep, since the field is long and narrow.
static func _grid() -> Array[Vector2]:
	if _offsets.is_empty():
		for row in range(-GRID, GRID + 1):
			for column in range(-GRID, GRID + 1):
				var stagger := 0.5 if row % 2 != 0 else 0.0
				_offsets.append(Vector2((column + stagger) * SPACING.x, row * SPACING.y))
		_offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			return a.length_squared() < b.length_squared())
	return _offsets

## `count` places round `point`, nearest first: on open floor, not in or in
## front of a building, and clear of the places in `taken`. Outside a match
## (no floor plan, the testbed) everyone simply gets the point itself.
func places_near(point: Vector2, count: int, taken: Array[Vector2]) -> Array[Vector2]:
	var places: Array[Vector2] = []
	if not is_inside_tree() or not Pen.crowd_mode:
		for i in count:
			places.append(point)
		return places
	var map := get_viewport().world_2d.navigation_map
	var has_floor := map.is_valid() and not NavigationServer2D.map_get_regions(map).is_empty()
	var near := minf(SPACING.x, SPACING.y) * 0.8
	for offset in _grid():
		if places.size() >= count:
			break
		var place := point + offset
		if has_floor and NavigationServer2D.map_get_closest_point(map, place).distance_to(place) > 3.0:
			continue
		if Building.clear_of(get_tree(), place).distance_to(place) > 0.5:
			continue
		var crowded := false
		for other in taken:
			if other.distance_to(place) < near:
				crowded = true
				break
		if crowded:
			continue
		places.append(place)
		taken.append(place)
	# a point walled in on every side: the rest share it, as before
	while places.size() < count:
		places.append(point)
	return places

