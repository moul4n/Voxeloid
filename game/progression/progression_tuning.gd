class_name ProgressionTuning
extends Resource

@export_group("Flow")
@export_range(1.0, 30.0, 0.5) var metric_refresh_hz := 5.0
@export_range(0.0, 3.0, 0.05) var objective_completion_hold_seconds := 1.0
@export_range(1.0, 1000.0, 1.0) var opening_body_mass_target := 20.0
@export_range(100.0, 100000.0, 100.0) var first_shell_mass_target := 6000.0
@export_range(1, 10, 1) var stellar_backdrop_spent_points := 3

@export_group("Camera")
@export_range(0.002, 2.2, 0.01) var opening_zoom := 1.0
@export_range(0.002, 2.2, 0.01) var opening_min_zoom := 0.75
@export_range(0.002, 2.2, 0.01) var opening_max_zoom := 1.25
@export_range(0.1, 0.9, 0.01) var opening_target_fill := 0.42
@export_range(0.1, 5.0, 0.05) var camera_transition_seconds := 1.4

@export_group("Readability")
@export_range(0.75, 1.5, 0.05) var hud_scale := 1.0
@export_range(2.0, 8.0, 0.25) var opening_particle_screen_diameter := 3.5
@export_range(100.0, 100000.0, 100.0) var particle_scale_fade_start := 2000.0
@export_range(100.0, 1000000.0, 100.0) var particle_scale_fade_end := 25000.0
@export_range(0.0, 2.0, 0.05) var visual_unlock_intensity := 1.0

@export_group("Audio")
@export_range(-60.0, 6.0, 1.0) var passive_music_db := -18.0
@export_range(-60.0, 6.0, 1.0) var event_music_db := -10.0

func sanitize() -> void:
	metric_refresh_hz = clampf(metric_refresh_hz, 1.0, 30.0)
	objective_completion_hold_seconds = clampf(objective_completion_hold_seconds, 0.0, 3.0)
	opening_body_mass_target = maxf(opening_body_mass_target, 1.0)
	first_shell_mass_target = maxf(first_shell_mass_target, opening_body_mass_target)
	stellar_backdrop_spent_points = clampi(stellar_backdrop_spent_points, 1, 10)
	opening_min_zoom = clampf(opening_min_zoom, 0.002, 2.2)
	opening_max_zoom = clampf(opening_max_zoom, opening_min_zoom, 2.2)
	opening_zoom = clampf(opening_zoom, opening_min_zoom, opening_max_zoom)
	particle_scale_fade_end = maxf(particle_scale_fade_end, particle_scale_fade_start + 1.0)

func metric_refresh_seconds() -> float:
	return 1.0 / maxf(metric_refresh_hz, 1.0)
