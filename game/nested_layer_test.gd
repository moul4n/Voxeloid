extends SceneTree

const Field = preload("res://core/material_field.gd")
const Profiles = preload("res://core/elements.gd")

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func close_to(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= maxf(0.01, absf(expected) * 0.000001)


func profile() -> Dictionary:
	var result := Profiles.HYDROGEN.duplicate(true)
	result["core_layer_min_grains"] = 1
	result["core_layer_grains"] = 100000
	result["core_layer_min_packing"] = 0.0
	result["inner_layer_min_mass"] = 200000.0
	result["inner_layer_mass_fraction"] = 0.9
	result["inner_layer_area_ratio"] = 0.1
	result["inner_layer_duration"] = 1.4
	return result


func finish(field) -> void:
	for tick in 90:
		field.step(1.0 / 60.0)


func _initialize() -> void:
	check_nested_conservation_and_geometry()
	check_animation_locality_and_automation()
	check_loose_consumption()
	if failures == 0:
		print("Nested body layer checks passed.")
	quit(1 if failures else 0)


func check_nested_conservation_and_geometry() -> void:
	var field = Field.new(profile())
	field.seed_uniform(300000)
	var initial_mass := field.total_mass()
	check(field.form_core_layer(), "first manual core did not form")
	finish(field)
	check(field.form_core_layer(), "second manual outer addition did not form")
	finish(field)
	var before_layers: Array[Dictionary] = field.get_body_layers()
	check(before_layers.size() == 1 and int(before_layers[0].count) == 200000, "manual outer material did not join the planet core")
	var source_area: float = PI * (float(before_layers[0].outer_radius) * float(before_layers[0].outer_radius) - field.PLAYER_RADIUS * field.PLAYER_RADIUS)
	check(field.inner_layer_status().ready, "200k formed mass did not unlock first inner compaction")
	check(field.compact_inner_layer(), "inner compaction did not begin")
	finish(field)
	var layers: Array[Dictionary] = field.get_body_layers()
	check(layers.size() == 4, "first refinement did not create the four body slots")
	check(layers[0].name == "Planet core" and layers[1].name == "Inner mantle" and layers[2].name == "Outer mantle", "body layers have wrong order or names")
	var total_count := 0
	for layer in layers:
		total_count += int(layer.count)
	check(total_count == field.compacted_count and close_to(field.total_mass(), initial_mass), "nested conversion lost count")
	var final_area: float = PI * (float(layers[3].outer_radius) * float(layers[3].outer_radius) - field.PLAYER_RADIUS * field.PLAYER_RADIUS)
	check(close_to(final_area, source_area * 0.19), "90 percent mass at 10 percent area did not leave the 19 percent footprint")
	var surface_area := PI * (float(layers[3].outer_radius) * float(layers[3].outer_radius) - float(layers[3].inner_radius) * float(layers[3].inner_radius))
	check(close_to(surface_area, source_area * 0.005), "surface is not the configured shallow five percent slot")
	var outer_area := PI * (float(layers[2].outer_radius) * float(layers[2].outer_radius) - float(layers[2].inner_radius) * float(layers[2].inner_radius))
	check(field.form_core_layer(), "manual material did not add beneath the surface")
	finish(field)
	layers = field.get_body_layers()
	var later_surface_area := PI * (float(layers[3].outer_radius) * float(layers[3].outer_radius) - float(layers[3].inner_radius) * float(layers[3].inner_radius))
	check(close_to(later_surface_area, surface_area), "later outer compaction grew the shallow surface")
	check(float(layers[2].outer_radius) > float(layers[2].inner_radius) and outer_area > 0.0, "outer mantle geometry became invalid")


func check_animation_locality_and_automation() -> void:
	var field = Field.new(profile())
	field.seed_uniform(300000)
	check(field.form_core_layer(), "animation test first core failed")
	finish(field)
	check(field.form_core_layer(), "animation test second core failed")
	finish(field)
	check(field.compact_inner_layer(), "animation test inner core failed")
	for tick in 17:
		field.step(1.0 / 60.0)
	var layers: Array[Dictionary] = field.get_body_layers()
	check(absf(float(layers[0].pulse)) > 0.0001, "inner conversion did not pulse its core")
	check(is_zero_approx(float(layers[1].pulse)) and is_zero_approx(float(layers[2].pulse)) and is_zero_approx(float(layers[3].pulse)), "inner conversion pulsed an unaffected layer")
	check(field.animation_outer_radius > field.animation_inner_radius, "inner animation window is invalid")
	check(close_to(float(layers[3].outer_radius), field.compacted_radius), "in-flight layer radii do not reach the rendered body radius")
	finish(field)
	check(not field.inner_automation_unlocked and not field.set_inner_automation(true), "locked automation enabled")
	check(field.unlock_inner_automation() and field.set_inner_automation(true), "automation upgrade could not enable")
	var core_before_growth := int(field.get_body_layers()[0].count)
	for tick in 90:
		field.step(1.0 / 60.0)
	check(int(field.get_body_layers()[0].count) == core_before_growth, "automation refined again before collecting a new milestone")
	var next_mass := float(field.inner_layer_status().next_automation_mass)
	field.spawn_grains(int(ceil(next_mass - field.inner_layer_status().total_collected_mass)), 0.0)
	for tick in 300:
		field.step(1.0 / 60.0)
	check(int(field.get_body_layers()[0].count) < core_before_growth and field.compacted_count == 200000, "automation did not refine the core after a new milestone")


func check_loose_consumption() -> void:
	var field = Field.new(profile())
	field.seed_uniform(300000)
	check(field.form_core_layer(), "consumption test core failed")
	finish(field)
	var compacted: int = field.compacted_count
	var before := field.total_mass()
	check(field.consume_loose(50000) == 50000, "loose consumption returned the wrong amount")
	check(field.compacted_count == compacted and close_to(field.total_mass(), before - 50000.0), "loose consumption touched compacted material")
	field.spawn_grains(1000, 0.0)
	var loose_before: int = field.settled_count - field.compacted_count
	check(field.consume_loose(999999) == loose_before, "consumption used in-flight arrivals")
