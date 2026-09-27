class_name Trophy
extends Carriable
## A piece of a fallen soldier's arms or kit, lying where it came to rest: a
## spear, a sword, a helm, a shield (any Forge.GEAR item). Anyone's labourers
## may carry it to one of their forges, which takes it into the store as if it
## had been made there (Forge._take_trophies). Left lying, it rusts away.

const LIFE := 120.0            ## seconds before it is past saving
const FADE := 10.0             ## and the last of them it fades out over

const IRON := Color(0.72, 0.74, 0.78)
const IRON_DARK := Color(0.38, 0.39, 0.43)
const WOOD := Color(0.52, 0.36, 0.20)
const WOOD_DARK := Color(0.33, 0.22, 0.12)
const STRING := Color(0.85, 0.82, 0.70)
const FLAME := Color(1.0, 0.60, 0.20)
const GEM := Color(0.55, 0.80, 1.0)
const GLINT := Color(1.0, 0.95, 0.75, 0.9)

## Which piece it is (Forge.GEAR).
var item := "sword"
var age := 0.0

func _ready() -> void:
	super()
	add_to_group("trophies")
	grip = Grip.IN_HANDS
	heavy = false
	shadow_radius = 10.0

func _process(delta: float) -> void:
	super(delta)
	if state == State.CARRIED:
		return
	age += delta
	modulate.a = clampf((LIFE - age) / FADE, 0.0, 1.0)
	if age >= LIFE:
		queue_free()

func can_be_taken() -> bool:
	return super() and age < LIFE - FADE

## Whatever angle it fell at, once still it lies flat on the ground.
func _settle() -> void:
	tilt = 0.0 if cos(tilt) >= 0.0 else PI

## The Forge.GEAR item a weapon in hand counts as, or "" for none (a club, tools).
static func item_for(weapon: int) -> String:
	match weapon:
		PlayerBody.Weapon.SWORD, PlayerBody.Weapon.SWORD_SHIELD:
			return "sword"
		PlayerBody.Weapon.SPEAR:
			return "spear"
		PlayerBody.Weapon.BOW:
			return "bow"
		PlayerBody.Weapon.CROSSBOW:
			return "crossbow"
		PlayerBody.Weapon.AXE:
			return "axe"
		PlayerBody.Weapon.GREATSWORD:
			return "greatsword"
		PlayerBody.Weapon.DAGGER:
			return "dagger"
		PlayerBody.Weapon.TORCH:
			return "torch"
		PlayerBody.Weapon.STAFF:
			return "staff"
	return ""

func _draw() -> void:
	_draw_shadow()
	draw_set_transform(Vector2(0.0, -height), tilt, Vector2.ONE)
	match item:
		"sword":
			_blade(18.0, 2.4)
		"greatsword":
			_blade(26.0, 3.2)
		"dagger":
			_blade(10.0, 2.0)
		"spear":
			draw_line(Vector2(-18.0, 0.0), Vector2(14.0, 0.0), WOOD, 2.2)
			draw_colored_polygon(PackedVector2Array([Vector2(13.0, -3.0), Vector2(22.0, 0.0), Vector2(13.0, 3.0)]), IRON)
		"axe":
			draw_line(Vector2(-14.0, 0.0), Vector2(12.0, 0.0), WOOD, 2.4)
			draw_colored_polygon(PackedVector2Array([Vector2(7.0, -1.0), Vector2(15.0, -8.0), Vector2(17.0, 3.0), Vector2(8.0, 2.0)]), IRON)
		"bow":
			draw_arc(Vector2(0.0, 5.0), 14.0, PI + 0.5, TAU - 0.5, 14, WOOD, 2.2, true)
			draw_line(Vector2(-12.2, -1.8), Vector2(12.2, -1.8), STRING, 1.0)
		"crossbow":
			draw_line(Vector2(-12.0, 0.0), Vector2(10.0, 0.0), WOOD, 3.0)
			draw_arc(Vector2(8.0, 0.0), 9.0, -PI * 0.5 - 0.9, -PI * 0.5 + 0.9, 8, IRON_DARK, 2.0, true)
			draw_arc(Vector2(8.0, 0.0), 9.0, PI * 0.5 - 0.9, PI * 0.5 + 0.9, 8, IRON_DARK, 2.0, true)
		"torch":
			draw_line(Vector2(-10.0, 0.0), Vector2(8.0, 0.0), WOOD, 2.6)
			draw_circle(Vector2(10.0, 0.0), 3.4, WOOD_DARK)
			draw_circle(Vector2(11.0, -1.0), 1.8, FLAME)
		"staff":
			draw_line(Vector2(-18.0, 0.0), Vector2(15.0, 0.0), WOOD, 2.2)
			draw_circle(Vector2(17.0, 0.0), 3.2, GEM)
		"helm":
			draw_arc(Vector2(0.0, 2.0), 7.5, PI, TAU, 12, IRON, 5.0, true)
			draw_line(Vector2(-8.5, 2.0), Vector2(8.5, 2.0), IRON_DARK, 2.0)
			draw_line(Vector2(0.0, -6.0), Vector2(0.0, 1.0), IRON_DARK, 1.2)
		"armour":
			var plate := PackedVector2Array([Vector2(-9.0, -8.0), Vector2(9.0, -8.0), Vector2(7.0, 7.0), Vector2(-7.0, 7.0)])
			draw_colored_polygon(plate, IRON)
			plate.append(plate[0])
			draw_polyline(plate, IRON_DARK, 1.2, true)
			draw_line(Vector2(0.0, -8.0), Vector2(0.0, 7.0), IRON_DARK, 1.0)
		"shield":
			draw_set_transform(Vector2(0.0, -height), tilt, Vector2(1.0, 0.75))
			draw_circle(Vector2.ZERO, 9.0, WOOD)
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, IRON_DARK, 1.6, true)
			draw_circle(Vector2.ZERO, 2.4, IRON)
	# a glint, so a piece worth fetching catches the eye among the fallen
	draw_circle(Vector2(2.0, -2.0), 1.1, GLINT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _blade(long: float, wide: float) -> void:
	draw_line(Vector2(-7.0, 0.0), Vector2(-1.0, 0.0), WOOD_DARK, 2.6)
	draw_line(Vector2(-1.0, -4.0), Vector2(-1.0, 4.0), IRON_DARK, 2.0)
	draw_line(Vector2(0.0, 0.0), Vector2(long, 0.0), IRON, wide)
