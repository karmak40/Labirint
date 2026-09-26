class_name Draft
extends RefCounted
## One soldier on order: a man hired at the castle for it, the pieces the
## forge makes for it, and where the two of them have got to. The man walks the
## whole chain himself -- to the forge for his arms, to the barracks with them
## -- and the draft is done with once the barracks takes him in to train.

enum Stage {
	HIRING,    ## the castle has still to turn the man out
	ARMING,    ## on his way to the forge, or waiting there for his pieces
	CARRYING,  ## armed, on his way to the barracks
}

var side: PlayerState
var kind := ""                 ## what he is to become (ProductionBuilding.CATALOG)
var needs: Array[String] = []  ## the pieces he has to collect (Forge.GEAR)
var man: Worker = null
var stage := Stage.HIRING

func _init(owner: PlayerState, soldier: String) -> void:
	side = owner
	kind = soldier
	for item in ProductionBuilding.CATALOG[soldier].get("arms", []):
		if Forge.GEAR.has(item):
			needs.append(item)

## The weapon he carries once armed, for the rig to draw in his hands.
func carried_weapon() -> int:
	if needs.has("sword") and needs.has("shield"):
		return PlayerBody.Weapon.SWORD_SHIELD
	for item in ProductionBuilding.CATALOG[kind].get("arms", []):
		if Forge.GEAR.has(item) and Forge.GEAR[item].has("weapon"):
			return Forge.GEAR[item]["weapon"]
		if item == "club":
			return PlayerBody.Weapon.CLUB
	return PlayerBody.Weapon.NONE
