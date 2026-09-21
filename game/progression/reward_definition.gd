class_name ProgressionRewardDefinition
extends Resource

enum Kind { UNLOCK, SET_METRIC, ADD_METRIC, EVENT }

@export var reward_id: StringName
@export var kind: Kind = Kind.UNLOCK
@export var target_id: StringName
@export var value: Variant = true
