class_name SideLayout
extends Resource
## Where one side's things stand at the start of a match, and what it starts with.
## Part of a MapData; nothing here does anything on its own.

@export var team: int = Team.Id.PLAYER
@export var base := Vector2.ZERO
@export var barracks := Vector2.ZERO
@export var stockpile := Vector2.ZERO
@export var towers: Array[Vector2] = []
## Where hired soldiers go and stand until told otherwise.
@export var rally := Vector2.ZERO
## One entry per worker already on the field, by trade: "wood", "ore" or "gold".
@export var start_workers: PackedStringArray = PackedStringArray()
## What is in the store on the first frame, e.g. {"wood": 4}.
@export var start_stock: Dictionary = {}
