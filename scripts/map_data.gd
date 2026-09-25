class_name MapData
extends Resource
## A map as data rather than as a scene: the floor, where the trees and seams
## are, and where each side sets up. MapBuilder turns one of these into a match,
## so another map is another .tres in resources/maps/, not another scene.

@export var title := "Skirmish"
@export var floor_size := Vector2(900.0, 560.0)
@export var tree_positions: Array[Vector2] = []
@export var vein_positions: Array[Vector2] = []
@export var gold_positions: Array[Vector2] = []
## Great rocks that nothing can be done with but walk round: walls of a gorge.
@export var boulder_positions: Array[Vector2] = []
## How long a felled tree takes to grow back, and a spent seam to refill; 0 is never.
## How rich the seams are and how much a tree gives: rocks per seam, each rock's
## worth, beams per tree.
@export var ore_rocks := 3
@export var ore_rock_worth := 1
@export var gold_rocks := 3
@export var gold_rock_worth := 1
@export var tree_logs := 2
@export var log_worth := 1
@export var regrow_time := 0.0
@export var refill_time := 0.0
@export var player: SideLayout
@export var enemy: SideLayout

func sides() -> Array[SideLayout]:
	var both: Array[SideLayout] = []
	for side in [player, enemy]:
		if side != null:
			both.append(side)
	return both
