class_name ProgressionState
extends RefCounted

var metrics: Dictionary = {}
var unlocks := ProgressionUnlockRegistry.new()
var completed_objectives: Dictionary = {}
var awarded_rewards: Dictionary = {}
var objective_progress: Dictionary = {}
var pinned_objective_id: StringName
var requested_pinned_objective_id: StringName
var events: Array[StringName] = []

func _init(metric_registry: ProgressionMetricRegistry = null) -> void:
	if metric_registry != null:
		metrics = metric_registry.default_values()

func is_completed(objective_id: StringName) -> bool:
	return completed_objectives.has(objective_id)

func mark_completed(objective_id: StringName) -> bool:
	if is_completed(objective_id):
		return false
	completed_objectives[objective_id] = true
	return true

func reward_key(objective_id: StringName, reward_id: StringName) -> StringName:
	return StringName("%s/%s" % [objective_id, reward_id])

func has_awarded(objective_id: StringName, reward_id: StringName) -> bool:
	return awarded_rewards.has(reward_key(objective_id, reward_id))

func mark_awarded(objective_id: StringName, reward_id: StringName) -> void:
	awarded_rewards[reward_key(objective_id, reward_id)] = true
