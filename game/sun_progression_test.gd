extends SceneTree
const Field := preload("res://core/material_field.gd")
const Profiles := preload("res://core/elements.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func finish(field) -> void:
	for tick in 120:
		field.step(1.0 / 60.0)

func _initialize() -> void:
	var field = Field.new()
	field.enable_sun_progression()
	field.seed_uniform(20)
	check(field.assimilate_player_core(), "first player level should cost 20 mass")
	check(field.count == 0 and field.sun_progression.absorbed_mass == 20.0, "player assimilation did not transfer exact mass")
	check(not field.assimilate_player_core(), "empty body paid for player upgrade")
	check(field.assimilate_player_core(true) and field.count == 0 and field.sun_progression.absorbed_mass == 20.0, "dev free level invented matter")
	field.clear()
	var total := 0
	for index in 7:
		var needed := int(field.sun_progression.required_mass())
		check(not field.form_core_layer(), "empty loose layer compacted")
		field.spawn_grains(needed, -PI / 4.0)
		finish(field)
		total += needed
		check(field.form_core_layer(), "Sun layer requirement did not unlock compaction")
		check(field.count == total and field.compacted_count == total, "compaction lost mass or left paid loose grains")
		finish(field)
		var state: Dictionary = field.get_sun_visual_state()
		check(bool(state.ignited) == (index >= 3), "75 SMU ignition gate mismatch")
		if index == 1:
			check(field.compact_inner_layer(), "second compact should unlock core densification")
			finish(field)
			check(field.get_body_layers().size() == 2, "early Sun zones should remain separate")
		if index == 3:
			check(field.get_sun_visual_state().ignited, "existing ignition lost during progression")
	check(not field.form_core_layer(true), "Sun exceeded seven layer limit")
	var final: Dictionary = field.get_sun_visual_state()
	check(final.stabilisation_available and is_equal_approx(final.temperature, 15000000.0), "solar mass/temperature final gate failed")
	check(final.player_temperature == 300.0 and final.player_mass == 0.0, "star heat or mass leaked into player state")
	field.clear()
	check(field.sun_progression.completed_layers == 0 and not field.get_sun_visual_state().ignited, "clear retained Sun progression")
	var heavy = Field.new(Profiles.HELIUM)
	heavy.enable_sun_progression()
	heavy.seed_uniform(int(ceil(6000.0 / float(Profiles.HELIUM.mass))))
	check(heavy.layer_status().ready, "layer gate ignored relative element mass")
	check(heavy.form_core_layer(), "heavy material conversion failed")
	check(heavy.sun_progression.history[0].mass >= 6000.0, "heavy conversion recorded counts as mass")
	var overfilled = Field.new()
	overfilled.enable_sun_progression()
	overfilled.seed_uniform(1000000000)
	check(overfilled.form_core_layer(), "overfilled layer failed")
	check(overfilled.compacted_count == 6000 and overfilled.count == 1000000000, "fixed Sun layer swallowed excess reserve")
	check(overfilled.count - overfilled.compacted_count == 999994000, "excess loose mass was not retained")
	check(is_equal_approx(overfilled.sun_progression.history[0].reward, 1.45), "fixed layer gained an overfill reward")
	var partial = Field.new()
	partial.enable_sun_progression()
	partial.seed_uniform(1)
	check(partial.form_core_layer(true), "dev partial layer could not be formed")
	check(partial.sun_progression.completed_layers == 0 and partial.sun_progression.completed_smu < 0.002,
		"underfilled dev layer received full physical mass credit")
	check(partial.sun_progression.required_mass() == 5999.0, "partial layer did not retain its remaining logical requirement")
	partial.spawn_grains(5999)
	finish(partial)
	check(partial.form_core_layer(), "partially formed layer could not be completed")
	finish(partial)
	var partial_total := 0.0
	for amount in partial.sun_progression.LAYER_MASSES:
		partial_total += amount
	check(partial.sun_progression.completed_layers == 1 and
		is_equal_approx(partial.sun_progression.completed_smu, 6000.0 / partial_total * 1000.0),
		"partial then completed layer did not earn exactly one fixed physical layer")
	if failures == 0:
		print("Sun progression checks passed: seven costs, weight, ignition, densification, manual conversion, player separation, dev and reset.")
	quit(1 if failures else 0)
