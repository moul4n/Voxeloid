extends RefCounted
class_name VoxVisualCueRegistry

## Briefs for future art and animation. These entries describe intent only;
## missing visual assets are expected during early development.

const DEFAULT_CUES := {
	"core_awakened": {
		"event_ids": ["game_started", "core_awakened"],
		"impact": "high",
		"style_art_placeholder": "A quiet core pulse grows into a clear, warm point of light. Keep the first change readable against the dark scene.",
		"duration_seconds": 2.4,
		"intensity": 0.65,
	},
	"first_matter_gathered": {
		"event_ids": ["first_matter_gathered", "mass_target_reached"],
		"impact": "medium",
		"style_art_placeholder": "A short inward stream and a gentle glow show matter joining the central body. Avoid a screen flash.",
		"duration_seconds": 1.2,
		"intensity": 0.4,
	},
	"talent_unlocked": {
		"event_ids": ["talent_unlocked"],
		"impact": "high",
		"style_art_placeholder": "A clean ring opens around the newly available talent, then settles into its idle state.",
		"duration_seconds": 1.8,
		"intensity": 0.55,
	},
	"stellar_ignition": {
		"event_ids": ["stellar_ignition", "sun_ignited"],
		"impact": "major",
		"style_art_placeholder": "A staged, bright ignition with a brief silhouette hold, expanding corona, and a lasting warmer star surface. Reserve the strongest light and motion for this event.",
		"duration_seconds": 4.5,
		"intensity": 1.0,
	},
	"inner_densification_reward": {
		"event_ids": ["inner_densification_reward"],
		"impact": "high",
		"style_art_placeholder": "The stellar centre contracts, warms and settles into a visibly tighter band. Keep the heat local and do not flash the interface.",
		"duration_seconds": 1.8,
		"intensity": 0.7,
	},
}

var cues: Dictionary = {}
var last_requested_cue_id := ""


func _init() -> void:
	for cue_id in DEFAULT_CUES:
		cues[cue_id] = DEFAULT_CUES[cue_id].duplicate(true)


func register_cue(cue_id: String, brief: Dictionary) -> bool:
	var clean_id := cue_id.strip_edges()
	if clean_id.is_empty():
		return false
	var entry := brief.duplicate(true)
	entry["event_ids"] = entry.get("event_ids", []).duplicate()
	entry["duration_seconds"] = maxf(0.0, float(entry.get("duration_seconds", 0.0)))
	entry["intensity"] = clampf(float(entry.get("intensity", 0.0)), 0.0, 1.0)
	cues[clean_id] = entry
	return true


func get_cue(cue_id: String) -> Dictionary:
	return cues.get(cue_id, {}).duplicate(true)


func find_for_event(event_id: String) -> Array[String]:
	var matches: Array[String] = []
	for cue_id in cues:
		if event_id in cues[cue_id].get("event_ids", []):
			matches.append(cue_id)
	return matches


func request_cue(cue_id: String) -> Dictionary:
	last_requested_cue_id = cue_id if cues.has(cue_id) else ""
	return get_cue(last_requested_cue_id)
