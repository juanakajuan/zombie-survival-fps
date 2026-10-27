class_name TestCase
extends Node
## Base class for tests. tests/run_tests.gd adds a fresh instance to the tree for each `test_*` method.
## A test method may be a coroutine. Use `await physics_frames(n)` to let the physics engine run.

var failures: PackedStringArray = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %s ± %s, got %s" % [message, expected, tolerance, actual])


func physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame
