extends "res://tests/lib/test_case.gd"
## Buildings show the blows they take and come down when they fall (user
## request): a blow knocks chips off the face that was struck, they fly towards
## the striker, land, lie a while and go; the walls wear (cracks, then holes,
## then smoke); the last blow starts a collapse with a burst of debris and a
## dust cloud; the ruin blocks from the first moment and `destroyed` fires once.
## The castle shows its wear on its own faces (wall, towers, keep).

var stage := 0
var tower: Tower
var falls := 0
var striker := Vector2.ZERO

func begin() -> void:
	time_limit = 60 * 40
	change_scene_to_file("res://scenes/main/Skirmish.tscn")

func step() -> bool:
	match stage:
		0:
			if not playing():
				return false
			silence(Team.Id.ENEMY)
			tower = Tower.new()
			tower.team = Team.Id.ENEMY
			tower.position = Vector2(900, 300)
			game().field().add_child(tower)
			tower.destroyed.connect(func(_b: Building) -> void: falls += 1)
			striker = tower.global_position + Vector2(-60, 40)
			stage = 1
			frame = 0
		1:
			if frame == 2:
				tower.take_hit(striker, 20.0)
				check(tower.shards.size() >= 2, "a blow knocks chips off", tower.shards.size())
				var toward := 0
				for shard in tower.shards:
					if shard.vel.x < 0.0:
						toward += 1
				check(toward * 2 >= tower.shards.size(), "they fly mostly towards the striker",
					"%d of %d" % [toward, tower.shards.size()])
			if frame == 60 * 2:
				var resting := 0
				var near := 0
				for shard in tower.shards:
					if shard.resting >= 0.0 and is_zero_approx(shard.z):
						resting += 1
					if shard.at.length() < 160.0:
						near += 1
				check(tower.shards.size() > 0 and resting == tower.shards.size(), "they fall and lie on the ground",
					"%d of %d" % [resting, tower.shards.size()])
				check(near == tower.shards.size(), "close by the tower", near)
			if frame == int(60 * (Building.SHARD_REST + 2.5)):
				check(tower.shards.is_empty(), "and after a while they are gone", tower.shards.size())
				# worn down step by step, it smokes past half
				while tower.wear() < 0.7:
					tower.take_hit(striker, 10.0)
				check(tower.is_alive() and tower.wear() >= Building.SMOKE_FROM, "badly worn, still standing", tower.wear())
				check(tower.shards.size() <= tower._shards_max(), "chips are capped", tower.shards.size())
				# the last blow
				tower.take_hit(striker, 10000.0)
				check(not tower.is_alive(), "the last blow brings it down at once")
				check(tower.collapse >= 0.0, "and it starts to come down")
				check(tower.shards.size() >= 10, "in a burst of debris", tower.shards.size())
				check(_still_blocks(tower), "the ruin blocks from the first moment")
				stage = 2
				frame = 0
		2:
			if frame == 30:
				check(tower.collapse > 0.3 and tower.collapse < Building.COLLAPSE_TIME, "half a second in, it is still falling", tower.collapse)
			if frame == int(60 * (Building.DUST_CLOUD_TIME + 0.5)):
				check(tower.collapse >= Building.DUST_CLOUD_TIME, "the fall and the dust are over", tower.collapse)
				check(falls == 1, "`destroyed` fired once", falls)
				tower.take_hit(striker, 50.0)
				check(falls == 1 and tower.collapse >= Building.DUST_CLOUD_TIME, "a blow on the ruin does nothing")
				check(_still_blocks(tower), "the ruin still blocks")
				# the castle wears on its own faces
				var castle: Building = game().side(Team.Id.ENEMY).base()
				var faces := castle.damage_faces()
				check(faces.size() == 4, "the castle has a wall, two towers and a keep", faces.size())
				var foot := 0.0
				for face in faces:
					foot = maxf(foot, face.end.y)
				check(is_equal_approx(foot, castle.footprint.y * 0.5), "standing on its front", foot)
				castle.take_hit(castle.global_position + Vector2(-400, 40), 30.0)
				var left_side := 0
				for shard in castle.shards:
					if shard.at.x < 0.0:
						left_side += 1
				check(castle.shards.size() > 0 and left_side == castle.shards.size(),
					"a blow from the west chips the west end", "%d of %d" % [left_side, castle.shards.size()])
				return true
	return false

func _still_blocks(building: Building) -> bool:
	for child in building.get_children():
		var shape := child as CollisionShape2D
		if shape != null and not shape.disabled:
			return true
	return false
