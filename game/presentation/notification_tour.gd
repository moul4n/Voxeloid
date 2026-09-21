extends RefCounted
class_name VoxNotificationTour

## A lightweight guided-bubble queue. The host UI resolves semantic target IDs
## to live controls and stores get_persistent_state() with its player settings.

signal step_changed(step: Dictionary)
signal tour_completed(tour_id: String)

var active_tour_id := ""
var steps: Array[Dictionary] = []
var current_index := -1
var dismissed_step_ids: Dictionary = {}
var completed_tour_ids: Dictionary = {}


func start_tour(tour_id: String, tour_steps: Array, restart_completed: bool = false) -> bool:
	var clean_tour_id := tour_id.strip_edges()
	if clean_tour_id.is_empty() or tour_steps.is_empty():
		return false
	if bool(completed_tour_ids.get(clean_tour_id, false)) and not restart_completed:
		return false
	active_tour_id = clean_tour_id
	steps.clear()
	for raw_step in tour_steps:
		if raw_step is Dictionary:
			var step: Dictionary = raw_step.duplicate(true)
			step["id"] = String(step.get("id", "")).strip_edges()
			step["target_id"] = String(step.get("target_id", "")).strip_edges()
			if not step.id.is_empty():
				steps.append(step)
	if steps.is_empty():
		active_tour_id = ""
		return false
	current_index = 0
	_advance_past_dismissed()
	return current_index >= 0


func current_step() -> Dictionary:
	if current_index < 0 or current_index >= steps.size():
		return {}
	return steps[current_index].duplicate(true)


func next() -> Dictionary:
	if current_index < 0 or current_index >= steps.size():
		return {}
	current_index += 1
	_advance_past_dismissed()
	if current_index >= 0:
		var step := current_step()
		step_changed.emit(step.duplicate(true))
		return step
	return {}


func dismiss_current() -> Dictionary:
	if current_index < 0 or current_index >= steps.size():
		return {}
	dismissed_step_ids[_step_key(active_tour_id, steps[current_index])] = true
	return next()


func dismiss_tour() -> void:
	if active_tour_id.is_empty():
		return
	for step in steps:
		dismissed_step_ids[_step_key(active_tour_id, step)] = true
	_finish_tour()


func get_persistent_state() -> Dictionary:
	return {
		"dismissed_step_ids": dismissed_step_ids.duplicate(true),
		"completed_tour_ids": completed_tour_ids.duplicate(true),
	}


func restore_persistent_state(state: Dictionary) -> void:
	dismissed_step_ids = state.get("dismissed_step_ids", {}).duplicate(true)
	completed_tour_ids = state.get("completed_tour_ids", {}).duplicate(true)


func _advance_past_dismissed() -> void:
	while current_index >= 0 and current_index < steps.size():
		if not bool(dismissed_step_ids.get(_step_key(active_tour_id, steps[current_index]), false)):
			var step := current_step()
			step_changed.emit(step.duplicate(true))
			return
		current_index += 1
	if current_index >= steps.size():
		_finish_tour()


func _finish_tour() -> void:
	var finished_id := active_tour_id
	if not finished_id.is_empty():
		completed_tour_ids[finished_id] = true
	active_tour_id = ""
	current_index = -1
	steps.clear()
	if not finished_id.is_empty():
		tour_completed.emit(finished_id)


func _step_key(tour_id: String, step: Dictionary) -> String:
	return "%s/%s" % [tour_id, String(step.get("id", ""))]
