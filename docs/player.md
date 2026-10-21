# Player movement design

## Goal

The first-person player of the survival game, with fast, smooth movement. `Game` adds a `Player` node to the arena. All movement tuning is in one `PlayerSettings` resource. Health and damage are in `DESIGN.md`.

Usage the design must support:

```gdscript
# Player: add the node, done. Default input actions register if missing.
var player: Player = Player.new()
player.settings = preload("res://my_fast_preset.tres")  # optional
level.add_child(player)
player.teleport(spawn.global_position, spawn.global_rotation.y)

# Weapon or viewmodel: attach to the camera.
player.camera.add_child(gun)

# Sound and effects: typed signals.
player.jumped.connect(play_jump_sound)
player.landed.connect(func(impact_speed: float) -> void: ...)
player.move_state_changed.connect(func(previous: Player.MoveState, current: Player.MoveState) -> void: ...)

# AI or tests: drive the same body without the Input singleton.
bot.player_controlled = false
bot.intent.move = Vector2(0.0, 1.0)
bot.intent.jump_pressed = true
bot.look(delta_yaw, delta_pitch)
```

## Candidates

| | A. One script | B. Body + camera rig + settings | C. Node state machine |
|---|---|---|---|
| Shape | One `CharacterBody3D` script owns input, movement, camera effects | Body script owns input parse, state machine, movement. Separate camera rig node runs at render rate. One settings resource. | One child node per state, a manager node switches between them |
| Camera smoothness | Camera code runs in physics tick or mixes clocks in one file | Rig interpolates the body position each rendered frame | Same problem as A |
| Testability | Tests drive real physics | Tests drive real physics through `intent`, no Input singleton | Tests must know the node tree |
| Reader load | One long file | Three files, each with one clock and one job | Many small files, logic spread across nodes |

Choice: **B**. The body runs on the physics clock and the camera runs on the render clock. That split is real, so it gets its own node. C adds indirection for three states and removes no branches. A forces the reader to track which code runs on which clock.

## Files

- `game/player/player_settings.gd`. `class_name PlayerSettings extends Resource`. All tuning, grouped with `@export_group`. The only source of truth for sizes and speeds.
- `game/player/player.gd`. `class_name Player extends CharacterBody3D`. Builds its own children from settings. Parses input into `Intent`. Runs the move state machine. Steps up stairs. Plans and runs mantles.
- `game/player/player_camera_rig.gd`. `class_name PlayerCameraRig extends Node3D`. Top-level node. Places the camera every rendered frame from the interpolated body position plus look angles plus feel effects.
- `tests/test_runner.gd`. Headless physics integration tests.

## Data shapes

```gdscript
class_name Player extends CharacterBody3D

enum MoveState { GROUND, AIR, SLIDE, MANTLE }
enum Stance { STAND, CROUCH }

class Intent:
	var move: Vector2 = Vector2.ZERO   # x right, y forward, length <= 1
	var jump_pressed: bool = false     # true for one tick on press
	var jump_held: bool = false
	var sprint_held: bool = false
	var crouch_held: bool = false

class Mantle:
	var path: PackedVector3Array  # start, over, ahead, landing
	var duration: float
	var elapsed: float = 0.0
	func sample() -> Vector3      # position at elapsed, by arc length along path
	func finished() -> bool

signal jumped
signal landed(impact_speed: float)
signal move_state_changed(previous: MoveState, current: MoveState)

@export var settings: PlayerSettings
@export var player_controlled: bool = true
@export var mouse_sensitivity: float     # degrees per screen pixel
@export var gamepad_look_speed: float    # degrees per second at full stick
@export var gamepad_look_exponent: float # stick response curve, 1 is linear
@export var invert_y: bool = false

var intent: Intent
var yaw: float      # radians, the only source of horizontal facing
var pitch: float    # radians, clamped
var move_state: MoveState
var stance: Stance
var camera: Camera3D

func look(delta_yaw: float, delta_pitch: float) -> void
func teleport(target_position: Vector3, target_yaw: float) -> void
func horizontal_speed() -> float
```

The body keeps two more private values for the mantle. `_mantle` is not null only while `move_state` is MANTLE. `_floor_height` is the y of the last floor that the body stood on. The Mantle group of `PlayerSettings` has two values:

| Setting | Default | Meaning |
|---|---|---|
| `mantle_max_height` | 1.2 m | The highest ledge top above the floor that a mantle reaches |
| `mantle_time` | 0.4 s | The time that a mantle takes |

The body never rotates. Facing is `yaw` only. The capsule is round, so body rotation adds nothing and would put mouse look behind physics interpolation.

## State machine

One `match move_state` in `_transition()`, then one `match move_state` for the move. Timers are floats that count down: `_coyote_left`, `_jump_buffer_left`, `_slide_cooldown_left`.

"On floor" in the table is the `_on_floor` flag from the last move, not `is_on_floor()`. In AIR, the flag is `is_on_floor()` after `move_and_slide()`. In MANTLE, the flag is true on the tick that the path ends. In GROUND and SLIDE, the flag is true when `_step_up()` climbs a step. Otherwise it is `is_on_floor()` after `move_and_slide()`, or the result of `_step_down()`.

| From | Condition | To | Effect |
|---|---|---|---|
| GROUND | buffered jump | AIR | jump velocity, emit `jumped` |
| GROUND | not on floor | AIR | start coyote timer |
| GROUND | forward intent, a ledge in reach, room on top (see Mantle) | MANTLE | plan the path, `elapsed` is zero |
| GROUND | crouch pressed, speed >= `slide_min_speed`, cooldown done | SLIDE | add `slide_boost` up to `slide_max_speed` |
| AIR | on floor, buffered jump | AIR | emit `landed`, then jump with no friction tick (bunny hop) |
| AIR | on floor, crouch held, speed >= `slide_min_speed` | SLIDE | emit `landed`, no boost |
| AIR | on floor | GROUND | emit `landed` |
| AIR | buffered jump, coyote time left | AIR | jump |
| AIR | `velocity.y <= 0`, forward intent, a ledge in reach, room on top | MANTLE | plan the path, `elapsed` is zero |
| SLIDE | buffered jump | AIR | jump, keep horizontal momentum |
| SLIDE | not on floor | AIR | start coyote timer |
| SLIDE | speed < `slide_exit_speed` or crouch released | GROUND | |
| MANTLE | path done | GROUND | the GROUND move runs in the next tick |

Each exit from SLIDE starts the slide cooldown. A state change emits `move_state_changed`. A bunny hop stays in AIR, so it emits no state change.

Stance is CROUCH while crouch is held, while in SLIDE, or while a ceiling blocks standing. Stance sets the capsule height. The capsule shrinks from the top, so the feet stay on the floor. In MANTLE the stance does not change. `_start_mantle()` can set CROUCH for a ledge with a low ceiling, and the normal rules apply again when the mantle ends.

## Movement model

Quake-style acceleration and friction, in m/s:

```
accelerate(wish_dir, wish_speed, accel):
	add = wish_speed - velocity_h.dot(wish_dir)
	if add > 0: velocity_h += wish_dir * min(accel * wish_speed * delta, add)

friction(amount):
	speed = velocity_h.length()
	drop = max(speed, stop_speed) * amount * delta
	velocity_h *= max(speed - drop, 0) / speed
```

- GROUND: friction with `ground_friction` and `stop_speed` (3.0 m/s), then accelerate to walk, sprint, or crouch speed. A stop from walk speed takes 0.23 s.
- AIR: no friction, accelerate with `air_acceleration` and `air_max_wish_speed`. The dot-product rule allows air strafing.
- SLIDE: a constant deceleration, not friction, so the speed loss does not grow with speed:

```
slide():
	velocity_h = velocity_h.move_toward(ZERO, slide_deceleration * delta)
	limit = max(velocity_h.length(), slide_max_speed)
	velocity_h += floor_normal_h * gravity * delta   # length g * sin(slope), downhill
	velocity_h = velocity_h turned toward the input, same length
	velocity_h = velocity_h.limit_length(limit)
```

With the defaults (`slide_deceleration` 6.5 m/s², gravity 24.4 m/s²), a slide gets faster down a slope steeper than asin(6.5 / 24.4) = 15.4 degrees. On flat floor, a slide from 13.9 m/s drops below `slide_exit_speed` (4.0 m/s) after 1.55 s. The cap applies only to the slope gain, so a slide that starts above `slide_max_speed` keeps its speed and loses only the deceleration. Steering turns the slide and adds no speed.

- Gravity comes from jump height and time to apex: `gravity = 2h / t^2`, `jump_velocity = 2h / t`. Falling uses `gravity * fall_gravity_multiplier`. AIR applies half the gravity of a tick before `move_and_slide()` and half after it, so the rise follows the exact parabola at any tick rate.
- A release of jump while the body rises multiplies vertical velocity by `jump_cut_multiplier`. Only a release cuts the jump. A jump that starts with `jump_held` false has the full height.

## Stairs

GROUND and SLIDE move through `_move_on_floor()`. It tries `_step_up()` first. If no step is climbed, it calls `move_and_slide()`, and then `_step_down()` if the body is not on the floor. All tests use `PhysicsServer3D.body_test_motion` with `PhysicsTestMotionParameters3D`.

`_step_up()`:

1. Test the horizontal motion of this tick. If it hits nothing, or it hits a walkable slope, there is no step.
2. Find the support height. It is the contact point of a 0.05 m test motion down, or the body origin if that is higher. The round bottom of the capsule can rest on an edge above the feet, so the step height is measured from what the body stands on, not from the body origin.
3. Raise the capsule to `step_height + 0.05` above the support height, or less if a ceiling stops it. The 0.05 m clearance keeps the capsule above the top edge of a step of exactly `step_height`.
4. Probe: from the raised position, move forward by the motion, but by at least 0.1 m, then sweep down. A slow body moves too little in one tick to get past the step edge, so the probe decides if a step is there. The step is rejected if nothing is under the probe, if the probe lands less than 0.01 m above the start, if the contact is more than `step_height` plus 0.01 m above the support height, or if the top is not walkable.
5. Do the same move with the real motion. If it lands at or above the start, put the body there, send the height change to the rig with `add_step()`, and skip `move_and_slide()` for this tick.

`_step_down()` tests a motion down by `step_height + 0.05`. If it finds a walkable top, it moves the body onto it, sends the height change to the rig, and calls `apply_floor_snap()`. A capsule that walks off a step rolls on the step edge, where the contact normal is too steep to count as floor. `floor_snap_length = step_height` alone does not keep the body on the floor there.

A walkable top is a contact normal within `floor_max_angle`. If the capsule rests on an edge, the contact normal is tilted. Then a 0.1 m ray down, 0.02 m past the contact point on the side away from the capsule center, reads the real top surface.

## Mantle

A mantle moves the body along a fixed path in `mantle_time`. It is a step that is too high for `_step_up()`. `_start_mantle()` runs in `_transition()`:

- In GROUND, after the buffered jump and the not-on-floor checks, and before the slide check.
- In AIR, only when `velocity.y <= 0`, after the on-floor and coyote jump checks. A rising body does not mantle, so a jump that would clear a ledge is not cut short.
- In SLIDE, never.

`_start_mantle()` and `_plan_mantle()` plan with `body_test_motion`. The mantle starts only if every step passes:

1. The forward intent is above zero. The direction is the horizontal wish direction.
2. A test motion of 0.1 m in that direction hits a surface that is not walkable. The horizontal part of its normal faces the body: `-normal_h.dot(direction) >= 0.7`.
3. The base height is the support height in GROUND, as for stairs. In AIR it is `_floor_height`.
4. Raise the capsule to `mantle_max_height + 0.05` above the base, or less if a ceiling stops it.
5. Move the raised capsule forward by the probe travel plus the capsule diameter. It must not hit anything. A wall or a ceiling over the ledge refuses the mantle. Then sweep down from there, by the height of the raise, to find the landing.
6. The mantle is refused in these cases: nothing is under the sweep, the contact is more than `mantle_max_height + 0.01` above the base, the top is not walkable, or the landing is not above the start by more than 0.01 m.
7. In GROUND, sweep down again from the raised capsule moved forward by only 0.1 m, where the body first reaches the obstacle. The mantle is refused if that contact is `step_height + 0.01` or less above the base. Stairs own that range, so the two have no gap and no overlap. The sweep must be near the body. At the landing, 0.7 m away, a staircase of 0.2 m risers is already 0.4 m or more above the base, and it would be a mantle.
8. Lower the raise to 0.05 m above the landing. The straight way up from the start and the way forward from there must not hit anything. The path is the start, that point over the ledge, that point moved forward, and the landing.
9. If the plan fails with a standing capsule, the planner sets CROUCH and plans again. If that fails too, it sets STAND again. A mantle is refused only if neither a standing nor a crouched capsule fits on the ledge.

`_move_mantle()` adds `delta` to `elapsed`, sets the position from `sample()`, and sets the velocity to the move of the tick divided by `delta`. The path has the same speed along its whole length. When `elapsed` reaches `mantle_time`, the velocity is zero, `_on_floor` is true, and `_floor_height` is the landing height. `_set_state()` clears `_mantle` when the state leaves MANTLE and emits `move_state_changed` for both changes.

The reach in AIR is measured from `_floor_height`, not from the body. `_floor_height` is the y of the last floor that the body stood on. A mantle then never goes higher than `mantle_max_height` above a floor. That is lower than `jump_height`, so a mantle opens no surface that a jump cannot reach. A zombie attacks only within 1.2 m of height, so a spot above that height stays out of reach for the player.

The body moves along the path in every tick, so the rig interpolates it like any other move and needs no change. The path has one move down: the last 0.05 m onto the ledge. `_move_mantle()` sends that move to the rig with `add_step()`, or the camera would drop 0.05 m in one tick. The head bob runs only in GROUND, so it is off during a mantle.

## Camera rig

`top_level = true` and `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF`. The rig interpolates the body position itself. It does not use `get_global_transform_interpolated()`.

```
add_step(h):           # the body calls it when _step_up(), _step_down(), or the end of a mantle moves it by h
	pending_step += h

record_tick():         # the body calls it at the end of _physics_process()
	previous_origin = current_origin + (0, pending_step, 0)
	current_origin = body.global_position
	step_offset -= pending_step
	pending_step = 0

_process(delta):
	origin = previous_origin.lerp(current_origin, Engine.get_physics_interpolation_fraction())
	eye_height = smooth toward stance eye height
	step_offset = decay toward 0
	rig transform = yaw basis at origin + (0, eye_height + step_offset, 0)
	camera.transform = basis from pitch and strafe roll, at head bob + landing dip spring
	camera.fov = smooth toward the vertical FOV for base_fov + speed-scaled kick
```

The body calls `record_tick()` directly, so the result does not depend on the order in which child nodes process. A step goes into the previous origin, so the lerp does not spread it over the next tick. Only the `step_offset` decay smooths a step, so a step up never moves the camera down. `snap()` puts both origins at the body position and every smoothed value on its target. `_ready()` and `teleport()` call it.

`Engine.get_physics_interpolation_fraction()` is valid with `physics/common/physics_interpolation` on or off, so the camera is smooth in both cases.

The rig basis is yaw only. Pitch, roll, head bob, and landing dip are on the camera, so the bob and the dip stay vertical when the player looks up or down. `base_fov` is the horizontal FOV at 16:9. `Camera3D.fov` is vertical with `KEEP_HEIGHT`, so the rig converts the value at the 16:9 reference, and a wider screen shows more at the sides (Hor+).

All smoothing uses `1.0 - exp(-rate * delta)` so it does not depend on frame rate. The landing dip uses an exact step of a critically damped spring.

Mouse look applies in `_unhandled_input` from `InputEventMouseMotion.screen_relative`, so window stretch does not change sensitivity and look has no tick delay. Gamepad look applies in the body's `_process`, which runs before the rig's `_process`, with the stick curved by `gamepad_look_exponent`.

## Boundaries

- Input: `Input` and `InputMap` are read only in `_read_intent()`, `_unhandled_input`, and `_process` (gamepad look). `Game` owns mouse capture, because pause and death release the mouse. Missing default actions register in `_ready`. Existing actions are not changed.
- Settings: `PlayerSettings` validates ranges with `@export_range`. If `settings` is null, the controller makes `PlayerSettings.new()`.
- Physics interpolation: the camera does not need `physics/common/physics_interpolation`. The controller does not warn when it is off. Other moving bodies in a game still need it for smooth motion. `teleport()` calls `reset_physics_interpolation()`, so a node that a user attaches to the body does not move across the gap.
- Teleport: `teleport()` sets the speed to zero, sets `yaw`, and sets `pitch` to zero. Then it settles the body: a zero-motion `move_and_slide()` and `apply_floor_snap()` find the floor, the state becomes GROUND or AIR with no `landed` signal, and the rig snaps.
- Camera: the camera becomes current only when `player_controlled` is true, so a bot does not take the view from the player.

## Verification plan

Headless tests drive real physics through `intent` with `player_controlled = false`, and each test builds its own `PlayerSettings` with explicit values, so the expected values are literals in the test. The suite runs on Jolt Physics and on Godot Physics. Two tests cap the frame rate at 240 FPS and read the camera height on each rendered frame, one while the body climbs twenty 0.3 m steps and one during a mantle. The mantle tests cover a walk into a 1.0 m ledge, a ledge above `mantle_max_height`, two kinds of low ceiling, a short jump onto a ledge, a jump at a ledge above the reach from the last floor, and a scripted route that ends at a literal position.

## Accepted deviations

The code differs from the first version of this design in the ways below. Each deviation was accepted by the lead in review.

- Stairs use a forward probe of at least 0.1 m, an edge ray, a step height from the support point, a raise of `step_height + 0.05`, and `_step_down()`. Without the probe minimum, a crouch walk does not climb 0.2 m steps. Without the edge ray, a crouch walk does not climb a 0.35 m step, and a walk down stairs enters AIR. Without the support point, a walk at 30 degrees into the corner of a staircase does not climb it. Without `_step_down()`, a walk down stairs enters AIR. The 0.05 m in the raise is a margin above the top edge of a step of exactly `step_height`. No test fails without it.
- The `_on_floor` flag replaces `is_on_floor()` in the state machine. A climbed step skips `move_and_slide()`, and `_step_down()` finds floor that `move_and_slide()` did not find, so `is_on_floor()` is wrong after both.
- Coyote time also starts on SLIDE to AIR, so a slide off a ledge gives the same late jump as a walk off a ledge.
- Gamepad look is read in `_process`, so stick look has no tick delay.
- The rig basis is yaw only, and pitch, roll, bob, and dip are on the camera, so the bob and the dip stay vertical when the player looks up or down.
- `base_fov` is horizontal at 16:9 (Hor+), so a wider screen shows more at the sides and does not lose the top and bottom of the view.
- Gravity is applied half before and half after the move, so the rise follows the exact parabola at any tick rate.
- Only a release cuts the jump, so a buffered press that was released before the landing, or a bot that does not set `jump_held`, still gets the full jump.
- `teleport()` resets pitch and settles on the floor, so a spawn starts level and in the correct state with no `landed` signal.
- The camera becomes current only when `player_controlled` is true, so a bot does not take the view from the player.
- Slide details: the cap applies only to the slope gain, so speed from air strafing is not cut. Steering adds no speed, so input cannot push a slide faster. A landing slide has no boost, so a chain of slide jumps cannot add the boost on each landing. The cooldown starts when the slide ends, so a long slide cannot chain into a new boost.
- `gamepad_look_exponent` (default 2.0) curves the stick, so small stick motions give fine aim.
- The mantle issue asked for a recorded golden run. The recording API was removed, so a scripted route test replaces it. The test uses a fixed sequence of intents and checks the end position against a literal value.
- The check that leaves stairs to `_step_up()` measures the obstacle 0.1 m ahead of the body, not at the landing of the mantle. With the contact at the landing, three tests of stairs failed, because a staircase is 0.4 m or more above the base 0.7 m ahead.
- `_move_mantle()` calls `add_step()` for the last move down onto the ledge. Without it, a camera test at 240 FPS measures a drop of 0.021 m in one frame, and the limit is 0.01 m.
- `stop_speed` is 3.0 m/s, so a stop from walk speed takes 0.23 s, inside the 0.25 s limit of the stop test.

The constant slide deceleration and the rig interpolation are not deviations. The lead asked for them in review, and the sections above describe them.
