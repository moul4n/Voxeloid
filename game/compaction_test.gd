extends SceneTree

const Field = preload("res://core/material_field.gd")
const Profiles = preload("res://core/elements.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func spread(field) -> float:
	var total := 0.0
	for i in field.COLUMNS:
		# Fraction away from the source, independent of grain size and packing.
		total += field.masses[i] * (1.0 - cos((float(i) + 0.5) * TAU / field.COLUMNS))
	return total / maxf(float(field.settled_count), 1.0)

func _initialize() -> void:
	var previous_spread := INF
	for profile in [Profiles.HYDROGEN, Profiles.HELIUM, Profiles.CARBON, Profiles.IRON]:
		var field = Field.new(profile)
		field.spawn_grains(500000, 0.0)
		for tick in 132:
			field.step(1.0 / 60.0)
		var before := spread(field)
		for tick in 600:
			field.step(1.0 / 60.0)
		var after := spread(field)
		check(after > before + 0.001, "%s did not spread downhill" % profile.id)
		check(after < previous_spread, "%s lost its relative resistance to flow" % profile.id)
		check(absf(field.total_mass() - 500000.0) < 0.01, "%s lost material" % profile.id)
		for radius in field.heights:
			check(is_finite(radius) and radius >= field.PLAYER_RADIUS, "invalid surface radius")
		previous_spread = after
		print("ELEMENT_FLOW %s spread %.4f -> %.4f" % [profile.id, before, after])
		check_compaction(profile)
	if failures == 0:
		print("Element and compaction checks passed.")
	quit(1 if failures else 0)

func check_compaction(profile: Dictionary) -> void:
	var field = Field.new(profile)
	var top_area: float = field.specific_area_for_overburden(0.0)
	var deep_area: float = field.specific_area_for_overburden(1000000.0)
	check(deep_area < top_area, "%s does not compact under load" % profile.id)
	check(field.pressure_for_overburden(0.0) == 0.0, "surface has nonzero overburden")
	var pressure: float = field.pressure_for_overburden(100.0)
	check(is_equal_approx(field.pressure_for_overburden(200.0), pressure * 2.0), "weight is not proportional to grains above")
	var heavier := profile.duplicate(true)
	heavier.mass = float(profile.mass) * 2.0
	var heavy_field = Field.new(heavier)
	check(is_equal_approx(heavy_field.pressure_for_overburden(100.0), pressure * 2.0), "mass does not increase overburden")
	check(heavy_field.specific_area_for_overburden(100.0) <= field.specific_area_for_overburden(100.0), "heavier load expands material")
	var no_gravity := profile.duplicate(true)
	no_gravity.gravity_response = 0.0
	var weightless = Field.new(no_gravity)
	check(weightless.pressure_for_overburden(1000000.0) == 0.0, "weight remains with gravity disabled")
	check(is_equal_approx(weightless.specific_area_for_overburden(1000000.0), top_area), "weightless grains compact")
	var disabled := profile.duplicate(true)
	disabled.compaction_response = 0.0
	var uncompressed = Field.new(disabled)
	check(is_equal_approx(uncompressed.specific_area_for_overburden(1000000.0), top_area), "compression dial does not disable packing")
	var harder := profile.duplicate(true)
	harder.compaction_stage_pressures *= 10.0
	var resistant = Field.new(harder)
	check(resistant.specific_area_for_overburden(10000.0) > field.specific_area_for_overburden(10000.0), "stage pressure dial does not increase required load")
	var previous_packing := 0.0
	for pressure_sample in [0.0, 1.0, 100.0, 1000.0, 10000.0, 1000000.0, 1e12]:
		var packing: float = field.packing_for_pressure(pressure_sample)
		check(packing >= previous_packing and packing <= 0.995, "packing curve is nonmonotonic or unbounded")
		previous_packing = packing
	for amount in [1, 10000, 500000, 1000000000]:
		field.seed_uniform(amount)
		var column_mass: float = float(amount) / field.COLUMNS
		var previous_radius := 0.0
		for layer in 65:
			var radius_sq: float = field.radius_squared_for_mass(column_mass, column_mass * float(layer) / 64.0)
			check(is_finite(radius_sq) and radius_sq >= previous_radius, "compaction folded radial layers")
			previous_radius = radius_sq
		check(absf(sqrt(previous_radius) - field.max_height) < maxf(0.01, field.max_height * 0.00001), "surface disagrees with compacted volume")
		check(absf(field.total_mass() - amount) < 0.01, "compaction changed grain count")
		# Independently integrate density to check the fast cumulative lookup.
		var reference_area := 0.0
		for sample in 2048:
			reference_area += field.specific_area_for_overburden(column_mass * (float(sample) + 0.5) / 2048.0) * column_mass / 2048.0
		var mapped_area: float = (previous_radius - pow(field.PLAYER_RADIUS + field.grain_size * 0.5, 2.0)) * TAU / float(field.COLUMNS) * 0.5
		check(absf(mapped_area - reference_area) / maxf(reference_area, 0.000001) < 0.001, "compaction lookup differs from pressure model")
		for layer in field.RADIAL_LOOKUP_SAMPLES + 1:
			var expected: float = field.radius_squared_for_mass(column_mass, column_mass * float(layer) / field.RADIAL_LOOKUP_SAMPLES)
			check(absf(field.radial_lookup[layer] - expected) < maxf(0.01, expected * 0.000001), "render lookup disagrees with CPU volume")
	field.clear()
	check(field.count == 0 and field.settled_count == 0, "clear retained compacted mass")
