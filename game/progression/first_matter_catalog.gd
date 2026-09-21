class_name FirstMatterCatalog
extends RefCounted

const Condition := preload("res://progression/condition_definition.gd")
const Reward := preload("res://progression/reward_definition.gd")
const Objective := preload("res://progression/objective_definition.gd")
const LATER_LAYER_MASSES := [12600.0, 26460.0, 55566.0, 116689.0, 245046.0, 514597.0]
const LAYER_NAMES := ["radiative layer", "convective layer", "stellar envelope", "deep envelope", "young photosphere", "first Sun"]

static func create(first_body_mass: float = 20.0, first_shell_mass: float = 6000.0) -> Array[ProgressionObjectiveDefinition]:
	var objectives: Array[ProgressionObjectiveDefinition] = [
		_objective(&"sun.call_matter", "Call the first spark", "Call one speck.", [Condition.metric_at_least(&"mass.total_gathered", 1.0)], [_unlock(&"indicator.capture_feedback")], 100),
		_objective(&"sun.hold_material", "Gather at least %d mass" % int(first_body_mass), "Gather enough to feed the Core.", [Condition.metric_at_least(&"mass.body", first_body_mass)], [_unlock(&"indicator.body_mass"), _unlock(&"action.feed_core")], 90),
		_objective(&"sun.feed_core", "Feed the heart", "Give the Core a little matter.", [Condition.metric_at_least(&"mass.core", 0.000001)], [_unlock(&"ui.core_growth")], 80),
		_objective(&"sun.awaken_core", "Wake the Core", "Grow the Core once.", [Condition.metric_at_least(&"core.level", 1.0)], [_unlock(&"ui.talents")], 70),
		_objective(&"sun.catch_wanderer", "Catch a drifter", "Catch something passing by.", [Condition.metric_at_least(&"capture.ambient_total", 1.0)], [_unlock(&"indicator.ambient_capture")], 60),
		_objective(&"sun.first_shell", "Gather mass for First Matter", "Build up enough loose mass to form your first permanent layer.", [Condition.metric_at_least(&"mass.loose", first_shell_mass)], [_unlock(&"action.compact_outer"), _event(&"first_compaction_ready")], 50),
		_objective(&"sun.preserve_layer", "Make it hold", "Finish shaping the shell.", [Condition.metric_at_least(&"body.compactions", 1.0)], [_unlock(&"talent.first_sun"), _unlock(&"camera.wide")], 40),
	]
	var previous_id := &"sun.preserve_layer"
	var priority := 39
	for layer_index in LATER_LAYER_MASSES.size():
		var layer_number := layer_index + 2
		if layer_number == 4:
			var ignition_id := &"sun.first_ignition"
			objectives.append(_objective(ignition_id, "Reach first ignition", "Grow the protostar to 75 stellar mass.",
				[Condition.metric_at_least(&"body.smu", 75.0), Condition.completed(previous_id)],
				[_unlock(&"indicator.heat"), _event(&"first_ignition")], priority))
			previous_id = ignition_id
			priority -= 1
		var gather_id := StringName("sun.gather_layer_%d" % layer_number)
		var compact_id := StringName("sun.compact_layer_%d" % layer_number)
		var amount := float(LATER_LAYER_MASSES[layer_index])
		objectives.append(_objective(gather_id, "Gather %s mass" % _mass_label(amount),
			"Gather enough for the next %s." % LAYER_NAMES[layer_index],
			[Condition.metric_at_least(&"mass.loose", amount), Condition.completed(previous_id)],
			[_event(StringName("layer_%d_ready" % layer_number))], priority))
		priority -= 1
		objectives.append(_objective(compact_id, "Compact the %s" % LAYER_NAMES[layer_index],
			"Bind the gathered matter into the growing Sun.",
			[Condition.metric_at_least(&"body.compactions", float(layer_number)), Condition.completed(gather_id)],
			[_event(StringName("layer_%d_compacted" % layer_number))], priority))
		previous_id = compact_id
		priority -= 1
	return objectives

static func _mass_label(amount: float) -> String:
	if amount >= 100000.0:
		return "%.0fk" % (amount / 1000.0)
	if amount >= 10000.0:
		return "%.1fk" % (amount / 1000.0)
	return "%d" % int(amount)

static func _objective(id: StringName, title: String, description: String, conditions: Array[ProgressionConditionDefinition], rewards: Array[ProgressionRewardDefinition], priority: int) -> ProgressionObjectiveDefinition:
	var objective := Objective.new()
	objective.objective_id = id
	objective.title = title
	objective.description = description
	objective.conditions = conditions
	objective.rewards = rewards
	objective.pin_priority = priority
	return objective

static func _unlock(id: StringName) -> ProgressionRewardDefinition:
	var reward := Reward.new()
	reward.reward_id = id
	reward.target_id = id
	return reward

static func _event(id: StringName) -> ProgressionRewardDefinition:
	var reward := Reward.new()
	reward.reward_id = id
	reward.kind = Reward.Kind.EVENT
	reward.target_id = id
	return reward
