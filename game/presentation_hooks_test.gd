extends SceneTree

const AudioDirector := preload("res://presentation/audio_director.gd")
const VisualCues := preload("res://presentation/visual_cue_registry.gd")
const Tour := preload("res://presentation/notification_tour.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_check_audio_director()
	_check_visual_registry()
	_check_tour_state()
	if failures == 0:
		print("Presentation hook checks passed: empty audio assets, cue briefs, guided bubbles and persisted tour state.")
	quit(1 if failures else 0)


func _check_audio_director() -> void:
	var audio = AudioDirector.new()
	var passive: Dictionary = audio.set_passive_track("ambient_void")
	var event: Dictionary = audio.request_event("talent_unlocked", "talent_chime")
	var transition: Dictionary = audio.request_transition("birth", "void", "core_awakened")
	check(not passive.asset_assigned and not event.asset_assigned, "unassigned audio assets should remain safe")
	check(transition.kind == "transition" and transition.duration_seconds > 0.0, "audio transition request was not retained")
	check(audio.request_count == 3 and audio.passive_track_id == "ambient_void", "audio intent state did not update")
	audio.assign_asset("talent_chime", "res://audio/talent_chime.ogg")
	check(audio.request_event("talent_unlocked", "talent_chime").asset_assigned, "assigned event asset was not reported")


func _check_visual_registry() -> void:
	var visuals = VisualCues.new()
	var ignition: Dictionary = visuals.request_cue("stellar_ignition")
	check(ignition.impact == "major" and ignition.intensity == 1.0, "ignition visual brief should carry the strongest impact")
	check("stellar_ignition" in visuals.find_for_event("sun_ignited"), "event lookup missed its visual cue")
	check(visuals.request_cue("missing_cue").is_empty(), "unknown visual cue should be a harmless empty brief")


func _check_tour_state() -> void:
	var steps := [
		{"id": "mass_intro", "target_id": "hud.mass_bar", "title": "Mass", "body": "Matter gathered so far."},
		{"id": "heat_intro", "target_id": "hud.heat_bar", "title": "Heat", "body": "Heat rises as the core grows."},
	]
	var tour = Tour.new()
	check(tour.start_tour("first_orbit", steps), "new tour failed to start")
	check(tour.current_step().target_id == "hud.mass_bar", "first bubble missed its semantic target")
	check(tour.dismiss_current().target_id == "hud.heat_bar", "dismiss should move the bubble to the next target")
	check(tour.dismiss_current().is_empty(), "last dismissal should finish the tour")
	var saved: Dictionary = tour.get_persistent_state()
	var restored = Tour.new()
	restored.restore_persistent_state(saved)
	check(not restored.start_tour("first_orbit", steps), "completed tour should stay completed after restore")
	check("first_orbit/mass_intro" in restored.dismissed_step_ids, "dismissed bubble was not persisted")
	check("first_orbit" in restored.completed_tour_ids, "completed tour was not persisted")
