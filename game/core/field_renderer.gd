class_name FieldRenderer
extends Node2D

const FIELD_COLUMNS := 720
const MAX_BATCHES := 1024
const RENDER_INSTANCE_BUDGET := 500000
const MAX_DISPLAY_SCREEN_DIAMETER := 3.0
const IDENTITY_FLOATS_PER_INSTANCE := 8
const RADIAL_LOOKUP_SAMPLES := 16

const SurfaceShader := preload("res://core/field_surface.gdshader")
const AirShader := preload("res://core/field_air.gdshader")
const RimShader := preload("res://core/field_rim.gdshader")
const BulkShader := preload("res://core/field_bulk.gdshader")
var _bulk: MeshInstance2D
var _bulk_material: ShaderMaterial
var _body_image: Image
var _body_texture: ImageTexture

var capacity := 0
var drawn_settled_count := 0
var drawn_air_count := 0
var drawn_rim_count := 0

var _surface_instances: MultiMeshInstance2D
var _air_instances: MultiMeshInstance2D
var _rim_instances: MultiMeshInstance2D
var _surface_multimesh: MultiMesh
var _air_multimesh: MultiMesh
var _rim_multimesh: MultiMesh
var _surface_material: ShaderMaterial
var _air_material: ShaderMaterial
var _rim_material: ShaderMaterial

var _surface_image: Image
var _surface_texture: ImageTexture
var _air_image: Image
var _air_texture: ImageTexture
var _rim_image: Image
var _rim_texture: ImageTexture
var _last_solver_id := 0
var _last_revision := -1
var _last_epoch := -1
var _batch_grain_count := 0
var _logical_settled_count := 0
var _logical_air_count := 0
var _logical_rim_count := 0
var _last_rim_slot_update := -1000.0

const MAX_RIM_INSTANCES := 2048
const RIM_LIFETIME := 1.2

func _init(instance_capacity: int = RENDER_INSTANCE_BUDGET) -> void:
	capacity = clampi(instance_capacity, 1, RENDER_INSTANCE_BUDGET)
	z_index = -1
	_build_surface_field()
	_build_air_batches()
	_build_rim_slots()
	_build_multimeshes()

func update_field(solver, center: Vector2, zoom: float) -> void:
	var solver_id: int = solver.get_instance_id()
	if solver_id != _last_solver_id:
		_last_solver_id = solver_id
		_last_revision = -1
		_last_epoch = -1
		_last_rim_slot_update = -1000.0
		_logical_rim_count = 0
	var epoch := int(solver.epoch)
	var revision := int(solver.revision)
	if revision != _last_revision or epoch != _last_epoch:
		_update_surface_texture(solver)
		_update_air_batches(solver)
		_update_body_layers(solver)
		_last_revision = revision
		_last_epoch = epoch

	position = center
	scale = Vector2.ONE * zoom
	var grain_diameter := float(solver.grain_size)
	var material_data: Dictionary = solver.material
	var grain_tint: Color = material_data.get("color", Color("80c0ff"))
	var simulation_time := float(solver.time)
	_air_material.set_shader_parameter("impact_settle_seconds", float(material_data.get("impact_settle_seconds", 0.55)))
	var core_radius := float(solver.PLAYER_RADIUS)
	_logical_settled_count = maxi(int(solver.settled_count) - int(solver.compacted_count), 0)
	_logical_air_count = maxi(int(solver.count) - int(solver.settled_count), 0)
	_logical_rim_count = _update_rim_slots(solver, simulation_time)
	var draw_counts := _allocate_draw_counts(_logical_settled_count, _logical_air_count, _logical_rim_count)
	drawn_settled_count = int(draw_counts.settled)
	drawn_air_count = int(draw_counts.air)
	drawn_rim_count = int(draw_counts.rim)
	_surface_multimesh.visible_instance_count = drawn_settled_count
	_air_multimesh.visible_instance_count = drawn_air_count
	_rim_multimesh.visible_instance_count = drawn_rim_count
	var settled_density_scale := sqrt(float(_logical_settled_count) / float(maxi(drawn_settled_count, 1)))
	var display_cap_world := MAX_DISPLAY_SCREEN_DIAMETER / maxf(zoom, 0.001)
	# Each sample covers its share of the full population at every zoom.
	var settled_display_diameter := grain_diameter * settled_density_scale
	var bulk_radius := maxf(float(solver.max_height), float(solver.compacted_radius))
	_bulk.scale = Vector2.ONE * bulk_radius * 2.0
	_bulk_material.set_shader_parameter("outer_radius", bulk_radius)
	_bulk_material.set_shader_parameter("compacted_radius", float(solver.compacted_radius))
	_bulk_material.set_shader_parameter("animation_inner_radius", float(solver.animation_inner_radius))
	_bulk_material.set_shader_parameter("animation_outer_radius", float(solver.animation_outer_radius))
	_bulk_material.set_shader_parameter("tint", grain_tint)
	_bulk_material.set_shader_parameter("loose_packing", float(material_data.get("compaction_loose_packing", 0.72)))
	_bulk_material.set_shader_parameter("max_packing", _maximum_stage_packing(material_data))
	_bulk_material.set_shader_parameter("darkening", float(material_data.get("compaction_depth_darkening", 0.2)))
	var sun_state: Dictionary = solver.call("get_sun_visual_state") if solver.has_method("get_sun_visual_state") else {}
	var surface_tint := grain_tint
	if bool(sun_state.get("enabled", false)):
		var warmth := float(sun_state.get("heat", 0.0)) * (0.32 if bool(sun_state.get("ignited", false)) else 0.08)
		surface_tint = grain_tint.lerp(Color("ffc568"), warmth)
	_bulk_material.set_shader_parameter("tint", surface_tint)
	_bulk_material.set_shader_parameter("conversion_progress", float(solver.compaction_progress))
	_bulk_material.set_shader_parameter("conversion_active", bool(solver.compaction_active))
	_bulk_material.set_shader_parameter("sun_enabled", bool(sun_state.get("enabled", false)))
	_bulk_material.set_shader_parameter("stellar_heat", clampf(float(sun_state.get("heat", 0.0)), 0.0, 1.0))
	_bulk_material.set_shader_parameter("stellar_ignited", bool(sun_state.get("ignited", false)))
	_bulk_material.set_shader_parameter("stellar_spin", float(sun_state.get("spin", 0.0)))
	_bulk_material.set_shader_parameter("simulation_time", simulation_time)
	_surface_material.set_shader_parameter("simulation_time", simulation_time)
	_surface_material.set_shader_parameter("core_radius", core_radius)
	_surface_material.set_shader_parameter("grain_diameter", grain_diameter)
	_surface_material.set_shader_parameter("display_diameter", settled_display_diameter)
	_surface_material.set_shader_parameter("settled_count", maxi(drawn_settled_count, 1))
	_surface_material.set_shader_parameter("logical_settled_count", maxi(_logical_settled_count, 1))
	_surface_material.set_shader_parameter("grain_tint", surface_tint)
	_surface_material.set_shader_parameter("compaction_loose_packing", float(material_data.get("compaction_loose_packing", 0.72)))
	_surface_material.set_shader_parameter("compaction_max_packing", _maximum_stage_packing(material_data))
	_surface_material.set_shader_parameter("compaction_depth_darkening", float(material_data.get("compaction_depth_darkening", 0.20)))

	_air_material.set_shader_parameter("simulation_time", simulation_time)
	_air_material.set_shader_parameter("core_radius", core_radius)
	_air_material.set_shader_parameter("grain_diameter", grain_diameter)
	var air_display_diameter := maxf(grain_diameter, minf(grain_diameter * sqrt(float(_logical_air_count) / float(maxi(drawn_air_count, 1))), display_cap_world))
	_air_material.set_shader_parameter("display_diameter", air_display_diameter)
	_air_material.set_shader_parameter("air_batch_count", _air_batch_count)
	_air_material.set_shader_parameter("drawn_air_count", maxi(drawn_air_count, 1))
	_air_material.set_shader_parameter("logical_air_count", _batch_grain_count)
	_air_material.set_shader_parameter("grain_tint", grain_tint)
	_rim_material.set_shader_parameter("simulation_time", simulation_time)
	_rim_material.set_shader_parameter("grain_diameter", grain_diameter)
	_rim_material.set_shader_parameter("display_diameter", maxf(grain_diameter, minf(grain_diameter * 1.35, display_cap_world)))
	_rim_material.set_shader_parameter("grain_tint", surface_tint)

func get_draw_counts() -> Dictionary:
	return {
		"settled": drawn_settled_count,
		"air": drawn_air_count,
		"rim": drawn_rim_count,
		"settled_logical": _logical_settled_count,
		"air_logical": _logical_air_count,
		"rim_logical": _logical_rim_count,
		"capacity": capacity,
	}

func _allocate_draw_counts(settled_count: int, air_count: int, rim_count: int) -> Dictionary:
	# The landing handoff is reserved first, but exists only while a column is fresh.
	var rim_draw := mini(rim_count, mini(MAX_RIM_INSTANCES, capacity))
	var remaining := capacity - rim_draw
	var total_count := settled_count + air_count
	if total_count <= remaining:
		return {"settled": settled_count, "air": air_count, "rim": rim_draw}
	if total_count <= 0:
		return {"settled": 0, "air": 0, "rim": rim_draw}
	var settled_draw := int(round(float(remaining) * float(settled_count) / float(total_count)))
	settled_draw = clampi(settled_draw, 0, mini(settled_count, remaining))
	var air_draw := mini(air_count, remaining - settled_draw)
	if settled_count > 0 and settled_draw == 0 and remaining > 0:
		settled_draw = 1
		air_draw = mini(air_count, remaining - 1)
	if air_count > 0 and air_draw == 0 and remaining > 0:
		air_draw = 1
		settled_draw = mini(settled_count, remaining - 1)
	return {"settled": settled_draw, "air": air_draw, "rim": rim_draw}

var _air_batch_count := 0

func _build_surface_field() -> void:
	_surface_image = Image.create(FIELD_COLUMNS, RADIAL_LOOKUP_SAMPLES + 2, false, Image.FORMAT_RGBAF)
	for column in FIELD_COLUMNS:
		_surface_image.set_pixel(column, 0, Color(0.0, 0.0, 43.0, 1.0))
	_surface_texture = ImageTexture.create_from_image(_surface_image)

func _build_air_batches() -> void:
	_air_image = Image.create(MAX_BATCHES, 2, false, Image.FORMAT_RGBAF)
	_air_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_air_texture = ImageTexture.create_from_image(_air_image)

func _build_rim_slots() -> void:
	_rim_image = Image.create(MAX_RIM_INSTANCES, 1, false, Image.FORMAT_RF)
	_rim_image.fill(Color(-1.0, 0.0, 0.0, 1.0))
	_rim_texture = ImageTexture.create_from_image(_rim_image)

func _build_multimeshes() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_bulk_material = ShaderMaterial.new()
	_bulk_material.shader = BulkShader
	_bulk_material.set_shader_parameter("field_texture", _surface_texture)
	_body_image = Image.create(4, 1, false, Image.FORMAT_RGBAF)
	_body_image.fill(Color(0, 0, 0, 0))
	_body_texture = ImageTexture.create_from_image(_body_image)
	_bulk_material.set_shader_parameter("body_texture", _body_texture)
	_bulk = MeshInstance2D.new()
	_bulk.mesh = quad
	_bulk.material = _bulk_material
	_bulk.z_index = -1
	add_child(_bulk)

	_surface_multimesh = _make_multimesh(quad)
	_air_multimesh = _make_multimesh(quad)
	_rim_multimesh = _make_multimesh(quad, MAX_RIM_INSTANCES)
	_surface_multimesh.visible_instance_count = 0
	_air_multimesh.visible_instance_count = 0
	_rim_multimesh.visible_instance_count = 0

	_surface_material = ShaderMaterial.new()
	_surface_material.shader = SurfaceShader
	_surface_material.set_shader_parameter("field_texture", _surface_texture)
	_air_material = ShaderMaterial.new()
	_air_material.shader = AirShader
	_air_material.set_shader_parameter("field_texture", _surface_texture)
	_air_material.set_shader_parameter("batch_texture", _air_texture)
	_rim_material = ShaderMaterial.new()
	_rim_material.shader = RimShader
	_rim_material.set_shader_parameter("field_texture", _surface_texture)
	_rim_material.set_shader_parameter("rim_slots", _rim_texture)

	_surface_instances = MultiMeshInstance2D.new()
	_surface_instances.multimesh = _surface_multimesh
	_surface_instances.material = _surface_material
	_surface_instances.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_surface_instances.z_index = 0
	add_child(_surface_instances)

	_air_instances = MultiMeshInstance2D.new()
	_air_instances.multimesh = _air_multimesh
	_air_instances.material = _air_material
	_air_instances.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_air_instances.z_index = 1
	add_child(_air_instances)

	_rim_instances = MultiMeshInstance2D.new()
	_rim_instances.multimesh = _rim_multimesh
	_rim_instances.material = _rim_material
	_rim_instances.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rim_instances.z_index = 1
	add_child(_rim_instances)

func _make_multimesh(quad: QuadMesh, instance_capacity: int = -1) -> MultiMesh:
	if instance_capacity < 0:
		instance_capacity = capacity
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = quad
	multimesh.instance_count = instance_capacity
	multimesh.custom_aabb = AABB(Vector3(-1000000.0, -1000000.0, -1.0), Vector3(2000000.0, 2000000.0, 2.0))
	multimesh.buffer = _make_identity_buffer(instance_capacity)
	return multimesh

func _make_identity_buffer(instance_count: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(instance_count * IDENTITY_FLOATS_PER_INSTANCE)
	for index in instance_count:
		var offset := index * IDENTITY_FLOATS_PER_INSTANCE
		buffer[offset] = 1.0
		buffer[offset + 5] = 1.0
	return buffer

func _update_surface_texture(solver) -> void:
	var masses: PackedFloat64Array = solver.masses
	var heights: PackedFloat32Array = solver.heights
	var total_mass := 0.0
	for column in FIELD_COLUMNS:
		total_mass += maxf(float(masses[column]), 0.0)
	var running_mass := 0.0
	var core_radius := float(solver.PLAYER_RADIUS) + float(solver.grain_size) * 0.5
	var lookup: PackedFloat32Array = solver.radial_lookup
	for column in FIELD_COLUMNS:
		running_mass += maxf(float(masses[column]), 0.0)
		var cumulative := running_mass / total_mass if total_mass > 0.0 else 0.0
		var surface_radius := maxf(float(heights[column]), core_radius)
		var rim_activity_value = solver.get("rim_activity")
		var rim_activity: PackedFloat32Array = rim_activity_value if rim_activity_value != null else PackedFloat32Array()
		var landing_time := float(rim_activity[column]) if rim_activity.size() == FIELD_COLUMNS else -1000.0
		# Row zero is shared by all field passes: B carries the latest landing.
		_surface_image.set_pixel(column, 0, Color(cumulative, surface_radius, landing_time, 1.0))
		var offset := column * (RADIAL_LOOKUP_SAMPLES + 1)
		for sample in RADIAL_LOOKUP_SAMPLES + 1:
			var radius_squared := float(lookup[offset + sample])
			# Recover each fixed shell's packing from its conserved particle area.
			# This avoids evaluating the pressure curve during renderer uploads.
			var segment := mini(sample, RADIAL_LOOKUP_SAMPLES - 1)
			var inner_squared := float(lookup[offset + segment])
			var outer_squared := float(lookup[offset + segment + 1])
			var shell_area := maxf((outer_squared - inner_squared) * 0.5 * TAU / float(FIELD_COLUMNS), 0.000001)
			var shell_mass := maxf(float(masses[column]) / float(RADIAL_LOOKUP_SAMPLES), 0.0)
			var packing := clampf(shell_mass * float(solver._particle_area) / shell_area, 0.05, 0.995)
			_surface_image.set_pixel(column, sample + 1, Color(radius_squared, packing, 0.0, 1.0))
	_surface_texture.update(_surface_image)

func _update_rim_slots(solver, simulation_time: float) -> int:
	# Slot contents only need refresh at a modest visual cadence.  The shader
	# supplies smooth motion and fading from the timestamp in the field texture.
	var latest_landing_value = solver.get("last_landing_time")
	var latest_landing := float(latest_landing_value) if latest_landing_value != null else -1000.0
	if latest_landing < simulation_time - RIM_LIFETIME:
		if _logical_rim_count > 0:
			_rim_image.fill(Color(-1.0, 0.0, 0.0, 1.0))
			_rim_texture.update(_rim_image)
		return 0
	var rim_activity_value = solver.get("rim_activity")
	var rim_activity: PackedFloat32Array = rim_activity_value if rim_activity_value != null else PackedFloat32Array()
	if rim_activity.size() != FIELD_COLUMNS:
		return 0
	var loose_count := maxi(int(solver.settled_count) - int(solver.compacted_count), 0)
	if loose_count <= 0:
		return 0
	if simulation_time >= _last_rim_slot_update and simulation_time - _last_rim_slot_update < 0.05 and _logical_rim_count > 0:
		return _logical_rim_count
	_last_rim_slot_update = simulation_time
	var slot := 0
	# Three tiny visual grains per recently touched radial column creates a thin
	# cap without pretending that each logical grain has its own simulation.
	for column in FIELD_COLUMNS:
		var age := simulation_time - float(rim_activity[column])
		if age < -0.00001 or age > RIM_LIFETIME:
			continue
		for copy in 3:
			if slot >= MAX_RIM_INSTANCES or slot >= loose_count:
				break
			_rim_image.set_pixel(slot, 0, Color(float(column), 0.0, 0.0, 1.0))
			slot += 1
		if slot >= MAX_RIM_INSTANCES or slot >= loose_count:
			break
	for clear_slot in range(slot, MAX_RIM_INSTANCES):
		_rim_image.set_pixel(clear_slot, 0, Color(-1.0, 0.0, 0.0, 1.0))
	_rim_texture.update(_rim_image)
	return slot


func _update_body_layers(solver) -> void:
	var layers: Array = solver.get_body_layers()
	_body_image.fill(Color(0, 0, 0, 0))
	for index in mini(layers.size(), 4):
		var layer: Dictionary = layers[index]
		var shade: float = [0.65, 0.78, 0.90, 1.0][index]
		_body_image.set_pixel(index, 0, Color(float(layer.inner_radius), float(layer.outer_radius), shade, float(layer.get("pulse", 0.0))))
	_body_texture.update(_body_image)
	_bulk_material.set_shader_parameter("body_layer_count", mini(layers.size(), 4))

func _maximum_stage_packing(material_data: Dictionary) -> float:
	var packings: Vector3 = material_data.get("compaction_stage_packings", Vector3(0.79, 0.87, 0.94))
	return maxf(packings.x, maxf(packings.y, packings.z))

func _update_air_batches(solver) -> void:
	_air_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var total_count := 0
	_air_batch_count = 0
	var batches: Array = solver.batches
	var batch_limit := mini(batches.size(), MAX_BATCHES)
	for batch_index in batch_limit:
		var batch: Dictionary = batches[batch_index]
		var amount := maxi(int(batch.get("amount", 0)), 0)
		if amount > 0:
			total_count += amount
	var cumulative_count := 0
	for batch_index in batch_limit:
		var batch: Dictionary = batches[batch_index]
		var amount := maxi(int(batch.get("amount", 0)), 0)
		if amount == 0 or total_count <= 0:
			continue
		cumulative_count += amount
		var birth := float(batch.get("birth", 0.0))
		var duration := maxf(float(batch.get("duration", 0.0001)), 0.0001)
		var angle := float(batch.get("angle", 0.0))
		var start_radius := float(batch.get("start_radius", 360.0))
		var end_radius := float(batch.get("end_radius", float(solver.PLAYER_RADIUS)))
		var spread := float(batch.get("spread", 0.24))
		var seed := float(batch.get("seed", _air_batch_count + 1))
		var cumulative_fraction := float(cumulative_count) / float(total_count)
		_air_image.set_pixel(_air_batch_count, 0, Color(cumulative_fraction, angle, birth, duration))
		_air_image.set_pixel(_air_batch_count, 1, Color(start_radius, end_radius, spread, seed))
		_air_batch_count += 1
	_air_texture.update(_air_image)
	_batch_grain_count = total_count
