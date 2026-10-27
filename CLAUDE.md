# Zombie Survival FPS

A round-based zombie survival FPS. Godot 4.7, GDScript only, Forward+ renderer, Jolt physics.
An agent writes most of the code. The human uses the Godot editor at the same time.

## Commands

| Command | Use |
|---|---|
| `tools/check.sh [filter]` | The gate. It imports the project, loads every script and scene, and runs the tests. Run it after each change. |
| `tools/smoke.sh [scene] [frames] [out.png]` | Runs the game off-screen with gamescope and saves a screenshot (default `.smoke/smoke.png`). Read the PNG to see the result. |
| `godot --path . -e` | Opens the editor. This is for the human. |

A change is done only when `tools/check.sh` passes. For a visual change, also run `tools/smoke.sh` and look at the screenshot.

## Strict typing

`project.godot` makes these GDScript warnings errors: `untyped_declaration`, all `unsafe_*` warnings, and `missing_await`. `tools/check.sh` fails on them. Do not lower these settings.

- Give every variable, parameter, and return value a type. `:=` is correct when the right side has a known type.
- For a value from a `Dictionary` or another `Variant` API, assign it to a typed variable: `var n: String = data["name"]`.
- Do not use `as` on a `Variant` value. `unsafe_cast` is an error. Use `as` only between known object types.

## Layout

- `levels/`: maps. `test_range.tscn` is the greybox test map and the main scene. `greybox_grid.gdshader` draws a 1 m grid.
- `debug/smoke.gd`: the autoload that `tools/smoke.sh` uses. It does nothing in a normal run.
- `tests/`: `run_tests.gd` (runner), `test_case.gd` (base class), and tests in `tests/<area>/test_*.gd`.
- `tools/`: agent scripts.
- Put each feature in its own folder, with the scene and its script side by side (for example `player/player.tscn` and `player/player.gd`).

## Tests

- A test file is `tests/<area>/test_<thing>.gd`. It `extends TestCase` and its methods start with `test_`.
- Each test method gets a new instance in the scene tree. Add nodes to the test with `add_child()`. The runner frees them after the test.
- Use `await physics_frames(n)` to run physics. Use `Input.action_press()` for input. The runner releases all actions after each test.
- An engine error or a `push_error()` during a test makes the test fail.
- Test what a player can see, such as position, velocity, or health. Do not test private fields.

## Editor and agent together

- The editor writes a `.tscn` file again when the human saves it. Do not edit a scene that the human is editing. Ask first, or make a new scene.
- Make tunable values `@export` (with `@export_range` where it helps) so that the human can tune them in the Inspector.
- Put game data, such as weapons and round settings, in `.tres` Resources.
- Commit the `.uid` files next to scripts and shaders. Godot makes them.
- Input actions are in the Input Map in `project.godot`. Use physical keycodes. Current actions: `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`.

## Style

- Follow the official GDScript style guide: snake_case for files, folders, functions, and variables, and PascalCase for nodes and `class_name`.
- Write a comment only for a reason that the code cannot show.
