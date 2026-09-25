class_name Player3DBody
extends CharacterBody3D
## 3D counterpart of the 2D player, for comparing the figure in the round.
##
## Units are metres here rather than pixels, which is why the numbers look
## nothing like the 2D ones while describing the same motion: 50px = 1m, so the
## figure is ~1.8m tall, runs at 3.3m/s and covers 2.2m per stride -- real human
## figures, which is what the 2D version was tuned to in disguise.

const SPEED := 3.3
const ACCELERATION := 28.0
const JUMP_SPEED := 5.4
const GRAVITY := 18.0

func _physics_process(delta: float) -> void:
	var wish := _input_direction() * SPEED
	velocity.x = move_toward(velocity.x, wish.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, wish.z, ACCELERATION * delta)

	if is_on_floor():
		velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or not key.pressed:
		return
	if key.physical_keycode == KEY_SPACE:
		jump()

func jump() -> void:
	if is_grounded():
		velocity.y = JUMP_SPEED

func is_grounded() -> bool:
	return is_on_floor()

## Movement across the floor only, with the jump taken out of it.
func planar_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)

func _input_direction() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.z += 1.0
	return dir.normalized() if dir.length() > 0.0 else dir
