class_name ProgressionDirector
extends RefCounted

const Condition := preload("res://progression/condition_definition.gd")
const Reward := preload("res://progression/reward_definition.gd")

var metric_registry: ProgressionMetricRegistry
var state: ProgressionState
var objectives: Array[ProgressionObjectiveDefinition] = []

func _init(definitions: Array[ProgressionObjectiveDefinition] = [], registry: ProgressionMetricRegistry = null, progression_state: ProgressionState = null) -> void:
	metric_registry = registry if registry != null else ProgressionMetricRegistry.new()
	state = progression_state if progression_state != null else ProgressionState.new(metric_registry)
	objectives = definitions.duplicate()

func set_metric(metric_name: StringName, value: Variant, owner: StringName = &"") -> bool:
	if not metric_registry.accepts(metric_name, value):
		return false
	var metric := metric_registry.definition(metric_name)
	if not owner.is_empty() and StringName(metric.owner) != owner:
		return false
	state.metrics[String(metric_name)] = value
	return true

func publish_metric(metric_name: StringName, value: Variant, owner: StringName) -> bool:
	return set_metric(metric_name, value, owner)

func evaluate() -> Array[StringName]:
	var newly_completed: Array[StringName] = []
	for objective in objectives:
		var result := _evaluate_objective(objective)
		state.objective_progress[objective.objective_id] = result.progress
		if result.met and state.mark_completed(objective.objective_id):
			newly_completed.append(objective.objective_id)
		if state.is_completed(objective.objective_id):
			_apply_rewards(objective)
	_refresh_pinned_objective()
	return newly_completed

func progress_for(objective_id: StringName) -> float:
	return float(state.objective_progress.get(objective_id, 0.0))

func current_objective() -> ProgressionObjectiveDefinition:
	return _find_objective(state.pinned_objective_id)

func pin_objective(objective_id: StringName) -> bool:
	if _find_objective(objective_id) == null or state.is_completed(objective_id):
		return false
	state.requested_pinned_objective_id = objective_id
	state.pinned_objective_id = objective_id
	return true

func _evaluate_objective(objective: ProgressionObjectiveDefinition) -> Dictionary:
	if objective.conditions.is_empty():
		return {"met": false, "progress": 0.0}
	var met := true
	var progress := 1.0
	for condition in objective.conditions:
		var result := _evaluate_condition(condition)
		met = met and result.met
		progress = minf(progress, result.progress)
	return {"met": met, "progress": progress}

func _evaluate_condition(condition: ProgressionConditionDefinition) -> Dictionary:
	match condition.kind:
		Condition.Kind.UNLOCKED:
			return _boolean_result(state.unlocks.is_unlocked(condition.unlock_id))
		Condition.Kind.COMPLETED:
			return _boolean_result(state.is_completed(condition.objective_id))
		Condition.Kind.ALL, Condition.Kind.ANY:
			return _evaluate_group(condition)
		Condition.Kind.METRIC:
			return _evaluate_metric(condition)
	return {"met": false, "progress": 0.0}

func _evaluate_group(condition: ProgressionConditionDefinition) -> Dictionary:
	if condition.children.is_empty():
		return {"met": false, "progress": 0.0}
	var met := condition.kind == Condition.Kind.ALL
	var progress := 1.0 if condition.kind == Condition.Kind.ALL else 0.0
	for child in condition.children:
		var result := _evaluate_condition(child)
		if condition.kind == Condition.Kind.ALL:
			met = met and result.met
			progress = minf(progress, result.progress)
		else:
			met = met or result.met
			progress = maxf(progress, result.progress)
	return {"met": met, "progress": progress}

func _evaluate_metric(condition: ProgressionConditionDefinition) -> Dictionary:
	if not metric_registry.has(condition.metric_name):
		return {"met": false, "progress": 0.0}
	var actual: Variant = state.metrics.get(String(condition.metric_name), null)
	match condition.comparison:
		Condition.Comparison.GREATER_OR_EQUAL:
			return _greater_or_equal(actual, condition.value)
		Condition.Comparison.LESS_OR_EQUAL:
			return _less_or_equal(actual, condition.value)
		Condition.Comparison.EQUALS:
			return _boolean_result(actual == condition.value)
		Condition.Comparison.INSIDE_RANGE:
			return _inside_range(actual, condition.range_min, condition.range_max)
		Condition.Comparison.OUTSIDE_RANGE:
			var inside := _inside_range(actual, condition.range_min, condition.range_max)
			return {"met": not inside.met, "progress": 1.0 - inside.progress}
	return {"met": false, "progress": 0.0}

func _greater_or_equal(actual: Variant, target: Variant) -> Dictionary:
	if not _numbers(actual, target):
		return {"met": false, "progress": 0.0}
	var target_number := float(target)
	if target_number <= 0.0:
		return _boolean_result(float(actual) >= target_number)
	return {"met": float(actual) >= target_number, "progress": clampf(float(actual) / target_number, 0.0, 1.0)}

func _less_or_equal(actual: Variant, target: Variant) -> Dictionary:
	if not _numbers(actual, target):
		return {"met": false, "progress": 0.0}
	var target_number := float(target)
	if target_number >= 0.0:
		return {"met": float(actual) <= target_number, "progress": clampf(1.0 - maxf(float(actual), 0.0) / maxf(target_number, 0.000001), 0.0, 1.0)}
	return _boolean_result(float(actual) <= target_number)

func _inside_range(actual: Variant, lower: float, upper: float) -> Dictionary:
	if not _numbers(actual, lower):
		return {"met": false, "progress": 0.0}
	if lower > upper:
		return {"met": false, "progress": 0.0}
	var number := float(actual)
	if number >= lower and number <= upper:
		return {"met": true, "progress": 1.0}
	var width := maxf(upper - lower, 1.0)
	var distance := lower - number if number < lower else number - upper
	return {"met": false, "progress": clampf(1.0 - distance / width, 0.0, 1.0)}

func _numbers(left: Variant, right: Variant) -> bool:
	return (typeof(left) == TYPE_INT or typeof(left) == TYPE_FLOAT) and (typeof(right) == TYPE_INT or typeof(right) == TYPE_FLOAT)

func _boolean_result(value: bool) -> Dictionary:
	return {"met": value, "progress": 1.0 if value else 0.0}

func _apply_rewards(objective: ProgressionObjectiveDefinition) -> void:
	for reward in objective.rewards:
		var reward_id := reward.reward_id if not reward.reward_id.is_empty() else reward.target_id
		if reward_id.is_empty() or state.has_awarded(objective.objective_id, reward_id):
			continue
		match reward.kind:
			Reward.Kind.UNLOCK:
				state.unlocks.grant(reward.target_id)
			Reward.Kind.SET_METRIC:
				set_metric(reward.target_id, reward.value)
			Reward.Kind.ADD_METRIC:
				var old_value: Variant = state.metrics.get(String(reward.target_id), 0.0)
				if _numbers(old_value, reward.value):
					set_metric(reward.target_id, float(old_value) + float(reward.value))
			Reward.Kind.EVENT:
				state.events.append(reward.target_id)
		state.mark_awarded(objective.objective_id, reward_id)

func _refresh_pinned_objective() -> void:
	if not state.requested_pinned_objective_id.is_empty() and not state.is_completed(state.requested_pinned_objective_id):
		state.pinned_objective_id = state.requested_pinned_objective_id
		return
	state.requested_pinned_objective_id = &""
	state.pinned_objective_id = &""
	var best_priority := -2147483648
	for objective in objectives:
		if not state.is_completed(objective.objective_id) and objective.pin_priority > best_priority:
			best_priority = objective.pin_priority
			state.pinned_objective_id = objective.objective_id

func _find_objective(objective_id: StringName) -> ProgressionObjectiveDefinition:
	for objective in objectives:
		if objective.objective_id == objective_id:
			return objective
	return null
