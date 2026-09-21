extends SceneTree

const Registry := preload("res://progression/metric_registry.gd")
const State := preload("res://progression/progression_state.gd")
const Director := preload("res://progression/progression_director.gd")
const Condition := preload("res://progression/condition_definition.gd")
const Reward := preload("res://progression/reward_definition.gd")
const Objective := preload("res://progression/objective_definition.gd")
const Catalog := preload("res://progression/first_matter_catalog.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func objective(id: StringName, condition: ProgressionConditionDefinition, rewards: Array[ProgressionRewardDefinition] = []) -> ProgressionObjectiveDefinition:
	var item := Objective.new()
	item.objective_id = id
	item.conditions = [condition]
	item.rewards = rewards
	return item

func reward_event(id: StringName) -> ProgressionRewardDefinition:
	var reward := Reward.new()
	reward.reward_id = id
	reward.target_id = id
	reward.kind = Reward.Kind.EVENT
	return reward

func _initialize() -> void:
	var registry := Registry.new()
	var state := State.new(registry)
	var threshold := Condition.metric_at_least(&"mass.body", 10.0)
	var director := Director.new([objective(&"body.ten", threshold, [reward_event(&"once")])], registry, state)
	check(director.set_metric(&"mass.body", 4.0), "registered metric rejected")
	check(not director.publish_metric(&"mass.body", 4.0, &"ambient_dust"), "wrong metric owner was accepted")
	director.evaluate()
	check(is_equal_approx(director.progress_for(&"body.ten"), 0.4), "partial progress is wrong")
	check(state.pinned_objective_id == &"body.ten", "incomplete objective was not pinned")
	check(director.current_objective().objective_id == &"body.ten", "current objective helper returned the wrong objective")
	director.set_metric(&"mass.body", 10.0)
	check(director.evaluate() == [&"body.ten"], "threshold objective did not complete")
	director.evaluate()
	check(state.events.size() == 1, "reward ran more than once")
	var unlocked := Condition.new()
	unlocked.kind = Condition.Kind.UNLOCKED
	unlocked.unlock_id = &"gate.open"
	var completed := Condition.completed(&"body.ten")
	var group := Condition.new()
	group.kind = Condition.Kind.ALL
	group.children = [unlocked, completed]
	var grouped := Director.new([objective(&"combined", group)], registry, state)
	grouped.evaluate()
	check(not state.is_completed(&"combined"), "all group ignored locked condition")
	state.unlocks.grant(&"gate.open")
	grouped.evaluate()
	check(state.is_completed(&"combined"), "all group failed after unlock")
	var outside := Condition.new()
	outside.metric_name = &"mass.body"
	outside.comparison = Condition.Comparison.OUTSIDE_RANGE
	outside.range_min = 3.0
	outside.range_max = 8.0
	var range_director := Director.new([objective(&"outside", outside)], registry)
	range_director.set_metric(&"mass.body", 10.0)
	range_director.evaluate()
	check(range_director.state.is_completed(&"outside"), "outside range condition failed")
	var at_most := Condition.new()
	at_most.metric_name = &"body.heat"
	at_most.comparison = Condition.Comparison.LESS_OR_EQUAL
	at_most.value = 0.5
	var exact := Condition.new()
	exact.metric_name = &"core.level"
	exact.comparison = Condition.Comparison.EQUALS
	exact.value = 1.0
	var in_range := Condition.new()
	in_range.metric_name = &"body.smu"
	in_range.comparison = Condition.Comparison.INSIDE_RANGE
	in_range.range_min = 1.0
	in_range.range_max = 2.0
	var either := Condition.new()
	either.kind = Condition.Kind.ANY
	either.children = [Condition.metric_at_least(&"mass.core", 100.0), Condition.metric_at_least(&"capture.ambient_total", 1.0)]
	var comparisons := Director.new([objective(&"at_most", at_most), objective(&"exact", exact), objective(&"in_range", in_range), objective(&"either", either)], registry)
	comparisons.set_metric(&"core.level", 1.0)
	comparisons.set_metric(&"body.smu", 1.5)
	comparisons.set_metric(&"capture.ambient_total", 1.0)
	comparisons.evaluate()
	check(comparisons.state.is_completed(&"at_most") and comparisons.state.is_completed(&"exact") and comparisons.state.is_completed(&"in_range") and comparisons.state.is_completed(&"either"), "supported comparison or any condition failed")
	var catalog := Catalog.create(2.0, 20.0)
	var default_catalog := Catalog.create()
	check(is_equal_approx(default_catalog[1].conditions[0].value, 20.0), "default Core introduction target is not 20 mass")
	check(default_catalog[1].title == "Gather at least 20 mass", "default Core introduction copy is wrong")
	var first := Director.new(catalog, registry)
	first.set_metric(&"mass.total_gathered", 1.0)
	first.evaluate()
	check(first.state.unlocks.is_unlocked(&"indicator.capture_feedback"), "first matter catalog did not grant capture feedback")
	first.set_metric(&"mass.loose", 20.0)
	first.evaluate()
	check(first.state.unlocks.is_unlocked(&"action.compact_outer") and first.state.events.has(&"first_compaction_ready"), "tunable shell objective did not grant rewards")
	first.set_metric(&"body.compactions", 1.0)
	first.evaluate()
	check(first.state.unlocks.is_unlocked(&"talent.first_sun") and first.state.unlocks.is_unlocked(&"camera.wide"), "first compaction did not unlock the preservation rewards")
	if failures == 0:
		print("Progression system checks passed: metrics, partial progress, conditions, rewards, pinning, and first-matter catalog.")
	quit(1 if failures else 0)
