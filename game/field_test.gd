extends SceneTree

const MaterialFieldScript := preload("res://core/material_field.gd")
const ElementsData := preload("res://core/elements.gd")


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true


func advance(field: MaterialFieldScript, seconds: float, tick := 1.0 / 60.0) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var delta := minf(tick, remaining)
		field.step(delta)
		remaining -= delta


func mass_sum(field: MaterialFieldScript) -> float:
	var total := 0.0
	for value in field.masses:
		total += value
	return total


func height_variance(field: MaterialFieldScript) -> float:
	var mean := 0.0
	for value in field.heights:
		mean += value
	mean /= float(field.COLUMNS)
	var variance := 0.0
	for value in field.heights:
		variance += pow(value - mean, 2.0)
	return variance / float(field.COLUMNS)


func height_range(field: MaterialFieldScript) -> Vector2:
	var minimum := INF
	var maximum := -INF
	for value in field.heights:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return Vector2(minimum, maximum)


func prepare_constant_ring_solver(field: MaterialFieldScript, conductance: float) -> void:
	for column in field.COLUMNS:
		field._edge_conductance[column] = conductance
		field._lower[column] = -conductance
		field._upper[column] = -conductance
		field._diagonal[column] = 1.0 + conductance * 2.0


func _initialize() -> void:
	var field: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN, 500000)
	if not check(field.masses.size() == field.COLUMNS and field.heights.size() == field.COLUMNS, "field did not allocate fixed columns"):
		return
	if not check(field.count == 0 and field.settled_count == 0 and is_equal_approx(field.total_mass(), 0.0), "empty field has mass"):
		return
	# Numerical regression for the cyclic M-matrix solve.  A uniform RHS must
	# stay uniform, and a single peak must stay non-negative and lose no mass.
	var solver: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	for column in solver.COLUMNS:
		solver.masses[column] = 37.0
	prepare_constant_ring_solver(solver, 8.0)
	solver._solve_cyclic()
	for value in solver._solution:
		if not check(absf(value - 37.0) < 0.000001, "constant-conductance solve changed a uniform RHS"):
			return
	if not check(solver.last_solver_relative_error < 0.0000000001, "cyclic solve failed raw mass conservation"):
		return
	for column in solver.COLUMNS:
		solver.masses[column] = 0.0
	solver.masses[0] = 72000.0
	prepare_constant_ring_solver(solver, 8.0)
	solver._solve_cyclic()
	var peak_sum := 0.0
	for value in solver._solution:
		if not check(value >= 0.0 and value <= 72000.0, "implicit solve violated the maximum principle"):
			return
		peak_sum += value
	if not check(absf(peak_sum - 72000.0) < 0.000001 and solver.last_solver_relative_error < 0.0000000001, "peak solve lost raw mass"):
		return

	field.spawn_grains(500000, 0.0)
	if not check(field.count == 500000 and field.settled_count == 0 and field.batches.size() == 1, "airborne count was not reserved"):
		return
	if not check(is_equal_approx(field.total_mass(), 500000.0), "airborne mass was lost"):
		return
	advance(field, 2.2)
	if not check(field.settled_count == 500000 and field.batches.is_empty(), "due batch did not settle once"):
		return
	if not check(absf(mass_sum(field) - 500000.0) <= 0.01 and absf(field.total_mass() - 500000.0) <= 0.01, "landing did not conserve mass"):
		return

	# The seam is periodic: equal arrivals on either side have equal geometry.
	var seam: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	seam.spawn_grains(3000, -0.001)
	seam.spawn_grains(3000, TAU - 0.001)
	advance(seam, 2.2)
	if not check(absf(seam.sample_height(-0.001) - seam.sample_height(TAU - 0.001)) < 0.01, "angle seam is not periodic"):
		return

	# Hydrogen is mobile while a high-repose profile keeps a steeper slope.
	var rough_data := ElementsData.HYDROGEN.duplicate()
	rough_data.repose_slope = 2.0
	rough_data.flow_rate = 1800.0
	var smooth: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	var rough: MaterialFieldScript = MaterialFieldScript.new(rough_data)
	for target in [smooth, rough]:
		target.spawn_grains(12000, 0.0)
		advance(target, 2.2)
	var smooth_before := smooth.sample_height(0.0)
	advance(smooth, 8.0)
	advance(rough, 8.0)
	if not check(smooth.sample_height(0.0) < smooth_before - 0.1, "mobile material did not redistribute"):
		return
	if not check(rough.sample_height(0.0) > smooth.sample_height(0.0) + 1.0, "high-repose material did not retain a steeper heap"):
		return
	if not check(is_finite(smooth.max_height) and smooth.max_height > MaterialFieldScript.PLAYER_RADIUS, "redistribution produced invalid height"):
		return
	if not check(absf(smooth.total_mass() - 12000.0) <= 0.01, "redistribution lost mass"):
		return

	var capped: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN, 100000)
	capped.spawn_grains(500000)
	if not check(capped.count == 100000 and capped.batches.size() == 1, "capacity did not cap queued particles"):
		return
	capped.clear()
	if not check(capped.count == 0 and capped.settled_count == 0 and capped.batches.is_empty() and is_equal_approx(capped.total_mass(), 0.0), "clear did not remove air and surface mass"):
		return

	var fixed: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	fixed.seed_uniform(500000)
	if not check(fixed.count == 500000 and fixed.settled_count == 500000 and fixed.batches.is_empty() and fixed.masses.size() == MaterialFieldScript.COLUMNS, "500k field grew per-particle storage"):
		return
	var a := fixed.sample_seed(12345)
	var b := fixed.sample_seed(12345)
	if not check(a >= 0.0 and a < 1.0 and is_equal_approx(a, b), "sample seed is not stable"):
		return
	var billion: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	billion.seed_uniform(MaterialFieldScript.MAX_PARTICLES + 1)
	if not check(billion.count == MaterialFieldScript.MAX_PARTICLES and billion.settled_count == MaterialFieldScript.MAX_PARTICLES and absf(mass_sum(billion) - float(MaterialFieldScript.MAX_PARTICLES)) < 0.01, "one-billion logical cap or fixed storage failed"):
		return
	var whole: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	var split: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	for target in [whole, split]:
		target.spawn_grains(8000, 0.7)
	whole.step(2.5)
	for _tick in 150:
		split.step(1.0 / 60.0)
	if not check(absf(whole.total_mass() - split.total_mass()) <= 0.01 and absf(whole.sample_height(0.7) - split.sample_height(0.7)) <= 0.01, "fixed stepping changed surface"):
		return
	# A one-sided 500k arrival must spread progressively across local edges.
	# It should not solve the opposite side of the ring in the impact tick.
	var burst: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	burst.spawn_grains(500000, 0.0)
	advance(burst, 2.2)
	var burst_variance := height_variance(burst)
	advance(burst, 3.8)
	var range_6 := height_range(burst)
	advance(burst, 6.0)
	var range_12 := height_range(burst)
	var began := Time.get_ticks_usec()
	advance(burst, 10.0)
	var elapsed_ms := float(Time.get_ticks_usec() - began) / 1000.0
	var range_22 := height_range(burst)
	if not check(height_variance(burst) < burst_variance and range_12.x > range_6.x and range_22.x > range_12.x and range_22.y < range_12.y,
		"one-sided hydrogen burst did not spread progressively across local edges"): return
	for column in burst.COLUMNS:
		if not check(burst.masses[column] >= 0.0 and is_finite(burst.heights[column]), "500k stress produced negative mass or invalid height"): return
	if not check(absf(mass_sum(burst) - 500000.0) <= 0.01 and burst.last_solver_relative_error < 0.0000000001, "500k extended flow lost mass"): return

	var no_gravity_data := ElementsData.HYDROGEN.duplicate()
	no_gravity_data.gravity_response = 0.0
	var no_gravity: MaterialFieldScript = MaterialFieldScript.new(no_gravity_data)
	no_gravity.spawn_grains(12000, 0.0)
	advance(no_gravity, 20.2)
	var no_gravity_height := no_gravity.sample_height(0.0)
	advance(no_gravity, 5.0)
	if not check(absf(no_gravity.sample_height(0.0) - no_gravity_height) < 0.001, "zero gravity redistributed material"): return

	var ongoing: MaterialFieldScript = MaterialFieldScript.new(ElementsData.HYDROGEN)
	for second in 20:
		ongoing.spawn_grains(500000, 0.0)
		advance(ongoing, 1.0)
	var ongoing_range := height_range(ongoing)
	if not check(ongoing.masses[int(ongoing.COLUMNS / 4)] > 0.0 and ongoing.masses[int(ongoing.COLUMNS / 2)] > 0.0 and ongoing_range.x > MaterialFieldScript.PLAYER_RADIUS and absf(mass_sum(ongoing) - float(ongoing.settled_count)) < 0.01 and is_finite(ongoing_range.y), "ongoing one-sided feed did not spread progressively around the core"): return
	var narrow_profile := ElementsData.HYDROGEN.duplicate()
	narrow_profile.flow_rate = 0.0
	narrow_profile.impact_spread = 0.1
	var wide_profile := narrow_profile.duplicate()
	wide_profile.impact_spread = 1.0
	var narrow := MaterialFieldScript.new(narrow_profile)
	var wide := MaterialFieldScript.new(wide_profile)
	narrow.spawn_grains(10000, 0.0)
	wide.spawn_grains(10000, 0.0)
	for tick in 180:
		narrow.step(1.0 / 60.0)
		wide.step(1.0 / 60.0)
	if not check(narrow.max_height > wide.max_height and absf(narrow.total_mass() - wide.total_mass()) < 0.01, "impact spread must change footprint without changing mass"): return
	var old_time := wide.time
	wide.step(INF)
	wide.step(NAN)
	if not check(wide.time == old_time, "invalid time step was accepted"): return
	print("Material field checks passed. 500k burst radii at 6/12/22 s: ", range_6.x, "/", range_6.y, ", ", range_12.x, "/", range_12.y, ", ", range_22.x, "/", range_22.y, "; final 10 s CPU simulation: ", elapsed_ms, " ms; ongoing 500k/s radius: ", ongoing_range.x, "/", ongoing_range.y, ".")
	quit(0)
