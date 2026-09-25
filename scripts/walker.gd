extends Node2D
## Upright stick figure with a real gait cycle, blending walk -> run by speed,
## plus an airborne pose for jumping.
##
## Walking and running are genuinely different cycles, not the same one sped up:
## a walk always keeps a foot down (stance > 50% of the cycle), while a run has
## a flight phase with both feet off the ground, a longer stride, higher knees,
## bent swinging arms and more forward lean. Those parameters are interpolated
## by current speed, so accelerating from a standstill reads as walk -> run.
##
## In every gait each foot spends its stance travelling backwards relative to
## the body at exactly the body's speed, which is what makes it look planted --
## the thing that separates walking from sliding.
##
## Smoothness comes from keeping the motion free of discontinuities: the swing
## curve's end slopes match the stance's, the flight arc starts and ends at the
## stance hip height, turning is a continuous squash rather than a mirror flip,
## and the pose is rebuilt every rendered frame rather than every physics tick.

const HIP_HEIGHT := 39.0          # hip height above the ground, legs near straight
const SHOULDER_ABOVE_HIP := 30.0
const HEAD_ABOVE_SHOULDER := 11.0
const NECK_REACH := 14.0           # how far the head may ever get from the shoulders
const HEAD_RADIUS := 9.0

## Segments are deliberately unequal, as a body's are: the knee then sits below
## the leg's midpoint and the elbow above the arm's, which reads far less like a
## symmetrical folding V than equal halves do.
const THIGH := 22.0
const SHIN := 18.0
const UPPER_ARM := 15.0
const FOREARM := 17.0

const WALK_SPEED := 70.0          # gait blend endpoints
const RUN_SPEED := 165.0

const WALK_STRIDE := 60.0         # distance travelled per full cycle
const RUN_STRIDE := 110.0
const WALK_STANCE := 0.6          # share of the cycle a foot is on the ground
const RUN_STANCE := 0.35          # below 0.5 => flight phase, both feet airborne
const WALK_FOOT_LIFT := 7.0
const RUN_FOOT_LIFT := 12.0
const WALK_LEAN := 3.0
const RUN_LEAN := 9.0
const WALK_ARM_SWING := 0.55
const RUN_ARM_SWING := 0.9
const WALK_ARM_HANG := 0.88       # arms hang straight
const RUN_ARM_HANG := 0.55        # hands held high => elbows strongly bent
const FLIGHT_BOUNCE := 2.0        # hip rise between steps while running
const HIP_SMOOTH := 28.0          # ~35ms: rounds off the bob's direction changes

const ARM_LAG := 0.06             # arms trail the legs slightly, as real ones do
const IDLE_FOOT_SPLIT := 4.0

# Standing still. Three separate rhythms, deliberately unrelated to each other:
# a body that breathes, shifts and looks on one shared clock reads as a machine
# idling. All of it is small on purpose -- idle life should be noticed without
# being watched -- and all of it fades the instant anything else happens.
const BREATH_PERIOD := 4.0        # seconds per breath
const BREATH_RISE := 1.2          # px the chest lifts
const BREATH_HEAD := 0.4

const SHIFT_MIN_WAIT := 3.5       # seconds between shifting weight
const SHIFT_MAX_WAIT := 7.0
const SHIFT_TIME := 0.45
const SHIFT_LIFT := 2.5           # how far the foot clears the floor
const SHIFT_RANGE := 3.5          # how far it is set back down
const SHIFT_HIP_DRIFT := 0.35     # hip leans onto the foot still carrying weight

const GLANCE_MIN_WAIT := 4.0      # seconds between looking about
const GLANCE_MAX_WAIT := 9.0
const GLANCE_TIME := 1.4
const GLANCE_REACH := 3.5
const GLANCE_RISE := 1.5
const IDLE_SETTLE := 6.0          # how fast idle motion fades in and out

# Handling a rock. Both hands are committed to it, so neither arm swings and the
# body leans back against the weight out in front -- the same trick the spear
# uses on one side, applied to both. The hand reaches the rock where it actually
# lies rather than at a fixed offset, so the stoop matches the thing being taken.
const CARRY_HAND := Vector2(15.0, 2.0)   # out in front of the chest
const CARRY_SPREAD := 8.0                # hands either side of it
const CARRY_LEAN := -4.0                 # counterweight to what is being held
const CARRY_ARM_DAMP := 0.08
const CARRY_ROCK_LIFT := 3.0             # rock rides a little above the hands

# Carrying something heavy. Not just slower: the whole gait changes shape. Steps
# shorten and both feet stay down longer, because a loaded body will not leave
# the ground; the trunk leans in under the weight; the load rides the shoulder so
# neither arm is free to swing; and the body sinks and labours with each step.
const LOAD_STRIDE := 0.72        # share of the unloaded stride
const LOAD_STANCE := 0.78        # both feet down far longer
const LOAD_LEAN := 7.0
const LOAD_FOOT_LIFT := 0.6      # feet barely clear the floor
const LOAD_ARM_DAMP := 0.12
const LOAD_SINK := 0.94          # rides lower on its legs
const LOAD_EASE := 4.0           # takes a moment to settle into, and out of

# Crouching. A second way of moving rather than a different one: it reshapes the
# same cycle, so every weapon, carry and strike keeps working on top of it. The
# body sinks onto bent knees and pitches forward, the steps shorten right down,
# both feet stay planted far longer, and the feet stop lifting -- which is what
# separates creeping from simply walking slowly.
# Dodge roll. The body tucks into a ball, turns over once and comes up on its
# feet. It has to turn about its own centre: a body that pivots on its toes is
# doing a cartwheel, not a roll, and the difference is obvious at a glance.
const ROLL_EASE := 30.0
const ROLL_TUCK_IN := 0.34       # share of the roll spent gathering into the ball
const ROLL_TUCK_OUT := 0.72      # and where the legs start reaching for the floor
const ROLL_PIVOT := 22.0         # how high above the floor the ball's centre sits
const ROLL_HIP := 0.46           # hip height while tucked, as a share of standing
# The tuck is measured out from the turning point, not up from the feet, because
# what matters is that every part of the body sits inside one radius of it. Laid
# out from the hip instead, the head swung wide and dipped through the floor at
# the bottom of the turn.
const ROLL_HIP_AT := Vector2(-6.0, 6.0)        # seat trailing, low
const ROLL_SHOULDER_AT := Vector2(2.0, -8.0)   # torso folded right down over it
const ROLL_HEAD_AT := Vector2(9.0, -9.0)       # chin on the chest, leading
const ROLL_NEAR_FOOT_AT := Vector2(12.0, 8.0)  # knees up, heels in to the seat
const ROLL_FAR_FOOT_AT := Vector2(9.0, 11.0)
const ROLL_NEAR_HAND_AT := Vector2(10.0, 2.0)  # hands gripping the shins
const ROLL_FAR_HAND_AT := Vector2(7.0, 5.0)

const CROUCH_HIP := 0.62         # hip height, as a share of standing
const CROUCH_TORSO := 0.88       # trunk pitches forward, so it reads shorter
const CROUCH_LEAN := 11.0
const CROUCH_STRIDE := 0.55
const CROUCH_STANCE := 0.72
const CROUCH_FOOT_LIFT := 0.5
const CROUCH_ARM_HANG := 0.74    # arms hang closer in, ready rather than swinging
const CROUCH_ARM_SWING := 0.45
const CROUCH_FOOT_SPLIT := 1.6   # feet set wider, for balance down low
const CROUCH_EASE := 7.0

# Walking backwards. Not a mirrored walk: what keeps a foot looking planted is
# that it travels against the direction of TRAVEL, not against the way the body
# happens to be pointing. Feeding that one signed value through the step is
# nearly the whole of it -- the arms follow the legs, so they reverse for free.
const BACK_STRIDE := 0.7      # shorter steps going backwards
const BACK_EASE := 8.0

const SHOULDER_SPOT := Vector2(-4.0, -6.0)  # where the load rests, above the shoulder
const SHOULDER_TILT := -0.22                # timber sits nose-up across the back
const SHOULDER_HAND := Vector2(4.0, -10.0)  # the hand that steadies it, reaching up

const PICKUP_GRAB := 0.46                # the hand closes here
const PICKUP_CROUCH := 0.52              # deep stoop to floor level
const PICKUP_LEAN := 9.0

const THROW_WIND_END := 0.34
const THROW_RELEASE := 0.52
const THROW_WIND_HAND := Vector2(-13.0, -10.0)
const THROW_THROW_HAND := Vector2(27.0, -16.0)
const THROW_LEAN_BACK := -6.0
const THROW_LEAN_IN := 11.0
const THROW_SPEED := 340.0
const THROW_LIFT := 250.0
const THROW_SPIN := 7.0
const JUMP_FOOT_TUCK := Vector2(-3.0, -12.0)
const JUMP_HIP_RATIO := 0.85
const JUMP_ARM_HANG := 0.3        # arms come up on the jump

const FALL_TIME := 0.7            # time to go from standing to flat on the floor
const FALL_ANGLE := 1.53          # ~88 degrees: lying down
const FALL_EXPONENT := 1.8        # >1 so the topple accelerates like a real fall
const KNEE_COLLAPSE := 0.45       # hip height once the legs have buckled
const IMPACT_BOUNCE := 0.07       # rebound off the floor, as a share of FALL_ANGLE
const IMPACT_DECAY := 9.0
const IMPACT_FREQ := 22.0
const DEATH_FOOT_DRAW := Vector2(-2.0, 0.0)
const DEATH_ARM_HANG := 0.96      # limp, fully extended arms
const DEATH_ARM_SPREAD := 8.0     # and splayed, or the two fall in the same line
const DEATH_EASE := 7.0

# Getting up. Three things happen in order and they overlap: a hand goes down and
# takes the weight, the hips come up over it, and only then do the legs take over
# and straighten. Shortcut any of them and the body simply rotates upright like a
# plank, which is what an instant revive looked like.
const RISE_PLANT := 0.16       ## the hand is down by here and stays down
const RISE_PUSH := 0.34        ## the hips start coming up
const RISE_OVER := 0.72        ## upright but still folded, weight over the feet
const RISE_LIFT := 0.62        ## hand leaves the ground here
const RISE_CROUCH := 0.52      ## how far down the body is at the deepest of it
const RISE_HAND_AHEAD := 20.0  ## where the supporting hand plants, ahead of the feet
const RISE_LEAN := 13.0

# Knocked back by a hit or a shot: an impulse rather than a collapse, so it
# leaves the standing pose at full speed and lands hard on its back.
const SHOT_FALL_TIME := 0.55
const SHOT_FALL_EXPONENT := 0.75  # <1 so the body is thrown away immediately
const SHOT_IMPACT_BOUNCE := 0.11
const SHOT_KNEE_COLLAPSE := 0.62  # legs are kicked out, not buckled under
const SHOT_FOOT := Vector2(9.0, -3.0)
const SHOT_ARM_HANG := -0.88      # negative: arms thrown up past the shoulders
const SHOT_ARM_FLING := 5.0
const SHOT_EASE := 22.0           # snaps into the pose; a collapse eases in
const HEAD_WHIP := 1.3            # px of head lag per rad/s of body rotation
const HEAD_WHIP_LIMIT := 8.0

# Cut down in melee. A shot launches the body; a blade drops it more or less
# where it stands. What marks it out is the jolt of the blow landing -- a
# hard knock through the torso that decays as the body goes over -- rather than
# any turn, which a strictly side-on figure cannot show convincingly.
const CUT_FALL_TIME := 0.62
const CUT_FALL_EXPONENT := 0.9
const CUT_IMPACT_BOUNCE := 0.09
const CUT_KNEE_COLLAPSE := 0.55
const CUT_JOLT := 13.0            # px the torso is knocked back by the blow
const CUT_JOLT_DECAY := 7.0
const CUT_FOOT := Vector2(4.0, -2.0)
const CUT_ARM_SWEEP := 6.0        # arms carried across, not flung overhead
const CUT_ARM_HANG := 0.88

# Axe chop: wind up over the shoulder, then a very short strike window -- the
# whole arc is swept in under a tenth of a second, which is what gives it weight
# -- followed by a slower recovery back to the carrying pose.
const SWING_REST_ANGLE := 1.36     # ~78 deg: arm hanging
const SWING_WIND_ANGLE := -2.18    # ~-125 deg: up and behind
const SWING_HIT_ANGLE := 0.91      # ~52 deg: forward and down
const SWING_WIND_END := 0.32
const SWING_STRIKE_END := 0.46
const SWING_ARM_REACH := 0.92      # share of arm length, so the elbow stays soft
const SWING_GRIP_GAP := 0.76       # second hand sits further down the handle
const SWING_LEAN_BACK := -4.0
const SWING_LEAN_IN := 7.0
const ATTACK_EASE := 18.0

# Taking a hit: the recoil starts at full strength on the very first frame --
# that instant snap is what makes it land -- then rings out and decays.
const HIT_RECOIL := 10.0           # px the torso is driven backwards
const HIT_HIP_RECOIL := 3.0
const HIT_DECAY := 11.0
const HIT_ARM_FLINCH := 7.0
const HIT_FLASH_TIME := 0.11

const AXE_CARRY_ANGLE := -0.56     # ~-32 deg: carried forward and up, clear of the floor
const AXE_HANDLE := 26.0
const CLUB_LENGTH := 27.0
const CLUB_BUTT := 4.0
const CLUB_HEAD := 4.2             # half-width of the heavy end
const CLUB_KNOT := Color(0.30, 0.21, 0.13)
const AXE_BUTT := 6.0              # handle protruding behind the grip
const AXE_HEAD := [                # around the handle tip: x along the handle, y to the blade side
	Vector2(-4.0, 2.0),
	Vector2(-6.0, 9.0),
	Vector2(4.0, 12.0),
	Vector2(6.0, 2.0),
	Vector2(6.0, -3.0),
	Vector2(-4.0, -3.0),
]
const WOOD_COLOR := Color(0.55, 0.42, 0.28)
const STEEL_COLOR := Color(0.72, 0.75, 0.80)
const STEEL_EDGE_COLOR := Color(0.95, 0.96, 0.98)

# Spear thrust. A spear is not a slower axe: it drives straight forward instead
# of sweeping an arc, so the hands travel along the shaft rather than around the
# shoulder, and the shaft levels off at the target instead of rotating through.
# Carrying one also changes the run, because the holding arm can no longer swing.
const SPEAR_LENGTH := 70.0
const SPEAR_BUTT := 10.0           # shaft protruding behind the rear hand
const SPEAR_HEAD_LENGTH := 16.0
const SPEAR_COLLAR := 4.0
const SPEAR_HEAD := [              # symmetric leaf blade, x along the shaft
	Vector2(-2.0, 3.0),
	Vector2(3.0, 4.5),
	Vector2(16.0, 0.0),
	Vector2(3.0, -4.5),
	Vector2(-2.0, -3.0),
]
const SPEAR_CARRY_ANGLE := -0.70   # ~-40 deg: carried high, well clear of the floor
const SPEAR_THRUST_ANGLE := 0.10   # ~+6 deg: angled slightly down, at body height
const SPEAR_GRIP_GAP := 18.0       # spacing of the two hands on the shaft
const SPEAR_GRIP_DROP := 11.0      # shaft runs this far below shoulder height
const SPEAR_READY_REACH := 14.0
const SPEAR_WOUND_REACH := -6.0    # cocked back behind the shoulder
const SPEAR_EXTEND_REACH := 40.0   # driven out; the arm's reach clamps it
const SPEAR_MAX_ARM := 0.97        # never let the grip leave the drawn hand
const SPEAR_WIND_END := 0.32
const SPEAR_THRUST_END := 0.44
const SPEAR_LEAN_BACK := -3.0
const SPEAR_LEAN_IN := 9.0
const SPEAR_CARRY_ARM_DAMP := 0.3  # that arm is busy holding the shaft

# Bow. Different again: nothing is swung at all. The bow arm pushes out while
# the string hand draws back to the jaw, the two hold for an instant, then the
# string is loosed -- it snaps forward in about a twentieth of a second while the
# string hand flies back past the ear, and the arrow leaves as its own object.
const BOW_HALF := 34.0             # limb reach either side of the grip
const BOW_TIP_BACK := 6.0          # tips curve back towards the archer
const BOW_BELLY := 12.0            # how far the limbs bow out towards the target
const BOW_SEGMENTS := 9
const BOW_AIM_ANGLE := -0.12       # ~-7 deg: aimed slightly up, so the shot arcs
const BOW_CARRY_ANGLE := 1.0       # ~57 deg: slung down across the body
const BOW_ARM_CARRY := 4.0
const BOW_ARM_REACH := 28.0        # bow arm pushed out at full draw
const BOW_HAND_DROP := 4.0
const BOW_DRAW_BACK := 16.0        # string hand behind the shoulder, at the jaw
const BOW_FOLLOW_BACK := 26.0      # and past the ear on the follow-through
const BOW_DRAW_END := 0.55
const BOW_HOLD_END := 0.62         # the loose happens here
const BOW_SNAP := 0.06             # share of the cycle the string takes to return
const BOW_LEAN_BACK := -2.0
const BOW_LEAN_IN := 3.0
const BOW_CARRY_ARM_DAMP := 0.5
# Where the bow hand rides when nothing is being shot. Measured from the
# shoulder and deliberately well inside the arm's reach of 32: it is that
# shortfall, and only that, which puts a bend in the elbow. Pinned up against
# the shoulder instead, the arm folds right up and the elbow juts out sideways.
const BOW_CARRY_HAND := Vector2(12.0, 20.0)
const BOW_CARRY_HOLD := 0.78       # some swing is left, so walking still reads

# A crossbow is a stock with a short stiff bow across the nose. Held level in
# both hands, loosed without a pause, and then spanned -- which is the only part
# of using one that takes any time at all.
const XBOW_STOCK := 25.0           # butt to nose
const XBOW_BUTT := 9.0             # how far it runs back past the hand
const XBOW_LIMB := 15.0            # half the span of the prod
const XBOW_PROD_BOW := 7.0         # how far the middle of it bellies forward
const XBOW_TIP_BACK := 4.5         # and how far the tips are swept back again
const XBOW_PROD_STEPS := 7
const XBOW_STIRRUP := 4.8          # the iron loop the foot goes through to span it
const XBOW_LOCK := 5.0             # the nut, where the string is caught
const XBOW_STRING_BACK := 9.0      # string drawn this far behind the nose, when spanned
const XBOW_CARRY_ANGLE := 0.42     # muzzle down while it is only being carried
const XBOW_AIM_ANGLE := -0.06      # and level when it is pointed
const XBOW_CARRY_HAND := Vector2(14.0, 14.0)
const XBOW_OFF_HAND := 13.0        # the free hand steadies the stock this far along
const XBOW_CARRY_HOLD := 0.8
const XBOW_CARRY_ARM_DAMP := 0.4
const XBOW_RAISE_END := 0.30       # up to the shoulder
const XBOW_SHOT := 0.44            # and the trigger goes here
const XBOW_LEAN_BACK := -1.0
const XBOW_LEAN_IN := 4.0
const QUARREL_SPEED := 1020.0      # flatter and faster than a shaft off a bow
const QUARREL_LENGTH := 15.0       # a bolt is a stub next to an arrow, and looks it
const QUARREL_HEAD := 5.0
const XBOW_WOOD := Color(0.40, 0.31, 0.22)
const XBOW_STEEL := Color(0.62, 0.64, 0.68)

# Spanning it: butt on the ground, foot in the stirrup, both hands hauling. The
# body is folded over the work and both arms are busy, which is exactly why it
# is the moment to be caught in.
const SPAN_STOOP_END := 0.24       # down over it
const SPAN_HAUL_END := 0.70        # string comes back, and catches at the end of this
const SPAN_STOOP := 0.55           # how far the body folds down
const SPAN_LEAN := 15.0
const SPAN_HAND_LOW := Vector2(17.0, 30.0)
const SPAN_HAND_BACK := Vector2(6.0, 8.0)
const BOW_STRING_COLOR := Color(0.86, 0.87, 0.90)

const ARROW_LENGTH := 46.0
const ARROW_SPEED := 760.0
const ARROW_GRAVITY := 260.0       # gentle, so the arrow flies flat then drops
const ARROW_DRAG := 30.0
const ARROW_CARRY := 0.15          # share of the archer's own momentum
const ARROW_MAX := 10              # oldest ones are dropped, so they cannot pile up
const ARROW_REACH := 22.0          # how near it has to pass to find a body
const AIM_SHARE := 0.6             # an aimed shot goes out a little softer, to arc onto its mark
const ARROW_HEAD_LENGTH := 7.0
const ARROW_SHAFT_COLOR := Color(0.72, 0.62, 0.45)
const ARROW_FLETCH_COLOR := Color(0.85, 0.35, 0.30)

# One-handed sword. Not a light axe: an axe is hauled overhead and dropped onto
# the target, while a sword is cut through a much flatter arc -- about a third of
# the axe's sweep -- and only one hand is on it, so the free arm swings back to
# counterbalance instead of joining the grip.
const SWORD_BLADE := 42.0
const SWORD_POMMEL := 5.0
const SWORD_GUARD := 7.0           # crossguard half-width
const SWORD_TAPER := 3.0           # blade half-width at the guard
const SWORD_CARRY_ANGLE := -1.05   # ~-60 deg: carried blade up, at the ready

# A dagger, held reversed: the blade runs back down along the forearm rather than
# out in front of the fist. That is what makes it read as a knife instead of a
# very short sword, and it is the grip a blow from behind is actually made with.
const DAGGER_BLADE := 13.0         # shorter than the forearm, or it is a short sword
const DAGGER_POMMEL := 3.5
const DAGGER_GUARD := 4.0
const DAGGER_TAPER := 2.2
const DAGGER_CARRY_ANGLE := 2.30   # ~132 deg: point down and back, along the arm
const DAGGER_CARRY_ARM_DAMP := 0.55
const DAGGER_ARM_REACH := 0.72     # a short weapon is worked close in
const DAGGER_REST_ANGLE := 0.85
const DAGGER_BACK_ANGLE := -0.55   # only a small cock of the wrist: no wind-up
const DAGGER_HIT_ANGLE := 0.10     # driven straight out in front, not swung down
const DAGGER_BACK_END := 0.34
const DAGGER_STRIKE_END := 0.55
# A mage's staff. Alone among these it never touches what it hurts: the whole
# move is a gather and a release, so what has to read is the charge building at
# the head and the moment it leaves. It is carried upright and planted, which is
# also the only silhouette here that is vertical.
const STAFF_SHAFT := 60.0
const STAFF_BUTT := 24.0           # how far the shaft runs on below the hand
const STAFF_ORB := 6.0
const STAFF_CLAW := 9.0            # the wooden claws cradling the stone
const STAFF_CARRY_ANGLE := -1.60   # straight up
const STAFF_AIM_ANGLE := -0.12     # brought down and levelled to cast
const STAFF_CARRY_ARM_DAMP := 0.45
# Held out in front of the body rather than up against it, and lower still to
# cast: at shoulder height the shaft crossed the figure's own chest and the
# stone ended up behind the head instead of out where it is aimed.
const STAFF_HAND := Vector2(18.0, 11.0)     # where the staff hand rides at rest
const STAFF_HAND_CAST := Vector2(25.0, 17.0)
const STAFF_OFF_REACH := 0.62      # the free hand comes up the shaft to the stone
const STAFF_CARRY_HOLD := 0.82     # a staff is held out, not swung with the arm
const STAFF_RAISE_END := 0.30
const STAFF_HOLD_END := 0.64       # the bolt leaves here
const STAFF_RECOVER := 0.12        # and the staff is held out a beat afterwards
const STAFF_LEAN_BACK := -6.0
const STAFF_LEAN_IN := 12.0
const STAFF_IDLE_GLOW := 0.16      # it is never quite dark, even at rest
const STAFF_PULSE := 2.1

const BOLT_SPEED := 540.0
const BOLT_LIFE := 1.1
const BOLT_RADIUS := 4.5
const BOLT_REACH := 30.0           # how near it has to pass to strike something
const BOLT_MAX := 8
const BOLT_TRAIL := 26.0

const STAFF_WOOD := Color(0.44, 0.33, 0.23)
const STAFF_WOOD_EDGE := Color(0.33, 0.24, 0.17)
const ORB_GLOW := Color(0.45, 0.72, 1.0)
const ORB_CORE := Color(0.93, 0.97, 1.0)

# A torch: a short stick, a wrapped burning head, and a flame that goes straight
# up whatever angle the stick is held at. That last part matters -- a flame that
# leans with the handle reads as a flag, not as fire.
const TORCH_STICK := 23.0
const TORCH_BUTT := 7.0
const TORCH_HEAD := 4.6            # the pitch-soaked wrapping that is actually alight
const TORCH_FLAME := 20.0
const TORCH_FLAME_WIDE := 5.8
const TORCH_SWAY := 3.2
const TORCH_TONGUES := 3
const TORCH_GLOW := 46.0
const TORCH_CARRY_ANGLE := -1.22   # held up and a little forward, clear of the face
const TORCH_CARRY_ARM_DAMP := 0.55
const TORCH_WOOD := Color(0.38, 0.29, 0.20)
const TORCH_WRAP := Color(0.22, 0.18, 0.15)

const DAGGER_LEAN_BACK := -2.0     # barely rocks back: there is no wind-up to it
const DAGGER_LEAN_IN := 7.0
const DAGGER_TURN := 0.85          # a reversed grip never quite lines up with the arm

# The sneak. Nothing about it is a strike with a bigger number on it: the body
# gathers, surges up out of the crouch, the free hand goes over the mark first
# and the blade follows it in, then it settles back down into cover.
const STAB_GATHER_END := 0.26
const STAB_DRIVE_END := 0.46
const STAB_HOLD_END := 0.66
const STAB_RISE := 1.52            # how far it comes up out of the crouch
const STAB_LEAN := 15.0
const STAB_CLAMP := Vector2(30.0, -9.0)   # the free hand, over the mark's shoulder
const STAB_GATHER_HAND := Vector2(-15.0, 14.0)
const STAB_DRIVE_HAND := Vector2(26.0, 6.0)
const STAB_EASE := 22.0
const STAB_IN := 0.20              # the pose is gathered into, not snapped into
const STAB_OUT := 0.84
const SWORD_REST_ANGLE := 1.36     # ~78 deg: arm hanging
const SWORD_WIND_ANGLE := -1.92    # ~-110 deg: hauled up behind the shoulder
const SWORD_HIT_ANGLE := 0.70      # ~40 deg: cut down through the target
const SWORD_WIND_END := 0.30
const SWORD_STRIKE_END := 0.42
const SWORD_ARM_REACH := 0.94
const SWORD_LEAN_BACK := -3.0
const SWORD_LEAN_IN := 6.0
const SWORD_OFF_HAND_BACK := 11.0  # free arm thrown back against the cut

# Shield. It changes the stance rather than the strike: the off arm stops being
# an arm and becomes a carried wall, so it no longer swings with the gait.
const SHIELD_FORWARD := 9.0        # held this far ahead of the shoulder
const SHIELD_DROP := 7.0
const SHIELD_CARRY_ARM_DAMP := 0.15
const SHIELD_SHAPE := [            # heater shape, flat on top, tapering to a point
	Vector2(-7.0, -15.0),
	Vector2(7.0, -14.0),
	Vector2(9.0, -4.0),
	Vector2(4.0, 10.0),
	Vector2(0.0, 15.0),
	Vector2(-4.0, 10.0),
	Vector2(-9.0, -4.0),
]
const SHIELD_FACE_COLOR := Color(0.36, 0.42, 0.55)
const SHIELD_RIM_COLOR := Color(0.78, 0.80, 0.85)
const SHIELD_BOSS_COLOR := Color(0.86, 0.88, 0.92)

# Two-hander. The weight shows in the timing, not just the size: the longest
# wind-up of anything here, the widest arc, and a recovery it cannot hurry.
# Both hands stay on the grip even at rest, so neither arm swings when running.
const GREAT_BLADE := 62.0
const GREAT_POMMEL := 7.0
const GREAT_GUARD := 10.0
const GREAT_TAPER := 4.0
const GREAT_GRIP_GAP := 12.0        # second hand, down towards the pommel
const GREAT_CARRY_ANGLE := -2.00    # ~-115 deg: rested back over the shoulder
const GREAT_REST_ANGLE := 1.30      # ~74 deg: arm hanging
const GREAT_WIND_ANGLE := -2.35     # ~-135 deg: hauled right back over the shoulder
const GREAT_HIT_ANGLE := 1.00       # ~57 deg: driven down through the target
const GREAT_WIND_END := 0.38
const GREAT_STRIKE_END := 0.54
const GREAT_ARM_REACH := 0.92
const GREAT_LEAN_BACK := -6.0
const GREAT_LEAN_IN := 10.0
const GREAT_CARRY_ARM_DAMP := 0.12

# Pickaxe. The target is the floor, not a man, and that changes the whole shape
# of the stroke: the body stands tall on the wind-up and drops its weight into
# the blow, the head is driven down in front instead of through chest height,
# and the stroke does not end at impact -- the pick is buried and has to be
# levered back out before the miner can straighten up.
const PICK_HAFT := 34.0
const PICK_BUTT := 6.0
const PICK_HEAD := [               # crosswise head: long spike one side, chisel the other
	Vector2(-2.5, 2.0),
	Vector2(-3.5, 9.0),
	Vector2(-1.0, 14.5),
	Vector2(2.5, 13.0),
	Vector2(2.5, 2.5),
	Vector2(3.5, -3.0),
	Vector2(3.0, -8.0),
	Vector2(-2.0, -7.5),
]
const PICK_CARRY_ANGLE := -0.62    # ~-36 deg: held out in front, clear of the body
const PICK_CARRY_FORWARD := 8.0    # and the grip carried ahead of the hip too
const PICK_REST_ANGLE := 1.36
const PICK_WIND_ANGLE := -2.30     # ~-132 deg: hauled overhead
const PICK_HIT_ANGLE := 1.12       # ~64 deg: driven down AND out, so it bites ahead of the feet
const PICK_LEVER := 0.18           # worked loose before it comes free
const PICK_WIND_END := 0.36
const PICK_STRIKE_END := 0.50
const PICK_HOLD_END := 0.62
const PICK_ARM_REACH := 0.95
const PICK_GRIP_GAP := 0.72
const PICK_LEAN_BACK := -5.0
const PICK_LEAN_IN := 13.0         # bent further over the work
const PICK_RISE := -0.30           # rises onto the toes before the stroke
const PICK_CROUCH := 0.72          # and dropped lower, to reach out that far
const PICK_CARRY_ARM_DAMP := 0.35

# Stone chips thrown off at the moment of impact -- without them the stroke is
# just a differently angled chop.
const CHIP_COUNT := 8
const CHIP_LIFE := 1.1
const CHIP_SPEED_MIN := 40.0
const CHIP_SPEED_MAX := 190.0
const CHIP_LIFT_MIN := 60.0
const CHIP_LIFT_MAX := 220.0
const CHIP_SPREAD := 1.1           # rad of scatter around the swing direction
const CHIP_GRAVITY := 900.0
const CHIP_BOUNCE := 0.35
const CHIP_DRAG := 150.0
const CHIP_MAX := 40
const CHIP_COLOR := Color(0.62, 0.60, 0.58)
const SPLINTER_COLOR := Color(0.70, 0.55, 0.35)

# Felling a tree. Against a man the axe is meant to pass through and carry on
# into a follow-through; against a trunk it stops dead where it lands, is rocked
# free, and only then comes back. The bite is at trunk height out in front, not
# at the ground like the pick and not at chest height like a fighting blow.
const CHOP_REST_ANGLE := 1.36
const CHOP_WIND_ANGLE := -2.25     # ~-129 deg: hauled up over the shoulder
const CHOP_HIT_ANGLE := 0.90       # ~52 deg: into the side of the trunk
const CHOP_LEVER := 0.14           # worked loose before it will come out
const CHOP_WIND_END := 0.38
const CHOP_STRIKE_END := 0.50
const CHOP_HOLD_END := 0.64        # buried in the wood for this stretch
const CHOP_ARM_REACH := 0.75       # elbows stay in: the bite is close work
const CHOP_GRIP_GAP := 0.72
const CHOP_LEAN_BACK := -5.0
const CHOP_LEAN_IN := 10.0
const CHOP_CROUCH := 0.92          # braced, but nothing like the pick's stoop
const CHOP_JOLT := 7.0             # the axe stopping dead jars the body
const CHOP_JOLT_DECAY := 12.0

# Dropping the axe on death. One roll decides the whole throw, so a weak one
# leaves it lying against the body and a strong one flings it most of a body
# length away -- the axe always starts falling from the height of the hand.
const DROP_SPEED_MIN := 25.0
const DROP_SPEED_MAX := 150.0
const DROP_LIFT_MIN := 0.0
const DROP_LIFT_MAX := 70.0
const DROP_SPREAD := 0.5           # rad of random deviation from the facing direction
const DROP_SPIN_MIN := 3.0         # rad/s, sign is randomised
const DROP_SPIN_MAX := 11.0
const DROP_CARRY := 0.3            # share of the body's momentum handed to the axe
const DROP_GRAVITY := 900.0
const DROP_BOUNCE := 0.25
const DROP_LANDING_SLOWDOWN := 0.55
const DROP_FLOOR_DRAG := 320.0
const DROP_SPIN_DRAG := 7.0
const DROP_SETTLE_EASE := 11.0

# Setting a weapon down: the hand carries it to the floor and lets go there, so
# it neither leaps out of the hand nor appears back in it.
const PUT_RELEASE := 0.55        # the weapon touches down here
const PUT_SPOT := Vector2(22.0, -4.0)  # where it is set, in front of the feet
const PUT_CROUCH := 0.60

const LIMB_WIDTH := 4.0
const JOINT_RADIUS := 2.6
const NEAR_COLOR := Color(0.9569, 0.9608, 0.9686)
const FAR_COLOR := Color(0.62, 0.64, 0.68)

# Armour. Set by whatever owns the rig; it changes nothing about how the figure
# moves, only what is drawn over it. Plate is added as pieces sitting on the
# joints the rig already computes -- a helm on the head, plates on the shoulders,
# a cuirass between hip and shoulder -- rather than as a second figure, so every
# animation already built keeps working underneath it.
## Antialias each stroke of the figure. A crowd of figures drawn this way costs a
## draw call per stroke, so a scene with many of them can switch it off and let the
## viewport's MSAA smooth the edges instead. On by default: the testbed is unchanged.
var smooth_lines := true
## Gather the whole figure into one triangle list and draw it in one call (Pen)
## instead of stroke by stroke. Off by default, which is the testbed exactly as
## it was; a crowd of figures turns it on and smooths edges with MSAA instead.
var batched := Pen.crowd_mode
var pen: Pen = null

# Every stroke of the figure goes through these, to the pen or straight to the
# canvas. Same arguments as the draw_* functions they stand for.
func _w_line(a: Vector2, b: Vector2, color: Color, width: float = -1.0, aa: bool = false) -> void:
	if batched: pen.line(a, b, color, width)
	else: draw_line(a, b, color, width, aa)

func _w_circle(center: Vector2, radius: float, color: Color) -> void:
	if batched: pen.circle(center, radius, color)
	else: draw_circle(center, radius, color)

func _w_polygon(points: PackedVector2Array, color: Color) -> void:
	if batched: pen.colored_polygon(points, color)
	else: draw_colored_polygon(points, color)

func _w_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, aa: bool = false) -> void:
	if batched: pen.polyline(points, color, width)
	else: draw_polyline(points, color, width, aa)

func _w_arc(center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float = -1.0, aa: bool = false) -> void:
	if batched: pen.arc(center, radius, start, end, count, color, width)
	else: draw_arc(center, radius, start, end, count, color, width, aa)

func _w_rect(r: Rect2, color: Color) -> void:
	if batched: pen.rect(r, color)
	else: draw_rect(r, color)

func _w_transform(position: Vector2, rotation: float, scale: Vector2) -> void:
	if batched: pen.set_transform(position, rotation, scale)
	else: draw_set_transform(position, rotation, scale)

@export var armoured := false
const PLATE_NEAR := Color(0.70, 0.73, 0.79)
const PLATE_FAR := Color(0.47, 0.50, 0.56)
const PLATE_EDGE := Color(0.30, 0.32, 0.37)
const VISOR_COLOR := Color(0.13, 0.14, 0.17)
const PLUME_COLOR := Color(0.66, 0.24, 0.26)

# The wind bar. Shown only when there is something to say -- a bar sitting full
# over every figure all the time is furniture.
const WIND_WIDE := 26.0
const WIND_TALL := 3.0
const WIND_ABOVE := 16.0
const WIND_BACK := Color(0.10, 0.11, 0.13, 0.55)
const WIND_FULL := Color(0.45, 0.72, 0.45)
const WIND_LOW := Color(0.80, 0.55, 0.22)
const WIND_SPENT := Color(0.74, 0.26, 0.22)
const LIFE_ABOVE := 22.0       # sits above the wind bar, never overlapping it
const LIFE_FULL := Color(0.72, 0.29, 0.27)
const LIFE_LOW := Color(0.85, 0.22, 0.18)
const ARMOUR_LIMB := 6.4       # a plated limb is visibly thicker than a bare one
const HELM_WIDE := 8.4
const HELM_TALL := 11.0
const PAULDRON := 7.2
const CUIRASS_WIDE := 8.0

# Taking the helm off. The head is always drawn; the helm is a separate thing
# that happens to be sitting on it. That is why none of this needs a "bare head"
# state -- take the helm elsewhere and the head is simply visible.
const HELM_GRIP := 0.28        ## hands reach it
const HELM_SEATED := 0.64      ## and it has arrived, either on the head or under the arm
const HELM_CLEAR := 17.0       ## how far above the head it is lifted on the way past
const HELM_STOW := Vector2(10.0, -6.0)   ## tucked against the hip, under the near arm
const HELM_HAND := 7.0         ## how wide the hands sit either side of it
const HELM_UNDER_ARM := Vector2(2.0, -5.0)
const HELM_TUCK := 0.72        ## how firmly the arm clamps it, short of pinning it

const MOVE_EPSILON := 5.0
const GAIT_EASE := 6.0
const TURN_EASE := 12.0
const IDLE_EASE := 9.0
const AIR_EASE := 20.0
const HEAD_EASE := 24.0
const MIN_TURN_SCALE := 0.3       # figure never collapses fully while turning

@onready var player: PlayerBody = get_parent() as PlayerBody

func _ready() -> void:
	# Dropped weapons lie in the rig that dropped them, so a rig that cannot be
	# found by anyone else is a weapon nobody else can pick up. Joining a group
	# is what makes a dead knight's sword a thing on the ground rather than a
	# thing belonging to the knight.
	add_to_group("rigs")

var facing := 1.0                 # continuous -1..1; passing through 0 reads as a turn
var phase := 0.0
var move_amount := 0.0
var air_amount := 0.0
var death_amount := 0.0
var collapse_amount := 0.0
var shot_amount := 0.0
var cut_amount := 0.0
var fall_side := 1.0       ## which way the body is going down, fixed at death
var run_blend := 0.0
var attack_amount := 0.0
var strike_amount := 0.0  ## like attack_amount, but only for the weapon's own strike
var load_amount := 0.0    ## how far the gait has settled under a heavy load
var crouch_amount := 0.0
var roll_amount := 0.0
var roll_pivot := Vector2.ZERO
var stab_amount := 0.0
var rise_amount := 0.0  ## how far through getting up, 0 lying to 1 standing
var stab_surge := 0.0   ## how far out of the crouch the sneak has risen
var helm_at := Vector2.ZERO
var helm_lean := Vector2.UP
var staff_charge := 0.0 ## how much light has gathered at the head of the staff
var glow_time := 0.0
var bolts: Array = []
var travel := 1.0         ## +1 going forwards, -1 backwards, blended through 0
var hit_amount := 0.0
var head_whip := 0.0
var prev_fall := 0.0
var hip_height := HIP_HEIGHT

var stride := WALK_STRIDE
var stance_fraction := WALK_STANCE
var foot_lift := WALK_FOOT_LIFT
var lean_amount := WALK_LEAN
var arm_swing := WALK_ARM_SWING
var arm_hang := WALK_ARM_HANG

# pose is built in the canonical facing-right frame and mirrored at draw time
var hip := Vector2.ZERO
var shoulder := Vector2.ZERO
var head := Vector2.ZERO
var near_foot := Vector2.ZERO
var far_foot := Vector2.ZERO
var near_hand := Vector2.ZERO
var far_hand := Vector2.ZERO
var weapon_grip := Vector2.ZERO
var weapon_dir := Vector2.RIGHT
var pose_started := false

# a dropped axe lives in world space, so it stays where it lands while the body
# keeps sliding
var was_flinching := false
var prev_hit_time := -1.0
var dropped_kind := PlayerBody.Weapon.AXE

## An arrow in the world: it flies on the floor plane with its own height above
## it, arcs down under gravity and stays stuck where it lands.
class Arrow:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var z := 0.0
	var z_vel := 0.0
	var angle := 0.0
	var stuck := false
	var gone := false    ## found a body, and goes with it
	var harm := 0.0      ## carried by the shaft, not looked up where it lands

## A stone chip knocked loose by the pick: same world-space treatment as an
## arrow, but short-lived and it fades out where it settles.
class Chip:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var z := 0.0
	var z_vel := 0.0
	var life := 0.0
	var size := 0.0
	var color := Color.WHITE

var idle_weight := 0.0      ## how much of the idle life is showing, 0..1
var idle_time := 0.0
var shift_wait := 0.0
var shift_phase := -1.0     ## negative when no weight shift is running
var shift_foot := 0
var shift_from := 0.0
var shift_to := 0.0
var foot_idle: Array[float] = [0.0, 0.0]
var foot_raise: Array[float] = [0.0, 0.0]
var hip_drift := 0.0
var glance_wait := 0.0
var glance_phase := -1.0
var glance_dir := 1.0
var head_idle := Vector2.ZERO

var arrows := []
var chips := []
var bow_draw := 0.0        ## 0 at rest, 1 at full draw
var prev_progress := 0.0
## A weapon lying in the world: thrown away, or dropped where its owner died.
## Several can exist at once, so this is a list rather than the single slot it
## started as -- a thrown weapon has to survive the next one being picked up.
class Dropped:
	var kind := PlayerBody.Weapon.AXE
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var z := 0.0
	var z_vel := 0.0
	var angle := 0.0
	var spin := 0.0

var dropped: Array = []
var taken_angle := 0.0        ## how the last weapon picked up was lying
var taken_point := Vector2.ZERO ## and where it lay
var natural_near := Vector2.ZERO ## gait hand positions, before any action overrides them
var natural_far := Vector2.ZERO
var was_dead := false

## A figure in a crowd moves its limbs every other frame, half the crowd on each,
## with the time between carried over -- the body itself still glides at the full
## rate. Everything the rig fires (a blade landing, a hand closing) is keyed to a
## moment being crossed, not reached, so the bigger step loses none of them.
const CROWD_STRIDE := 2
static var _crowd_slots := 0
## which of the frames this figure moves on, handed out in turn so the halves are even
var crowd_slot := _take_crowd_slot()
var held_delta := 0.0

static func _take_crowd_slot() -> int:
	_crowd_slots += 1
	return _crowd_slots % CROWD_STRIDE

func _process(delta: float) -> void:
	if batched:
		held_delta += delta
		if (Engine.get_process_frames() + crowd_slot) % CROWD_STRIDE != 0:
			return
		delta = held_delta
		held_delta = 0.0
	var speed := player.velocity.length()
	var moving := speed > MOVE_EPSILON

	run_blend = _ease(run_blend, clampf(inverse_lerp(WALK_SPEED, RUN_SPEED, speed), 0.0, 1.0), GAIT_EASE, delta)
	stride = lerpf(WALK_STRIDE, RUN_STRIDE, run_blend)
	stance_fraction = lerpf(WALK_STANCE, RUN_STANCE, run_blend)
	foot_lift = lerpf(WALK_FOOT_LIFT, RUN_FOOT_LIFT, run_blend)
	lean_amount = lerpf(WALK_LEAN, RUN_LEAN, run_blend)
	arm_swing = lerpf(WALK_ARM_SWING, RUN_ARM_SWING, run_blend)
	arm_hang = lerpf(WALK_ARM_HANG, RUN_ARM_HANG, run_blend)

	# a load shortens the step, keeps both feet down longer and scuffs them along
	stride = lerpf(stride, stride * LOAD_STRIDE, load_amount)
	stance_fraction = lerpf(stance_fraction, LOAD_STANCE, load_amount)
	foot_lift = lerpf(foot_lift, foot_lift * LOAD_FOOT_LIFT, load_amount)
	lean_amount = lerpf(lean_amount, LOAD_LEAN, load_amount)

	# and a crouch shortens it further still, and stops the feet leaving the floor
	stride = lerpf(stride, stride * BACK_STRIDE, clampf(-travel, 0.0, 1.0))
	stride = lerpf(stride, stride * CROUCH_STRIDE, crouch_amount)
	stance_fraction = lerpf(stance_fraction, CROUCH_STANCE, crouch_amount)
	foot_lift = lerpf(foot_lift, foot_lift * CROUCH_FOOT_LIFT, crouch_amount)
	lean_amount = lerpf(lean_amount, CROUCH_LEAN, crouch_amount)
	arm_swing = lerpf(arm_swing, arm_swing * CROUCH_ARM_SWING, crouch_amount)
	arm_hang = lerpf(arm_hang, CROUCH_ARM_HANG, crouch_amount)

	if moving and player.is_grounded() and not player.is_dead:
		phase = fposmod(phase + speed * delta / stride, 1.0)
	# A dead man's facing is frozen at the moment he went down -- except on a
	# shoulder, where he turns with whoever is carrying him. Without this the
	# body kept lying the way it fell while the balance offset flipped with the
	# bearer, so carrying it the other way threw the whole thing sideways.
	if not player.is_dead or player.carried_by != null:
		facing = _ease(facing, player.facing_x, TURN_EASE, delta)
	# the drawn facing, handed back so anything positioning this body uses the
	# same value that is actually being drawn rather than the raw target
	player.carry_facing = facing

	var walking := moving and not player.is_dead
	move_amount = _ease(move_amount, 1.0 if walking else 0.0, IDLE_EASE, delta)
	air_amount = _ease(air_amount, 0.0 if player.is_grounded() else 1.0, AIR_EASE, delta)

	var collapsing := player.is_dead and player.death_kind == PlayerBody.DeathKind.COLLAPSE
	var knocked := player.is_dead and player.death_kind == PlayerBody.DeathKind.KNOCKED_BACK
	var cut := player.is_dead and player.death_kind == PlayerBody.DeathKind.CUT_DOWN
	collapse_amount = _ease(collapse_amount, 1.0 if collapsing else 0.0, DEATH_EASE, delta)
	shot_amount = _ease(shot_amount, 1.0 if knocked else 0.0, SHOT_EASE, delta)
	cut_amount = _ease(cut_amount, 1.0 if cut else 0.0, SHOT_EASE, delta)
	# The death layers are faded out by the rise itself rather than by a timer of
	# their own. That way the body leaves the ground from exactly the attitude it
	# was lying in, and there is nothing left of the fall to snap back to once it
	# is standing.
	rise_amount = player.rise_progress()
	var still_down := 1.0 - smoothstep(0.0, 1.0, clampf(rise_amount / RISE_OVER, 0.0, 1.0))
	collapse_amount *= still_down
	shot_amount *= still_down
	cut_amount *= still_down
	death_amount = maxf(collapse_amount, maxf(shot_amount, cut_amount))
	attack_amount = _ease(attack_amount, 1.0 if player.is_attacking() else 0.0, ATTACK_EASE, delta)
	# a weapon poses for its own strike only: every other action shares the same
	# clock, and reading attack_amount would leave a spear mid-thrust after a
	# pick-up, or a bow drawn after a throw
	strike_amount = _ease(strike_amount, 1.0 if player.is_striking() else 0.0, ATTACK_EASE, delta)
	load_amount = _ease(load_amount, 1.0 if player.is_carrying_heavy() else 0.0, LOAD_EASE, delta)
	crouch_amount = _ease(crouch_amount, 1.0 if player.is_crouching else 0.0, CROUCH_EASE, delta)
	# Driven by the move's own clock, like the roll and for the same reason: an
	# exponential ease starts at full rate, which threw the hands 24 px in the
	# first frame -- during the gather, which is meant to be the quiet part.
	if player.is_backstabbing():
		stab_amount = _stab_shape(player.attack_progress())
	else:
		stab_amount = _ease(stab_amount, 0.0, STAB_EASE, delta)
	stab_surge = _stab_surge(player.attack_progress()) if player.is_backstabbing() else 0.0

	glow_time += delta
	# at rest the stone only breathes; under a cast it fills, and it is empty the
	# instant the bolt leaves, which is what makes the release readable
	var resting := STAFF_IDLE_GLOW * (0.5 + 0.5 * sin(glow_time * STAFF_PULSE))
	if player.is_striking() and _has_staff():
		staff_charge = maxf(resting, _staff_gather(player.attack_progress()))
	else:
		staff_charge = resting
	# Driven by the roll's own clock rather than eased towards a target. An
	# exponential ease starts at full rate, which threw the body 26 px into the
	# tuck on the first frame; a curve with a flat start gathers it up instead.
	if player.is_rolling():
		roll_amount = _roll_shape(player.roll_progress())
	else:
		roll_amount = _ease(roll_amount, 0.0, ROLL_EASE, delta)

	# which way the body is going relative to the way it is pointing; only
	# sideways travel counts, since moving up or down the field reads as neither
	var heading := 1.0
	if absf(player.velocity.x) > MOVE_EPSILON:
		heading = signf(player.velocity.x * player.facing_x)
	travel = _ease(travel, heading, BACK_EASE, delta)
	# The recoil is held as a decaying state rather than recomputed from the stun
	# timer. Deriving it from the timer meant that when the timer was cleared to
	# its "no hit" sentinel, the curve read that as the instant of impact and
	# snapped back to full strength -- a second jerk, a third of a second late.
	# As a state it also decouples the visible recoil from how long control is
	# taken away, which are two different things.
	# a fresh hit is either the first one or one that restarted the stun timer
	# while the last was still running
	var flinching := player.is_flinching()
	if flinching and (not was_flinching or player.hit_time < prev_hit_time):
		hit_amount = 1.0
	else:
		hit_amount = _ease(hit_amount, 0.0, HIT_DECAY, delta)
	was_flinching = flinching
	prev_hit_time = player.hit_time

	# the head lags behind a fast rotation, which is what gives a hit its whip
	var fall := _fall_rotation()
	var fall_rate := (fall - prev_fall) / maxf(delta, 0.0001)
	prev_fall = fall
	head_whip = _ease(head_whip, clampf(-fall_rate * HEAD_WHIP, -HEAD_WHIP_LIMIT, HEAD_WHIP_LIMIT), HEAD_EASE, delta)

	var progress := player.attack_progress() if player.is_attacking() else 0.0

	# Taking hold has to happen before the pose is built. The other moments read
	# the pose -- where the hand is when the arrow leaves, where the pick bites --
	# but a grab feeds it, and doing it afterwards draws the thing for one frame
	# at wherever it was last held.
	if player.is_picking_up() and prev_progress < PICKUP_GRAB and progress >= PICKUP_GRAB:
		player.take_hold()

	_update_idle(delta)
	_update_pose(delta)

	_update_rock(progress)
	if player.is_attacking():
		# weapon effects fire only on that weapon's own strike: picking up a rock
		# with a bow in hand runs the same clock straight past the loose
		if player.is_striking() and _has_bow() \
			and prev_progress < BOW_HOLD_END and progress >= BOW_HOLD_END:
			_release_arrow()
		elif player.is_striking() and _has_staff() \
			and prev_progress < STAFF_HOLD_END and progress >= STAFF_HOLD_END:
			_release_bolt()
		elif player.is_striking() and _has_crossbow() \
			and prev_progress < XBOW_SHOT and progress >= XBOW_SHOT:
			if player.crossbow_loaded:
				_release_arrow(QUARREL_SPEED, PlayerBody.STRIKE_HARM[PlayerBody.Weapon.CROSSBOW])
				player.shoot_crossbow()
		elif player.is_spanning() \
			and prev_progress < SPAN_HAUL_END and progress >= SPAN_HAUL_END:
			player.load_crossbow()
		elif player.is_striking() and _has_torch() \
			and prev_progress < SWING_STRIKE_END and progress >= SWING_STRIKE_END:
			player.torch_strike()
		elif player.is_striking() and _has_pickaxe() \
			and prev_progress < PICK_STRIKE_END and progress >= PICK_STRIKE_END:
			_spawn_chips(PICK_HAFT, CHIP_COLOR)
			player.strike_vein()
		elif player.is_chopping() \
			and prev_progress < CHOP_STRIKE_END and progress >= CHOP_STRIKE_END:
			_spawn_chips(AXE_HANDLE, SPLINTER_COLOR)
			player.bite_tree()
		elif player.is_putting_down() \
			and prev_progress < PUT_RELEASE and progress >= PUT_RELEASE:
			# the stoop is the same either way; only what leaves the hands differs
			if player.is_carrying():
				_put_down_rock()
			else:
				_put_down_weapon()

		# The sneak, and then -- separately from any weapon's own special effect --
		# an ordinary melee blow landing on whatever body is in reach. Separate
		# because it is not special to any one weapon: the pick that breaks a vein
		# will also break a man, and both happen on the same stroke.
		if player.is_backstabbing() 			and prev_progress < STAB_DRIVE_END and progress >= STAB_DRIVE_END:
			player.land_backstab()

		if player.is_helm_action() 			and prev_progress < HELM_SEATED and progress >= HELM_SEATED:
			player.seat_helm()

		var lands := _melee_strike_end()
		if player.is_striking() and lands > 0.0 			and prev_progress < lands and progress >= lands:
			player.land_strike()
	prev_progress = progress

	_simulate_arrows(delta)
	_simulate_bolts(delta)
	_simulate_chips(delta)

	# Carried, the body turns with its bearer -- so the side it lies on has to
	# turn with it. The mirror flips the pose but not the rotation, so leaving
	# the death's own side fixed threw the body out to the wrong hand entirely.
	if player.carried_by != null:
		fall_side = signf(facing)

	if player.is_dead and not was_dead:
		# fixed here, so a body spun by a cut still goes down the way it was pushed
		fall_side = signf(facing)
		_drop_weapon()
	was_dead = player.is_dead

	_simulate_dropped(delta)

	queue_redraw()

func _ease(current: float, target: float, rate: float, delta: float) -> float:
	return current + (target - current) * (1.0 - exp(-rate * delta))

## Life while standing about. Runs only when nothing else is, and everything it
## produces is eased back to neutral the moment something is -- so a step, a
## swing or a death never has to fight it.
func _update_idle(delta: float) -> void:
	var settled := (1.0 - move_amount) * (1.0 - death_amount) \
		* (1.0 - attack_amount) * (1.0 - air_amount) * (1.0 - hit_amount)
	idle_weight = _ease(idle_weight, settled, IDLE_SETTLE, delta)

	if settled < 0.5:
		# unwind rather than freeze, or the pose would jump on the way out
		for i in 2:
			foot_idle[i] = _ease(foot_idle[i], 0.0, IDLE_SETTLE, delta)
			foot_raise[i] = _ease(foot_raise[i], 0.0, IDLE_SETTLE * 2.0, delta)
		hip_drift = _ease(hip_drift, 0.0, IDLE_SETTLE, delta)
		head_idle = head_idle.lerp(Vector2.ZERO, 1.0 - exp(-IDLE_SETTLE * delta))
		shift_phase = -1.0
		glance_phase = -1.0
		return

	idle_time += delta
	_update_weight_shift(delta)
	_update_glance(delta)

## Every few seconds one foot is picked up and set down a little differently,
## and the hip leans onto whichever foot is still carrying the weight.
func _update_weight_shift(delta: float) -> void:
	if shift_phase < 0.0:
		shift_wait -= delta
		if shift_wait > 0.0:
			return
		shift_wait = randf_range(SHIFT_MIN_WAIT, SHIFT_MAX_WAIT)
		shift_phase = 0.0
		# the foot standing furthest from neutral is the one that wants moving
		shift_foot = 0 if absf(foot_idle[0]) > absf(foot_idle[1]) else 1
		shift_from = foot_idle[shift_foot]
		shift_to = randf_range(-SHIFT_RANGE, SHIFT_RANGE)
		return

	shift_phase += delta / SHIFT_TIME
	if shift_phase >= 1.0:
		shift_phase = -1.0
		foot_idle[shift_foot] = shift_to
		foot_raise[shift_foot] = 0.0
		return

	var t := smoothstep(0.0, 1.0, shift_phase)
	foot_idle[shift_foot] = lerpf(shift_from, shift_to, t)
	foot_raise[shift_foot] = sin(PI * shift_phase) * SHIFT_LIFT
	hip_drift = -foot_idle[1 - shift_foot] * SHIFT_HIP_DRIFT

## And every so often the head turns to look at something, then comes back.
func _update_glance(delta: float) -> void:
	if glance_phase < 0.0:
		glance_wait -= delta
		if glance_wait > 0.0:
			head_idle = head_idle.lerp(Vector2.ZERO, 1.0 - exp(-IDLE_SETTLE * delta))
			return
		glance_wait = randf_range(GLANCE_MIN_WAIT, GLANCE_MAX_WAIT)
		glance_phase = 0.0
		glance_dir = 1.0 if randf() < 0.5 else -1.0
		return

	glance_phase += delta / GLANCE_TIME
	if glance_phase >= 1.0:
		glance_phase = -1.0
		return

	# out and back on one smooth arc, so the look has no start or stop to it
	var swell := sin(PI * glance_phase)
	head_idle = Vector2(glance_dir * GLANCE_REACH, -GLANCE_RISE) * swell

func _breath() -> float:
	return sin(idle_time * TAU / BREATH_PERIOD) * idle_weight

func _update_pose(delta: float) -> void:
	var lift := Vector2(0.0, -player.air_height)

	var near_off := _foot_offset(phase, 1.0)
	var far_off := _foot_offset(phase + 0.5, -1.0)

	var recoil := _hit_recoil()
	var jolt := _cut_jolt() + _chop_jolt()
	var breath := _breath()
	hip = lift + Vector2(
		recoil * HIT_HIP_RECOIL + jolt * 0.35 + hip_drift * idle_weight,
		-_hip_height(near_off, far_off, delta)
	)
	shoulder = hip + Vector2(
		lean_amount * move_amount * travel + _swing_lean() + recoil * HIT_RECOIL + jolt,
		-SHOULDER_ABOVE_HIP * lerpf(1.0, CROUCH_TORSO, crouch_amount) - breath * BREATH_RISE
	)

	near_foot = lift + near_off
	far_foot = lift + far_off

	# arms swing opposite the leg on their own side (contralateral gait), reading
	# the leg slightly in the past so they trail it instead of mirroring exactly
	var near_swing := -_foot_offset(phase - ARM_LAG, 1.0).x
	if _has_spear():
		# a hand wrapped around a shaft cannot swing freely, so carrying a spear
		# visibly changes the run rather than just adding a prop to it
		near_swing *= SPEAR_CARRY_ARM_DAMP
	elif _has_bow():
		near_swing *= BOW_CARRY_ARM_DAMP
	elif _has_greatsword():
		near_swing *= GREAT_CARRY_ARM_DAMP
	elif _has_pickaxe():
		near_swing *= PICK_CARRY_ARM_DAMP
	elif _has_dagger():
		near_swing *= DAGGER_CARRY_ARM_DAMP
	elif _has_staff():
		near_swing *= STAFF_CARRY_ARM_DAMP
	elif _has_torch():
		near_swing *= TORCH_CARRY_ARM_DAMP
	elif _has_crossbow():
		near_swing *= XBOW_CARRY_ARM_DAMP
	if player.is_carrying():
		near_swing *= LOAD_ARM_DAMP if player.is_carrying_heavy() else CARRY_ARM_DAMP
	near_hand = _hand_target(near_swing, 1.0)

	var far_swing := -_foot_offset(phase + 0.5 - ARM_LAG, -1.0).x
	if player.is_carrying():
		far_swing *= LOAD_ARM_DAMP if player.is_carrying_heavy() else CARRY_ARM_DAMP
	elif _has_shield():
		# an arm strapped to a shield stops being an arm, so the run changes on
		# the off side the way carrying a spear changes it on the weapon side
		far_swing *= SHIELD_CARRY_ARM_DAMP
	elif _has_greatsword():
		# a two-hander commits both arms, so nothing swings at all
		far_swing *= GREAT_CARRY_ARM_DAMP
	far_hand = _hand_target(far_swing, -1.0)

	# kept so an action can hand the pose back to the gait without a step in it
	natural_near = near_hand
	natural_far = far_hand

	if player.is_picking_up():
		_pose_pickup()
	elif player.is_putting_down():
		_pose_put_down()
	elif player.is_throwing():
		_pose_throw()
	elif player.is_carrying():
		_pose_carry()
	elif player.is_chopping():
		_pose_chop()
	elif _has_spear():
		_pose_spear()
	elif _has_bow():
		_pose_bow()
	elif _has_greatsword():
		_pose_greatsword()
	elif _has_pickaxe():
		_pose_pickaxe()
	elif _has_dagger():
		_pose_dagger()
	elif _has_staff():
		_pose_staff()
	elif _has_torch():
		_pose_torch()
	elif _has_crossbow():
		_pose_crossbow()
	elif _has_sword():
		_pose_sword()
	else:
		# both hands go onto the handle for the chop, so the swing reads two-handed
		if attack_amount > 0.001:
			var swing := Vector2.from_angle(_swing_angle(player.attack_progress()))
			var reach := (UPPER_ARM + FOREARM) * SWING_ARM_REACH
			near_hand = near_hand.lerp(shoulder + swing * reach, attack_amount)
			far_hand = far_hand.lerp(shoulder + swing * reach * SWING_GRIP_GAP, attack_amount)
		_update_axe_pose()

	# the head trails the shoulders by a few hundredths of a second, so the bob
	# ripples up the body instead of moving as one rigid piece
	var ideal_head := shoulder + Vector2(
		lean_amount * move_amount * travel * 0.5 + head_whip + head_idle.x * idle_weight,
		-HEAD_ABOVE_SHOULDER + head_idle.y * idle_weight - breath * BREATH_HEAD
	)
	if pose_started:
		head = head.lerp(ideal_head, 1.0 - exp(-HEAD_EASE * delta))
	else:
		head = ideal_head
		pose_started = true

	# The lag above is what makes the bob ripple up the body, but it is only a
	# lag -- there is no neck holding the head on, so any pose that moves the
	# shoulders faster than the head can follow leaves the head floating clear of
	# the body. Spanning a crossbow stoops hard enough to show it. Clamping the
	# gap keeps the lag and puts a neck's length on it.
	var neck := head - shoulder
	var reach := neck.length()
	if reach > NECK_REACH:
		head = shoulder + neck * (NECK_REACH / reach)

	_pose_rise()
	_update_helm()
	_apply_roll_tuck()

## Getting up, laid over whatever attitude the body fell in.
##
## The hand is the whole trick. It goes down early, stays put on the ground while
## the hips travel up over it, and only lets go once the weight is over the feet.
## Without it the body has nothing to push against and the move reads as the
## corpse being winched upright.
func _pose_rise() -> void:
	if rise_amount <= 0.001 or rise_amount >= 1.0:
		return

	var p := rise_amount
	var plant := smoothstep(0.0, 1.0, clampf(p / RISE_PLANT, 0.0, 1.0))
	var release := smoothstep(0.0, 1.0, clampf((p - RISE_LIFT) / (1.0 - RISE_LIFT), 0.0, 1.0))
	var weight := plant * (1.0 - release)

	# planted on the floor in front, and it does not move while it is bearing
	var hand := Vector2(RISE_HAND_AHEAD, 0.0)
	near_hand = near_hand.lerp(hand, weight)

	# the torso comes up over the planted hand and the lean unwinds as it does
	var over := smoothstep(0.0, 1.0, clampf((p - RISE_PUSH) / (RISE_OVER - RISE_PUSH), 0.0, 1.0))
	# grown in with the hand rather than applied whole on the first frame, which
	# shifted the shoulders 13 px in one go before anything had begun to move
	var lean := RISE_LEAN * plant * (1.0 - over) * (1.0 - release)
	shoulder += Vector2(lean, 0.0)
	head += Vector2(lean * 0.7, 0.0)

## How far the body is folded up under itself: nothing while it is still lying,
## deepest as the hips come over the feet, gone once it is standing.
func _rise_fold() -> float:
	if rise_amount <= 0.001 or rise_amount >= 1.0:
		return 0.0
	# Skewed early: a symmetrical curve left him still folded in half four fifths
	# of the way up, so the last of it was a lurch to standing rather than a rise.
	var u := clampf((rise_amount - RISE_PLANT) / (1.0 - RISE_PLANT), 0.0, 1.0)
	return sin(PI * pow(u, 0.62))

## Where the helm is this frame: on the head, under the arm, or on its way
## between the two. It goes up clear of the head before it travels, because a
## helm that slides off sideways through the skull is worse than none at all.
func _update_helm() -> void:
	var worn := head
	var stowed := hip + Vector2(HELM_STOW.x, HELM_STOW.y)
	helm_lean = (head - shoulder).normalized() if (head - shoulder).length() > 0.01 else Vector2.UP

	if not player.is_helm_action():
		helm_at = worn if player.helm == PlayerBody.Helm.WORN else stowed
		# a helm under the arm is held there: without this the arm swings straight
		# through it, and some swing is left so walking still reads as walking
		if player.helm == PlayerBody.Helm.CARRIED:
			near_hand = near_hand.lerp(helm_at + HELM_UNDER_ARM, HELM_TUCK)
		return

	var p := player.attack_progress()
	var u := smoothstep(0.0, 1.0, clampf((p - HELM_GRIP) / (HELM_SEATED - HELM_GRIP), 0.0, 1.0))
	var from := stowed if player.donning else worn
	var to := worn if player.donning else stowed
	var clear := worn + Vector2(0.0, -HELM_CLEAR)

	var inv := 1.0 - u
	helm_at = from * (inv * inv) + clear * (2.0 * inv * u) + to * (u * u)

	# both hands go to it and stay with it: a helm is lifted with two hands and
	# the arms have to follow it, or it floats along beside a man standing still
	var grip := smoothstep(0.0, 1.0, clampf(p / HELM_GRIP, 0.0, 1.0))
	var let_go := smoothstep(0.0, 1.0, clampf((p - HELM_SEATED) / (1.0 - HELM_SEATED), 0.0, 1.0))
	var hold := grip * (1.0 - let_go)
	near_hand = near_hand.lerp(helm_at + Vector2(HELM_HAND, 2.0), hold)
	far_hand = far_hand.lerp(helm_at + Vector2(-HELM_HAND, 2.0), hold)

## Pull the whole figure into a ball for the roll, and move the point it turns
## about up off the floor and into the middle of that ball. Everything is drawn
## relative to the pivot and the pivot is fed back in as the draw offset, which
## is a rotation about the pivot rather than about the origin at the feet.
func _apply_roll_tuck() -> void:
	roll_pivot = Vector2(0.0, -ROLL_PIVOT * roll_amount)
	if roll_amount <= 0.001:
		return

	var t := roll_amount
	var c := roll_pivot
	hip = hip.lerp(c + ROLL_HIP_AT, t)
	shoulder = shoulder.lerp(c + ROLL_SHOULDER_AT, t)
	head = head.lerp(c + ROLL_HEAD_AT, t)
	near_foot = near_foot.lerp(c + ROLL_NEAR_FOOT_AT, t)
	far_foot = far_foot.lerp(c + ROLL_FAR_FOOT_AT, t)
	near_hand = near_hand.lerp(c + ROLL_NEAR_HAND_AT, t)
	far_hand = far_hand.lerp(c + ROLL_FAR_HAND_AT, t)
	# a weapon comes in with the hands rather than staying out where the gait
	# left it, or it sweeps round outside the ball like a paddle
	weapon_grip = weapon_grip.lerp(near_hand, t)

	# re-express the whole pose around the pivot; the draw offset puts it back
	hip -= roll_pivot
	shoulder -= roll_pivot
	head -= roll_pivot
	near_foot -= roll_pivot
	far_foot -= roll_pivot
	near_hand -= roll_pivot
	far_hand -= roll_pivot
	weapon_grip -= roll_pivot

## Angle of the swinging arm, measured in the canonical frame where 0 points
## forward and +90 degrees points straight down.
func _swing_angle(p: float) -> float:
	if p < SWING_WIND_END:
		# the arm whips up quickly and then hangs at the top of the wind-up
		var u := p / SWING_WIND_END
		return lerpf(SWING_REST_ANGLE, SWING_WIND_ANGLE, 1.0 - pow(1.0 - u, 3.0))
	if p < SWING_STRIKE_END:
		var u := (p - SWING_WIND_END) / (SWING_STRIKE_END - SWING_WIND_END)
		return lerpf(SWING_WIND_ANGLE, SWING_HIT_ANGLE, smoothstep(0.0, 1.0, u))
	var u := (p - SWING_STRIKE_END) / (1.0 - SWING_STRIKE_END)
	return lerpf(SWING_HIT_ANGLE, SWING_REST_ANGLE, 1.0 - pow(1.0 - u, 2.0))

## Recoil from a hit: full strength immediately, then a monotone return to the
## stance. Deliberately not a damped oscillation -- ringing carries the body back
## through neutral and out the other side, which reads as a second, softer hit
## rather than as one. Negative, so the body is driven away from what struck it.
func _hit_recoil() -> float:
	return -hit_amount

## The blow that felled the body, knocking the torso back as it goes over.
## death_time only ever counts up, so unlike the stun timer there is no sentinel
## here for a decay curve to misread as a fresh impact.
func _cut_jolt() -> float:
	# deliberately not scaled by the eased cut_amount: a blow lands at full force
	# on the frame it arrives, and easing it in blunts exactly the thing that
	# makes it read as a blow
	if cut_amount <= 0.001:
		return 0.0
	return -CUT_JOLT * exp(-CUT_JOLT_DECAY * maxf(player.death_time, 0.0))

## Torso rocks back on the wind-up and drives forward through the strike. A
## spear lunges harder and recovers sooner than an axe, so the phase boundaries
## come from whichever weapon is in hand.
func _swing_lean() -> float:
	if attack_amount <= 0.001:
		return 0.0

	var wind_end := SWING_WIND_END
	var strike_end := SWING_STRIKE_END
	var back := SWING_LEAN_BACK
	var into := SWING_LEAN_IN
	if player.is_throwing():
		wind_end = THROW_WIND_END
		strike_end = THROW_RELEASE
		back = THROW_LEAN_BACK
		into = THROW_LEAN_IN
	elif player.is_putting_down():
		# bending to set something down is a stoop, not a wind-up
		return PICKUP_LEAN * sin(PI * player.attack_progress()) * attack_amount
	elif player.is_picking_up():
		# a stoop is one long lean in, with nothing to wind up for
		return PICKUP_LEAN * sin(PI * player.attack_progress()) * attack_amount
	elif player.is_chopping():
		wind_end = CHOP_WIND_END
		strike_end = CHOP_STRIKE_END
		back = CHOP_LEAN_BACK
		into = CHOP_LEAN_IN
	elif _has_spear():
		wind_end = SPEAR_WIND_END
		strike_end = SPEAR_THRUST_END
		back = SPEAR_LEAN_BACK
		into = SPEAR_LEAN_IN
	elif _has_bow():
		# an archer barely leans: the shot is made by the arms, not the body
		wind_end = BOW_DRAW_END
		strike_end = BOW_HOLD_END
		back = BOW_LEAN_BACK
		into = BOW_LEAN_IN
	elif _has_greatsword():
		wind_end = GREAT_WIND_END
		strike_end = GREAT_STRIKE_END
		back = GREAT_LEAN_BACK
		into = GREAT_LEAN_IN
	elif _has_pickaxe():
		wind_end = PICK_WIND_END
		strike_end = PICK_STRIKE_END
		back = PICK_LEAN_BACK
		into = PICK_LEAN_IN
	elif _has_dagger():
		wind_end = DAGGER_BACK_END
		strike_end = DAGGER_STRIKE_END
		back = DAGGER_LEAN_BACK
		into = DAGGER_LEAN_IN
	elif _has_staff():
		wind_end = STAFF_RAISE_END
		strike_end = STAFF_HOLD_END
		back = STAFF_LEAN_BACK
		into = STAFF_LEAN_IN
	elif _has_crossbow():
		wind_end = XBOW_RAISE_END
		strike_end = XBOW_SHOT
		back = XBOW_LEAN_BACK
		into = XBOW_LEAN_IN
	elif _has_sword():
		wind_end = SWORD_WIND_END
		strike_end = SWORD_STRIKE_END
		back = SWORD_LEAN_BACK
		into = SWORD_LEAN_IN

	var p := player.attack_progress()
	var lean: float
	if p < wind_end:
		lean = back * smoothstep(0.0, 1.0, p / wind_end)
	elif p < strike_end:
		var u := (p - wind_end) / (strike_end - wind_end)
		lean = lerpf(back, into, smoothstep(0.0, 1.0, u))
	else:
		var u := (p - strike_end) / (1.0 - strike_end)
		lean = into * (1.0 - smoothstep(0.0, 1.0, u))

	return lean * attack_amount

## Death knocks the axe loose. It leaves the hand at the hand's own height and
## falls from there, so even the weakest throw looks like it was let go of rather
## than placed. A single roll drives the throw: how far, how high, how fast it
## tumbles -- which is what makes one death drop it underfoot and the next send
## it skittering away.
func _drop_weapon() -> void:
	if player.weapon == PlayerBody.Weapon.NONE:
		return

	var force := randf()
	var heading := Vector2(signf(facing), 0.0).rotated(randf_range(-DROP_SPREAD, DROP_SPREAD))
	_release_weapon(
		heading * lerpf(DROP_SPEED_MIN, DROP_SPEED_MAX, force) + player.velocity * DROP_CARRY,
		lerpf(DROP_LIFT_MIN, DROP_LIFT_MAX, force),
		randf_range(DROP_SPIN_MIN, DROP_SPIN_MAX) * (1.0 if randf() < 0.5 else -1.0)
	)

## Set down rather than thrown: it leaves the hand already at floor level and at
## rest, so it stays exactly where it was put.
func _put_down_weapon() -> void:
	_release_weapon(Vector2.ZERO, 0.0, 0.0)

func _put_down_rock() -> void:
	var held := (near_hand + far_hand) * 0.5 + Vector2(0.0, -CARRY_ROCK_LIFT)
	player.let_go(_canonical_to_world(held), maxf(0.0, -held.y), Vector2.ZERO, 0.0, 0.0)

## Puts whatever is in hand into the world, leaving the hands empty.
func _release_weapon(velocity: Vector2, lift: float, spin: float) -> void:
	var grip := Vector2(weapon_grip.x * signf(facing), weapon_grip.y)

	var item := Dropped.new()
	item.kind = player.weapon
	item.pos = to_global(Vector2(grip.x, 0.0))
	item.z = maxf(0.0, -grip.y)
	item.angle = Vector2(weapon_dir.x * signf(facing), weapon_dir.y).angle()
	item.vel = velocity
	item.z_vel = lift
	item.spin = spin
	dropped.append(item)

	player.weapon = PlayerBody.Weapon.NONE

## The nearest weapon lying still within reach. Only settled ones count: you
## cannot catch one in mid-air.
func _nearest_dropped_item(from: Vector2, reach: float) -> Dropped:
	var best: Dropped = null
	var best_distance := reach
	for i in dropped.size():
		var item: Dropped = dropped[i]
		if item.z > 0.5 or item.vel.length() > 6.0:
			continue
		var distance := from.distance_to(item.pos)
		if distance <= best_distance:
			best_distance = distance
			best = item
	return best

func nearest_dropped_range(from: Vector2, reach: float) -> float:
	var item := _nearest_dropped_item(from, reach)
	return -1.0 if item == null else from.distance_to(item.pos)

## Takes that weapon out of the world and hands back its kind, remembering the
## angle it was lying at so the hand can lift it out of that pose rather than
## snapping it straight to the carry.
func take_dropped(from: Vector2, reach: float) -> int:
	var taken := _nearest_dropped_item(from, reach)
	if taken == null:
		return -1

	var side := signf(facing)
	taken_angle = Vector2(cos(taken.angle) * side, sin(taken.angle)).angle()
	# remembered because the hand has to keep rising from here: the moment it
	# leaves the floor there is nothing left to search for, and a hand that falls
	# back on a default spot jumps there
	taken_point = _world_to_canonical(taken.pos, taken.z)
	dropped.erase(taken)
	return taken.kind

func _simulate_dropped(delta: float) -> void:
	for i in dropped.size():
		var item: Dropped = dropped[i]

		if item.z > 0.0 or item.z_vel > 0.0:
			item.z_vel -= DROP_GRAVITY * delta
			item.z += item.z_vel * delta
			if item.z <= 0.0:
				item.z = 0.0
				item.z_vel = -item.z_vel * DROP_BOUNCE
				if absf(item.z_vel) < 30.0:
					item.z_vel = 0.0
				item.vel *= DROP_LANDING_SLOWDOWN
				item.spin *= 0.4
		else:
			item.vel = item.vel.move_toward(Vector2.ZERO, DROP_FLOOR_DRAG * delta)
			item.spin = lerpf(item.spin, 0.0, minf(1.0, DROP_SPIN_DRAG * delta))

			# once it has stopped tumbling it settles flat, turning whichever way
			# it already faces rather than winding back
			var settle := clampf(1.0 - absf(item.spin) / 3.0, 0.0, 1.0)
			if settle > 0.0:
				var flat := 0.0 if absf(angle_difference(item.angle, 0.0)) < PI * 0.5 else PI
				item.angle = lerp_angle(item.angle, flat, 1.0 - exp(-DROP_SETTLE_EASE * settle * delta))

		item.pos += item.vel * delta
		item.angle += item.spin * delta

func _has_spear() -> bool:
	return player.weapon == PlayerBody.Weapon.SPEAR

func _has_bow() -> bool:
	return player.weapon == PlayerBody.Weapon.BOW

func _has_sword() -> bool:
	return player.weapon == PlayerBody.Weapon.SWORD \
		or player.weapon == PlayerBody.Weapon.SWORD_SHIELD

func _has_shield() -> bool:
	return player.weapon == PlayerBody.Weapon.SWORD_SHIELD

func _has_greatsword() -> bool:
	return player.weapon == PlayerBody.Weapon.GREATSWORD

func _has_pickaxe() -> bool:
	return player.weapon == PlayerBody.Weapon.PICKAXE

func _has_dagger() -> bool:
	return player.weapon == PlayerBody.Weapon.DAGGER

func _has_staff() -> bool:
	return player.weapon == PlayerBody.Weapon.STAFF

func _has_torch() -> bool:
	return player.weapon == PlayerBody.Weapon.TORCH

func _has_crossbow() -> bool:
	return player.weapon == PlayerBody.Weapon.CROSSBOW

## Where in the stroke the blow lands, for whatever is in hand. A bow and a staff
## return nothing on purpose: what they send out has its own moment of release
## and finds its own mark, so the swing itself never connects with anything.
func _melee_strike_end() -> float:
	if _has_bow() or _has_staff() or _has_crossbow():
		return -1.0
	if _has_spear():
		return SPEAR_THRUST_END
	if _has_greatsword():
		return GREAT_STRIKE_END
	if _has_pickaxe():
		return PICK_STRIKE_END
	if _has_dagger():
		return DAGGER_STRIKE_END
	if _has_sword():
		return SWORD_STRIKE_END
	return SWING_STRIKE_END

## Where a world point sits in the figure's own drawing frame: mirrored back out
## of the facing, with height above the floor separated from the floor position.
func _world_to_canonical(world: Vector2, above_floor: float) -> Vector2:
	var local := to_local(world)
	return Vector2(local.x * signf(facing), -above_floor)

## And the reverse, for putting something back into the world.
func _canonical_to_world(point: Vector2) -> Vector2:
	return to_global(Vector2(point.x * signf(facing), 0.0))

## Stooping for a rock: the hand goes to where the rock actually lies, so the
## reach matches the thing being picked up instead of miming at a fixed spot.
func _pose_pickup() -> void:
	var p := player.attack_progress()
	# reach for the thing itself, whichever it is -- a hand that stoops to a fixed
	# spot makes whatever is picked up jump into it from wherever it really lay
	var rock := player.target_item if player.target_item != null else player.carried_item
	var reach := shoulder + Vector2(18.0, 30.0)
	if rock != null:
		reach = _world_to_canonical(rock.global_position, rock.height + CARRY_ROCK_LIFT)
	elif player.weapon != PlayerBody.Weapon.NONE:
		reach = taken_point   # already in hand: keep lifting it from where it lay
	else:
		var item := _nearest_dropped_item(player.global_position, PlayerBody.PICKUP_RANGE)
		if item != null:
			reach = _world_to_canonical(item.pos, item.z)

	# Down to it, then back up. Where "up" is depends on what was taken: a rock is
	# held out in front, but a weapon has to arrive exactly where the hand carries
	# it normally -- end anywhere else and it jerks the moment the action releases
	# the pose back to the gait.
	var blend := smoothstep(0.0, 1.0, clampf((p - PICKUP_GRAB) / (1.0 - PICKUP_GRAB), 0.0, 1.0))
	var spread := CARRY_SPREAD * 0.5 * (1.0 - blend if rock == null else 1.0)

	var near_end := natural_near if rock == null else shoulder + CARRY_HAND - Vector2(0.0, CARRY_SPREAD * 0.5)
	var far_end := natural_far if rock == null else shoulder + CARRY_HAND + Vector2(0.0, CARRY_SPREAD * 0.5)

	near_hand = near_hand.lerp((reach - Vector2(0.0, spread)).lerp(near_end, blend), attack_amount)
	far_hand = far_hand.lerp((reach + Vector2(0.0, spread)).lerp(far_end, blend), attack_amount)

	# a weapon just taken off the floor comes up turning out of the way it lay,
	# rather than appearing in the hand already shouldered
	if player.weapon != PlayerBody.Weapon.NONE:
		weapon_grip = near_hand
		weapon_dir = Vector2.from_angle(lerp_angle(taken_angle, _carry_angle_for(player.weapon), blend))

## The angle a given weapon is held at when simply carried.
func _carry_angle_for(kind: PlayerBody.Weapon) -> float:
	match kind:
		PlayerBody.Weapon.SPEAR:
			return SPEAR_CARRY_ANGLE
		PlayerBody.Weapon.BOW:
			return BOW_CARRY_ANGLE
		PlayerBody.Weapon.SWORD, PlayerBody.Weapon.SWORD_SHIELD:
			return SWORD_CARRY_ANGLE
		PlayerBody.Weapon.GREATSWORD:
			return GREAT_CARRY_ANGLE
		PlayerBody.Weapon.PICKAXE:
			return PICK_CARRY_ANGLE
		PlayerBody.Weapon.DAGGER:
			return DAGGER_CARRY_ANGLE
		PlayerBody.Weapon.STAFF:
			return STAFF_CARRY_ANGLE
		PlayerBody.Weapon.TORCH:
			return TORCH_CARRY_ANGLE
		PlayerBody.Weapon.CROSSBOW:
			return XBOW_CARRY_ANGLE
		_:
			return AXE_CARRY_ANGLE

## Crouches and lays the weapon on the floor in front, then straightens up. The
## weapon rides the hand all the way down and turns flat as it goes, so it is
## already lying the way it will lie before it is let go of -- nothing jumps.
func _pose_put_down() -> void:
	var p := player.attack_progress()
	var down := smoothstep(0.0, 1.0, clampf(p / PUT_RELEASE, 0.0, 1.0))
	var back := smoothstep(0.0, 1.0, clampf((p - PUT_RELEASE) / (1.0 - PUT_RELEASE), 0.0, 1.0))

	# Starts from wherever the hand already is -- out in front for a rock, at the
	# side for a weapon -- and ends back at the hand's own resting place, so
	# neither taking the pose nor releasing it costs anything.
	var start := natural_near
	if _carried_on_shoulder():
		start = shoulder + SHOULDER_HAND
	elif player.is_carrying():
		start = shoulder + CARRY_HAND
	var reach := start.lerp(PUT_SPOT, down)
	var target := reach.lerp(natural_near, back)

	if player.is_carrying():
		# A rock stays in both hands all the way down, and the hands are driven
		# outright rather than blended in: the carry pose sets them directly, so
		# easing in from the gait would drop them to the hip for a few frames
		# first.
		near_hand = target - Vector2(0.0, CARRY_SPREAD * 0.5)
		far_hand = target + Vector2(0.0, CARRY_SPREAD * 0.5)
	else:
		near_hand = near_hand.lerp(target, attack_amount)
		far_hand = far_hand.lerp(target.lerp(natural_far, 0.5), attack_amount * 0.6)

	weapon_grip = near_hand
	# 0 is flat on the floor in this frame, whichever way the figure faces
	weapon_dir = Vector2.from_angle(lerp_angle(_carry_angle_for(player.weapon), 0.0, down))

## Carried in both hands in front of the chest -- or, if it is too big for that,
## hoisted onto the shoulder with one hand up steadying it.
func _pose_carry() -> void:
	if _carried_on_shoulder():
		near_hand = shoulder + SHOULDER_HAND
		far_hand = shoulder + Vector2(SHOULDER_HAND.x - 10.0, SHOULDER_HAND.y + 14.0)
		return

	var carry := shoulder + CARRY_HAND
	near_hand = carry + Vector2(0.0, -CARRY_SPREAD * 0.5)
	far_hand = carry + Vector2(0.0, CARRY_SPREAD * 0.5)

func _carried_on_shoulder() -> bool:
	return player.is_carrying() and player.carried_item.grip == Carriable.Grip.ON_SHOULDER

## Wound back past the shoulder, then hurled out and up.
func _pose_throw() -> void:
	var p := player.attack_progress()
	var target: Vector2
	if p < THROW_WIND_END:
		var u := smoothstep(0.0, 1.0, p / THROW_WIND_END)
		target = (shoulder + CARRY_HAND).lerp(shoulder + THROW_WIND_HAND, u)
	elif p < THROW_RELEASE:
		var u := smoothstep(0.0, 1.0, (p - THROW_WIND_END) / (THROW_RELEASE - THROW_WIND_END))
		target = (shoulder + THROW_WIND_HAND).lerp(shoulder + THROW_THROW_HAND, u)
	else:
		var u := smoothstep(0.0, 1.0, (p - THROW_RELEASE) / (1.0 - THROW_RELEASE))
		target = (shoulder + THROW_THROW_HAND).lerp(shoulder + CARRY_HAND * 0.4, u)

	near_hand = near_hand.lerp(target + Vector2(0.0, -CARRY_SPREAD * 0.4), attack_amount)
	far_hand = far_hand.lerp(target + Vector2(0.0, CARRY_SPREAD * 0.4), attack_amount)

## Keeps a held rock sitting in the hands, and sends it on its way when thrown.
func _update_rock(progress: float) -> void:
	if player.is_carrying():
		var held := (near_hand + far_hand) * 0.5 + Vector2(0.0, -CARRY_ROCK_LIFT)
		var angle := 0.0
		if _carried_on_shoulder():
			held = shoulder + SHOULDER_SPOT
			angle = SHOULDER_TILT * signf(facing)
		player.carried_item.hold_at(_canonical_to_world(held), -held.y, angle)

		if player.is_throwing() and prev_progress < THROW_RELEASE and progress >= THROW_RELEASE:
			var side := signf(facing)
			player.let_go(
				_canonical_to_world(held), -held.y,
				Vector2(side * THROW_SPEED, 0.0) + player.velocity * 0.3,
				THROW_LIFT,
				-side * THROW_SPIN
			)

## Felling stroke: same two-handed swing as a fighting chop, but it ends against
## something that will not give. The axe stops where it lands, dwells while it is
## rocked free, and the body is jarred by the stop instead of following through.
func _pose_chop() -> void:
	var swing := Vector2.from_angle(_chop_angle(player.attack_progress()))
	var reach := (UPPER_ARM + FOREARM) * CHOP_ARM_REACH
	near_hand = near_hand.lerp(shoulder + swing * reach, attack_amount)
	far_hand = far_hand.lerp(shoulder + swing * reach * CHOP_GRIP_GAP, attack_amount)

	weapon_grip = near_hand
	weapon_dir = _blade_along_forearm(AXE_CARRY_ANGLE, attack_amount)

func _chop_angle(p: float) -> float:
	if p < CHOP_WIND_END:
		var u := p / CHOP_WIND_END
		return lerpf(CHOP_REST_ANGLE, CHOP_WIND_ANGLE, 1.0 - pow(1.0 - u, 3.0))
	if p < CHOP_STRIKE_END:
		var u := (p - CHOP_WIND_END) / (CHOP_STRIKE_END - CHOP_WIND_END)
		return lerpf(CHOP_WIND_ANGLE, CHOP_HIT_ANGLE, smoothstep(0.0, 1.0, u))
	if p < CHOP_HOLD_END:
		# buried in the wood: it only creeps while being worked loose
		var u := (p - CHOP_STRIKE_END) / (CHOP_HOLD_END - CHOP_STRIKE_END)
		return CHOP_HIT_ANGLE + CHOP_LEVER * smoothstep(0.0, 1.0, u)
	var u := (p - CHOP_HOLD_END) / (1.0 - CHOP_HOLD_END)
	return lerpf(CHOP_HIT_ANGLE + CHOP_LEVER, CHOP_REST_ANGLE, 1.0 - pow(1.0 - u, 2.0))

## The axe stopping dead in the trunk jars the body back. Distinct from a cut
## death's jolt only in what drives it -- the timer here is the stroke, not the
## fall -- and it is what sells the blow as landing in something solid.
func _chop_jolt() -> float:
	if not player.is_chopping():
		return 0.0

	var since := player.attack_progress() - CHOP_STRIKE_END
	if since < 0.0:
		return 0.0
	return -CHOP_JOLT * exp(-CHOP_JOLT_DECAY * since) * attack_amount

## Same swing structure as the axe -- both hands on the haft, head following the
## forearm -- aimed at the floor instead of at a man.
func _pose_pickaxe() -> void:
	# carried out in front rather than against the hip, so the haft does not run
	# through the body
	near_hand += Vector2(PICK_CARRY_FORWARD, 0.0)

	if strike_amount > 0.001:
		var swing := Vector2.from_angle(_pickaxe_angle(player.attack_progress()))
		var reach := (UPPER_ARM + FOREARM) * PICK_ARM_REACH
		near_hand = near_hand.lerp(shoulder + swing * reach, strike_amount)
		far_hand = far_hand.lerp(shoulder + swing * reach * PICK_GRIP_GAP, strike_amount)

	weapon_grip = near_hand
	weapon_dir = _blade_along_forearm(PICK_CARRY_ANGLE, strike_amount)

func _pickaxe_angle(p: float) -> float:
	if p < PICK_WIND_END:
		var u := p / PICK_WIND_END
		return lerpf(PICK_REST_ANGLE, PICK_WIND_ANGLE, 1.0 - pow(1.0 - u, 3.0))
	if p < PICK_STRIKE_END:
		var u := (p - PICK_WIND_END) / (PICK_STRIKE_END - PICK_WIND_END)
		return lerpf(PICK_WIND_ANGLE, PICK_HIT_ANGLE, smoothstep(0.0, 1.0, u))
	if p < PICK_HOLD_END:
		# buried in the rock: it only creeps while being worked loose
		var u := (p - PICK_STRIKE_END) / (PICK_HOLD_END - PICK_STRIKE_END)
		return PICK_HIT_ANGLE + PICK_LEVER * smoothstep(0.0, 1.0, u)
	var u := (p - PICK_HOLD_END) / (1.0 - PICK_HOLD_END)
	return lerpf(PICK_HIT_ANGLE + PICK_LEVER, PICK_REST_ANGLE, 1.0 - pow(1.0 - u, 2.0))

## Rises before the stroke, then drops its weight through it. Returns a
## multiplier on hip height, so it reads as the whole body doing the work.
func _mining_crouch() -> float:
	if attack_amount <= 0.001:
		return 1.0
	if player.is_picking_up():
		# stoops to the floor and straightens up again
		var stoop := sin(PI * clampf(player.attack_progress() / PICKUP_GRAB, 0.0, 1.0))
		if player.attack_progress() > PICKUP_GRAB:
			stoop = 1.0 - smoothstep(0.0, 1.0, (player.attack_progress() - PICKUP_GRAB) / (1.0 - PICKUP_GRAB))
		return lerpf(1.0, PICKUP_CROUCH, stoop * attack_amount)
	if player.is_putting_down():
		var p := player.attack_progress()
		var stoop := smoothstep(0.0, 1.0, clampf(p / PUT_RELEASE, 0.0, 1.0))
		if p > PUT_RELEASE:
			stoop = 1.0 - smoothstep(0.0, 1.0, (p - PUT_RELEASE) / (1.0 - PUT_RELEASE))
		return lerpf(1.0, PUT_CROUCH, stoop * attack_amount)
	if player.is_chopping():
		return _chop_brace()
	# likewise the miner's stoop belongs to the mining stroke, not to any action
	# that happens to be running with a pick in hand
	if not _has_pickaxe() or not player.is_striking():
		return 1.0

	var p := player.attack_progress()
	var amount: float
	if p < PICK_WIND_END:
		amount = PICK_RISE * smoothstep(0.0, 1.0, p / PICK_WIND_END)
	elif p < PICK_STRIKE_END:
		var u := (p - PICK_WIND_END) / (PICK_STRIKE_END - PICK_WIND_END)
		amount = lerpf(PICK_RISE, 1.0, smoothstep(0.0, 1.0, u))
	elif p < PICK_HOLD_END:
		amount = 1.0
	else:
		var u := (p - PICK_HOLD_END) / (1.0 - PICK_HOLD_END)
		amount = 1.0 - smoothstep(0.0, 1.0, u)

	return lerpf(1.0, PICK_CROUCH, amount * attack_amount)

## A woodcutter braces into the stroke rather than stooping over it: much less
## drop than the pick, and held while the axe is worked free.
func _chop_brace() -> float:
	var p := player.attack_progress()
	var amount: float
	if p < CHOP_WIND_END:
		amount = 0.0
	elif p < CHOP_STRIKE_END:
		amount = smoothstep(0.0, 1.0, (p - CHOP_WIND_END) / (CHOP_STRIKE_END - CHOP_WIND_END))
	elif p < CHOP_HOLD_END:
		amount = 1.0
	else:
		amount = 1.0 - smoothstep(0.0, 1.0, (p - CHOP_HOLD_END) / (1.0 - CHOP_HOLD_END))

	return lerpf(1.0, CHOP_CROUCH, amount * attack_amount)

func _spawn_chips(reach: float, color: Color) -> void:
	var side := signf(facing)
	var head := Vector2(weapon_grip.x * side, weapon_grip.y) \
		+ Vector2(weapon_dir.x * side, weapon_dir.y) * reach

	for i in CHIP_COUNT:
		var chip := Chip.new()
		chip.color = color
		chip.pos = to_global(Vector2(head.x, 0.0))
		chip.z = maxf(2.0, -head.y)
		# thrown back out of the cut, scattered around the way the pick went in
		var heading := Vector2(-side, 0.0).rotated(randf_range(-CHIP_SPREAD, CHIP_SPREAD))
		chip.vel = heading * randf_range(CHIP_SPEED_MIN, CHIP_SPEED_MAX)
		chip.z_vel = randf_range(CHIP_LIFT_MIN, CHIP_LIFT_MAX)
		chip.life = CHIP_LIFE
		chip.size = randf_range(1.2, 2.6)
		chips.append(chip)

	while chips.size() > CHIP_MAX:
		chips.pop_front()

func _simulate_chips(delta: float) -> void:
	var alive := []
	for i in chips.size():
		var chip: Chip = chips[i]
		chip.life -= delta
		if chip.life <= 0.0:
			continue

		chip.z_vel -= CHIP_GRAVITY * delta
		chip.z += chip.z_vel * delta
		if chip.z <= 0.0:
			chip.z = 0.0
			chip.z_vel = -chip.z_vel * CHIP_BOUNCE
			if absf(chip.z_vel) < 25.0:
				chip.z_vel = 0.0
			chip.vel *= 0.6

		chip.vel = chip.vel.move_toward(Vector2.ZERO, CHIP_DRAG * delta)
		chip.pos += chip.vel * delta
		alive.append(chip)

	chips = alive

## The blade angle every swung weapon uses: carried at a fixed angle, and once
## swinging it follows the forearm, so the wrist carries it round the arc. This
## is the axe's behaviour, which is the one that reads as a real strike; driving
## it from the shoulder instead makes the weapon and arm rotate as one piece.
func _blade_along_forearm(carry_angle: float, blend: float) -> Vector2:
	var elbow := _joint(shoulder, near_hand, UPPER_ARM, FOREARM, -1.0)
	var forearm := near_hand - elbow
	var along := forearm.angle() if forearm.length() > 0.01 else PI * 0.5
	return Vector2.from_angle(lerp_angle(carry_angle, along, blend))

## Both hands stay on the grip whatever it is doing -- rested back over the
## shoulder, or hauled round in an arc wider than the axe's and slower than
## anything else here.
func _pose_greatsword() -> void:
	if strike_amount > 0.001:
		var swing := Vector2.from_angle(_greatsword_angle(player.attack_progress()))
		near_hand = near_hand.lerp(
			shoulder + swing * (UPPER_ARM + FOREARM) * GREAT_ARM_REACH,
			strike_amount
		)

	weapon_grip = near_hand
	weapon_dir = _blade_along_forearm(GREAT_CARRY_ANGLE, strike_amount)

	# both hands stay on the grip, swinging or not
	far_hand = near_hand - weapon_dir * GREAT_GRIP_GAP

	# the second hand rides the grip below the first, so the two-handed hold
	# never comes apart
	far_hand = near_hand - weapon_dir * GREAT_GRIP_GAP

func _greatsword_angle(p: float) -> float:
	if p < GREAT_WIND_END:
		var u := p / GREAT_WIND_END
		return lerpf(GREAT_REST_ANGLE, GREAT_WIND_ANGLE, 1.0 - pow(1.0 - u, 3.0))
	if p < GREAT_STRIKE_END:
		var u := (p - GREAT_WIND_END) / (GREAT_STRIKE_END - GREAT_WIND_END)
		return lerpf(GREAT_WIND_ANGLE, GREAT_HIT_ANGLE, smoothstep(0.0, 1.0, u))
	var u := (p - GREAT_STRIKE_END) / (1.0 - GREAT_STRIKE_END)
	return lerpf(GREAT_HIT_ANGLE, GREAT_REST_ANGLE, 1.0 - pow(1.0 - u, 2.0))

## A one-handed cut: thrown from the shoulder through a flat arc, with the blade
## following the forearm so the wrist carries it round. The off arm either
## counterbalances the cut or, with a shield, holds its ground.
## Planted upright at rest, brought down and levelled to cast. The free hand
## comes up the shaft towards the stone as the charge builds, so the gathering is
## something the body does and not just a light getting brighter.
func _pose_staff() -> void:
	var level := _staff_level()
	var aim := Vector2.from_angle(lerpf(STAFF_CARRY_ANGLE, STAFF_AIM_ANGLE, level))
	var grip := shoulder + STAFF_HAND.lerp(STAFF_HAND_CAST, level)

	# Held out in front whether or not anything is being cast. Blended only by
	# strike_amount it sat wherever the gait arm happened to swing, which put the
	# shaft straight through the body at rest -- and what is left of the swing is
	# deliberate, so carrying it still reads as walking.
	near_hand = near_hand.lerp(grip, maxf(STAFF_CARRY_HOLD, strike_amount))
	# The free hand follows the staff, not the light. Driven by the charge it
	# tore 60 px back to the gait in a single frame at the release -- the stone
	# is meant to go out instantly, the arm is not.
	far_hand = far_hand.lerp(grip + aim * STAFF_SHAFT * STAFF_OFF_REACH, level)

	weapon_grip = near_hand
	weapon_dir = aim

## How far the staff has come down out of its carry: raised, held level while the
## charge gathers, and returned once the bolt is away.
func _staff_level() -> float:
	if strike_amount <= 0.001:
		return 0.0
	var p := player.attack_progress()
	var held := STAFF_HOLD_END + STAFF_RECOVER
	if p < STAFF_RAISE_END:
		return smoothstep(0.0, 1.0, p / STAFF_RAISE_END) * strike_amount
	if p < held:
		return strike_amount
	return (1.0 - smoothstep(0.0, 1.0, (p - held) / (1.0 - held))) * strike_amount

## And how much light has gathered. Nothing is left after the release: a stone
## still burning once the bolt has gone says the cast never finished.
func _staff_gather(p: float) -> float:
	if p >= STAFF_HOLD_END:
		return 0.0
	return smoothstep(0.0, 1.0, p / STAFF_HOLD_END)

## Swung, on the axe's own arc and the axe's own timing -- one hand, up behind
## the shoulder and down through. The torch only differs in what it is carrying
## at the end of it, so it has no swing machinery of its own to get wrong.
func _pose_torch() -> void:
	if strike_amount > 0.001:
		var swing := Vector2.from_angle(_swing_angle(player.attack_progress()))
		near_hand = near_hand.lerp(
			shoulder + swing * (UPPER_ARM + FOREARM) * SWING_ARM_REACH, strike_amount)

	weapon_grip = near_hand
	weapon_dir = _blade_along_forearm(TORCH_CARRY_ANGLE, strike_amount)

## Short, quick and close in. There is no wind-up worth the name -- a knife that
## is hauled back over the shoulder has stopped being a knife -- so the blade is
## cocked barely past the wrist and driven straight out.
func _pose_dagger() -> void:
	if player.is_backstabbing():
		_pose_backstab()
		return

	if strike_amount > 0.001:
		var thrust := Vector2.from_angle(_dagger_angle(player.attack_progress()))
		near_hand = near_hand.lerp(
			shoulder + thrust * (UPPER_ARM + FOREARM) * DAGGER_ARM_REACH,
			strike_amount
		)

	weapon_grip = near_hand
	weapon_dir = _blade_along_forearm(DAGGER_CARRY_ANGLE, strike_amount * DAGGER_TURN)

func _dagger_angle(p: float) -> float:
	if p < DAGGER_BACK_END:
		var u := p / DAGGER_BACK_END
		return lerpf(DAGGER_REST_ANGLE, DAGGER_BACK_ANGLE, 1.0 - pow(1.0 - u, 3.0))
	if p < DAGGER_STRIKE_END:
		var u := (p - DAGGER_BACK_END) / (DAGGER_STRIKE_END - DAGGER_BACK_END)
		return lerpf(DAGGER_BACK_ANGLE, DAGGER_HIT_ANGLE, smoothstep(0.0, 1.0, u))
	var u := (p - DAGGER_STRIKE_END) / (1.0 - DAGGER_STRIKE_END)
	return lerpf(DAGGER_HIT_ANGLE, DAGGER_REST_ANGLE, 1.0 - pow(1.0 - u, 2.0))

## The blow from behind. The free hand goes over the mark first and the blade
## follows it, which is what separates this from a fast stab: it is a hold, not
## a swing. The body surges up out of the crouch to make it and sinks straight
## back down afterwards, so cover is given up for as short a time as possible.
func _pose_backstab() -> void:
	var p := player.attack_progress()
	var surge := _stab_surge(p)

	# the knife hand gathers back and low, then drives forward at the mark's back
	var gathered := shoulder + STAB_GATHER_HAND
	var driven := shoulder + STAB_DRIVE_HAND
	var knife := gathered.lerp(driven, smoothstep(0.0, 1.0, _stab_drive(p)))
	near_hand = near_hand.lerp(knife, stab_amount)

	# and the free hand clamps over the shoulder ahead of the blade, leading it
	var clamp_at := shoulder + STAB_CLAMP
	far_hand = far_hand.lerp(clamp_at, stab_amount * smoothstep(0.0, 1.0, _stab_drive(p) * 1.4))

	shoulder += Vector2(STAB_LEAN * surge * stab_amount, 0.0)
	head += Vector2(STAB_LEAN * 0.6 * surge * stab_amount, 0.0)

	weapon_grip = near_hand
	# the knife is carried reversed and turns point-first as it goes in: held
	# reversed all the way through, the arm reads as raised rather than driving
	weapon_dir = _blade_along_forearm(DAGGER_CARRY_ANGLE, _stab_drive(p))

## How far the pose itself has taken over: gathered into, held, released.
func _stab_shape(p: float) -> float:
	if p < STAB_IN:
		return smoothstep(0.0, 1.0, p / STAB_IN)
	if p > STAB_OUT:
		return 1.0 - smoothstep(0.0, 1.0, (p - STAB_OUT) / (1.0 - STAB_OUT))
	return 1.0

## How far the body has come up out of the crouch: nothing, then all of it at the
## drive, held while the blade is in, then back down into cover.
func _stab_surge(p: float) -> float:
	if p < STAB_GATHER_END:
		return 0.0
	if p < STAB_DRIVE_END:
		return smoothstep(0.0, 1.0, (p - STAB_GATHER_END) / (STAB_DRIVE_END - STAB_GATHER_END))
	if p < STAB_HOLD_END:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (p - STAB_HOLD_END) / (1.0 - STAB_HOLD_END))

## And how far the blade itself has travelled, which leads the body slightly.
func _stab_drive(p: float) -> float:
	if p < STAB_GATHER_END:
		return 0.0
	if p < STAB_HOLD_END:
		return clampf((p - STAB_GATHER_END) / (STAB_DRIVE_END - STAB_GATHER_END), 0.0, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, (p - STAB_HOLD_END) / (1.0 - STAB_HOLD_END)) * 0.6

func _pose_sword() -> void:
	if strike_amount > 0.001:
		var swing := Vector2.from_angle(_sword_angle(player.attack_progress()))
		near_hand = near_hand.lerp(
			shoulder + swing * (UPPER_ARM + FOREARM) * SWORD_ARM_REACH,
			strike_amount
		)
		if not _has_shield():
			far_hand = far_hand.lerp(far_hand - Vector2(SWORD_OFF_HAND_BACK, 0.0), strike_amount)

	if _has_shield():
		far_hand = shoulder + Vector2(SHIELD_FORWARD, SHIELD_DROP)

	weapon_grip = near_hand
	weapon_dir = _blade_along_forearm(SWORD_CARRY_ANGLE, strike_amount)

func _sword_angle(p: float) -> float:
	if p < SWORD_WIND_END:
		var u := p / SWORD_WIND_END
		return lerpf(SWORD_REST_ANGLE, SWORD_WIND_ANGLE, 1.0 - pow(1.0 - u, 3.0))
	if p < SWORD_STRIKE_END:
		var u := (p - SWORD_WIND_END) / (SWORD_STRIKE_END - SWORD_WIND_END)
		return lerpf(SWORD_WIND_ANGLE, SWORD_HIT_ANGLE, smoothstep(0.0, 1.0, u))
	var u := (p - SWORD_STRIKE_END) / (1.0 - SWORD_STRIKE_END)
	return lerpf(SWORD_HIT_ANGLE, SWORD_REST_ANGLE, 1.0 - pow(1.0 - u, 2.0))

## The bow is held out in the near hand while the far hand draws the string back
## to the jaw. Nothing swings: the shot is made by the two hands pulling apart.
## Carried muzzle-down in a bent arm and brought level to shoot. Spanning it is a
## different pose entirely, and takes over when that is what is happening.
func _pose_crossbow() -> void:
	if player.is_spanning():
		_pose_span()
		return

	var raise := 0.0
	if strike_amount > 0.001:
		raise = smoothstep(0.0, 1.0, clampf(player.attack_progress() / XBOW_RAISE_END, 0.0, 1.0))
		raise *= strike_amount
	var aim := Vector2.from_angle(lerpf(XBOW_CARRY_ANGLE, XBOW_AIM_ANGLE, raise))

	var carried := shoulder + XBOW_CARRY_HAND
	var levelled := shoulder + Vector2(XBOW_CARRY_HAND.x + 4.0, 2.0)
	near_hand = near_hand.lerp(carried.lerp(levelled, raise), XBOW_CARRY_HOLD)

	# the off hand comes onto the stock to steady it, and only while aiming
	far_hand = far_hand.lerp(near_hand + aim * XBOW_OFF_HAND, raise)

	weapon_grip = near_hand
	weapon_dir = aim

## Butt on the ground, foot through the stirrup, both hands hauling the string
## back over the nut. Everything about it is slow and low, which is the point.
func _pose_span() -> void:
	var p := player.attack_progress()
	var down := smoothstep(0.0, 1.0, clampf(p / SPAN_STOOP_END, 0.0, 1.0))
	var up := smoothstep(0.0, 1.0, clampf((p - SPAN_HAUL_END) / (1.0 - SPAN_HAUL_END), 0.0, 1.0))
	var over := down * (1.0 - up)
	var haul := smoothstep(0.0, 1.0,
		clampf((p - SPAN_STOOP_END) / (SPAN_HAUL_END - SPAN_STOOP_END), 0.0, 1.0)) * (1.0 - up)

	var low := shoulder + SPAN_HAND_LOW
	var back := shoulder + SPAN_HAND_BACK
	var pull := low.lerp(back, haul)
	near_hand = near_hand.lerp(pull, over)
	far_hand = far_hand.lerp(pull + Vector2(-5.0, 3.0), over)

	shoulder += Vector2(SPAN_LEAN * over, 0.0)
	head += Vector2(SPAN_LEAN * 0.8 * over, 0.0)

	# the weapon stands on its butt while this is going on
	weapon_grip = low.lerp(near_hand, 0.4)
	weapon_dir = Vector2.from_angle(lerpf(XBOW_CARRY_ANGLE, 1.15, over))

## How far the body is folded over the work of spanning.
func _span_stoop() -> float:
	if not player.is_spanning():
		return 1.0
	var p := player.attack_progress()
	var down := smoothstep(0.0, 1.0, clampf(p / SPAN_STOOP_END, 0.0, 1.0))
	var up := smoothstep(0.0, 1.0, clampf((p - SPAN_HAUL_END) / (1.0 - SPAN_HAUL_END), 0.0, 1.0))
	return lerpf(1.0, SPAN_STOOP, down * (1.0 - up))

func _pose_bow() -> void:
	var aim := Vector2.from_angle(lerpf(BOW_CARRY_ANGLE, BOW_AIM_ANGLE, strike_amount))
	bow_draw = _bow_draw()

	var grip := shoulder + aim * lerpf(BOW_ARM_CARRY, _bow_arm_reach(), strike_amount)
	grip += Vector2(0.0, BOW_HAND_DROP)

	# At rest the bow hangs from a softly bent arm, not from a fist jammed under
	# the collarbone. Drawing straightens it: that is the whole difference
	# between carrying a bow and shooting one.
	var carried := shoulder + BOW_CARRY_HAND
	near_hand = near_hand.lerp(carried, BOW_CARRY_HOLD).lerp(grip, strike_amount)
	far_hand = far_hand.lerp(grip - aim * _bow_hand_back(), strike_amount)

	weapon_grip = near_hand
	weapon_dir = aim

## How far the string is pulled: drawn steadily, held, then loosed in a snap.
func _bow_draw() -> float:
	if strike_amount <= 0.001:
		return 0.0

	var p := player.attack_progress()
	if p < BOW_DRAW_END:
		return smoothstep(0.0, 1.0, p / BOW_DRAW_END) * strike_amount
	if p < BOW_HOLD_END:
		return strike_amount
	return maxf(0.0, 1.0 - (p - BOW_HOLD_END) / BOW_SNAP) * strike_amount

func _bow_arm_reach() -> float:
	var p := player.attack_progress()
	if p < BOW_HOLD_END:
		return lerpf(BOW_ARM_CARRY, BOW_ARM_REACH, smoothstep(0.0, 1.0, p / BOW_DRAW_END))
	# the bow arm holds its aim for a moment after the loose, then relaxes
	var u := (p - BOW_HOLD_END) / (1.0 - BOW_HOLD_END)
	return lerpf(BOW_ARM_REACH, BOW_ARM_CARRY, smoothstep(0.0, 1.0, maxf(0.0, u - 0.3) / 0.7))

## The string hand does not follow the string home: released, it carries on back
## past the ear and only then relaxes.
func _bow_hand_back() -> float:
	var p := player.attack_progress()
	if p < BOW_HOLD_END:
		return BOW_DRAW_BACK * smoothstep(0.0, 1.0, p / BOW_DRAW_END)

	var u := (p - BOW_HOLD_END) / (1.0 - BOW_HOLD_END)
	if u < 0.25:
		return lerpf(BOW_DRAW_BACK, BOW_FOLLOW_BACK, u / 0.25)
	return lerpf(BOW_FOLLOW_BACK, 0.0, smoothstep(0.0, 1.0, (u - 0.25) / 0.75))

## Fired at the moment the string is loosed, from the bow itself, inheriting a
## little of the archer's own momentum.
func _release_arrow(speed: float = ARROW_SPEED, harm: float = -1.0) -> void:
	var side := signf(facing)
	var grip := Vector2(weapon_grip.x * side, weapon_grip.y)
	var dir := Vector2(weapon_dir.x * side, weapon_dir.y)

	var arrow := Arrow.new()
	arrow.pos = to_global(Vector2(grip.x, 0.0))
	arrow.z = maxf(0.0, -grip.y)
	arrow.vel = Vector2(dir.x * speed, 0.0) + player.velocity * ARROW_CARRY
	arrow.z_vel = -dir.y * speed
	if player.aim_point != Vector2.INF:
		_aim_arrow(arrow, player.aim_point, speed)
	arrow.angle = dir.angle()
	# what it will do is settled as it leaves, by whatever loosed it
	arrow.harm = harm if harm >= 0.0 else PlayerBody.STRIKE_HARM[player.weapon]

	arrows.append(arrow)
	if arrows.size() > ARROW_MAX:
		arrows.pop_front()

## Sends a shot at a point on the floor instead of straight ahead: across the
## field towards it, and lofted just enough to come down there. Drag and gravity
## are the arrow's own, so it is the same shaft on the same arc as any other --
## only pointed.
func _aim_arrow(arrow: Arrow, at: Vector2, speed: float) -> void:
	var toward := at - arrow.pos
	var reach := toward.length()
	if reach < 1.0:
		return
	var flat := speed * AIM_SHARE
	arrow.vel = toward / reach * flat
	# how long it is in the air, allowing for the drag that slows it
	var flight := reach / maxf(flat - ARROW_DRAG * reach / flat * 0.5, flat * 0.5)
	arrow.z_vel = (0.5 * ARROW_GRAVITY * flight * flight - arrow.z) / flight
	arrow.angle = Vector2(arrow.vel.x, -arrow.z_vel).angle()

## A cast bolt: it flies flat at the height it left the stone, finds whatever it
## passes through, and burns out on its own if it finds nothing.
class Bolt:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var z := 0.0
	var life := 0.0
	var spent := false

## Sent from the stone itself, not from the hand, and dead level: a bolt that
## followed the staff's angle would climb away over everything it was aimed at.
func _release_bolt() -> void:
	var side := signf(facing)
	var grip := Vector2(weapon_grip.x * side, weapon_grip.y)
	var dir := Vector2(weapon_dir.x * side, weapon_dir.y)
	var head := grip + dir * STAFF_SHAFT

	var bolt := Bolt.new()
	bolt.pos = to_global(Vector2(head.x, 0.0))
	bolt.z = maxf(0.0, -head.y)
	bolt.vel = Vector2(side * BOLT_SPEED, 0.0)

	bolts.append(bolt)
	if bolts.size() > BOLT_MAX:
		bolts.pop_front()

func _simulate_bolts(delta: float) -> void:
	for i in bolts.size():
		var bolt: Bolt = bolts[i]
		if bolt.spent:
			continue
		bolt.life += delta
		bolt.pos += bolt.vel * delta
		if player.hit_target_at(bolt.pos, BOLT_REACH, PlayerBody.STRIKE_HARM[PlayerBody.Weapon.STAFF]):
			bolt.spent = true
			_burst(bolt)
		elif bolt.life > BOLT_LIFE:
			bolt.spent = true
	# spent ones leave nothing behind, unlike an arrow, which stays where it stuck
	var live: Array = []
	for i in bolts.size():
		var bolt: Bolt = bolts[i]
		if not bolt.spent:
			live.append(bolt)
	bolts = live

## Sparks where it struck, using the same short-lived debris as the pick's chips.
func _burst(bolt: Bolt) -> void:
	for i in range(7):
		var chip := Chip.new()
		chip.pos = bolt.pos
		chip.z = bolt.z
		chip.vel = Vector2(randf_range(-90.0, 90.0), randf_range(-70.0, 70.0))
		chip.z_vel = randf_range(40.0, 160.0)
		chip.size = randf_range(1.2, 2.4)
		chip.color = ORB_GLOW if i % 2 == 0 else ORB_CORE
		chips.append(chip)

func _simulate_arrows(delta: float) -> void:
	for i in arrows.size():
		var arrow: Arrow = arrows[i]
		if arrow.stuck:
			continue

		# An arrow in flight finds what it passes through. Without this it sailed
		# clean through everyone -- the bolt from the staff was the only thing
		# whose flight could hurt anything.
		#
		# One that lands is gone: a shaft left where it struck hangs in mid-air
		# the moment the body walks on, and one dropped at his feet is litter
		# that only says a shot was taken. The flinch is the news.
		if player.hit_target_at(arrow.pos, ARROW_REACH, arrow.harm):
			arrow.gone = true
			continue

		arrow.z_vel -= ARROW_GRAVITY * delta
		arrow.z += arrow.z_vel * delta
		arrow.vel = arrow.vel.move_toward(Vector2.ZERO, ARROW_DRAG * delta)
		arrow.pos += arrow.vel * delta

		# the shaft points along its screen-space travel, so it pitches over as
		# it falls and keeps that angle once it lands
		arrow.angle = Vector2(arrow.vel.x, arrow.vel.y - arrow.z_vel).angle()
		if arrow.z <= 0.0:
			arrow.z = 0.0
			arrow.stuck = true

	# only the ones that hit nobody are left standing in the field
	var live: Array = []
	for i in arrows.size():
		var arrow: Arrow = arrows[i]
		if not arrow.gone:
			live.append(arrow)
	arrows = live

## The spear is thrust, not swung: the shaft levels off at the target and the
## hands drive straight along it. The rear hand keeps the grip, the front hand
## comes onto the shaft for the thrust and guides it out.
func _pose_spear() -> void:
	weapon_dir = Vector2.from_angle(lerpf(SPEAR_CARRY_ANGLE, SPEAR_THRUST_ANGLE, strike_amount))

	if strike_amount > 0.001:
		var front := shoulder + weapon_dir * _spear_reach() + Vector2(0.0, SPEAR_GRIP_DROP)

		# hold the grip inside the arm's reach, or the spear drifts free of the
		# hand that is supposed to be holding it
		var span := front - shoulder
		var limit := (UPPER_ARM + FOREARM) * SPEAR_MAX_ARM
		if span.length() > limit:
			front = shoulder + span.normalized() * limit

		near_hand = near_hand.lerp(front - weapon_dir * SPEAR_GRIP_GAP, strike_amount)
		far_hand = far_hand.lerp(front, strike_amount)

	weapon_grip = near_hand

## How far ahead of the shoulder the leading hand sits: cocked back, driven out
## fast, then recovered slowly.
func _spear_reach() -> float:
	var p := player.attack_progress()
	var reach: float
	if p < SPEAR_WIND_END:
		reach = lerpf(SPEAR_READY_REACH, SPEAR_WOUND_REACH, smoothstep(0.0, 1.0, p / SPEAR_WIND_END))
	elif p < SPEAR_THRUST_END:
		var u := (p - SPEAR_WIND_END) / (SPEAR_THRUST_END - SPEAR_WIND_END)
		reach = lerpf(SPEAR_WOUND_REACH, SPEAR_EXTEND_REACH, smoothstep(0.0, 1.0, u))
	else:
		var u := (p - SPEAR_THRUST_END) / (1.0 - SPEAR_THRUST_END)
		reach = lerpf(SPEAR_EXTEND_REACH, SPEAR_READY_REACH, 1.0 - pow(1.0 - u, 2.0))
	return reach

## The axe is gripped in the near hand. Carried, it sits at a fixed angle clear
## of the floor; swung, it follows the forearm, so the head sweeps its own arc.
func _update_axe_pose() -> void:
	weapon_grip = near_hand

	var elbow := _joint(shoulder, near_hand, UPPER_ARM, FOREARM, -1.0)
	var forearm := near_hand - elbow
	var along := forearm.normalized() if forearm.length() > 0.01 else Vector2.DOWN
	weapon_dir = Vector2.from_angle(AXE_CARRY_ANGLE).lerp(along, strike_amount).normalized()

## Foot offset in the canonical facing-right frame: x is fore/aft, y is up.
func _foot_offset(p: float, side: float) -> Vector2:
	# the step itself is shared with anything else that walks; everything below
	# is what this particular body does on top of it
	var walk := Gait.foot_offset(p, stride, stance_fraction, foot_lift, travel)

	# standing feet are not nailed down: they carry whatever the weight shift has
	# most recently left them at
	var foot := 0 if side > 0.0 else 1
	var idle := Vector2(
		side * IDLE_FOOT_SPLIT * lerpf(1.0, CROUCH_FOOT_SPLIT, crouch_amount)
			+ foot_idle[foot] * idle_weight,
		-foot_raise[foot] * idle_weight   # negative is up in this frame
	)
	var tuck := Vector2(JUMP_FOOT_TUCK.x + side * IDLE_FOOT_SPLIT, JUMP_FOOT_TUCK.y)
	var limp := Vector2(DEATH_FOOT_DRAW.x + side * IDLE_FOOT_SPLIT * 0.6, DEATH_FOOT_DRAW.y)
	var kicked := Vector2(SHOT_FOOT.x + side * IDLE_FOOT_SPLIT * 0.5, SHOT_FOOT.y)
	var cut := Vector2(CUT_FOOT.x + side * IDLE_FOOT_SPLIT * 0.7, CUT_FOOT.y)
	return idle.lerp(walk, move_amount) \
		.lerp(tuck, air_amount) \
		.lerp(limp, collapse_amount) \
		.lerp(kicked, shot_amount) \
		.lerp(cut, cut_amount)

## Hip height above the ground.
##
## The supporting leg keeps a constant length and the hip simply rides over the
## planted foot, the way a body vaults over its own leg. That matters for how the
## figure reads: hold the leg's length fixed and the knee keeps one slight bend
## all through stance, whereas letting the hip sink below the leg's reach folds
## the knee hard -- the geometry is unforgiving, a few pixels of sink swing the
## knee out by triple that.
func _hip_height(near: Vector2, far: Vector2, delta: float) -> float:
	var height := Gait.ride_height([near, far], HIP_HEIGHT)

	# running leaves the ground between steps, so the body arcs up a little
	var half_phase := fposmod(phase, 0.5)
	if stance_fraction < 0.5 and half_phase >= stance_fraction:
		var u := (half_phase - stance_fraction) / (0.5 - stance_fraction)
		height += FLIGHT_BOUNCE * sin(PI * u) * run_blend

	height = lerpf(height, HIP_HEIGHT * JUMP_HIP_RATIO, air_amount)

	if death_amount > 0.001:
		# the knees give way as the body goes down, then the legs straighten out
		# again as it settles limp, instead of staying folded underneath it
		var ratio := KNEE_COLLAPSE
		var span := FALL_TIME
		match player.death_kind:
			PlayerBody.DeathKind.KNOCKED_BACK:
				ratio = SHOT_KNEE_COLLAPSE
				span = SHOT_FALL_TIME
			PlayerBody.DeathKind.CUT_DOWN:
				ratio = CUT_KNEE_COLLAPSE
				span = CUT_FALL_TIME
		var buckle := sin(PI * clampf(player.death_time / (span * 1.4), 0.0, 1.0))
		height *= lerpf(1.0, ratio, buckle * death_amount)

	height *= _span_stoop()
	height = lerpf(height, height * ROLL_HIP, roll_amount)
	height *= _mining_crouch()
	height = lerpf(height, height * LOAD_SINK, load_amount)
	height = lerpf(height, height * CROUCH_HIP, crouch_amount)

	# Through the middle of getting up the body is folded right down over its own
	# feet -- that pass through a deep crouch is what separates standing up from
	# rotating upright.
	height = lerpf(height, height * RISE_CROUCH, _rise_fold())

	# Rising out of the crouch is the cost of the sneak: for the length of the
	# blow you are standing up in plain view. This has to come after the crouch
	# itself, not before -- ahead of it the crouch simply puts the body back down
	# and the move never stands up at all.
	height = lerpf(height, height * STAB_RISE, stab_amount * stab_surge)

	# smoothing the result rounds off the kinks where the supporting foot changes
	# and where stance hands over to flight, so nothing has to be faked upstream
	hip_height = _ease(hip_height, height, HIP_SMOOTH, delta)
	return hip_height

func _hand_target(swing: float, side: float) -> Vector2:
	var arm_length := UPPER_ARM + FOREARM
	var hang := lerpf(arm_hang, JUMP_ARM_HANG, air_amount)
	hang = lerpf(hang, DEATH_ARM_HANG, collapse_amount)
	hang = lerpf(hang, SHOT_ARM_HANG, shot_amount)
	hang = lerpf(hang, CUT_ARM_HANG, cut_amount)

	# a shot throws the arms straight overhead; a cut carries them across. Both
	# poses reach nearly the arm's full length, because a dead arm is slack, not
	# folded -- and the two are splayed apart, or they collapse into one line
	var fling := SHOT_ARM_FLING * shot_amount - CUT_ARM_SWEEP * cut_amount
	fling += side * DEATH_ARM_SPREAD * death_amount

	# hands are thrown back and up by the impact, the way a flinch throws them
	var flinch := _hit_recoil() * HIT_ARM_FLINCH
	return shoulder + Vector2(
		swing * arm_swing * move_amount + fling + flinch,
		arm_length * hang + flinch * 0.5
	)

func _draw() -> void:
	if batched:
		if pen == null:
			pen = Pen.new()
		pen.begin()
	_draw_shadow()

	# mirroring by scaling the whole figure keeps the IK intact and lets a change
	# of direction read as a turn instead of an instant flip
	var turn: float = signf(facing) * maxf(absf(facing), MIN_TURN_SCALE)
	_w_transform(roll_pivot, _fall_rotation() + _roll_rotation(), Vector2(turn, 1.0))

	# a brief blanch on impact, so a hit registers even at a glance
	var flash := 0.0
	if hit_amount > 0.001 and player.hit_time >= 0.0:
		flash = clampf(1.0 - player.hit_time / HIT_FLASH_TIME, 0.0, 1.0) * hit_amount
	var near_color := (PLATE_NEAR if armoured else NEAR_COLOR).lerp(Color.WHITE, flash)
	var far_color := (PLATE_FAR if armoured else FAR_COLOR).lerp(Color.WHITE, flash * 0.7)
	var limb := ARMOUR_LIMB if armoured else LIMB_WIDTH

	# far limbs first, dimmed, so the near side reads as closer
	_draw_limb(hip, far_foot, THIGH, SHIN, 1.0, far_color, limb)
	_draw_limb(shoulder, far_hand, UPPER_ARM, FOREARM, -1.0, far_color, limb)

	if armoured:
		_stroke_armour(near_color)
	else:
		_w_line(hip, shoulder, near_color, LIMB_WIDTH, smooth_lines)
	_w_circle(head, HEAD_RADIUS, near_color)
	if player.helm != PlayerBody.Helm.NONE:
		_stroke_helm(helm_at, near_color)

	# the shield is carried in front of the chest, so it covers the torso but
	# stays behind the weapon arm; it is strapped on and never dropped
	if _has_shield():
		_stroke_shield(far_hand)

	_draw_limb(hip, near_foot, THIGH, SHIN, 1.0, near_color, limb)
	_draw_limb(shoulder, near_hand, UPPER_ARM, FOREARM, -1.0, near_color, limb)
	if armoured:
		_stroke_pauldron(near_color)
	# hands full of rock means nothing is in them to draw
	if not player.is_carrying():
		_stroke_weapon(weapon_grip, weapon_dir, player.weapon)

	_w_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_dropped()

	_draw_arrows()
	_draw_bolts()
	_draw_wind()
	_draw_chips()
	if batched:
		pen.flush(self)

## Death: the figure goes over about its feet, then rebounds off the floor and
## settles. A collapse starts slow and accelerates the way a topple does; a hit
## throws the body away at full speed and lands it on its back, in the opposite
## direction. Scaling by death_amount means reviving eases the figure back
## upright instead of snapping it.
## How tightly the body is balled up: gathered in off the feet, held through the
## turn, and opened out again in time for the legs to meet the floor.
func _roll_shape(p: float) -> float:
	if p < ROLL_TUCK_IN:
		return smoothstep(0.0, 1.0, p / ROLL_TUCK_IN)
	if p > ROLL_TUCK_OUT:
		return 1.0 - smoothstep(0.0, 1.0, (p - ROLL_TUCK_OUT) / (1.0 - ROLL_TUCK_OUT))
	return 1.0

## One full turn over the course of the roll, slowest at the two ends: the body
## leaves the floor and meets it again with its feet, and only the middle of the
## move is actually upside down. A full turn also means the angle finishes where
## it started, so there is nothing to unwind when the roll releases.
func _roll_rotation() -> float:
	if not player.is_rolling():
		return 0.0
	var p := player.roll_progress()
	# The drawn rotation is in screen space, so this needs no facing factor --
	# unlike the fall, which is described relative to the facing and has to be
	# flipped with it. roll_dir is already a world direction; multiplying it by
	# the facing as well cancelled out, and a roll to the left turned over the
	# same way as a roll to the right.
	return TAU * smoothstep(0.0, 1.0, p) * player.roll_dir

func _fall_rotation() -> float:
	if death_amount <= 0.001:
		return 0.0

	var span := FALL_TIME
	var curve := FALL_EXPONENT
	var bounce := IMPACT_BOUNCE
	var direction := 1.0   # forward when the legs simply give way

	match player.death_kind:
		PlayerBody.DeathKind.KNOCKED_BACK:
			span = SHOT_FALL_TIME
			curve = SHOT_FALL_EXPONENT
			bounce = SHOT_IMPACT_BOUNCE
			direction = -1.0
		PlayerBody.DeathKind.CUT_DOWN:
			span = CUT_FALL_TIME
			curve = CUT_FALL_EXPONENT
			bounce = CUT_IMPACT_BOUNCE
			direction = -1.0

	var t := player.death_time
	var angle := FALL_ANGLE * clampf(pow(t / span, curve), 0.0, 1.0)
	if t > span:
		var since := t - span
		angle -= FALL_ANGLE * bounce * exp(-IMPACT_DECAY * since) * cos(IMPACT_FREQ * since)

	return angle * death_amount * direction * fall_side

## Stays on the floor while the figure jumps, shrinking and fading with height.
## The shadow stays on the ground whatever the body is doing above it.
##
## A jump lifts the figure within the node, so that case needs nothing. Being
## carried lifts the node itself -- and the shadow, drawn at the node's own
## origin, went up with it. Putting the carry height back takes it down again.
func _draw_shadow() -> void:
	# A body on the ground is flat on the ground: a shadow under it only reads as
	# something standing there, which is exactly the wrong thing to say about a
	# corpse you are meant to be able to walk over.
	if player.is_dead and player.carried_by == null:
		return
	var fade := clampf((player.air_height + player.height) / 120.0, 0.0, 0.5)
	_w_transform(Vector2(0.0, 2.0 + player.height), 0.0, Vector2(1.0, 0.42))
	_w_circle(Vector2.ZERO, 20.0 * (1.0 - fade * 0.7), Color(0.0, 0.0, 0.0, 0.25 * (1.0 - fade)))
	_w_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Two-bone limb: root -> joint -> tip, with the joint pushed to the side that
## matches a human knee (forward) or elbow (backward). The tip is clamped to the
## limb's reach so the segments never visually stretch.
func _draw_limb(root: Vector2, tip: Vector2, a: float, b: float, bend_sign: float,
		color: Color, width: float = LIMB_WIDTH) -> void:
	var joint := Gait.joint(root, tip, a, b, bend_sign)
	var reached := Gait.reached(root, tip, a, b)

	_w_line(root, joint, color, width, smooth_lines)
	_w_line(joint, reached, color, width, smooth_lines)
	_w_circle(reached, JOINT_RADIUS * (width / LIMB_WIDTH), color)

## Plate over the torso and a closed helm, both hung on points the rig already
## works out. The helm is squared off and slotted: a round head under a plume
## still reads as a bare head, and the visor is what says the face is covered.
func _stroke_armour(near_color: Color) -> void:
	var along := (shoulder - hip)
	var up := along.normalized() if along.length() > 0.01 else Vector2.UP
	var side := Vector2(up.y, -up.x)

	var cuirass := PackedVector2Array([
		hip + side * CUIRASS_WIDE * 0.55,
		shoulder + side * CUIRASS_WIDE,
		shoulder - side * CUIRASS_WIDE,
		hip - side * CUIRASS_WIDE * 0.55,
	])
	_w_polygon(cuirass, near_color)
	var rim := cuirass.duplicate()
	rim.append(cuirass[0])
	_w_polyline(rim, PLATE_EDGE, 1.3, smooth_lines)
	# the ridge down the breastplate
	_w_line(hip + up * 4.0, shoulder - up * 3.0, PLATE_EDGE, 1.2, smooth_lines)

## Drawn at wherever the helm currently is, rather than always on the head --
## which is the whole reason it can be taken off.
func _stroke_helm(at: Vector2, near_color: Color) -> void:
	var lean := helm_lean
	# forward, not backward: the other perpendicular put the eye slot on the back
	# of his head and the crest down inside his chest
	var across := Vector2(-lean.y, lean.x)

	var helm := PackedVector2Array([
		at - across * HELM_WIDE + lean * HELM_TALL * 0.45,
		at - across * HELM_WIDE * 0.8 - lean * HELM_TALL * 0.55,
		at + across * HELM_WIDE * 0.8 - lean * HELM_TALL * 0.55,
		at + across * HELM_WIDE + lean * HELM_TALL * 0.45,
	])
	_w_polygon(helm, near_color)
	var rim := helm.duplicate()
	rim.append(helm[0])
	_w_polyline(rim, PLATE_EDGE, 1.3, smooth_lines)

	# the slot to see out of, on the side the figure faces
	_w_line(at + across * HELM_WIDE * 0.15 + lean * 1.0,
		at + across * HELM_WIDE * 0.95 + lean * 1.0, VISOR_COLOR, 2.4, smooth_lines)
	# and a crest, because a helm in silhouette needs something on top of it
	_w_line(at + lean * HELM_TALL * 0.45, at + lean * (HELM_TALL * 0.45 + 7.0),
		PLUME_COLOR, 3.0, smooth_lines)

## A plate over the near shoulder, drawn after the arm so it caps the joint.
func _stroke_pauldron(near_color: Color) -> void:
	_w_circle(shoulder, PAULDRON, near_color)
	_w_arc(shoulder, PAULDRON, 0.0, TAU, 18, PLATE_EDGE, 1.2, smooth_lines)

## Two-bone IK: where the knee or elbow lands between root and tip.
func _joint(root: Vector2, tip: Vector2, a: float, b: float, bend_sign: float) -> Vector2:
	return Gait.joint(root, tip, a, b, bend_sign)

func _stroke_weapon(grip: Vector2, dir: Vector2, kind: PlayerBody.Weapon) -> void:
	match kind:
		PlayerBody.Weapon.NONE:
			return
		PlayerBody.Weapon.SPEAR:
			_stroke_spear(grip, dir)
		PlayerBody.Weapon.BOW:
			_stroke_bow(grip, dir)
		PlayerBody.Weapon.SWORD, PlayerBody.Weapon.SWORD_SHIELD:
			_stroke_sword(grip, dir, SWORD_BLADE, SWORD_GUARD, SWORD_TAPER, SWORD_POMMEL)
		PlayerBody.Weapon.GREATSWORD:
			_stroke_sword(grip, dir, GREAT_BLADE, GREAT_GUARD, GREAT_TAPER, GREAT_POMMEL)
		PlayerBody.Weapon.PICKAXE:
			_stroke_pickaxe(grip, dir)
		PlayerBody.Weapon.DAGGER:
			_stroke_sword(grip, dir, DAGGER_BLADE, DAGGER_GUARD, DAGGER_TAPER, DAGGER_POMMEL)
		PlayerBody.Weapon.STAFF:
			_stroke_staff(grip, dir)
		PlayerBody.Weapon.TORCH:
			_stroke_torch(grip, dir)
		PlayerBody.Weapon.CROSSBOW:
			_stroke_crossbow(grip, dir)
		PlayerBody.Weapon.CLUB:
			_stroke_club(grip, dir)
		_:
			_stroke_axe(grip, dir)

## Haft with a crosswise head: a long spike one side, a short chisel the other.
func _stroke_pickaxe(grip: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var tip := grip + dir * PICK_HAFT

	_w_line(grip - dir * PICK_BUTT, tip, WOOD_COLOR, 3.0, smooth_lines)

	var head := PackedVector2Array()
	for i in PICK_HEAD.size():
		var point: Vector2 = PICK_HEAD[i]
		head.append(tip + dir * point.x + perp * point.y)

	_w_polygon(head, STEEL_COLOR)

	var outline := head.duplicate()
	outline.append(head[0])
	_w_polyline(outline, STEEL_EDGE_COLOR, 1.2, smooth_lines)

## Chips settle where they land and fade out rather than piling up forever.
## Drawn outside the figure's mirrored frame on purpose: a bar that flips with
## the body fills from the wrong end when it turns round.
func _draw_wind() -> void:
	if player.is_dead:
		return

	var wind := clampf(player.stamina / PlayerBody.STAMINA_MAX, 0.0, 1.0)
	if wind < 0.999:
		_bar(WIND_ABOVE, wind,
			WIND_SPENT if wind < 0.2 else (WIND_LOW if wind < 0.5 else WIND_FULL))

	var life := clampf(player.health / player.health_max, 0.0, 1.0)
	if life < 0.999:
		_bar(LIFE_ABOVE, life, LIFE_LOW if life < 0.3 else LIFE_FULL)

func _bar(above: float, share: float, tone: Color) -> void:
	var at := Vector2(head.x * signf(facing), head.y - above)
	var half := WIND_WIDE * 0.5
	_w_rect(Rect2(at.x - half - 1.0, at.y - 1.0,
		WIND_WIDE + 2.0, WIND_TALL + 2.0), WIND_BACK)
	_w_rect(Rect2(at.x - half, at.y, WIND_WIDE * share, WIND_TALL), tone)

func _draw_chips() -> void:
	for i in chips.size():
		var chip: Chip = chips[i]
		var fade := clampf(chip.life / (CHIP_LIFE * 0.5), 0.0, 1.0)
		var at := to_local(chip.pos) + Vector2(0.0, -chip.z)
		_w_circle(at, chip.size, Color(chip.color.r, chip.color.g, chip.color.b, fade))

## Pommel, grip, crossguard and a tapered blade -- the guard is what stops it
## reading as a metal stick. Sized by the caller, since a two-hander is the same
## shape at a different scale.
func _stroke_sword(grip: Vector2, dir: Vector2, blade_length: float, guard_half: float, taper: float, pommel: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var guard := grip + dir * 3.0
	var tip := guard + dir * blade_length

	_w_line(grip - dir * pommel, guard, WOOD_COLOR, 3.2, smooth_lines)
	_w_circle(grip - dir * pommel, 2.0, STEEL_COLOR)
	_w_line(guard + perp * guard_half, guard - perp * guard_half, STEEL_COLOR, 2.8, smooth_lines)

	var blade := PackedVector2Array([
		guard + perp * taper,
		tip + perp * 0.8,
		tip + dir * 3.0,
		tip - perp * 0.8,
		guard - perp * taper,
	])
	_w_polygon(blade, STEEL_COLOR)

	var outline := blade.duplicate()
	outline.append(blade[0])
	_w_polyline(outline, STEEL_EDGE_COLOR, 1.1, smooth_lines)

## Carried upright on the off arm, so it stays readable instead of collapsing to
## an edge-on sliver the way a strictly side-on shield would.
func _stroke_shield(centre: Vector2) -> void:
	var face := PackedVector2Array()
	for i in SHIELD_SHAPE.size():
		var point: Vector2 = SHIELD_SHAPE[i]
		face.append(centre + point)

	_w_polygon(face, SHIELD_FACE_COLOR)

	var rim := face.duplicate()
	rim.append(face[0])
	_w_polyline(rim, SHIELD_RIM_COLOR, 1.8, smooth_lines)
	_w_circle(centre + Vector2(0.0, -2.0), 3.0, SHIELD_BOSS_COLOR)

## Limbs bowed towards the target, tips curling back, and a string that breaks
## into a V around the nock once it is drawn. The nocked arrow rides on the
## string, so it pulls back with the hand and is gone the moment it is loosed.
func _stroke_bow(grip: Vector2, dir: Vector2) -> void:
	var up := Vector2(dir.y, -dir.x)
	var upper := grip + up * BOW_HALF - dir * BOW_TIP_BACK
	var lower := grip - up * BOW_HALF - dir * BOW_TIP_BACK
	var belly := grip + dir * BOW_BELLY

	# quadratic through the belly: one curve for both limbs
	var limb := PackedVector2Array()
	for i in BOW_SEGMENTS + 1:
		var t := float(i) / float(BOW_SEGMENTS)
		var a := upper.lerp(belly, t)
		var b := belly.lerp(lower, t)
		limb.append(a.lerp(b, t))
	_w_polyline(limb, WOOD_COLOR, 2.6, smooth_lines)

	var nock := grip - dir * (BOW_DRAW_BACK * bow_draw)
	_w_line(upper, nock, BOW_STRING_COLOR, 1.2, smooth_lines)
	_w_line(nock, lower, BOW_STRING_COLOR, 1.2, smooth_lines)

	if bow_draw > 0.01:
		_stroke_arrow(nock + dir * ARROW_LENGTH, dir)

## Long shaft and a symmetric leaf blade: no cutting side, since a spear is
## meant to arrive point first from any angle.
func _stroke_spear(grip: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var base := grip + dir * (SPEAR_LENGTH - SPEAR_HEAD_LENGTH)

	_w_line(grip - dir * SPEAR_BUTT, base, WOOD_COLOR, 2.5, smooth_lines)
	_w_line(base + perp * SPEAR_COLLAR, base - perp * SPEAR_COLLAR, STEEL_COLOR, 2.5, smooth_lines)

	var head := PackedVector2Array()
	for i in SPEAR_HEAD.size():
		var point: Vector2 = SPEAR_HEAD[i]
		head.append(base + dir * point.x + perp * point.y)

	_w_polygon(head, STEEL_COLOR)

	var outline := head.duplicate()
	outline.append(head[0])
	_w_polyline(outline, STEEL_EDGE_COLOR, 1.2, smooth_lines)

## Handle plus a bladed head, with the blade facing the way the head travels on
## a swing, so the chop leads with its edge.
## A club: a stick that thickens to a knotted head. It is swung the way the axe
## is -- everything that is not drawn here is the axe's.
func _stroke_club(grip: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var butt := grip - dir * CLUB_BUTT
	var tip := grip + dir * CLUB_LENGTH
	_w_polygon(PackedVector2Array([
		butt + perp * 1.6, tip + perp * CLUB_HEAD, tip - perp * CLUB_HEAD, butt - perp * 1.6]), WOOD_COLOR)
	_w_circle(tip, CLUB_HEAD, WOOD_COLOR)
	# knots in the head, so it reads as wood rather than a paddle
	_w_circle(tip - dir * 6.0 + perp * 2.0, 1.3, CLUB_KNOT)
	_w_circle(tip - dir * 1.0 - perp * 2.4, 1.2, CLUB_KNOT)

func _stroke_axe(grip: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var tip := grip + dir * AXE_HANDLE

	_w_line(grip - dir * AXE_BUTT, tip, WOOD_COLOR, 3.0, smooth_lines)

	var head := PackedVector2Array()
	for i in AXE_HEAD.size():
		var point: Vector2 = AXE_HEAD[i]
		head.append(tip + dir * point.x + perp * point.y)

	_w_polygon(head, STEEL_COLOR)

	var outline := head.duplicate()
	outline.append(head[0])
	_w_polyline(outline, STEEL_EDGE_COLOR, 1.5, smooth_lines)

## Shaft, head and fletching, measured back from the point.
func _stroke_arrow(point: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var butt := point - dir * ARROW_LENGTH

	_w_line(butt, point, ARROW_SHAFT_COLOR, 2.0, smooth_lines)

	var head := PackedVector2Array([
		point,
		point - dir * ARROW_HEAD_LENGTH + perp * 3.0,
		point - dir * ARROW_HEAD_LENGTH - perp * 3.0,
	])
	_w_polygon(head, STEEL_COLOR)

	_w_line(butt + dir * 2.0 + perp * 3.0, butt + dir * 9.0, ARROW_FLETCH_COLOR, 1.6, smooth_lines)
	_w_line(butt + dir * 2.0 - perp * 3.0, butt + dir * 9.0, ARROW_FLETCH_COLOR, 1.6, smooth_lines)

## Arrows live in world space, so they stay where they land while the archer
## walks away from them.
## Shaft, claws, and the stone they hold. The stone is drawn as a soft halo round
## a hard core so that charge shows as the halo swelling rather than as a colour
## change, which reads at a glance and at this size.
func _stroke_staff(grip: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var head := grip + dir * STAFF_SHAFT
	var butt := grip - dir * STAFF_BUTT

	_w_line(butt, head - dir * STAFF_CLAW * 0.4, STAFF_WOOD, 3.2, smooth_lines)
	# a knot or two, so the shaft is a branch rather than a dowel
	_w_circle(butt + dir * STAFF_SHAFT * 0.34, 2.4, STAFF_WOOD_EDGE)
	_w_circle(butt + dir * STAFF_SHAFT * 0.66, 1.9, STAFF_WOOD_EDGE)

	var cradle := head - dir * STAFF_CLAW
	for side in [-1.0, 1.0]:
		_w_line(cradle, head + perp * side * STAFF_CLAW * 0.62, STAFF_WOOD, 2.2, smooth_lines)

	# kept well under the size of the head: at full charge this was three times it
	# and swallowed the figure holding it
	var swell := 1.0 + staff_charge * 0.85
	_w_circle(head, STAFF_ORB * swell * 1.55, Color(ORB_GLOW.r, ORB_GLOW.g, ORB_GLOW.b, 0.14 + staff_charge * 0.26))
	_w_circle(head, STAFF_ORB * swell, ORB_GLOW)
	_w_circle(head, STAFF_ORB * swell * 0.5, ORB_CORE)

## Stick, wrapping, and fire. The flame is drawn rising straight up regardless of
## how the stick is held: hang it off the stick's own direction and a torch waved
## about looks like someone signalling with a flag.
func _stroke_torch(grip: Vector2, dir: Vector2) -> void:
	var head := grip + dir * TORCH_STICK

	_w_line(grip - dir * TORCH_BUTT, head, TORCH_WOOD, 3.0, smooth_lines)
	_w_line(head - dir * TORCH_HEAD, head, TORCH_WRAP, 5.2, smooth_lines)

	Flame.draw_glow(self, head, TORCH_GLOW, 1.0, 8, 1.0)
	for i in range(TORCH_TONGUES):
		var tall := Flame.tongue_height(TORCH_FLAME, glow_time, float(i) + 4.0)
		var spread := (float(i) - float(TORCH_TONGUES - 1) * 0.5) * 2.2
		var root := head + Vector2(spread, -1.0)
		_w_polygon(Flame.tongue(root, Vector2.UP, tall,
			TORCH_FLAME_WIDE, TORCH_SWAY, glow_time, float(i) + 4.0, 4),
			Flame.LOW.lerp(Flame.MID, 0.5))
		_w_polygon(Flame.tongue(root, Vector2.UP, tall * 0.62,
			TORCH_FLAME_WIDE * 0.45, TORCH_SWAY, glow_time, float(i) + 4.0, 4),
			Flame.TIP)

## Stock, prod, string, and -- when there is one -- the quarrel in the groove.
## Whether it is spanned is read straight off the weapon: the string sits back
## over the nut and a bolt shows, or it does not and there is none.
func _stroke_crossbow(grip: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var nose := grip + dir * XBOW_STOCK
	var butt := grip - dir * XBOW_BUTT

	_w_line(butt, nose, XBOW_WOOD, 4.0, smooth_lines)

	# The prod is one curved lath, not two straight limbs meeting in a V: it
	# bellies forward in the middle and sweeps back again at the tips, which is
	# the shape that makes it read as a bow rather than as a bracket.
	var tip_a := nose + perp * XBOW_LIMB - dir * XBOW_TIP_BACK
	var tip_b := nose - perp * XBOW_LIMB - dir * XBOW_TIP_BACK
	var belly := nose + dir * XBOW_PROD_BOW
	var lath := PackedVector2Array()
	for i in range(XBOW_PROD_STEPS + 1):
		var t := float(i) / float(XBOW_PROD_STEPS)
		var inv := 1.0 - t
		lath.append(tip_a * (inv * inv) + belly * (2.0 * inv * t) + tip_b * (t * t))
	_w_polyline(lath, XBOW_STEEL, 3.0, smooth_lines)

	# the stirrup out at the nose, and the nut the string catches on
	# tucked against the nose rather than standing off it, or it reads as a ring
	# hung somewhere past the end of the weapon
	_w_arc(nose + dir * XBOW_STIRRUP * 0.55, XBOW_STIRRUP, dir.angle() - 2.1,
		dir.angle() + 2.1, 10, XBOW_STEEL, 1.8, smooth_lines)
	_w_circle(nose - dir * XBOW_STRING_BACK, XBOW_LOCK * 0.45, XBOW_STEEL)
	# and a trigger under the stock
	_w_line(grip + dir * 2.0, grip + dir * 4.0 - perp * XBOW_LOCK, XBOW_STEEL, 1.8, smooth_lines)

	# Spanned, the string is hauled back over the nut and makes a shallow V.
	# Slack, it lies straight across the tips -- and it has to be drawn out at
	# the tips' own forward curve, or it falls exactly on the prod and vanishes.
	var caught := nose - dir * XBOW_STRING_BACK if player.crossbow_loaded 		else nose + dir * XBOW_PROD_BOW
	_w_line(tip_a, caught, BOW_STRING_COLOR, 1.2, smooth_lines)
	_w_line(tip_b, caught, BOW_STRING_COLOR, 1.2, smooth_lines)

	if player.crossbow_loaded:
		_stroke_quarrel(nose + dir * 3.0, dir, perp)

## A bolt is a stub with a heavy head, not a shaft. Drawn short on purpose: at an
## arrow's length it sticks a hand's breadth out past the nose and the weapon
## reads as a very odd bow.
func _stroke_quarrel(at: Vector2, dir: Vector2, perp: Vector2) -> void:
	var butt := at - dir * QUARREL_LENGTH
	_w_line(butt, at, ARROW_SHAFT_COLOR, 2.2, smooth_lines)
	_w_polygon(PackedVector2Array([
		at + dir * QUARREL_HEAD,
		at - dir * 1.0 + perp * 2.6,
		at - dir * 1.0 - perp * 2.6,
	]), STEEL_COLOR)
	_w_line(butt + dir * 1.5 + perp * 2.2, butt + dir * 5.0, ARROW_FLETCH_COLOR, 1.4, smooth_lines)
	_w_line(butt + dir * 1.5 - perp * 2.2, butt + dir * 5.0, ARROW_FLETCH_COLOR, 1.4, smooth_lines)

func _draw_bolts() -> void:
	for i in bolts.size():
		var bolt: Bolt = bolts[i]
		var point := to_local(bolt.pos) + Vector2(0.0, -bolt.z)
		var back := point - bolt.vel.normalized() * BOLT_TRAIL
		# a streak behind it, so a thing crossing the room at 540 px/s is visible
		_w_line(back, point, Color(ORB_GLOW.r, ORB_GLOW.g, ORB_GLOW.b, 0.35), BOLT_RADIUS * 0.9, smooth_lines)
		_w_circle(point, BOLT_RADIUS * 1.9, Color(ORB_GLOW.r, ORB_GLOW.g, ORB_GLOW.b, 0.25))
		_w_circle(point, BOLT_RADIUS, ORB_GLOW)
		_w_circle(point, BOLT_RADIUS * 0.5, ORB_CORE)

func _draw_arrows() -> void:
	for i in arrows.size():
		var arrow: Arrow = arrows[i]
		var point := to_local(arrow.pos) + Vector2(0.0, -arrow.z)

		if not arrow.stuck:
			_w_transform(to_local(arrow.pos) + Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.35))
			_w_circle(Vector2.ZERO, 5.0, Color(0.0, 0.0, 0.0, 0.18))
			_w_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		_stroke_arrow(point, Vector2.from_angle(arrow.angle))

## Drawn in world space, outside the figure's transform, so it keeps lying where
## it landed while the body slides on past it.
func _draw_dropped() -> void:
	for i in dropped.size():
		var item: Dropped = dropped[i]
		var ground := to_local(item.pos)

		_w_transform(ground + Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.35))
		_w_circle(Vector2.ZERO, 9.0, Color(0.0, 0.0, 0.0, 0.2 * (1.0 - clampf(item.z / 80.0, 0.0, 0.6))))
		_w_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		_stroke_weapon(ground + Vector2(0.0, -item.z), Vector2.from_angle(item.angle), item.kind)
