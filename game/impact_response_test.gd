extends SceneTree

const Field = preload("res://core/material_field.gd")
const Profiles = preload("res://core/elements.gd")

func measure(seconds: float) -> float:
	var profile: Dictionary = Profiles.HYDROGEN.duplicate(true)
	profile.impact_settle_seconds = seconds
	var field = Field.new(profile)
	field.seed_uniform(750000)
	field.spawn_grains(500000, -PI / 4.0)
	var previous: PackedFloat32Array = field.heights.duplicate()
	var peak := 0.0
	for tick in 180:
		field.step(1.0 / 60.0)
		for column in field.COLUMNS:
			peak = maxf(peak, absf(field.heights[column] - previous[column]))
		previous = field.heights.duplicate()
	assert(field.settled_count == 1250000)
	assert(absf(field.total_mass() - 1250000.0) < 0.01)
	return peak

func large_impact_footprint() -> int:
	var field = Field.new(Profiles.HYDROGEN)
	field.seed_uniform(750000)
	var baseline := 750000.0 / float(field.COLUMNS)
	field.spawn_grains(500000, -PI / 4.0)
	for tick in 60:
		field.step(1.0 / 60.0)
	var touched := 0
	for mass in field.masses:
		if float(mass) > baseline + 1.0:
			touched += 1
	return touched

func _initialize() -> void:
	var short_landing := measure(0.2)
	var eased_landing := measure(0.55)
	var footprint := large_impact_footprint()
	print("IMPACT peak radial step: short=%.3f eased=%.3f footprint_columns=%d" % [short_landing, eased_landing, footprint])
	if eased_landing >= short_landing * 0.8:
		push_error("Longer landing did not sufficiently reduce the surface jump")
		quit(1)
	elif footprint < 60:
		push_error("Large impact did not spread across a broad enough footprint")
		quit(1)
	else:
		print("Impact response checks passed: reduced surface jump and conserved material.")
		quit()
