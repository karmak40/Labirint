extends Node3D
## Volumetric stick figure: the same gait as the 2D walker, solved in 3D.
##
## The animation logic ports across untouched because none of it was ever about
## pixels -- stance foot travelling backwards at exactly body speed so it looks
## planted, stride and cadence, the walk/run blend with its flight phase, the
## constant-length supporting leg that keeps knees from folding, two-bone IK,
## the head trailing the shoulders. What changes is only the presentation: points
## become Vector3, and instead of drawing lines the bones are capsule meshes
## placed between those points every frame.
##
## Being in the round also settles the problem the 2D version had to dodge: the
## figure can both turn to face where it is going and keep a readable gait, so
## there is no need for the side-on cheat or the mirror-flip turn.

const HIP_HEIGHT := 0.78
const SHOULDER_ABOVE_HIP := 0.60
const HEAD_ABOVE_SHOULDER := 0.22
const HEAD_RADIUS := 0.17

const THIGH := 0.44
const SHIN := 0.36
const UPPER_ARM := 0.30
const FOREARM := 0.34

const WALK_SPEED := 1.4
const RUN_SPEED := 3.3

const WALK_STRIDE := 1.2
const RUN_STRIDE := 2.2
const WALK_STANCE := 0.6
const RUN_STANCE := 0.35
const WALK_FOOT_LIFT := 0.14
const RUN_FOOT_LIFT := 0.24
const WALK_LEAN := 0.06
const RUN_LEAN := 0.18
const WALK_ARM_SWING := 0.55
const RUN_ARM_SWING := 0.9
const WALK_ARM_HANG := 0.88
const RUN_ARM_HANG := 0.55

const FLIGHT_BOUNCE := 0.04
const HIP_SMOOTH := 28.0
const ARM_LAG := 0.06
const STANCE_WIDTH := 0.11    ## sideways gap, which 2D could only fake
const IDLE_FOOT_SPLIT := 0.07
const SHOULDER_WIDTH := 0.17

const JUMP_FOOT_TUCK := Vector2(-0.06, 0.24)  ## x along the body, y upwards
const JUMP_HIP_RATIO := 0.85
const JUMP_ARM_HANG := 0.3

const LIMB_RADIUS := 0.055
const TORSO_RADIUS := 0.075

const MOVE_EPSILON := 0.1
const TURN_EASE := 12.0
const IDLE_EASE := 9.0
const AIR_EASE := 20.0
const HEAD_EASE := 24.0

@onready var player: Player3DBody = get_parent() as Player3DBody

var facing := Vector3.FORWARD
var phase := 0.0
var move_amount := 0.0
var air_amount := 0.0
var run_blend := 0.0
var hip_height := HIP_HEIGHT

var stride := WALK_STRIDE
var stance_fraction := WALK_STANCE
var foot_lift := WALK_FOOT_LIFT
var lean_amount := WALK_LEAN
var arm_swing := WALK_ARM_SWING
var arm_hang := WALK_ARM_HANG

var hip := Vector3.ZERO
var shoulder := Vector3.ZERO
var near_foot := Vector3.ZERO
var far_foot := Vector3.ZERO
var head_position := Vector3.ZERO
var pose_started := false

var bones := {}
var bone_lengths := {}

func _ready() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.88, 0.90, 0.93)
	skin.roughness = 0.75

	_add_bone("torso", SHOULDER_ABOVE_HIP, TORSO_RADIUS, skin)
	for side in ["near", "far"]:
		_add_bone(side + "_thigh", THIGH, LIMB_RADIUS, skin)
		_add_bone(side + "_shin", SHIN, LIMB_RADIUS, skin)
		_add_bone(side + "_upper_arm", UPPER_ARM, LIMB_RADIUS, skin)
		_add_bone(side + "_forearm", FOREARM, LIMB_RADIUS, skin)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = HEAD_RADIUS
	head_mesh.height = HEAD_RADIUS * 2.0
	head_mesh.material = skin

	var head := MeshInstance3D.new()
	head.name = "head"
	head.mesh = head_mesh
	add_child(head)
	bones["head"] = head

func _add_bone(bone_name: String, length: float, radius: float, material: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0 + 0.001)
	mesh.material = material

	var bone := MeshInstance3D.new()
	bone.name = bone_name
	bone.mesh = mesh
	add_child(bone)

	bones[bone_name] = bone
	bone_lengths[bone_name] = mesh.height

func _process(delta: float) -> void:
	var motion := player.planar_velocity()
	var speed := motion.length()
	var moving := speed > MOVE_EPSILON
	var grounded := player.is_grounded()

	run_blend = _ease(run_blend, clampf(inverse_lerp(WALK_SPEED, RUN_SPEED, speed), 0.0, 1.0), 6.0, delta)
	stride = lerpf(WALK_STRIDE, RUN_STRIDE, run_blend)
	stance_fraction = lerpf(WALK_STANCE, RUN_STANCE, run_blend)
	foot_lift = lerpf(WALK_FOOT_LIFT, RUN_FOOT_LIFT, run_blend)
	lean_amount = lerpf(WALK_LEAN, RUN_LEAN, run_blend)
	arm_swing = lerpf(WALK_ARM_SWING, RUN_ARM_SWING, run_blend)
	arm_hang = lerpf(WALK_ARM_HANG, RUN_ARM_HANG, run_blend)

	if moving:
		facing = facing.slerp(motion / speed, 1.0 - exp(-TURN_EASE * delta)).normalized()
	if moving and grounded:
		phase = fposmod(phase + speed * delta / stride, 1.0)

	move_amount = _ease(move_amount, 1.0 if moving else 0.0, IDLE_EASE, delta)
	air_amount = _ease(air_amount, 0.0 if grounded else 1.0, AIR_EASE, delta)

	_update_pose(delta)

func _ease(current: float, target: float, rate: float, delta: float) -> float:
	return current + (target - current) * (1.0 - exp(-rate * delta))

func _update_pose(delta: float) -> void:
	# the rig sits at the player's feet and the body itself never rotates -- the
	# facing vector does that job -- so poses are built directly in local space,
	# where the floor is y = 0
	var forward := facing
	var right := forward.cross(Vector3.UP).normalized()

	var near_off := _foot_offset(phase, 1.0)
	var far_off := _foot_offset(phase + 0.5, -1.0)

	hip = Vector3.UP * _hip_height(near_off, far_off, delta)
	shoulder = hip + Vector3.UP * SHOULDER_ABOVE_HIP + forward * (lean_amount * move_amount)
	var ideal_head := shoulder + Vector3.UP * HEAD_ABOVE_SHOULDER

	# head trails the shoulders slightly, so the bob rolls up the body
	if pose_started:
		head_position = head_position.lerp(ideal_head, 1.0 - exp(-HEAD_EASE * delta))
	else:
		head_position = ideal_head
		pose_started = true

	near_foot = forward * near_off.x + right * STANCE_WIDTH + Vector3.UP * near_off.y
	far_foot = forward * far_off.x - right * STANCE_WIDTH + Vector3.UP * far_off.y

	# arms swing against the leg on their own side, reading it slightly in the
	# past so they trail rather than mirror
	var near_shoulder := shoulder + right * SHOULDER_WIDTH
	var far_shoulder := shoulder - right * SHOULDER_WIDTH
	var near_hand := _hand_target(near_shoulder, forward, -_foot_offset(phase - ARM_LAG, 1.0).x)
	var far_hand := _hand_target(far_shoulder, forward, -_foot_offset(phase + 0.5 - ARM_LAG, -1.0).x)

	_place("torso", hip, shoulder)
	bones["head"].position = head_position

	# knees bend forwards, elbows backwards, as a body's do
	_place_two_bone("near_thigh", "near_shin", hip + right * STANCE_WIDTH * 0.35, near_foot, THIGH, SHIN, forward)
	_place_two_bone("far_thigh", "far_shin", hip - right * STANCE_WIDTH * 0.35, far_foot, THIGH, SHIN, forward)
	_place_two_bone("near_upper_arm", "near_forearm", near_shoulder, near_hand, UPPER_ARM, FOREARM, -forward)
	_place_two_bone("far_upper_arm", "far_forearm", far_shoulder, far_hand, UPPER_ARM, FOREARM, -forward)

## Foot offset relative to the hip: x runs fore/aft along the body, y upwards.
func _foot_offset(p: float, side: float) -> Vector2:
	var reach := stride * stance_fraction * 0.5
	var walk := Vector2.ZERO

	p = fposmod(p, 1.0)
	if p < stance_fraction:
		# linear travel backwards == stationary on the ground
		walk.x = reach - 2.0 * reach * (p / stance_fraction)
	else:
		var u := (p - stance_fraction) / (1.0 - stance_fraction)
		# end slopes match the stance, so the foot's speed never jumps at toe-off
		# or heel strike; the small overshoot before contact is real gait
		var m := -2.0 * reach * (1.0 - stance_fraction) / stance_fraction
		var u2 := u * u
		var u3 := u2 * u
		walk.x = (2.0 * u3 - 3.0 * u2 + 1.0) * -reach \
			+ (u3 - 2.0 * u2 + u) * m \
			+ (-2.0 * u3 + 3.0 * u2) * reach \
			+ (u3 - u2) * m
		walk.y = foot_lift * pow(sin(PI * u), 1.5)

	var idle := Vector2(side * IDLE_FOOT_SPLIT, 0.0)
	var tuck := Vector2(JUMP_FOOT_TUCK.x + side * IDLE_FOOT_SPLIT, JUMP_FOOT_TUCK.y)
	return idle.lerp(walk, move_amount).lerp(tuck, air_amount)

## Supporting leg holds a constant length and the hip rides over the planted
## foot; letting the hip sink below the leg's reach is what folds knees hard.
func _hip_height(near: Vector2, far: Vector2, delta: float) -> float:
	var support := minf(absf(near.x), absf(far.x))
	var height := sqrt(maxf(0.01, HIP_HEIGHT * HIP_HEIGHT - support * support))

	var half_phase := fposmod(phase, 0.5)
	if stance_fraction < 0.5 and half_phase >= stance_fraction:
		var u := (half_phase - stance_fraction) / (0.5 - stance_fraction)
		height += FLIGHT_BOUNCE * sin(PI * u) * run_blend

	height = lerpf(height, HIP_HEIGHT * JUMP_HIP_RATIO, air_amount)

	# smoothing rounds off the kinks where the supporting foot changes over
	hip_height = _ease(hip_height, height, HIP_SMOOTH, delta)
	return hip_height

func _hand_target(shoulder: Vector3, forward: Vector3, swing: float) -> Vector3:
	var arm_length := UPPER_ARM + FOREARM
	var hang := lerpf(arm_hang, JUMP_ARM_HANG, air_amount)
	return shoulder + forward * (swing * arm_swing * move_amount) - Vector3.UP * (arm_length * hang)

## Places both segments of a limb, with the joint solved by two-bone IK and the
## tip clamped to the limb's reach so nothing visually stretches.
func _place_two_bone(upper: String, lower: String, root: Vector3, tip: Vector3, a: float, b: float, bend: Vector3) -> void:
	var offset := tip - root
	var span: float = clampf(offset.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := offset.normalized() if offset.length() > 0.0001 else Vector3.DOWN
	var reached := root + dir * span

	var x := (span * span + a * a - b * b) / (2.0 * span)
	var h := sqrt(maxf(0.0, a * a - x * x))

	var perp := bend - dir * bend.dot(dir)
	if perp.length() < 0.0001:
		perp = Vector3.UP - dir * Vector3.UP.dot(dir)
	var joint := root + dir * x + perp.normalized() * h

	_place(upper, root, joint)
	_place(lower, joint, reached)

## Stands a capsule between two points: its local +Y is the bone's axis. Any
## small mismatch between the span and the mesh goes into the Y column, so the
## bone stretches exactly to fit rather than falling short of the joint.
func _place(bone_name: String, from: Vector3, to: Vector3) -> void:
	var bone: MeshInstance3D = bones[bone_name]
	var axis := to - from
	var length := axis.length()
	if length < 0.0001:
		bone.position = from
		return

	var y := axis / length
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()

	var fit: float = length / bone_lengths[bone_name]
	bone.transform = Transform3D(Basis(x, y * fit, x.cross(y)), (from + to) * 0.5)
