class_name VoxelSystem
extends RefCounted

const ElementsData := preload("res://core/elements.gd")

const MAX_PARTICLES := 1200
const PLAYER_RADIUS := 42.0
# Hydrogen's diameter in world pixels.
const CELL := 2.0
const COLLISION_RADIUS := PLAYER_RADIUS + CELL * 0.5
const SPAWN_RADIUS := 360.0
const GRAVITY := 135.0
const FIXED_STEP := 1.0 / 60.0
const SUBSTEPS := 2
const SOLVER_ITERATIONS := 4

var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var count := 0
var capacity := MAX_PARTICLES
# Quiet contact count for the HUD. It never freezes a grain.
var settled_count := 0

var material: Dictionary = {}
var grain_size := CELL
var gravity_response := 1.0
var repose_slope := 0.08
var surface_friction := 0.04
var flow_rate := 36.0
var damping := 0.997
var impact_spread := 0.16
var mass := 1.0
var collision_radius := COLLISION_RADIUS

var rng := RandomNumberGenerator.new()
var _accumulator := 0.0
var _contacted := PackedByteArray()
var _predicted_positions := PackedVector2Array()
var _hash: Dictionary = {}
var _neighbour_origins := PackedVector2Array()
var _neighbour_count := -1
var _neighbour_margin := 0.0
var _pairs: Array[Vector2i] = []
const FORWARD_CELLS := [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
var _hash_cell_size := CELL

func _init(material_data: Dictionary = ElementsData.HYDROGEN, particle_capacity: int = MAX_PARTICLES) -> void:
	capacity = clampi(particle_capacity, 1, 10000)
	material = material_data.duplicate()
	grain_size = maxf(float(material.get("grain_size", CELL)), 0.25)
	mass = maxf(float(material.get("mass", 1.0)), 0.01)
	gravity_response = maxf(float(material.get("gravity_response", 1.0)), 0.0)
	repose_slope = maxf(float(material.get("repose_slope", 0.08)), 0.0)
	surface_friction = clampf(float(material.get("surface_friction", 0.04)), 0.0, 1.0)
	flow_rate = maxf(float(material.get("flow_rate", 36.0)), 0.0)
	damping = maxf(float(material.get("damping", 0.997)), 0.0)
	impact_spread = maxf(float(material.get("impact_spread", 0.16)), 0.0)
	collision_radius = PLAYER_RADIUS + grain_size * 0.5
	_hash_cell_size = grain_size * 1.52
	_neighbour_margin = grain_size * 0.25
	_neighbour_origins.resize(capacity)
	positions.resize(capacity)
	velocities.resize(capacity)
	_contacted.resize(capacity)
	_predicted_positions.resize(capacity)
	rng.seed = 914702

func spawn_hydrogen(amount: int = 1, source_angle: float = NAN) -> void:
	spawn_grains(amount, source_angle)

func spawn_grains(amount: int = 1, source_angle: float = NAN) -> void:
	var spawn_count := mini(maxi(amount, 0), capacity - count)
	if spawn_count == 0:
		return
	var start_angle := source_angle if is_finite(source_angle) else rng.randf_range(0.0, TAU)
	for offset in spawn_count:
		var angle := start_angle
		if is_finite(source_angle):
			angle += rng.randf_range(-0.12, 0.12)
		else:
			angle += TAU * float(offset) / float(spawn_count) + rng.randf_range(-0.09, 0.09)
		var radial := Vector2.RIGHT.rotated(angle)
		positions[count] = radial * SPAWN_RADIUS
		velocities[count] = -radial * rng.randf_range(48.0, 78.0) + radial.orthogonal() * rng.randf_range(-62.0, 62.0)
		count += 1

func step(delta: float) -> void:
	_accumulator += minf(maxf(delta, 0.0), 0.25)
	while _accumulator + 0.000001 >= FIXED_STEP:
		_simulate_fixed()
		_accumulator -= FIXED_STEP
	if _accumulator < 0.0:
		_accumulator = 0.0

func _simulate_fixed() -> void:
	var delta := FIXED_STEP / float(SUBSTEPS)
	_contacted.fill(0)
	for _substep in SUBSTEPS:
		_integrate(delta)
		for _iteration in SOLVER_ITERATIONS:
			_solve_core_positions()
			_ensure_neighbours()
			_solve_pair_positions()
		_solve_core_positions()
		_ensure_neighbours()
		_apply_position_correction_velocity(delta)
		_resolve_pair_velocities()
		_resolve_core_velocities()
	_update_quiet_contact_count()

func _integrate(delta: float) -> void:
	var air_drag := exp(-damping * delta)
	for index in count:
		var position := positions[index]
		var radius_sq := position.length_squared()
		var normal := position / sqrt(radius_sq) if radius_sq > 0.000001 else Vector2.RIGHT
		var velocity := velocities[index]
		velocity += -normal * GRAVITY * gravity_response * delta
		velocity *= air_drag
		velocities[index] = velocity
		positions[index] = position + velocity * delta
		_predicted_positions[index] = positions[index]

func _apply_position_correction_velocity(delta: float) -> void:
	# Carry projection corrections into the next substep. Without this, a dense
	# bed repeatedly integrates back into the same overlaps after every solve.
	for index in count:
		var correction_velocity := (positions[index] - _predicted_positions[index]) / delta
		velocities[index] = (velocities[index] + correction_velocity).limit_length(360.0)

func _solve_core_positions() -> void:
	var minimum_radius_sq := collision_radius * collision_radius
	for index in count:
		var position := positions[index]
		var radius_sq := position.length_squared()
		if radius_sq >= minimum_radius_sq:
			continue
		var normal := position / sqrt(radius_sq) if radius_sq > 0.000001 else _fallback_normal(index, index + 17)
		positions[index] = normal * collision_radius
		_contacted[index] = 1

func _ensure_neighbours() -> void:
	# A buffered neighbour list stays complete while each grain moves at most
	# half the buffer. This grid only finds contacts; positions remain continuous.
	if _neighbour_count == count:
		var limit_sq := _neighbour_margin * _neighbour_margin
		var valid := true
		for index in count:
			if positions[index].distance_squared_to(_neighbour_origins[index]) > limit_sq:
				valid = false
				break
		if valid:
			return
	_rebuild_spatial_hash()

func _rebuild_spatial_hash() -> void:
	_neighbour_count = count
	for index in count:
		_neighbour_origins[index] = positions[index]
	_hash.clear()
	for index in count:
		var cell := _cell_for(positions[index])
		if _hash.has(cell):
			_hash[cell].append(index)
		else:
			_hash[cell] = [index]
	# Each neighbouring cell pair is visited once. The lookup grid finds neighbours;
	# it never changes a particle's position or gives it a reserved resting place.
	_pairs.clear()
	for cell_variant in _hash:
		var cell: Vector2i = cell_variant
		var bucket: Array = _hash[cell]
		for first in bucket.size():
			for second in range(first + 1, bucket.size()):
				_add_neighbour(bucket[first], bucket[second])
		for offset in FORWARD_CELLS:
			var neighbour_key: Vector2i = cell + offset
			if not _hash.has(neighbour_key):
				continue
			var neighbours: Array = _hash[neighbour_key]
			for first in bucket:
				for second in neighbours:
					_add_neighbour(first, second)

func _add_neighbour(first: int, second: int) -> void:
	if positions[first].distance_squared_to(positions[second]) <= _hash_cell_size * _hash_cell_size:
		_pairs.append(Vector2i(first, second))

func _solve_pair_positions() -> void:
	var minimum_distance_sq := grain_size * grain_size
	for pair in _pairs:
		var index := pair.x
		var other := pair.y
		var difference := positions[other] - positions[index]
		var distance_sq := difference.length_squared()
		if distance_sq >= minimum_distance_sq:
			continue
		var distance := sqrt(distance_sq)
		var normal := _contact_normal(index, other, difference, distance)
		var correction := (grain_size - distance) * 0.5
		positions[index] -= normal * correction
		positions[other] += normal * correction
		_contacted[index] = 1
		_contacted[other] = 1

func _resolve_pair_velocities() -> void:
	var contact_distance := grain_size * 1.015
	var contact_distance_sq := contact_distance * contact_distance
	# Tangential friction occurs once per substep, not once per solver pass.
	var mobility := clampf(flow_rate / 1800.0, 0.0, 1.0)
	var friction := clampf((surface_friction + repose_slope * 0.06) * (1.15 - mobility * 0.55), 0.0, 1.0)
	var restitution := clampf(0.015 + impact_spread * mass * 0.045, 0.0, 0.32)
	for pair in _pairs:
		var index := pair.x
		var other := pair.y
		var difference := positions[other] - positions[index]
		var distance_sq := difference.length_squared()
		if distance_sq > contact_distance_sq:
			continue
		var distance := sqrt(distance_sq)
		var normal := _contact_normal(index, other, difference, distance)
		var relative := velocities[other] - velocities[index]
		var normal_speed := relative.dot(normal)
		if normal_speed < 0.0:
			var normal_impulse := -normal_speed * (1.0 + restitution) * 0.5
			velocities[index] -= normal * normal_impulse
			velocities[other] += normal * normal_impulse
		var tangent := normal.orthogonal()
		var tangent_speed := (velocities[other] - velocities[index]).dot(tangent)
		var tangent_impulse := tangent_speed * friction * 0.5
		velocities[index] += tangent * tangent_impulse
		velocities[other] -= tangent * tangent_impulse
		_contacted[index] = 1
		_contacted[other] = 1

func _resolve_core_velocities() -> void:
	# Repose is rolling resistance. Contact grains remain movable at every speed.
	var mobility := clampf(flow_rate / 1800.0, 0.0, 1.0)
	var rolling_resistance := clampf(surface_friction * 0.65 + repose_slope * 0.18 + (1.0 - mobility) * 0.08, 0.0, 0.9)
	var contact_distance_sq := (collision_radius + 0.03) * (collision_radius + 0.03)
	for index in count:
		var position := positions[index]
		var radius_sq := position.length_squared()
		if radius_sq > contact_distance_sq:
			continue
		var normal := position / sqrt(radius_sq) if radius_sq > 0.000001 else Vector2.RIGHT
		var velocity := velocities[index]
		# The core is an inelastic support. Projection must not create an outward
		# launch velocity when a test or a fast grain starts inside it.
		velocity -= normal * velocity.dot(normal)
		var tangent := normal.orthogonal()
		velocity = normal * velocity.dot(normal) + tangent * velocity.dot(tangent) * (1.0 - rolling_resistance)
		velocities[index] = velocity
		_contacted[index] = 1

func _update_quiet_contact_count() -> void:
	settled_count = 0
	for index in count:
		if _contacted[index] != 0 and velocities[index].length_squared() <= 14.0 * 14.0:
			settled_count += 1

func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _hash_cell_size), floori(position.y / _hash_cell_size))

func _cell_key(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

func _contact_normal(first: int, second: int, difference: Vector2, distance: float) -> Vector2:
	if distance > 0.000001:
		return difference / distance
	# A head-on high-speed pair can land at exactly the same point in one
	# substep. Its incoming relative velocity preserves the physical side.
	var relative := velocities[second] - velocities[first]
	if relative.length_squared() > 0.000001:
		return -relative.normalized()
	return _fallback_normal(first, second)

func _fallback_normal(first: int, second: int) -> Vector2:
	var phase := float((first * 73856093 + second * 19349663) & 1023) * TAU / 1024.0
	return Vector2(cos(phase), sin(phase))

func clear() -> void:
	count = 0
	_neighbour_count = -1
	_pairs.clear()
	settled_count = 0
	_accumulator = 0.0
	_contacted.fill(0)
	_hash.clear()
	rng.seed = 914702
