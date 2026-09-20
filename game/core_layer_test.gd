extends SceneTree

const Field = preload("res://core/material_field.gd")
const Profiles = preload("res://core/elements.gd")

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func close_to(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= maxf(0.01, absf(expected) * 0.000001)


func core_profile() -> Dictionary:
	var profile := Profiles.HYDROGEN.duplicate(true)
	# Match the player-facing readiness tuning while keeping this focused test
	# independent from element balance experiments.
	profile["core_layer_min_grains"] = 250000
	profile["core_layer_grains"] = 100000
	profile["core_layer_min_packing"] = 0.45
	profile["compaction_stage_pressures"] = Vector3(180.0, 950.0, 4500.0)
	return profile


func _initialize() -> void:
	check_explicit_creation_and_conservation()
	check_arrivals_and_repeated_layers()
	check_forced_and_disabled_paths()
	if failures == 0:
		print("Core layer checks passed.")
	quit(1 if failures else 0)


func check_explicit_creation_and_conservation() -> void:
	var field = Field.new(core_profile())
	field.seed_uniform(750000)
	var before := field.total_mass()
	var initial_radius: float = field.compacted_radius
	var status := field.layer_status()
	check(bool(status.ready), "750k compacted full ring is not ready: %s" % status.reason)
	for tick in 120:
		field.step(1.0 / 60.0)
	check(field.compacted_count == 0, "simulation formed a core without a player action")
	check(field.form_core_layer(), "ready core layer did not form")
	check(field.compacted_count == 100000, "core layer used the wrong grain count")
	check(field.compaction_active and is_equal_approx(field.compaction_progress, 0.0), "core layer did not begin compaction")
	var start_area: float = PI * (field.compacted_radius * field.compacted_radius - field.PLAYER_RADIUS * field.PLAYER_RADIUS)
	check(field.settled_count == 750000, "forming a core changed settled count")
	check(close_to(field.total_mass(), before), "forming a core lost logical mass")
	check(field.compacted_radius > initial_radius, "core radius did not grow")
	check(close_to(float(field.layer_status().radius), field.compacted_radius), "layer status has stale radius")
	var loose_mass := 0.0
	for mass in field.masses:
		loose_mass += mass
	check(close_to(loose_mass, 650000.0), "core mass remained in loose columns")
	check(not field.form_core_layer(true), "a second layer formed during compaction")
	field.step(0.0)
	check(is_equal_approx(field.compaction_progress, 0.0), "zero delta advanced compaction")
	for tick in 42:
		field.step(1.0 / 60.0)
	check(field.compaction_active and field.compaction_progress > 0.45 and field.compaction_progress < 0.55, "fixed ticks did not reach mid-compaction")
	var mid_area: float = PI * (field.compacted_radius * field.compacted_radius - field.PLAYER_RADIUS * field.PLAYER_RADIUS)
	check(mid_area > start_area * 0.1 and mid_area < start_area, "mid-compaction area was not intermediate")
	for tick in 48:
		field.step(1.0 / 60.0)
	check(not field.compaction_active and is_equal_approx(field.compaction_progress, 1.0), "compaction did not complete")
	var final_area: float = PI * (field.compacted_radius * field.compacted_radius - field.PLAYER_RADIUS * field.PLAYER_RADIUS)
	check(close_to(final_area, start_area * 0.1), "completed core did not occupy 10 percent of its original area")
	check(field.form_core_layer(), "a second explicit core layer did not form after compaction")
	check(field.compacted_count == 200000 and close_to(field.total_mass(), before), "repeated core layer broke conservation")
	field.clear()
	check(field.count == 0 and field.settled_count == 0 and field.compacted_count == 0, "clear retained core material")
	check(is_equal_approx(field.compacted_radius, field.PLAYER_RADIUS), "clear retained core radius")
	check(not field.compaction_active and is_equal_approx(field.compaction_progress, 0.0), "clear retained compaction state")


func check_arrivals_and_repeated_layers() -> void:
	var field = Field.new(core_profile())
	field.seed_uniform(750000)
	check(field.form_core_layer(), "initial compact core did not form")
	for tick in 84:
		field.step(1.0 / 60.0)
	field.spawn_grains(100000, 0.0)
	check(close_to(field.total_mass(), 850000.0), "in-flight mass was not conserved after a core")
	for tick in 180:
		field.step(1.0 / 60.0)
	check(field.settled_count == 850000, "arrival did not settle after a core")
	check(field.form_core_layer(), "arrived material could not form a later core layer")
	check(field.compacted_count == 200000, "later core layer used wrong count")
	check(close_to(field.total_mass(), 850000.0), "arrival plus core layer lost material")
	field.clear()
	check(not field.compaction_active and is_equal_approx(field.compacted_radius, field.PLAYER_RADIUS), "clear during compaction did not reset geometry")


func check_forced_and_disabled_paths() -> void:
	var forced_profile := core_profile()
	forced_profile["core_layer_min_grains"] = 999999
	forced_profile["core_layer_min_packing"] = 1.0
	forced_profile["core_layer_grains"] = 720
	var forced = Field.new(forced_profile)
	forced.seed_uniform(720)
	check(not bool(forced.layer_status().ready), "forced test unexpectedly met normal readiness")
	check(forced.form_core_layer(true), "forced core layer did not use available full-ring material")
	check(forced.compacted_count == 720 and close_to(forced.total_mass(), 720.0), "forced layer changed mass")
	var disabled_profile := core_profile()
	disabled_profile["core_layer_enabled"] = false
	var disabled = Field.new(disabled_profile)
	disabled.seed_uniform(750000)
	check(not bool(disabled.layer_status().ready), "disabled core layer reported ready")
	check(disabled.layer_status().reason == "core layers disabled", "disabled core layer gave wrong reason")
	check(not disabled.form_core_layer(), "disabled core layer formed without force")
	check(disabled.compacted_count == 0 and close_to(disabled.total_mass(), 750000.0), "disabled core layer changed mass")
