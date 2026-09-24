class_name MaterialField
extends RefCounted

# A radial, annular height field.  Each mass value is a number of emitted
# particles, so material.mass remains a gameplay response knob rather than a
# made-up chemical conversion. Geometry includes pressure-dependent packing.
const ElementsData := preload("res://core/elements.gd")
const CompactionCurve := preload("res://core/compaction_curve.gd")
const SunProgression := preload("res://core/sun_progression.gd")

var sun_progression: RefCounted
var _sun_outer_zone := 0

func enable_sun_progression() -> void:
	sun_progression = SunProgression.new()
	material = material.duplicate(true)
	material.inner_layer_min_mass = 18600.0
	_inner_layer_min_mass = 18600.0
	_inner_next_automation_mass = _inner_minimum_mass()

func get_sun_visual_state() -> Dictionary:
	if sun_progression == null:
		return {"enabled": false}
	var unit_mass := maxf(float(material.get("mass", 1.0)), 0.001)
	return sun_progression.status(float(settled_count) * unit_mass, float(compacted_count) * unit_mass,
		float(settled_count - compacted_count) * unit_mass, compaction_active)

func assimilate_player_core(free: bool = false) -> bool:
	if sun_progression == null or sun_progression.player_level >= SunProgression.PLAYER_LEVEL_CAP or compaction_active:
		return false
	var unit_mass := maxf(float(material.get("mass", 1.0)), 0.001)
	var grains := int(ceil(sun_progression.player_cost() / unit_mass))
	if not free and settled_count - compacted_count < grains:
		return false
	if not free:
		var consumed := consume_loose(grains)
		sun_progression.absorbed_mass += float(consumed) * unit_mass
	sun_progression.player_level += 1
	return true

const MAX_PARTICLES := 1_000_000_000
const PLAYER_RADIUS := 42.0
const COLUMNS := 720
const DEPOSIT_ARC := 0.24
const MAX_BATCHES := 1024
const FIXED_STEP := 1.0 / 60.0
const RADIAL_LOOKUP_SAMPLES := 16
const MAX_LANDING_EVENTS := 64
const LANDING_EVENT_LIFETIME := 1.2

var material: Dictionary
var grain_size: float
var capacity: int
var count := 0
var settled_count := 0
var rim_activity := PackedFloat32Array()
var last_landing_time := -1000.0
var _impact_disturbance := 0.0
# Settled grains converted by an explicit player action.  They are no longer
# stored in the flowing columns, but remain part of the exact logical count.
var compacted_count := 0
var compacted_radius := PLAYER_RADIUS
# Formed planet or sun structure, ordered from centre to surface.  The player
# core remains the separate PLAYER_RADIUS circle at the centre.
var _body_layers: Array[Dictionary] = []
var animation_inner_radius := PLAYER_RADIUS
var animation_outer_radius := PLAYER_RADIUS
var inner_automation_unlocked := false
var inner_automation_enabled := false
var compaction_kind: String:
	get:
		if not compaction_active:
			return ""
		return "inner" if _inner_compaction_source_index >= 0 else "outer"
# Core-layer conversion keeps its count immediately, while its occupied area
# visibly contracts over fixed simulation ticks.
var compaction_active := false
var compaction_progress := 0.0
var compaction_pulse := 0.0
var time := 0.0
var masses := PackedFloat64Array()
var heights := PackedFloat32Array()
# Radius-squared coordinates from core (0) to surface (RADIAL_LOOKUP_SAMPLES)
# for every column.  This is a fixed 12,240-float cache, independent of count.
var radial_lookup := PackedFloat32Array()
var batches: Array[Dictionary] = []
var landing_events: Array[Dictionary] = []
var revision := 0
var epoch := 0
var seed_counter := 0
var max_height := PLAYER_RADIUS
var last_solver_relative_error := 0.0

var _base_radius: float
var _particle_area: float
var _pressure_area: float
var _volume_curve := CompactionCurve.new()
var _curve_key: Array = []
var _lookup_masses := PackedFloat64Array()
var _compaction_loose_packing := 0.72
var _compaction_response := 1.0
var _compaction_stage_pressures := Vector3(1800.0, 9500.0, 45000.0)
var _compaction_stage_packings := Vector3(0.79, 0.87, 0.94)
var _accumulator := 0.0
var _edge_conductance := PackedFloat64Array()
var _edge_flux := PackedFloat64Array()
var _outgoing_flux := PackedFloat64Array()
var _lower := PackedFloat64Array()
var _diagonal := PackedFloat64Array()
var _upper := PackedFloat64Array()
var _solution := PackedFloat64Array()
var _cyclic_vector := PackedFloat64Array()
var _thomas_denominator := PackedFloat64Array()
var _formed_core_area := 0.0
var _compaction_start_area := 0.0
var _compaction_target_area := 0.0
var _compaction_elapsed := 0.0
var _core_layer_area_ratio := 0.1
var _core_layer_compaction_duration := 1.4
var _inner_layer_min_mass := 200000.0
var _inner_automation_multiplier := 1.75
var _inner_next_automation_mass := 200000.0
var _total_collected_mass := 0.0
var _inner_compaction_source_index := -1
var _inner_compaction_start_total_area := 0.0
var _inner_compaction_target_total_area := 0.0
var _animation_layer_static_area := 0.0


func _init(profile: Dictionary = ElementsData.HYDROGEN, particle_capacity: int = MAX_PARTICLES) -> void:
	material = profile.duplicate()
	grain_size = maxf(float(material.get("grain_size", 2.0)), 0.25)
	capacity = clampi(particle_capacity, 0, MAX_PARTICLES)
	_base_radius = PLAYER_RADIUS + grain_size * 0.5
	_particle_area = PI * pow(grain_size * 0.5, 2.0)
	# A column rests on its core arc times one grain depth.  This is a stable
	# 2D area proxy, not a claim that the cutaway has literal 3D units.
	_pressure_area = maxf(_base_radius * _angle_step() * grain_size, 0.001)
	_compaction_loose_packing = clampf(float(material.get("compaction_loose_packing", 0.72)), 0.05, 0.995)
	_compaction_response = maxf(float(material.get("compaction_response", 1.0)), 0.0)
	_compaction_stage_pressures = material.get("compaction_stage_pressures", Vector3(1800.0, 9500.0, 45000.0))
	_compaction_stage_packings = material.get("compaction_stage_packings", Vector3(0.79, 0.87, 0.94))
	_inner_layer_min_mass = _inner_minimum_mass()
	_inner_next_automation_mass = _inner_layer_min_mass
	_inner_automation_multiplier = maxf(float(material.get("inner_automation_multiplier", 1.75)), 1.01)
	masses.resize(COLUMNS)
	heights.resize(COLUMNS)
	radial_lookup.resize(COLUMNS * (RADIAL_LOOKUP_SAMPLES + 1))
	_edge_conductance.resize(COLUMNS)
	_edge_flux.resize(COLUMNS)
	_outgoing_flux.resize(COLUMNS)
	_lower.resize(COLUMNS)
	_diagonal.resize(COLUMNS)
	_upper.resize(COLUMNS)
	_solution.resize(COLUMNS)
	_cyclic_vector.resize(COLUMNS)
	_thomas_denominator.resize(COLUMNS)
	_reset_surface()


func spawn_hydrogen(amount: int = 1, source_angle: float = NAN) -> void:
	spawn_grains(amount, source_angle)

func capture_ambient_batch(captures: Array[Dictionary]) -> int:
	# Dust has already flown to the surface. Deposit once, without respawning
	# another sky batch or converting any of it into permanent layers.
	var accepted_total := 0
	for capture in captures:
		var angle := float(capture.get("angle", 0.0))
		if not is_finite(angle):
			continue
		var accepted := mini(maxi(int(capture.get("amount", 0)), 0), capacity - count)
		if accepted <= 0:
			continue
		count += accepted
		settled_count += accepted
		accepted_total += accepted
		_deposit(accepted, angle)
	if accepted_total > 0:
		_total_collected_mass += float(accepted_total) * maxf(float(material.get("mass", 1.0)), 0.0)
		_rebuild_heights()
		revision += 1
	return accepted_total


func spawn_grains(amount: int = 1, source_angle: float = NAN, source_radius: float = NAN) -> void:
	var accepted := mini(maxi(amount, 0), capacity - count)
	if accepted <= 0:
		return
	var angle := source_angle
	if not is_finite(angle):
		angle = -PI * 0.25
	angle = _wrap_angle(angle)
	var target := sample_height(angle)
	var gravity := maxf(float(material.get("gravity_response", 1.0)), 0.01)
	var duration := 2.0 / sqrt(gravity)
	var batch := {
		"amount": accepted,
		"arrival_total": accepted,
		"landed": 0,
		"angle": angle,
		"birth": time,
		"duration": duration,
		"start_radius": maxf(source_radius, target + grain_size) if is_finite(source_radius) else maxf(360.0, target + 240.0),
		"end_radius": target,
		"seed": seed_counter,
		"spread": _deposit_arc(),
	}
	batch.landing_span = _landing_span_for(accepted, duration)
	_record_landing_event(batch, time + duration - float(batch.landing_span), accepted, float(batch.landing_span))
	seed_counter += 1
	count += accepted
	_total_collected_mass += float(accepted) * maxf(float(material.get("mass", 1.0)), 0.0)
	_append_batch(batch)
	revision += 1


func step(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += delta
	while _accumulator + 0.00000001 >= FIXED_STEP:
		_simulate(FIXED_STEP)
		_accumulator -= FIXED_STEP


func _simulate(delta: float) -> void:
	time += delta
	while not landing_events.is_empty() and time - float(landing_events[0].birth) > float(landing_events[0].duration):
		landing_events.pop_front()
	if sun_progression != null:
		sun_progression.step(delta)
	var changed := _advance_core_compaction(delta)
	changed = _land_due_batches() or changed
	_impact_disturbance = move_toward(_impact_disturbance, 0.0, delta * 0.55)
	# Only nested layers may be automated after an upgrade unlock.  Forming the
	# outer planet core is always an explicit player action.
	if not compaction_active and inner_automation_unlocked and inner_automation_enabled:
		if _total_collected_mass + 0.000001 >= _inner_next_automation_mass and compact_inner_layer():
			changed = true
	# The loop count is fixed at COLUMNS; it never scales with particle count.
	if settled_count > 0:
		if changed:
			_rebuild_heights()
		changed = _redistribute(delta) or changed
	if changed:
		_rebuild_heights()
		revision += 1


func clear() -> void:
	if sun_progression != null:
		sun_progression = SunProgression.new()
	count = 0
	settled_count = 0
	compacted_count = 0
	compacted_radius = PLAYER_RADIUS
	_body_layers.clear()
	animation_inner_radius = PLAYER_RADIUS
	animation_outer_radius = PLAYER_RADIUS
	_total_collected_mass = 0.0
	_inner_next_automation_mass = _inner_minimum_mass()
	_cancel_core_compaction()
	_set_loose_base_radius()
	time = 0.0
	_accumulator = 0.0
	batches.clear()
	landing_events.clear()
	seed_counter = 0
	epoch += 1
	_reset_surface()
	revision += 1


func sample_height(angle: float) -> float:
	var column := _column_for_angle(angle)
	var next := (column + 1) % COLUMNS
	var fractional := _column_fraction(angle)
	return lerpf(heights[column], heights[next], fractional)


func total_mass() -> float:
	# In-flight particles are part of count but not yet present in masses.
	var settled_mass := 0.0
	for value in masses:
		settled_mass += value
	return settled_mass + float(compacted_count + count - settled_count)


func seed_uniform(amount: int) -> void:
	if sun_progression != null:
		sun_progression = SunProgression.new()
	rim_activity.fill(-1000.0)
	last_landing_time = -1000.0
	_impact_disturbance = 0.0
	# Benchmark setup: fill every angular sector evenly, with no flight queue.
	# This has no particle array and gives renderers a stable 100k/500k surface.
	var accepted := clampi(amount, 0, capacity)
	count = accepted
	settled_count = accepted
	compacted_count = 0
	compacted_radius = PLAYER_RADIUS
	_body_layers.clear()
	animation_inner_radius = PLAYER_RADIUS
	animation_outer_radius = PLAYER_RADIUS
	_total_collected_mass = float(accepted) * maxf(float(material.get("mass", 1.0)), 0.0)
	_inner_next_automation_mass = _inner_minimum_mass()
	_cancel_core_compaction()
	_set_loose_base_radius()
	batches.clear()
	landing_events.clear()
	for column in COLUMNS:
		masses[column] = float(accepted) / float(COLUMNS)
		_edge_conductance[column] = 0.0
	_rebuild_heights()
	revision += 1


func layer_status() -> Dictionary:
	# A core layer needs material all the way around the player.  That keeps its
	# boundary circular and prevents a local mound being converted into a core.
	_refresh_compaction_curve()
	var loose_count := maxi(settled_count - compacted_count, 0)
	var enabled := bool(material.get("core_layer_enabled", true))
	var minimum_settled := maxi(int(material.get("core_layer_min_grains", 250000)), 1)
	var layer_grains := maxi(int(material.get("core_layer_grains", 100000)), COLUMNS)
	var minimum_packing := clampf(float(material.get("core_layer_min_packing", 0.45)), 0.0, 1.0)
	var least_column := INF
	for column in COLUMNS:
		least_column = minf(least_column, maxf(masses[column], 0.0))
	var full_ring_grains := maxi(int(floor(least_column * float(COLUMNS) + 0.000001)), 0)
	var inner_packing := packing_for_pressure(pressure_for_overburden(least_column))
	var packing_span := maxf(1.0 - _compaction_loose_packing, 0.000001)
	var normalized_packing := clampf((inner_packing - _compaction_loose_packing) / packing_span, 0.0, 1.0)
	if sun_progression != null:
		minimum_settled = int(ceil(sun_progression.required_mass() / maxf(float(material.get("mass", 1.0)), 0.001)))
		# Keep excess loose for upgrades/future layers, even at the storage cap.
		layer_grains = mini(loose_count, minimum_settled)
		full_ring_grains = loose_count
		minimum_packing = 0.0
		enabled = enabled and sun_progression.completed_layers < SunProgression.LAYER_COUNT
	var reason := "ready"
	if compaction_active:
		reason = "core layer compacting"
	elif not enabled:
		reason = "core layers disabled"
	elif loose_count <= 0:
		reason = "no settled loose material"
	elif loose_count < minimum_settled:
		reason = "need more settled material"
	elif full_ring_grains < layer_grains:
		reason = "need a full material ring"
	elif normalized_packing < minimum_packing:
		reason = "inner ring needs compaction"
	if sun_progression != null and sun_progression.completed_layers >= SunProgression.LAYER_COUNT:
		reason = "Solar layers complete"
	return {
		"ready": reason == "ready",
		"reason": reason,
		"radius": compacted_radius,
		"compacted_count": compacted_count,
		"loose_count": loose_count,
		"minimum_settled": minimum_settled,
		"layer_grains": layer_grains,
		"full_ring_grains": full_ring_grains,
		"inner_packing": inner_packing,
		"normalized_inner_packing": normalized_packing,
		"minimum_packing": minimum_packing,
	}


func form_core_layer(force: bool = false) -> bool:
	# This is intentionally never called by simulation.  A player or the dev
	# shortcut must choose the moment of conversion.
	if compaction_active:
		return false
	if sun_progression != null and sun_progression.completed_layers >= SunProgression.LAYER_COUNT:
		return false
	var status := layer_status()
	if not force and not bool(status.ready):
		return false
	var full_ring_grains := int(status.full_ring_grains)
	if full_ring_grains <= 0:
		return false
	var requested := int(status.layer_grains)
	var layer_grains := mini(requested, full_ring_grains)
	if layer_grains <= 0:
		return false
	var per_column := float(layer_grains) / float(COLUMNS)
	var consumed_area := 0.0
	var loose_total := maxf(float(settled_count - compacted_count), 1.0)
	# Capture the physical footprint before removing the inner shell.  The
	# volume curve keeps this correct for pressure-packed, non-uniform columns.
	for column in COLUMNS:
		var take := masses[column] * float(layer_grains) / loose_total if sun_progression != null else per_column
		var consumed_radius_sq := radius_squared_for_mass(masses[column], take)
		consumed_area += 0.5 * _angle_step() * maxf(consumed_radius_sq - _base_radius * _base_radius, 0.0)
	for column in COLUMNS:
		var take := masses[column] * float(layer_grains) / loose_total if sun_progression != null else per_column
		masses[column] = maxf(masses[column] - take, 0.0)
	compacted_count += layer_grains
	if sun_progression != null:
		_sun_outer_zone = mini(sun_progression.completed_layers, 2)
		var zone_count := mini(sun_progression.completed_layers + 1, 4)
		sun_progression.record_compaction(float(layer_grains) * float(material.get("mass", 1.0)), layer_grains, force)
		# New outer conversions reveal their own zones without requiring the
		# separate optional inner-core densification button first.
		while _body_layers.size() < zone_count:
			_body_layers.append({"name": SunProgression.BAND_NAMES[_body_layers.size()], "count": 0, "area": 0.0, "pulse": 0.0})
	_core_layer_area_ratio = clampf(float(material.get("core_layer_area_ratio", 0.1)), 0.001, 1.0)
	_core_layer_compaction_duration = maxf(float(material.get("core_layer_duration", 1.4)), FIXED_STEP)
	var previous_area := _formed_core_area
	var outer_target_index := _outer_target_index()
	_animation_layer_static_area = float(_body_layers[outer_target_index].get("area", 0.0)) if outer_target_index >= 0 else 0.0
	_compaction_start_area = _formed_core_area + consumed_area
	_compaction_target_area = _formed_core_area + consumed_area * _core_layer_area_ratio
	_formed_core_area = _compaction_target_area
	_add_outer_body_layer(layer_grains, consumed_area * _core_layer_area_ratio)
	_compaction_elapsed = 0.0
	compaction_active = true
	compaction_progress = 0.0
	_inner_compaction_source_index = -1
	compaction_pulse = 0.0
	animation_inner_radius = _radius_for_area(previous_area)
	animation_outer_radius = _radius_for_area(_compaction_start_area)
	_set_compacted_area(_compaction_start_area)
	_refresh_animation_window()
	_set_loose_base_radius()
	_rebuild_heights()
	revision += 1
	return true


func _advance_core_compaction(delta: float) -> bool:
	if not compaction_active:
		return false
	_compaction_elapsed += delta
	compaction_progress = clampf(_compaction_elapsed / _core_layer_compaction_duration, 0.0, 1.0)
	var eased := compaction_progress * compaction_progress * (3.0 - 2.0 * compaction_progress)
	var nominal_area := lerpf(_compaction_start_area, _compaction_target_area, eased)
	# The outer binding animation moves only its boundary.  Nested conversion
	# pulses only the source core and the new adjacent inner mantle.
	var local_pulse := sin(compaction_progress * TAU * 7.0) * (1.0 - compaction_progress)
	compaction_pulse = local_pulse
	if _inner_compaction_source_index >= 0:
		compaction_pulse = local_pulse
		_set_inner_animation_pulse(local_pulse)
	else:
		_set_outer_animation_pulse(local_pulse)
	var shudder := (_compaction_start_area - _compaction_target_area) * 0.035 * compaction_pulse
	_set_compacted_area(clampf(nominal_area + shudder, _compaction_target_area, _compaction_start_area))
	_refresh_animation_window()
	# Inner densification only changes bound layers. Rebuilding all 720 loose
	# radial lookups every fixed tick caused a needless click-time slowdown.
	# Keep the loose field stable during the short animation and reconcile it
	# once when the conversion finishes.
	if _inner_compaction_source_index < 0:
		_set_loose_base_radius()
		_rebuild_heights()
	if compaction_progress >= 1.0:
		compaction_active = false
		compaction_pulse = 0.0
		_set_compacted_area(_formed_core_area)
		animation_inner_radius = PLAYER_RADIUS
		animation_outer_radius = compacted_radius
		_clear_layer_pulses()
		_inner_compaction_source_index = -1
		_set_loose_base_radius()
		_rebuild_heights()
	return true


func _set_compacted_area(area: float) -> void:
	compacted_radius = _radius_for_area(area)


func _cancel_core_compaction() -> void:
	_formed_core_area = 0.0
	_compaction_start_area = 0.0
	_compaction_target_area = 0.0
	_compaction_elapsed = 0.0
	compaction_active = false
	compaction_progress = 0.0
	compaction_pulse = 0.0
	_inner_compaction_source_index = -1
	_animation_layer_static_area = 0.0
	animation_inner_radius = PLAYER_RADIUS
	animation_outer_radius = PLAYER_RADIUS
	_clear_layer_pulses()


func get_body_layers() -> Array[Dictionary]:
	# This is deliberately a compact draw description.  Logical grain counts
	# remain exact while the renderer needs only four annular sections.
	var result: Array[Dictionary] = []
	var accumulated_area := 0.0
	var transient_area := maxf(_current_compacted_area() - _formed_core_area, 0.0) if compaction_active else 0.0
	var animated_index := _animated_layer_index()
	for index in _body_layers.size():
		var layer: Dictionary = _body_layers[index]
		var inner_radius := _radius_for_area(accumulated_area)
		var display_area := maxf(float(layer.get("area", 0.0)), 0.0)
		if index == animated_index:
			display_area += transient_area
		accumulated_area += display_area
		result.append({
			"name": SunProgression.BAND_NAMES[index] if sun_progression != null else str(layer.get("name", "Planet core")),
			"count": int(layer.get("count", 0)),
			"inner_radius": inner_radius,
			"outer_radius": _radius_for_area(accumulated_area),
			"pulse": float(layer.get("pulse", 0.0)),
		})
	return result


func inner_layer_status() -> Dictionary:
	var core_count := 0
	if not _body_layers.is_empty():
		core_count = int(_body_layers[0].get("count", 0))
	var core_mass := float(core_count) * maxf(float(material.get("mass", 1.0)), 0.0)
	var formed_mass := float(compacted_count) * maxf(float(material.get("mass", 1.0)), 0.0)
	var minimum_mass := _inner_minimum_mass()
	var reason := "ready"
	if compaction_active:
		reason = "core layer compacting"
	elif _body_layers.is_empty():
		reason = "form a planet core first"
	elif core_count <= 1:
		reason = "core is too small to densify"
	elif formed_mass < minimum_mass:
		reason = "need more compacted body mass"
	elif _total_collected_mass + 0.000001 < _inner_next_automation_mass:
		reason = "collect more mass for the next core"
	return {
		"ready": reason == "ready",
		"reason": reason,
		"core_count": core_count,
		"core_mass": core_mass,
		"formed_mass": formed_mass,
		"minimum_mass": minimum_mass,
		"total_collected_mass": _total_collected_mass,
		"next_automation_mass": _inner_next_automation_mass,
	}


func compact_inner_layer(force: bool = false) -> bool:
	if compaction_active or _body_layers.is_empty():
		return false
	var status := inner_layer_status()
	if not force and not bool(status.get("ready", false)):
		return false
	var source: Dictionary = _body_layers[0]
	var source_count := int(source.get("count", 0))
	var source_area := maxf(float(source.get("area", 0.0)), 0.0)
	_animation_layer_static_area = 0.0
	if source_count <= 1 or source_area <= 0.0:
		return false
	var mass_fraction := clampf(float(material.get("inner_layer_mass_fraction", 0.9)), 0.001, 0.999)
	var area_ratio := clampf(float(material.get("inner_layer_area_ratio", 0.1)), 0.001, 1.0)
	var moved_count := clampi(int(floor(float(source_count) * mass_fraction)), 1, source_count - 1)
	var residual_count := source_count - moved_count
	var effective_fraction := float(moved_count) / float(source_count)
	var start_total_area := _body_area()
	var source_inner_area := _body_area_before(0)
	var new_core_area := source_area * effective_fraction * area_ratio
	var residual_area := source_area * (1.0 - effective_fraction)
	source["count"] = moved_count
	source["area"] = new_core_area
	source["pulse"] = 0.0
	_body_layers[0] = source
	if _body_layers.size() == 1:
		_add_first_inner_mantles(residual_count, residual_area)
	else:
		var inner_mantle: Dictionary = _body_layers[1]
		inner_mantle["count"] = int(inner_mantle.get("count", 0)) + residual_count
		inner_mantle["area"] = float(inner_mantle.get("area", 0.0)) + residual_area
		inner_mantle["pulse"] = 0.0
		_body_layers[1] = inner_mantle
	_formed_core_area = _body_area()
	_compaction_start_area = start_total_area
	_compaction_target_area = _formed_core_area
	_core_layer_compaction_duration = maxf(float(material.get("inner_layer_duration", material.get("core_layer_duration", 1.4))), FIXED_STEP)
	_inner_compaction_start_total_area = start_total_area
	_inner_compaction_target_total_area = _formed_core_area
	_inner_compaction_source_index = 0
	_compaction_elapsed = 0.0
	compaction_active = true
	compaction_progress = 0.0
	compaction_pulse = 0.0
	animation_inner_radius = _radius_for_area(source_inner_area)
	_set_compacted_area(start_total_area)
	_refresh_animation_window()
	_set_loose_base_radius()
	_rebuild_heights()
	# Advance the milestone before the animation starts.  A large stockpile then
	# yields one layer per crossed threshold, not every fixed simulation tick.
	_inner_next_automation_mass = maxf(_inner_next_automation_mass * _inner_automation_multiplier,
		_total_collected_mass * _inner_automation_multiplier)
	if sun_progression != null:
		sun_progression.record_inner_densification()
	revision += 1
	return true


func unlock_inner_automation() -> bool:
	inner_automation_unlocked = true
	return true


func set_inner_automation(enabled: bool) -> bool:
	if not inner_automation_unlocked:
		return false
	inner_automation_enabled = enabled
	return true


func consume_loose(amount: int) -> int:
	# Compacted rings and in-flight arrivals cannot pay for a construction.
	var available := maxi(settled_count - compacted_count, 0)
	var consumed := mini(maxi(amount, 0), available)
	if consumed <= 0:
		return 0
	var loose_total := 0.0
	for value in masses:
		loose_total += maxf(value, 0.0)
	if loose_total <= 0.0:
		return 0
	var removed := 0.0
	var largest := 0
	for column in COLUMNS:
		if masses[column] > masses[largest]:
			largest = column
		var take := minf(masses[column], float(consumed) * masses[column] / loose_total)
		masses[column] -= take
		removed += take
	masses[largest] = maxf(masses[largest] - (float(consumed) - removed), 0.0)
	count -= consumed
	settled_count -= consumed
	_rebuild_heights()
	revision += 1
	return consumed


func _add_outer_body_layer(layer_count: int, layer_area: float) -> void:
	if sun_progression != null:
		var target := _outer_target_index()
		var skin_count := int(floor(float(layer_count) * 0.02)) if _body_layers.size() == 4 else 0
		var skin_area := layer_area * float(skin_count) / maxf(float(layer_count), 1.0)
		_body_layers[target]["count"] = int(_body_layers[target].count) + layer_count - skin_count
		_body_layers[target]["area"] = float(_body_layers[target].area) + layer_area - skin_area
		if skin_count > 0:
			_body_layers[3]["count"] = int(_body_layers[3].count) + skin_count
			_body_layers[3]["area"] = float(_body_layers[3].area) + skin_area
		return
	if _body_layers.is_empty():
		_body_layers.append({"name": _body_kind() + " core", "count": layer_count, "area": layer_area, "pulse": 0.0})
		return
	# Once the shallow surface exists, manual outer compaction grows the mantle
	# beneath it.  The surface keeps its small fixed footprint.
	var index := _body_layers.size() - 1
	if _body_layers.size() >= 4:
		index -= 1
	var layer: Dictionary = _body_layers[index]
	layer["count"] = int(layer.get("count", 0)) + layer_count
	layer["area"] = float(layer.get("area", 0.0)) + layer_area
	_body_layers[index] = layer


func _add_first_inner_mantles(residual_count: int, residual_area: float) -> void:
	var inner_weight := maxf(float(material.get("inner_mantle_fraction", 0.60)), 0.0)
	var outer_weight := maxf(float(material.get("outer_mantle_fraction", 0.35)), 0.0)
	var surface_weight := maxf(float(material.get("surface_fraction", 0.05)), 0.0)
	var weight_total := inner_weight + outer_weight + surface_weight
	if weight_total <= 0.0:
		inner_weight = 0.60
		outer_weight = 0.35
		surface_weight = 0.05
		weight_total = 1.0
	var inner_fraction := inner_weight / weight_total
	var outer_fraction := outer_weight / weight_total
	var inner_count := int(floor(float(residual_count) * inner_fraction))
	var outer_count := int(floor(float(residual_count) * outer_fraction))
	var surface_count := residual_count - inner_count - outer_count
	var inner_area := residual_area * float(inner_count) / maxf(float(residual_count), 1.0)
	var outer_area := residual_area * float(outer_count) / maxf(float(residual_count), 1.0)
	var surface_area := residual_area - inner_area - outer_area
	_body_layers.append({"name": "Inner mantle", "count": inner_count, "area": inner_area, "pulse": 0.0})
	_body_layers.append({"name": "Outer mantle", "count": outer_count, "area": outer_area, "pulse": 0.0})
	_body_layers.append({"name": str(material.get("surface_kind", "Surface")), "count": surface_count, "area": surface_area, "pulse": 0.0})


func _set_inner_animation_pulse(pulse: float) -> void:
	if _body_layers.is_empty():
		return
	var core: Dictionary = _body_layers[0]
	core["pulse"] = pulse
	_body_layers[0] = core


func _set_outer_animation_pulse(pulse: float) -> void:
	if _body_layers.is_empty():
		return
	var index := _body_layers.size() - 1
	if _body_layers.size() >= 4:
		index -= 1
	var layer: Dictionary = _body_layers[index]
	layer["pulse"] = pulse
	_body_layers[index] = layer


func _clear_layer_pulses() -> void:
	for index in _body_layers.size():
		var layer: Dictionary = _body_layers[index]
		layer["pulse"] = 0.0
		_body_layers[index] = layer


func _body_area() -> float:
	var result := 0.0
	for layer in _body_layers:
		result += maxf(float(layer.get("area", 0.0)), 0.0)
	return result


func _body_area_before(index: int) -> float:
	var result := 0.0
	for layer_index in index:
		result += maxf(float(_body_layers[layer_index].get("area", 0.0)), 0.0)
	return result


func _current_compacted_area() -> float:
	return PI * (compacted_radius * compacted_radius - PLAYER_RADIUS * PLAYER_RADIUS)


func _animated_layer_index() -> int:
	if not compaction_active or _body_layers.is_empty():
		return -1
	if _inner_compaction_source_index >= 0:
		return 0
	return _outer_target_index()


func _refresh_animation_window() -> void:
	if not compaction_active:
		return
	var index := _animated_layer_index()
	if index < 0:
		return
	var before := _body_area_before(index)
	var display_area := maxf(float(_body_layers[index].get("area", 0.0)), 0.0)
	display_area += maxf(_current_compacted_area() - _formed_core_area, 0.0)
	animation_inner_radius = _radius_for_area(before + _animation_layer_static_area)
	animation_outer_radius = _radius_for_area(before + display_area)


func _outer_target_index() -> int:
	if _body_layers.is_empty():
		return -1
	if sun_progression != null:
		return mini(_sun_outer_zone, _body_layers.size() - 1)
	return _body_layers.size() - 2 if _body_layers.size() >= 4 else _body_layers.size() - 1


func _radius_for_area(area: float) -> float:
	return sqrt(PLAYER_RADIUS * PLAYER_RADIUS + maxf(area, 0.0) / PI)


func _inner_minimum_mass() -> float:
	return maxf(float(material.get("inner_layer_min_mass", 200000.0)), 0.0)


func _body_kind() -> String:
	return str(material.get("body_kind", "Planet"))


func sample_seed(particle_index: int) -> float:
	# Stable stateless hash for a renderer's free-position sampling.
	var value := int(particle_index) + epoch * 1619
	value = (value ^ 274763641) * 2654435769
	value = value ^ (value >> 16)
	value = value * 2246822519
	value = value ^ (value >> 13)
	return float(value & 0x00ffffff) / float(0x01000000)


func _append_batch(batch: Dictionary) -> void:
	if not batches.is_empty():
		var previous: Dictionary = batches[batches.size() - 1]
		if previous.birth == batch.birth and is_equal_approx(previous.angle, batch.angle) and is_equal_approx(float(previous.start_radius), float(batch.start_radius)):
			previous.amount = int(previous.amount) + int(batch.amount)
			previous.arrival_total = int(previous.get("arrival_total", previous.amount - batch.amount)) + int(batch.amount)
			previous.landing_span = _landing_span_for(int(previous.arrival_total), float(previous.duration))
			batches[batches.size() - 1] = previous
			return
	if batches.size() < MAX_BATCHES:
		batches.append(batch)
		return
	# Preserve every particle when input outpaces the renderer's bounded queue.
	# The final queued arrival becomes the representative for the coalesced mass.
	var tail: Dictionary = batches[batches.size() - 1]
	var old_amount := float(tail.amount)
	var new_amount := float(batch.amount)
	var combined := old_amount + new_amount
	var x := cos(float(tail.angle)) * old_amount + cos(float(batch.angle)) * new_amount
	var y := sin(float(tail.angle)) * old_amount + sin(float(batch.angle)) * new_amount
	tail.amount = int(combined)
	tail.arrival_total = int(tail.get("arrival_total", int(old_amount))) + int(batch.amount)
	tail.angle = atan2(y, x)
	tail.end_radius = (float(tail.end_radius) * old_amount + float(batch.end_radius) * new_amount) / combined
	tail.start_radius = maxf(float(tail.start_radius), float(batch.start_radius))
	tail.landing_span = _landing_span_for(int(tail.arrival_total), float(tail.duration))
	batches[batches.size() - 1] = tail


func _land_due_batches() -> bool:
	var changed := false
	var index := 0
	while index < batches.size():
		var batch: Dictionary = batches[index]
		var end_time := float(batch.birth) + float(batch.duration)
		var total := int(batch.get("arrival_total", batch.amount))
		# Small inputs keep their direct response. Large arrivals apply their load
		# over a longer interval so a thin shell develops one broad, damped body
		# response instead of a sequence of sharp whole-ring corrections.
		var impact_scale := _large_impact_scale(total)
		var landing_span := float(batch.get("landing_span", _landing_span_for(total, float(batch.duration))))
		if time + 0.0000001 < end_time - landing_span:
			break
		var progress := clampf((time - end_time + landing_span + 0.0000001) / landing_span, 0.0, 1.0)
		progress = progress * progress * (3.0 - 2.0 * progress)
		var delivered := int(batch.get("landed", 0))
		var landing := mini(int(batch.amount), maxi(int(floor(float(total) * progress)) - delivered, 0))
		if landing > 0:
			_deposit(landing, float(batch.angle), total)
			_impact_disturbance = maxf(_impact_disturbance, impact_scale)
			settled_count += landing
			batch.amount = int(batch.amount) - landing
			batch.landed = delivered + landing
			changed = true
		if int(batch.amount) <= 0:
			batches.remove_at(index)
		else:
			batches[index] = batch
			index += 1
	return changed


func _deposit_arc() -> float:
	return DEPOSIT_ARC * clampf(float(material.get("impact_spread", 1.0)), 0.1, 2.0)

func _landing_span_for(total: int, duration: float) -> float:
	var settle_seconds := maxf(float(material.get("impact_settle_seconds", 0.55)), 0.01)
	return minf(settle_seconds * lerpf(1.0, 2.2, _large_impact_scale(total)), duration * 0.68)

func _record_landing_event(batch: Dictionary, birth: float, total: int, landing_span: float) -> void:
	if landing_events.size() >= MAX_LANDING_EVENTS:
		landing_events.pop_front()
	landing_events.append({
		"angle": float(batch.angle),
		"birth": birth,
		"duration": landing_span + LANDING_EVENT_LIFETIME * 0.6,
		"amount": total,
		"seed": int(batch.seed),
		"spread": float(batch.spread),
	})

func _deposit(amount: int, angle: float, impact_total: int = 0) -> void:
	last_landing_time = time
	var centre := _column_for_angle(angle)
	var impact_scale := _large_impact_scale(maxi(impact_total, amount))
	# Large bodies splash across a wider section instead of pulling a narrow
	# spike out of the whole shell. Small arrivals retain the material profile.
	var spread_arc := minf(_deposit_arc() * lerpf(1.0, 3.1, impact_scale), 0.90)
	var half_width := maxi(1, int(ceil(spread_arc * 0.5 / _angle_step())))
	var weights := PackedFloat64Array()
	weights.resize(half_width * 2 + 1)
	var weight_sum := 0.0
	for offset in range(-half_width, half_width + 1):
		var distance := absf(float(offset)) / float(half_width + 1)
		var weight := maxf(0.0, 1.0 - distance)
		weights[offset + half_width] = weight
		weight_sum += weight
	var placed := 0.0
	for offset in range(-half_width, half_width + 1):
		var share := float(amount) * weights[offset + half_width] / weight_sum
		var column := posmod(centre + offset, COLUMNS)
		masses[column] += share
		rim_activity[column] = time
		placed += share
	# Keep floating-point roundoff local and preserve exact total mass.
	masses[centre] += float(amount) - placed


func _redistribute(delta: float) -> bool:
	var flow_rate := maxf(float(material.get("flow_rate", 0.0)), 0.0)
	var gravity := maxf(float(material.get("gravity_response", 1.0)), 0.0)
	if flow_rate <= 0.0 or gravity <= 0.0:
		return false
	var repose := maxf(float(material.get("repose_slope", 0.0)), 0.0)
	var friction := clampf(float(material.get("surface_friction", 0.0)), 0.0, 1.0)
	var damping := maxf(float(material.get("damping", 0.0)), 0.0)
	var material_mass := maxf(float(material.get("mass", 1.0)), 0.05)
	var step_angle := _angle_step()
	# This is a material-response speed in angular world space, not a chemical
	# property.  The profile values shape gameplay while grain geometry remains
	# governed by grain size, pressure packing and conserved particle count.
	var mobility := flow_rate / (flow_rate + 600.0)
	var resistance := (1.0 - friction) / (1.0 + damping * 2.0 + sqrt(material_mass) * 0.3)
	var impact_flow_scale := lerpf(1.0, 0.38, clampf(_impact_disturbance, 0.0, 1.0))
	var angular_diffusion := 3.5 * gravity * mobility * resistance * impact_flow_scale
	# Positive-repose material needs a tiny open contact to transmit a slope
	# beyond the initial deposit.  It remains much slower than low-friction gas.
	var creep := maxf(float(material.get("compaction_creep", 0.0)), 0.0)
	var has_open_edge := false
	for column in COLUMNS:
		var next := (column + 1) % COLUMNS
		var difference := float(heights[column]) - float(heights[next])
		var run := maxf((float(heights[column]) + float(heights[next])) * 0.5 * step_angle, 0.001)
		# A zero-repose fluid conducts across a flat contact.  The gradient still
		# produces zero net flux there, but its implicit solve can transmit a
		# one-sided pressure wave around the complete ring.  Positive-repose
		# profiles retain a yielded contact threshold and can hold a steep heap.
		var slope_factor := 1.0 if repose <= 0.0 else creep
		if repose > 0.0 and absf(difference) > 0.000001:
			slope_factor = maxf(slope_factor, 1.0 - repose * run / absf(difference))
		# Each fixed step may cross one neighbouring edge. Cap its relaxation so
		# an impact spreads outward from its contact instead of being solved around
		# the complete periodic ring in one tick.
		var base_relaxation := minf(angular_diffusion * delta / (step_angle * step_angle), 0.49)
		_edge_conductance[column] = base_relaxation * slope_factor
		has_open_edge = has_open_edge or _edge_conductance[column] > 0.000000001
	if not has_open_edge:
		return false
	var previous_total := 0.0
	for column in COLUMNS:
		previous_total += masses[column]
	var moved := false
	# Zero-repose material uses four bounded spatial scales. Each pass remains
	# local, but fluid pressure can travel around a large body without hundreds
	# of tiny angular hops. The widest pass spans sixteen degrees, never the whole
	# body. Rough material crosses adjacent edges only and can retain a pile.
	var strides := [1, 4, 16, 32] if repose <= 0.0 else [1]
	for stride in strides:
		_edge_flux.fill(0.0)
		_outgoing_flux.fill(0.0)
		var stride_scale := 1.0 / sqrt(float(stride))
		for column in COLUMNS:
			var next := (column + int(stride)) % COLUMNS
			var difference := masses[column] - masses[next]
			var conductance := minf(_edge_conductance[column], _edge_conductance[next]) * stride_scale
			var flux := difference * 0.5 * conductance
			_edge_flux[column] = flux
			if flux > 0.0:
				_outgoing_flux[column] += flux
			else:
				_outgoing_flux[next] -= flux
		# Two edges can request the same source. Leave at least half of each
		# column in place during a pass so all intermediate states stay valid.
		for column in COLUMNS:
			if _outgoing_flux[column] <= masses[column] * 0.5 or _outgoing_flux[column] <= 0.0:
				continue
			var flux_scale := masses[column] * 0.5 / _outgoing_flux[column]
			var right_edge := column
			var left_edge := (column + COLUMNS - int(stride)) % COLUMNS
			if _edge_flux[right_edge] > 0.0:
				_edge_flux[right_edge] *= flux_scale
			if _edge_flux[left_edge] < 0.0:
				_edge_flux[left_edge] *= flux_scale
		for column in COLUMNS:
			var left_edge := (column + COLUMNS - int(stride)) % COLUMNS
			var next_mass := masses[column] + _edge_flux[left_edge] - _edge_flux[column]
			moved = moved or absf(next_mass - masses[column]) > maxf(0.000000001, masses[column] * 0.000000001)
			_solution[column] = maxf(next_mass, 0.0)
		for column in COLUMNS:
			masses[column] = _solution[column]
	var solved_total := 0.0
	var largest_column := 0
	for column in COLUMNS:
		solved_total += masses[column]
		if masses[column] > masses[largest_column]:
			largest_column = column
	# Correct only floating-point roundoff on the largest bin.
	masses[largest_column] += previous_total - solved_total
	last_solver_relative_error = absf(previous_total - solved_total) / maxf(previous_total, 1.0)
	return moved


func _solve_cyclic() -> void:
	var last := COLUMNS - 1
	var alpha := _upper[last]
	var beta := _lower[0]
	var gamma := -_diagonal[0]
	var corner_product_over_gamma := alpha * beta / gamma
	# Reuse field-owned work buffers for both tridiagonal solves.
	_thomas_denominator[0] = _diagonal[0] - gamma
	_solution[0] = masses[0] / _thomas_denominator[0]
	for column in range(1, COLUMNS):
		var diagonal := _diagonal[column]
		if column == last:
			diagonal -= corner_product_over_gamma
		var multiplier := _lower[column] / _thomas_denominator[column - 1]
		_thomas_denominator[column] = diagonal - multiplier * _upper[column - 1]
		_solution[column] = (masses[column] - _lower[column] * _solution[column - 1]) / _thomas_denominator[column]
	for column in range(COLUMNS - 2, -1, -1):
		_solution[column] -= _upper[column] * _solution[column + 1] / _thomas_denominator[column]

	_thomas_denominator[0] = _diagonal[0] - gamma
	_cyclic_vector[0] = gamma / _thomas_denominator[0]
	for column in range(1, COLUMNS):
		var diagonal := _diagonal[column]
		if column == last:
			diagonal -= corner_product_over_gamma
		var multiplier := _lower[column] / _thomas_denominator[column - 1]
		_thomas_denominator[column] = diagonal - multiplier * _upper[column - 1]
		var rhs := alpha if column == last else 0.0
		_cyclic_vector[column] = (rhs - _lower[column] * _cyclic_vector[column - 1]) / _thomas_denominator[column]
	for column in range(COLUMNS - 2, -1, -1):
		_cyclic_vector[column] -= _upper[column] * _cyclic_vector[column + 1] / _thomas_denominator[column]
	var factor := (_solution[0] + beta * _solution[last] / gamma) / (1.0 + _cyclic_vector[0] + beta * _cyclic_vector[last] / gamma)
	for column in COLUMNS:
		_solution[column] -= factor * _cyclic_vector[column]
	var source_total := 0.0
	var solved_total := 0.0
	for column in COLUMNS:
		source_total += masses[column]
		solved_total += _solution[column]
	last_solver_relative_error = absf(solved_total - source_total) / maxf(source_total, 1.0)


func _rebuild_heights() -> void:
	_refresh_compaction_curve()
	max_height = _base_radius
	for column in COLUMNS:
		var mass := maxf(masses[column], 0.0)
		if absf(mass - _lookup_masses[column]) > maxf(0.000000001, mass * 0.000000001):
			heights[column] = sqrt(_rebuild_radial_lookup(column, mass))
			_lookup_masses[column] = mass
		max_height = maxf(max_height, heights[column])


func _refresh_compaction_curve() -> void:
	var key: Array = [material.get("mass", 1.0), material.get("gravity_response", 1.0),
		material.get("compaction_loose_packing", 0.72), material.get("compaction_response", 1.0),
		material.get("compaction_stage_pressures", Vector3(1800.0, 9500.0, 45000.0)),
		material.get("compaction_stage_packings", Vector3(0.79, 0.87, 0.94))]
	if key == _curve_key:
		return
	_curve_key = key
	_compaction_loose_packing = clampf(float(key[2]), 0.05, 0.995)
	_compaction_response = maxf(float(key[3]), 0.0)
	_compaction_stage_pressures = key[4]
	_compaction_stage_packings = key[5]
	_volume_curve.rebuild(_particle_area, _compaction_loose_packing,
		_compaction_stage_pressures, _compaction_stage_packings,
		pressure_for_overburden(1.0), _compaction_response)
	_lookup_masses.resize(COLUMNS)
	_lookup_masses.fill(-1.0)


func pressure_for_overburden(grains_above: float) -> float:
	var gravity := maxf(float(material.get("gravity_response", 1.0)), 0.0)
	if gravity <= 0.0 or grains_above <= 0.0:
		return 0.0
	var grain_mass := maxf(float(material.get("mass", 1.0)), 0.0)
	return grain_mass * gravity * grains_above / _pressure_area


func packing_for_pressure(pressure: float) -> float:
	var packing := _compaction_loose_packing
	var adjusted_pressure := maxf(pressure, 0.0) * _compaction_response
	for stage in 3:
		var threshold := maxf(_vector_stage(_compaction_stage_pressures, stage), 0.001)
		var target := clampf(_vector_stage(_compaction_stage_packings, stage), packing, 0.995)
		var progress := adjusted_pressure / (adjusted_pressure + threshold)
		packing = lerpf(packing, target, progress)
	return packing


func specific_area_for_overburden(grains_above: float) -> float:
	return _particle_area / packing_for_pressure(pressure_for_overburden(grains_above))


func radius_squared_for_mass(column_mass: float, mass_from_core: float) -> float:
	_refresh_compaction_curve()
	var total := maxf(column_mass, 0.0)
	var extent := clampf(mass_from_core, 0.0, total)
	if extent <= 0.0:
		return _base_radius * _base_radius
	var volume: float = _volume_curve.integral(total) - _volume_curve.integral(total - extent)
	return _base_radius * _base_radius + 2.0 * volume / _angle_step()


func _rebuild_radial_lookup(column: int, column_mass: float) -> float:
	var total := maxf(column_mass, 0.0)
	var offset := column * (RADIAL_LOOKUP_SAMPLES + 1)
	var radius_sq := _base_radius * _base_radius
	radial_lookup[offset] = radius_sq
	var shell_mass := total / float(RADIAL_LOOKUP_SAMPLES)
	var total_area: float = _volume_curve.integral(total)
	for sample in RADIAL_LOOKUP_SAMPLES:
		var volume: float = total_area - _volume_curve.integral(maxf(total - (float(sample) + 1.0) * shell_mass, 0.0))
		radius_sq = _base_radius * _base_radius + 2.0 * volume / _angle_step()
		radial_lookup[offset + sample + 1] = radius_sq
	return radius_sq


func _vector_stage(values: Vector3, stage: int) -> float:
	match stage:
		0:
			return values.x
		1:
			return values.y
		_:
			return values.z


func _reset_surface() -> void:
	rim_activity.resize(COLUMNS)
	rim_activity.fill(-1000.0)
	last_landing_time = -1000.0
	_lookup_masses.resize(COLUMNS)
	_lookup_masses.fill(-1.0)
	for column in COLUMNS:
		masses[column] = 0.0
		heights[column] = _base_radius
		var offset := column * (RADIAL_LOOKUP_SAMPLES + 1)
		for sample in RADIAL_LOOKUP_SAMPLES + 1:
			radial_lookup[offset + sample] = _base_radius * _base_radius
		_edge_conductance[column] = 0.0
		_edge_flux[column] = 0.0
		_outgoing_flux[column] = 0.0
	max_height = _base_radius


func _set_loose_base_radius() -> void:
	# Loose grain centres begin one grain radius outside the permanent core.
	_base_radius = compacted_radius + grain_size * 0.5
	# Pressure keeps the original player-scale reference area.  Changing it as
	# the permanent core grows would make the remaining loose material suddenly
	# decompress and visually expand at the instant a layer is formed.
	_lookup_masses.resize(COLUMNS)
	_lookup_masses.fill(-1.0)


func _angle_step() -> float:
	return TAU / float(COLUMNS)


func _large_impact_scale(amount: int) -> float:
	return smoothstep(10000.0, 500000.0, float(maxi(amount, 0)))


func _wrap_angle(angle: float) -> float:
	return fposmod(angle, TAU)


func _column_for_angle(angle: float) -> int:
	return int(floor(_wrap_angle(angle) / _angle_step())) % COLUMNS


func _column_fraction(angle: float) -> float:
	var units := _wrap_angle(angle) / _angle_step()
	return units - floor(units)
