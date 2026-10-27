extends TestCase

var _died_count := 0
var _damage_events: Array[float] = []


func test_starts_at_max_health() -> void:
	var health := _spawn_health(80.0)
	assert_almost_eq(health.current, 80.0, 0.001, "current starts at max_health")
	assert_true(not health.is_dead(), "alive at start")


func test_damage_reduces_current_and_emits_damaged() -> void:
	var health := _spawn_health(100.0)
	health.damage(30.0)
	assert_almost_eq(health.current, 70.0, 0.001, "current after damage")
	assert_eq(_damage_events, [30.0] as Array[float], "damaged emitted with the amount")
	assert_eq(_died_count, 0, "not dead yet")


func test_damage_past_zero_clamps_and_emits_died_once() -> void:
	var health := _spawn_health(100.0)
	health.damage(250.0)
	assert_almost_eq(health.current, 0.0, 0.001, "current clamps to 0")
	assert_true(health.is_dead(), "is dead")
	assert_eq(_died_count, 1, "died emitted once")


func test_dead_ignores_further_damage() -> void:
	var health := _spawn_health(100.0)
	health.damage(100.0)
	health.damage(10.0)
	assert_almost_eq(health.current, 0.0, 0.001, "current stays 0")
	assert_eq(_died_count, 1, "died not emitted again")
	assert_eq(_damage_events.size(), 1, "damaged not emitted after death")


func test_non_positive_damage_is_ignored() -> void:
	var health := _spawn_health(100.0)
	health.damage(0.0)
	health.damage(-20.0)
	assert_almost_eq(health.current, 100.0, 0.001, "current unchanged")
	assert_eq(_damage_events.size(), 0, "no damaged signal")


func test_reset_revives_at_max_health() -> void:
	var health := _spawn_health(100.0)
	health.damage(100.0)
	health.reset()
	assert_almost_eq(health.current, 100.0, 0.001, "current back at max")
	assert_true(not health.is_dead(), "alive again")
	health.damage(100.0)
	assert_eq(_died_count, 2, "can die again after reset")


func test_find_on_returns_direct_child_health_or_null() -> void:
	var holder := Node.new()
	add_child(holder)
	assert_true(Health.find_on(holder) == null, "null without a Health child")
	var health := Health.new()
	holder.add_child(health)
	assert_true(Health.find_on(holder) == health, "finds the Health child")


func _spawn_health(max_health: float) -> Health:
	var health := Health.new()
	health.max_health = max_health
	health.damaged.connect(func(amount: float) -> void: _damage_events.append(amount))
	health.died.connect(func() -> void: _died_count += 1)
	add_child(health)
	return health
