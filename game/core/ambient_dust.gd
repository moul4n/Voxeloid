extends RefCounted

const POOL_CAPACITY := 768
const FIXED_STEP := 1.0 / 60.0
const DEFAULT_BOUNDS := Rect2(-4000.0, -4000.0, 8000.0, 8000.0)

var config: Dictionary = {
	"flux_per_second": 24.0,
	"base_direction": Vector2(0.96, 0.28),
	"minimum_speed": 90.0,
	"maximum_speed": 180.0,
	"gravity_strength": 200.0,
	"gravity_softening": 48.0,
	"gravity_multiplier": 1.0,
	"capture_multiplier": 1.0,
	"source_flux_multiplier": 1.0,
	"stellar_output": 0.0,
	"capture_mass_scale": 1000.0,
	"maximum_gravity_acceleration": 1200.0,
	"lifetime_seconds": 90.0,
}

var bounds: Rect2 = DEFAULT_BOUNDS
var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var ages := PackedFloat32Array()
var lifetimes := PackedFloat32Array()
var capture_attempted := PackedByteArray()
var active_count := 0
var escaped_count := 0
var captured_count := 0

var _rng := RandomNumberGenerator.new()
var _seed := 734921
var _spawn_accumulator := 0.0
var _step_accumulator := 0.0

func _init(options: Dictionary = {}, random_seed: int = 734921) -> void:
	for key: Variant in options:
		config[key] = options[key]
	positions.resize(POOL_CAPACITY)
	velocities.resize(POOL_CAPACITY)
	ages.resize(POOL_CAPACITY)
	lifetimes.resize(POOL_CAPACITY)
	capture_attempted.resize(POOL_CAPACITY)
	_seed = random_seed
	_rng.seed = _seed

func set_bounds(new_bounds: Rect2) -> void:
	# Bounds are a level-space property. Camera movement never changes this pool.
	bounds = new_bounds.abs()

func reset() -> void:
	active_count = 0
	escaped_count = 0
	captured_count = 0
	_spawn_accumulator = 0.0
	_step_accumulator = 0.0
	_rng.seed = _seed

func prime(requested_count: int = 384) -> void:
	# Seed a level with already-present flybys so the opening view is populated.
	# These motes are ordinary pool members and award nothing until captured.
	var direction: Vector2 = config["base_direction"]
	if direction.length_squared() < 0.000001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	var count_to_add := mini(maxi(requested_count, 0), POOL_CAPACITY - active_count)
	var end := bounds.position + bounds.size
	for _index in count_to_add:
		var position := Vector2(_rng.randf_range(bounds.position.x, end.x), _rng.randf_range(bounds.position.y, end.y))
		_add_mote(position, direction * _random_speed(), 0.0)

func step(delta: float, body_mass: float, surface_radius: float, height_sampler: Callable = Callable()) -> Array[Dictionary]:
	var captures: Array[Dictionary] = []
	_step_accumulator += maxf(delta, 0.0)
	while _step_accumulator + 0.0000001 >= FIXED_STEP:
		_step_accumulator -= FIXED_STEP
		_simulate(FIXED_STEP, maxf(body_mass, 0.0), maxf(surface_radius, 0.0), height_sampler, captures)
	return captures

func _simulate(delta: float, body_mass: float, surface_radius: float, height_sampler: Callable, captures: Array[Dictionary]) -> void:
	_spawn_accumulator += _flux_rate() * delta
	while _spawn_accumulator >= 1.0 and active_count < POOL_CAPACITY:
		_spawn_accumulator -= 1.0
		_spawn_mote()
	if active_count >= POOL_CAPACITY:
		_spawn_accumulator = minf(_spawn_accumulator, 0.999)

	var index := 0
	while index < active_count:
		var start: Vector2 = positions[index]
		var velocity: Vector2 = velocities[index]
		var age: float = float(ages[index]) + delta
		var acceleration := _gravity_at(start, body_mass)
		velocity += acceleration * delta
		var finish := start + velocity * delta
		var collision_radius := surface_radius
		var hit_t := _segment_circle_entry(start, finish, collision_radius) if body_mass > 0.0 else -1.0
		# Distant flybys need no angular field lookup or callable dispatch.
		if hit_t >= 0.0 and height_sampler.is_valid():
			var segment := finish - start
			var segment_length_sq := maxf(segment.length_squared(), 0.000001)
			var closest_t := clampf(-start.dot(segment) / segment_length_sq, 0.0, 1.0)
			var closest_point := start + segment * closest_t
			collision_radius = maxf(float(height_sampler.call(closest_point.angle())), 0.0)
			hit_t = _segment_circle_entry(start, finish, collision_radius)
		if hit_t >= 0.0:
			if capture_attempted[index] == 0:
				capture_attempted[index] = 1
				if _rng.randf() < _capture_probability(body_mass):
					var hit_position := start.lerp(finish, hit_t)
					captures.append({"amount": 1, "angle": hit_position.angle()})
					captured_count += 1
					_remove_mote(index)
					continue
		else:
			capture_attempted[index] = 0
		if age >= float(lifetimes[index]) or not bounds.has_point(finish):
			escaped_count += 1
			_remove_mote(index)
			continue
		positions[index] = finish
		velocities[index] = velocity
		ages[index] = age
		index += 1

func _flux_rate() -> float:
	var source_scale := maxf(float(config["source_flux_multiplier"]), 0.0)
	var stellar_scale := 1.0 + maxf(float(config["stellar_output"]), 0.0)
	return maxf(float(config["flux_per_second"]), 0.0) * source_scale * stellar_scale

func _spawn_mote() -> void:
	var direction: Vector2 = config["base_direction"]
	if direction.length_squared() < 0.000001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var lateral_min := INF
	var lateral_max := -INF
	for corner: Vector2 in _bounds_corners():
		var projection := corner.dot(perpendicular)
		lateral_min = minf(lateral_min, projection)
		lateral_max = maxf(lateral_max, projection)
	var lateral := _rng.randf_range(lateral_min, lateral_max)
	var interval := _line_bounds_interval(direction, perpendicular, lateral)
	var position := direction * interval.x + perpendicular * lateral
	_add_mote(position, direction * _random_speed(), 0.0)

func _random_speed() -> float:
	var minimum_speed := maxf(float(config["minimum_speed"]), 0.0)
	var maximum_speed := maxf(float(config["maximum_speed"]), minimum_speed)
	return _rng.randf_range(minimum_speed, maximum_speed)

func _add_mote(position: Vector2, velocity: Vector2, age: float) -> void:
	if active_count >= POOL_CAPACITY:
		return
	positions[active_count] = position
	velocities[active_count] = velocity
	ages[active_count] = age
	lifetimes[active_count] = maxf(float(config["lifetime_seconds"]), FIXED_STEP)
	capture_attempted[active_count] = 0
	active_count += 1

func _bounds_corners() -> Array[Vector2]:
	var end := bounds.position + bounds.size
	return [bounds.position, Vector2(end.x, bounds.position.y), end, Vector2(bounds.position.x, end.y)]

func _line_bounds_interval(direction: Vector2, perpendicular: Vector2, lateral: float) -> Vector2:
	var low := -INF
	var high := INF
	var end := bounds.position + bounds.size
	var axes: Array[Vector3] = [
		Vector3(direction.x, perpendicular.x, 0.0),
		Vector3(direction.y, perpendicular.y, 1.0),
	]
	for axis: Vector3 in axes:
		var travel := axis.x
		var offset := axis.y * lateral
		var minimum := bounds.position.x if axis.z == 0.0 else bounds.position.y
		var maximum := end.x if axis.z == 0.0 else end.y
		if absf(travel) < 0.000001:
			continue
		var first := (minimum - offset) / travel
		var second := (maximum - offset) / travel
		low = maxf(low, minf(first, second))
		high = minf(high, maxf(first, second))
	return Vector2(low, high)

func _gravity_at(position: Vector2, body_mass: float) -> Vector2:
	if body_mass <= 0.0:
		return Vector2.ZERO
	var radius_sq := position.length_squared()
	if radius_sq < 0.000001:
		return Vector2.ZERO
	var softening := maxf(float(config["gravity_softening"]), 0.001)
	var scale := float(config["gravity_strength"]) * body_mass * maxf(float(config["gravity_multiplier"]), 0.0)
	var acceleration := scale / (radius_sq + softening * softening)
	acceleration = minf(acceleration, maxf(float(config["maximum_gravity_acceleration"]), 0.0))
	return -position.normalized() * acceleration

func _capture_probability(body_mass: float) -> float:
	if body_mass <= 0.0:
		return 0.0
	var mass_scale := maxf(float(config["capture_mass_scale"]), 0.001)
	var mass_factor := body_mass / (body_mass + mass_scale)
	return clampf(mass_factor * maxf(float(config["capture_multiplier"]), 0.0), 0.0, 1.0)

func _segment_circle_entry(start: Vector2, finish: Vector2, radius: float) -> float:
	if radius <= 0.0:
		return -1.0
	var delta := finish - start
	var a := delta.length_squared()
	if a < 0.000001:
		return 0.0 if start.length_squared() <= radius * radius else -1.0
	var c := start.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var b := 2.0 * start.dot(delta)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var t := (-b - sqrt(discriminant)) / (2.0 * a)
	return t if t >= 0.0 and t <= 1.0 else -1.0

func _remove_mote(index: int) -> void:
	var last := active_count - 1
	if index != last:
		positions[index] = positions[last]
		velocities[index] = velocities[last]
		ages[index] = ages[last]
		lifetimes[index] = lifetimes[last]
		capture_attempted[index] = capture_attempted[last]
	active_count -= 1
