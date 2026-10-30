# Zombie Survival FPS

A round-based zombie survival FPS. Godot 4.7, GDScript only, Forward+ renderer, Jolt physics.
An agent writes most of the code. The human uses the Godot editor at the same time.

[DESIGN.md](DESIGN.md) has the core loop and the decided game rules. Read it before gameplay work. Update it in the same commit only when the change alters the core loop or a decided rule.

## Commands

| Command | Use |
|---|---|
| `tools/check.sh [filter]` | The gate. It imports the project, lints the scripts, checks `project.godot`, loads every script and scene, and runs the tests. Run it after each change. |
| `tools/smoke.sh [scene] [frames] [out.png]` | Runs the game off-screen with gamescope and saves a screenshot (default `.smoke/smoke.png`). Read the PNG to see the result. |
| `godot --path . -e` | Opens the editor. This is for the human. |
| `godot --headless --path . --import` | Imports new or changed assets. Run it in the main checkout after a pull that adds assets (a `.glb`, an image, a font). Without it, `tools/smoke.sh` and the verify skill's `drive.sh` load an old import, or none. |

A change is done only when `tools/check.sh` passes. For a visual change, also run `tools/smoke.sh` and look at the screenshot.

## Strict typing

`project.godot` makes these GDScript warnings errors: `untyped_declaration`, all `unsafe_*` warnings, and `missing_await`. `tools/check.sh` fails on them. Do not lower these settings.

- Give every variable, parameter, and return value a type. `:=` is correct when the right side has a known type.
- For a value from a `Dictionary` or another `Variant` API, assign it to a typed variable: `var n: String = data["name"]`.
- Do not use `as` on a `Variant` value. `unsafe_cast` is an error. Use `as` only between known object types.

## Rules and what enforces them

| Rule | Enforced by |
|---|---|
| Strict typing: every declaration has a type, no `unsafe_*` | `project.godot` warnings as errors, loaded by `tools/check_scripts.gd` |
| An engine error or `push_error()` fails a test | `tests/run_tests.gd` |
| Tests do not wait for real time (15 s budget, `--fixed-fps 60`) | `tools/check.sh` |
| No `await` in a node script (an await resumes on a freed node) | `tools/lint.gd` rule `await_in_node` |
| `project.godot` stays in the editor's canonical form (fix: `tools/canon_project.sh`) | `tools/check_project.gd` |
| Tests and the verify driver use typed accessors (`player.camera`, `player.weapon`, `player.hud.readout()`), not node paths | `tools/lint.gd` rule `test_node_path` |
| A test does not copy a `TestCase` helper (`spawn_player`, `run_seconds`, ...) | `tools/lint.gd` rule `test_helper_copy` |
| A group name comes from its owner's constant (`Player.GROUP`), not a string literal | `tools/lint.gd` rule `group_literal` |
| Only `Player` writes `Input.mouse_mode` (or calls `Input.set_mouse_mode`) and `weapon.trigger_enabled` | `tools/lint.gd` rule `mouse_mode_owner` |
| A gameplay script has no numeric or `Color` `const`; a tunable value is `@export` or in a `.tres` | `tools/lint.gd` rule `magic_const` |
| A gameplay script does not walk up the tree (`n = n.get_parent()`) to find its owner. The owner sets a typed reference, as `Player` sets `weapon.wielder` | `tools/lint.gd` rule `ancestor_walk` |
| A static collider on layer 1 is a navmesh obstacle with no group. A static body that zombies walk through goes on a layer other than 1 | The `NavigationMesh` in `levels/test_range.tscn` parses static colliders on layer 1, and `levels/level_navigation.gd` bakes it at start; `tests/levels/test_test_range.gd` checks that each layer-1 static body is off the navmesh |
| Do not edit a scene that is open in the editor | `tools/check.sh` prints a warning (not an error) for each `.tscn` changed on the branch that is in `open_scenes` of the main checkout's `.godot/editor/editor_layout.cfg` |

A lint rule is a row in the `Rule` table in `tools/lint.gd`. An exception goes on the offending line, and only with the human's approval: `# lint-allow <rule>: <reason> (until YYYY-MM-DD, approved: <human>)`. An expired or incomplete line fails the lint.

## Layout

- `levels/`: maps. `compound.tscn` is the main scene. `test_range.tscn` is the greybox test map that the tests and the verify skill use. `greybox_grid.gdshader` draws a 1 m grid.
- `debug/smoke.gd`: the autoload that `tools/smoke.sh` uses. It does nothing in a normal run.
- `tests/`: `run_tests.gd` (runner), `test_case.gd` (base class), and tests in `tests/<area>/test_*.gd`.
- `tools/`: agent scripts.
- Put each feature in its own folder, with the scene and its script side by side (for example `player/player.tscn` and `player/player.gd`).

## Tests

- A test file is `tests/<area>/test_<thing>.gd`. It `extends TestCase` and its methods start with `test_`.
- Each test method gets a new instance in the scene tree. Add nodes to the test with `add_child()`. The runner frees them after the test.
- Use the `TestCase` helpers: `spawn_player()` (with a floor), `spawn_level()` (the test range, after its navmesh bake), `spawn_zombie()`, `spawn_dummy()`, `spawn_nav_world()`, and `run_seconds()`.
- Read a scene through the typed accessors of its feature class (`player.camera`, `player.weapon.view_model`, `player.hud.readout()`, `game_over.round_text()`). If one is missing, add it to the feature class.
- Use `await physics_frames(n)` to run physics. Use `Input.action_press()` for input. The runner releases all actions after each test.
- An engine error or a `push_error()` during a test makes the test fail.
- Test what a player can see, such as position, velocity, or health. Do not test private fields.

## Editor and agent together

- The editor writes a `.tscn` file again when the human saves it. Do not edit a scene that the human is editing. Ask first, or make a new scene.
- Make tunable values `@export` (with `@export_range` where it helps) so that the human can tune them in the Inspector.
- Put game data, such as weapons and round settings, in `.tres` Resources.
- Commit the `.uid` files next to scripts and shaders. Godot makes them.
- Input actions are in the Input Map in `project.godot`. Use physical keycodes. Current actions: `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`, `crouch`, `fire`, `aim`, `reload`, `interact`, `melee`, `restart`, `weapon_1`, `weapon_2`, `weapon_next` (wheel down), `weapon_previous` (wheel up), `third_person` (debug builds only).

## Godot AI MCP server

- `.mcp.json` registers the `godot-ai` server (hi-godot/godot-ai 4.3.1). Its addon is in `addons/godot_ai/`. It works only while the human has the editor open.
- Use it to see the live editor: the scene tree, editor errors, and screenshots of and input to the game that runs from the editor.
- To change a scene that is open in the editor, use the godot-ai tools. They edit the editor's copy, so the human's next save does not overwrite the change.
- `tools/check.sh` is still the gate. A godot-ai result does not replace it.
- Do not edit files in `addons/godot_ai/`. The human updates the addon with the **Update** button in the Godot AI dock. After an update, change the `godot-ai==` version in `.mcp.json` to match.
- Telemetry is off: `.mcp.json` passes `--disable-telemetry`, and the editor setting `godot_ai/telemetry_enabled` is false.

## Style

- Follow the official GDScript style guide: snake_case for files, folders, functions, and variables, and PascalCase for nodes and `class_name`.
- Write a comment only for a reason that the code cannot show.
