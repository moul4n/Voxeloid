extends RefCounted
class_name VoxAudioDirector

## Data-only audio intent model. A playback layer can consume these requests later.
## Empty asset assignments are valid and never produce errors.

signal request_changed(request: Dictionary)

var passive_track_id := ""
var current_event_id := ""
var current_event_track_id := ""
var last_transition: Dictionary = {}
var assigned_assets: Dictionary = {}
var request_count := 0


func set_passive_track(track_id: String, fade_seconds: float = 2.0) -> Dictionary:
	passive_track_id = track_id.strip_edges()
	return _record_request({
		"kind": "passive_track",
		"track_id": passive_track_id,
		"fade_seconds": maxf(0.0, fade_seconds),
		"asset_assigned": assigned_assets.has(passive_track_id) and not passive_track_id.is_empty(),
	})


func request_event(event_id: String, track_id: String = "", fade_seconds: float = 0.25) -> Dictionary:
	current_event_id = event_id.strip_edges()
	current_event_track_id = track_id.strip_edges()
	return _record_request({
		"kind": "event_cue",
		"event_id": current_event_id,
		"track_id": current_event_track_id,
		"fade_seconds": maxf(0.0, fade_seconds),
		"asset_assigned": assigned_assets.has(current_event_track_id) and not current_event_track_id.is_empty(),
	})


func request_transition(transition_id: String, from_event: String, to_event: String,
		style: String = "soft_crossfade", duration_seconds: float = 1.0) -> Dictionary:
	last_transition = {
		"transition_id": transition_id.strip_edges(),
		"from_event": from_event.strip_edges(),
		"to_event": to_event.strip_edges(),
		"style": style.strip_edges(),
		"duration_seconds": maxf(0.0, duration_seconds),
	}
	var request := last_transition.duplicate(true)
	request["kind"] = "transition"
	return _record_request(request)


func assign_asset(cue_id: String, asset_path: String) -> void:
	var clean_id := cue_id.strip_edges()
	var clean_path := asset_path.strip_edges()
	if clean_id.is_empty() or clean_path.is_empty():
		assigned_assets.erase(clean_id)
	else:
		assigned_assets[clean_id] = clean_path


func clear_asset(cue_id: String) -> void:
	assigned_assets.erase(cue_id.strip_edges())


func get_state() -> Dictionary:
	return {
		"passive_track_id": passive_track_id,
		"current_event_id": current_event_id,
		"current_event_track_id": current_event_track_id,
		"last_transition": last_transition.duplicate(true),
		"request_count": request_count,
	}


func _record_request(request: Dictionary) -> Dictionary:
	request_count += 1
	request["sequence"] = request_count
	request_changed.emit(request.duplicate(true))
	return request
