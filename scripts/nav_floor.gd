class_name NavFloor
extends NavigationRegion2D
## The walkable floor, as far as finding a way across it goes.
##
## Everything that stands in the way out here already says so with a static
## body -- a trunk, a stump, a vein, a wall, later a building -- so the floor
## does not need a second list of obstacles. It bakes a mesh from the floor
## rectangle minus those bodies, grown by a body's width so a path never hugs a
## trunk closer than a shoulder can pass.
##
## One bake once the map has stood itself up. Things out here only ever shrink
## (a tree becomes a stump, a vein runs out), so a stale mesh is merely a touch
## cautious, never wrong. Anything that adds a new obstacle calls `rebake()`.

const SOURCE_GROUP := &"nav_source"

@export var floor_size := Vector2(900.0, 560.0)
@export var agent_radius := 16.0   ## a body is 14 across the middle, and a little to spare

func _ready() -> void:
	var mesh := NavigationPolygon.new()
	mesh.add_outline(PackedVector2Array([
		Vector2.ZERO, Vector2(floor_size.x, 0.0), floor_size, Vector2(0.0, floor_size.y)]))
	mesh.agent_radius = agent_radius
	mesh.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.source_geometry_group_name = SOURCE_GROUP
	navigation_polygon = mesh
	# the whole map is the source: whatever static bodies are under it are in the way
	var map_root := get_parent()
	if map_root != null:
		map_root.add_to_group(SOURCE_GROUP)
	# trees and veins make their blockers in their own _ready, which may come after ours
	rebake.call_deferred()

## `on_thread`: work it out in the background, for a building put up mid-match
## -- the old mesh stays in use until the new one is ready.
func rebake(on_thread := false) -> void:
	if is_baking():
		# already at it: go again once that finishes, with whatever is new since
		if not bake_finished.is_connected(_rebake_after):
			bake_finished.connect(_rebake_after, CONNECT_ONE_SHOT)
		return
	bake_navigation_polygon(on_thread)

func _rebake_after() -> void:
	rebake(true)
