class_name Swarm
extends MultiMeshInstance2D
## The swarm tier: one draw call, N instances, motion integrated in the vertex shader.
## CPU only writes a slot on spawn (GPU path). The CPU path integrates in GDScript so the
## two can be compared; key G switches. See docs/phase0-build-plan.html § Swarm renderer.

const MAX_INSTANCES := 60000
const FLOATS_PER_INSTANCE := 16   # 2D transform 8 + color 4 + custom 4

var capacity := 20000
var gpu_path := true
var live := 0

var _mm: MultiMesh
var _mat: ShaderMaterial
var _free: PackedInt32Array          # free-list of slots
var _die_at: PackedFloat32Array      # per-slot death time (seconds), for slot recycling
var _t0 := 0.0
# CPU-path state
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _alive := PackedByteArray()
var _spawned_this_frame := 0
var _tex: Texture2D
var _scan_cursor := 0


func _ready() -> void:
	_t0 = Time.get_ticks_msec() / 1000.0
	# Baked atlas from art/bake/bake.py if present, else the procedural stand-in.
	if ResourceLoader.exists("res://art/atlas/debris.png"):
		_tex = load("res://art/atlas/debris.png")
	else:
		_tex = Atlas.debris_atlas(SeededRng.rng)
	texture = _tex
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://render/swarm.gdshader")
	_mat.set_shader_parameter("atlas_grid", float(Atlas.GRID))
	_mat.set_shader_parameter("quad_size", float(Atlas.FRAME))
	_mat.set_shader_parameter("floor_y", 520.0 - global_position.y)
	material = _mat
	_build(capacity)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0


func _build(n: int) -> void:
	capacity = mini(n, MAX_INSTANCES)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _make_quad(float(Atlas.FRAME))
	_mm.instance_count = capacity
	multimesh = _mm
	_free.resize(capacity)
	_die_at.resize(capacity)
	_pos.resize(capacity); _vel.resize(capacity); _alive.resize(capacity)
	for i in range(capacity):
		_free[capacity - 1 - i] = i          # pop from the end → low slots first
		_die_at[i] = -1.0
		_alive[i] = 0
		_mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(1.0e6, 1.0e6)))
		_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	live = 0
	_scan_cursor = 0
	_mat.set_shader_parameter("gpu_path", gpu_path)


## Explicit quad so the shader can rely on local = (UV - 0.5) * size, y down.
static func _make_quad(size: float) -> ArrayMesh:
	var h := size * 0.5
	var verts := PackedVector3Array([
		Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func set_capacity(n: int) -> void:
	if n != capacity:
		_build(n)


func set_layer_mask(mask: int) -> void:
	_mat.set_shader_parameter("layer_mask", mask)


func set_gpu_path(on: bool) -> void:
	gpu_path = on
	clear()
	_mat.set_shader_parameter("gpu_path", on)
	Metrics.swarm_path = "gpu" if on else "cpu"


func clear() -> void:
	_build(capacity)


static func pack(frame: int, life_s: float, seed01: float) -> float:
	# frame 0..63 | life tenths 0..255 | seed 0..255  → fits exactly in a float32 mantissa (24 bits)
	var life_t := clampi(int(round(life_s * 10.0)), 1, 255)
	var seed_i := clampi(int(seed01 * 255.0), 0, 255)
	return float(frame + life_t * 64 + seed_i * 16384)


## Spawn `n` instances around `origin`. Returns how many were actually spawned (free slots).
func spawn(n: int, origin: Vector2, speed: float = 350.0, life_s: float = 4.0, tint: Color = Color.WHITE) -> int:
	var t := now()
	var rng := SeededRng.rng
	var count := 0
	for i in range(n):
		var slot := _take_slot(t)
		if slot < 0:
			break
		var ang := rng.randf() * TAU
		var sp := speed * rng.randf_range(0.4, 1.0)
		var vx := cos(ang) * sp
		var vy := sin(ang) * sp - speed * 0.6         # bias upward so it fountains
		var life := life_s * rng.randf_range(0.6, 1.0)
		var frame := rng.randi_range(0, Atlas.GRID * Atlas.GRID - 1)
		_die_at[slot] = t + life
		if gpu_path:
			_mm.set_instance_transform_2d(slot, Transform2D(0.0, origin))
			_mm.set_instance_custom_data(slot, Color(t, vx, vy, pack(frame, life, rng.randf())))
		else:
			_pos[slot] = origin
			_vel[slot] = Vector2(vx, vy)
			_alive[slot] = 1
			_mm.set_instance_custom_data(slot, Color(t, 0.0, 0.0, pack(frame, life, rng.randf())))
		_mm.set_instance_color(slot, tint)
		count += 1
	live += count
	_spawned_this_frame += count
	return count


func _take_slot(t: float) -> int:
	if _free.size() > 0:
		var s := _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
		return s
	return -1


func _process(dt: float) -> void:
	var t := now()
	_mat.set_shader_parameter("now", t)
	# recycle dead slots (cheap scan; amortised by only scanning a window per frame)
	var scanned := 0
	var i := _scan_cursor
	while scanned < 2048 and capacity > 0:
		var d := _die_at[i]
		if d >= 0.0 and d <= t:
			_die_at[i] = -1.0
			_alive[i] = 0
			_free.append(i)
			live -= 1
		i = (i + 1) % capacity
		scanned += 1
	_scan_cursor = i

	if not gpu_path:
		_cpu_integrate(dt)

	Metrics.live_swarm_now = live
	_spawned_this_frame = 0



func _cpu_integrate(dt: float) -> void:
	# The deliberately slow path: GDScript loop over every live slot each frame.
	var g := 900.0
	var floor_y := 520.0 - global_position.y
	for s in range(capacity):
		if _alive[s] == 0:
			continue
		var v := _vel[s]
		v.y += g * dt
		var p := _pos[s] + v * dt
		if p.y > floor_y:
			p.y = floor_y - (p.y - floor_y) * 0.35
			v.y = -v.y * 0.35
		_pos[s] = p
		_vel[s] = v
		_mm.set_instance_transform_2d(s, Transform2D(0.0, p))
