class_name ProgressionConditionDefinition
extends Resource

enum Kind { METRIC, UNLOCKED, COMPLETED, ALL, ANY }
enum Comparison { GREATER_OR_EQUAL, LESS_OR_EQUAL, EQUALS, INSIDE_RANGE, OUTSIDE_RANGE }

@export var kind: Kind = Kind.METRIC
@export var metric_name: StringName
@export var comparison: Comparison = Comparison.GREATER_OR_EQUAL
@export var value: Variant = 0.0
@export var range_min := 0.0
@export var range_max := 1.0
@export var unlock_id: StringName
@export var objective_id: StringName
@export var children: Array[ProgressionConditionDefinition] = []

static func metric_at_least(name: StringName, target: float) -> ProgressionConditionDefinition:
	var condition := ProgressionConditionDefinition.new()
	condition.metric_name = name
	condition.comparison = Comparison.GREATER_OR_EQUAL
	condition.value = target
	return condition

static func completed(id: StringName) -> ProgressionConditionDefinition:
	var condition := ProgressionConditionDefinition.new()
	condition.kind = Kind.COMPLETED
	condition.objective_id = id
	return condition
