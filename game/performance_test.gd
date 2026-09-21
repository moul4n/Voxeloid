extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const PARTICLE_COUNT := 100000
const WARMUP_FRAMES := 120
const MEASURE_FRAMES := 600

var _root: Node2D
var _main: Node2D
var _mode := "normal"
var _scenario := "settled"
var _particle_count := PARTICLE_COUNT
var _warmup_left := WARMUP_FRAMES
var _frame_times: Array[float] = []
var _warmup_until := 0
var _measured_ms := 0.0
var _manual_physics_samples: Array[float] = []
var _last_frame_usec := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--physics-off"):
		_mode = "physics-off"
	elif args.has("--manual-step"):
		_mode = "manual-step"
	for arg in args:
		if arg.begins_with("--scenario="):
			_scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--grains="):
			_particle_count = clampi(arg.trim_prefix("--grains=").to_int(), 0, 1000000000)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_start")

func _start() -> void:
	_root = MAIN_SCENE.instantiate()
	root.add_child(_root)
	_main = _root
	await process_frame
	_seed_dense_rings()
	# Diagnostic switches isolate the bounded ambient work and backdrop draw.
	_main._sync_ambient_dust()
	if OS.get_cmdline_user_args().has("--without-dust"):
		_main.ambient_dust.reset()
		_main.ambient_dust.config.flux_per_second = 0.0
	if OS.get_cmdline_user_args().has("--without-backdrop"):
		_main.space_backdrop.hide()
	if _mode != "normal":
		_main.set_physics_process(false)
	_last_frame_usec = Time.get_ticks_usec()
	_warmup_until = _last_frame_usec + 1000000
	print("PERF_START mode=%s grains=%d warmup=%d frames=%d" % [_mode, _particle_count, WARMUP_FRAMES, MEASURE_FRAMES])

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last_frame_usec != 0:
		var frame_ms := float(now - _last_frame_usec) / 1000.0
		if _warmup_left > 0 or now < _warmup_until:
			_warmup_left -= 1
		else:
			_frame_times.append(frame_ms)
			_measured_ms += frame_ms
	_last_frame_usec = now
	if _mode == "manual-step":
		var started := Time.get_ticks_usec()
		_main.voxels.step(1.0 / 60.0)
		if _frame_times.size() > 0:
			_manual_physics_samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	if _frame_times.size() >= MEASURE_FRAMES and _measured_ms >= 3000.0:
		_finish()
		return true
	return false

func _seed_dense_rings() -> void:
	var system = _main.voxels
	system.clear()
	if _scenario == "arrival" or _scenario == "flight":
		if _scenario == "flight":
			system.material.gravity_response = 0.01 # Keep all instances airborne for this draw stress test.
		system.spawn_grains(_particle_count, -PI * 0.25)
	elif _scenario == "flow":
		system.seed_uniform(_particle_count / 2)
		system.spawn_grains(_particle_count - system.count, -PI * 0.25)
	else:
		system.seed_uniform(_particle_count)
	# Fit all deposited matter in the view; print zoom with every result.
	var column_count := float(_particle_count) / float(system.COLUMNS)
	var fitted_radius: float = sqrt(system.radius_squared_for_mass(column_count, column_count))
	_main.zoom_level = minf(1.0, 320.0 / fitted_radius)
	if _scenario == "visual-stress":
		_main.grain_renderer.update_field(system, _main.get_viewport_rect().size * 0.5, _main.zoom_level)
		_main.grain_renderer.debug_fill_visual_effects(float(system.time), float(system.grain_size))
func _finish() -> void:
	var draws: Dictionary = _main.grain_renderer.get_draw_counts()
	print("PERF_INSTANCES settled=%d air=%d rim=%d" % [draws.settled, draws.air, int(draws.get("rim", 0))])
	print("PERF_EFFECTS impacts=%d patches=%d" % [int(draws.get("impacts", 0)), int(draws.get("patches", 0))])
	print("PERF_DUST active=%d visible=%d captured=%d" % [_main.ambient_dust.active_count, _main.dust_renderer.drawn_count, _main.dust_deposited])
	if OS.get_cmdline_user_args().has("--capture"):
		root.get_texture().get_image().save_png("res://../scratch/checks/field-%s-%d.png" % [_scenario, _particle_count])
	print("PERF_SCENE scenario=%s zoom=%.3f count=%d deposited=%d incoming=%d" % [_scenario, _main.zoom_level, _main.voxels.count, _main.voxels.settled_count, _main.voxels.count - _main.voxels.settled_count])
	var total_ms := 0.0
	for frame_ms in _frame_times:
		total_ms += frame_ms
	print("PERF_AVERAGE fps=%.1f measured_seconds=%.3f" % [1000.0 * _frame_times.size() / total_ms, total_ms / 1000.0])
	_frame_times.sort()
	var median_frame_ms := _percentile(_frame_times, 0.5)
	var p95_frame_ms := _percentile(_frame_times, 0.95)
	var median_fps := 1000.0 / maxf(median_frame_ms, 0.001)
	var physics_median := 0.0
	var physics_p95 := 0.0
	if _mode == "manual-step":
		_manual_physics_samples.sort()
		physics_median = _percentile(_manual_physics_samples, 0.5)
		physics_p95 = _percentile(_manual_physics_samples, 0.95)
	if _mode != "manual-step":
		print("PERF_RESULT mode=%s grains=%d frames=%d median_fps=%.1f p95_frame_ms=%.3f" % [_mode, _particle_count, _frame_times.size(), median_fps, p95_frame_ms])
	else:
		print("PERF_RESULT mode=%s grains=%d frames=%d median_fps=%.1f p95_frame_ms=%.3f median_physics_ms=%.3f p95_physics_ms=%.3f" % [_mode, _particle_count, _frame_times.size(), median_fps, p95_frame_ms, physics_median, physics_p95])
	quit(0)

func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(int(ceil(fraction * float(sorted_values.size()))) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]
