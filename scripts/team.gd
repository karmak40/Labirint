class_name Team
## Which side something is on. Only the deciding cares: a blow lands on whatever
## it lands on, and it is the head behind the sword that picks who to go for.

enum Id { NEUTRAL, PLAYER, ENEMY }

## Neutral is nobody's enemy -- straw, sheep and anything that never said.
static func hostile(a: int, b: int) -> bool:
	return a != Id.NEUTRAL and b != Id.NEUTRAL and a != b

## Same declared side. Neutral is nobody's ally either, so straw still gets hit.
static func allied(a: int, b: int) -> bool:
	return a != Id.NEUTRAL and a == b

## Banner colour, for flags and markings.
static func color(id: int) -> Color:
	match id:
		Id.PLAYER:
			return Color(0.26, 0.47, 0.82)
		Id.ENEMY:
			return Color(0.80, 0.25, 0.22)
	return Color(0.62, 0.62, 0.60)

## A flat ring in the side's colour round a body's feet, so two armies of the
## same figures can be told apart at a glance. Drawn on the floor, under the rig.
static func draw_foot_ring(canvas: CanvasItem, id: int) -> void:
	if id == Id.NEUTRAL:
		return
	var tint := color(id)
	canvas.draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.42))
	canvas.draw_circle(Vector2.ZERO, 15.0, Color(tint, 0.28))
	canvas.draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 28, Color(tint, 0.9), 2.2, true)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Where to aim at a target from `from`: the nearest point of a wall for anything
## big enough to have one (a castle is struck where you stand, not at its middle),
## the target's own position for everything else.
static func spot(target: Node2D, from: Vector2) -> Vector2:
	if target.has_method("nearest_point"):
		return target.nearest_point(from)
	return target.global_position

## The side of anything in "targets", including the ones that never declared one.
static func of(node: Object) -> int:
	if node != null and node.has_method("team_of"):
		return node.team_of()
	return Id.NEUTRAL
