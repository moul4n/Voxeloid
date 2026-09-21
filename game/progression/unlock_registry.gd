class_name ProgressionUnlockRegistry
extends RefCounted

var _granted: Dictionary = {}
var _grant_order: Array[StringName] = []

func grant(unlock_id: StringName) -> bool:
	if unlock_id.is_empty() or _granted.has(unlock_id):
		return false
	_granted[unlock_id] = true
	_grant_order.append(unlock_id)
	return true

func revoke(unlock_id: StringName) -> bool:
	if not _granted.has(unlock_id):
		return false
	_granted.erase(unlock_id)
	_grant_order.erase(unlock_id)
	return true

func is_unlocked(unlock_id: StringName) -> bool:
	return _granted.has(unlock_id)

func granted_ids() -> Array[StringName]:
	return _grant_order.duplicate()
