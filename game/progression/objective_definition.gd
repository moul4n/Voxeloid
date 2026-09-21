class_name ProgressionObjectiveDefinition
extends Resource

@export var objective_id: StringName
@export var title := ""
@export_multiline var description := ""
@export var conditions: Array[ProgressionConditionDefinition] = []
@export var rewards: Array[ProgressionRewardDefinition] = []
@export var pin_priority := 0
