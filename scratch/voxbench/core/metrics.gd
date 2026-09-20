extends Node
## Autoload "Metrics".
## Preallocated ring buffer of per-frame timings. Never allocates while recording.
## On stop(): writes user://bench/<date>_<time>_<scenario>_<git>/summary.json + frames.csv
## and returns the summary dictionary. See docs/phase0-build-plan.html § Metrics recorder.

const CAP := 12000            # 10 s at up to 1200 fps
const SCHEMA := 1

var recording := false
var meta := {}                # filled by the scenario runner before start()
var label := ""               # free-text run label (key L)
var live_swarm_now := 0       # set by the swarm each frame
var live_actors_now := 0      # set by the actor pool each frame
var swarm_path := "gpu"       # "gpu" | "cpu", set by swarm

var _frame := PackedFloat32Array()
var _proc := PackedFloat32Array()
var _phys := PackedFloat32Array()
var _t := PackedFloat32Array()
var _live := PackedInt32Array()
var _n := 0
var _t0_usec := 0
var _draw_samples := PackedInt32Array()
var _prim_samples := PackedInt32Array()
var _sample_accum := 0.0
var _git := ""


func _ready() -> void:
	_frame.resize(CAP); _proc.resize(CAP); _phys.resize(CAP); _t.resize(CAP); _live.resize(CAP)
	_git = _git_hash()
	process_priority = 1000   # run after everything else so live counts are settled


func git_hash() -> String:
	return _git


func start(scenario: String, extra: Dictionary = {}) -> void:
	_n = 0
	_draw_samples = PackedInt32Array()
	_prim_samples = PackedInt32Array()
	_sample_accum = 0.0
	_t0_usec = Time.get_ticks_usec()
	meta = extra.duplicate(true)
	meta["schema"] = SCHEMA
	meta["scenario"] = scenario
	meta["label"] = label
	meta["git"] = _git
	meta["godot"] = Engine.get_version_info().get("string", "?")
	meta["renderer"] = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	meta["gpu"] = RenderingServer.get_video_adapter_name()
	meta["cpu"] = OS.get_processor_name()
	meta["resolution"] = [960, 540]
	var win := get_viewport().get_window()
	meta["window"] = [win.size.x, win.size.y]
	meta["vsync"] = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	meta["swarm_path"] = swarm_path
	meta["date"] = Time.get_datetime_string_from_system(false, true)
	recording = true


func _process(dt: float) -> void:
	if not recording or _n >= CAP:
		return
	var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_frame[_n] = dt * 1000.0
	_proc[_n] = p
	_phys[_n] = ph
	_t[_n] = float(Time.get_ticks_usec() - _t0_usec) / 1000.0
	_live[_n] = live_swarm_now
	_n += 1
	_sample_accum += dt
	if _sample_accum >= 1.0:
		_sample_accum = 0.0
		_draw_samples.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		_prim_samples.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))


func stop() -> Dictionary:
	recording = false
	var warm: float = float(meta.get("warmup_s", 3.0))
	var skip := 0
	while skip < _n and _t[skip] < warm * 1000.0:
		skip += 1
	var out := meta.duplicate(true)
	var pass_ms: float = float(meta.get("pass_p99_ms", 3.33))
	var fs := _stats(_frame, skip)
	out["frames"] = _n - skip
	out["capture_s"] = (_t[_n - 1] - _t[skip]) / 1000.0 if _n > skip + 1 else 0.0
	out["frame_ms"] = fs
	out["process_ms"] = _stats(_proc, skip)
	out["physics_ms"] = _stats(_phys, skip)
	out["draw_calls"] = _istats(_draw_samples)
	out["primitives"] = _istats(_prim_samples)
	out["live_swarm"] = _istats(_live.slice(skip, _n))
	out["live_actors"] = live_actors_now
	out["pass"] = fs.get("p99", 1e9) <= pass_ms
	out["pass_rule"] = "p99_frame_ms <= %.2f" % pass_ms
	out["run_id"] = _run_id(str(meta.get("scenario", "free")))
	_write(out, skip)
	return out


func _stats(a: PackedFloat32Array, skip: int) -> Dictionary:
	var n := _n - skip
	if n <= 0:
		return {"avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "low1pct_fps": 0.0}
	var v := a.slice(skip, _n)
	v.sort()
	var sum := 0.0
	for x in v:
		sum += x
	var lo_start := int(n * 0.99)
	var lsum := 0.0
	var lcount := 0
	for i in range(lo_start, n):
		lsum += v[i]; lcount += 1
	var lavg: float = (lsum / lcount) if lcount > 0 else v[n - 1]
	return {
		"avg": snappedf(sum / n, 0.001),
		"p50": snappedf(v[n / 2], 0.001),
		"p95": snappedf(v[mini(n - 1, int(n * 0.95))], 0.001),
		"p99": snappedf(v[mini(n - 1, int(n * 0.99))], 0.001),
		"max": snappedf(v[n - 1], 0.001),
		"low1pct_fps": snappedf(1000.0 / maxf(lavg, 0.0001), 0.1),
	}


func _istats(a: PackedInt32Array) -> Dictionary:
	if a.size() == 0:
		return {"avg": 0, "max": 0}
	var s := 0
	var m := 0
	for x in a:
		s += x; m = maxi(m, x)
	return {"avg": int(float(s) / a.size()), "max": m}


func _run_id(scenario: String) -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d%02d_%s_%s" % [d.year, d.month, d.day, d.hour, d.minute, scenario, _git]


func _write(out: Dictionary, skip: int) -> void:
	var dir := "user://bench/%s" % out["run_id"]
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "/summary.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	var c := FileAccess.open(dir + "/frames.csv", FileAccess.WRITE)
	if c:
		c.store_line("frame,t_ms,frame_ms,process_ms,physics_ms,live_swarm")
		for i in range(_n):
			c.store_line("%d,%.2f,%.3f,%.3f,%.3f,%d" % [i - skip, _t[i], _frame[i], _proc[i], _phys[i], _live[i]])
		c.close()
	print("[metrics] wrote ", ProjectSettings.globalize_path(dir))
	print("[metrics] %s p50 %.2f  p95 %.2f  p99 %.2f  max %.2f  1%%low %.0f fps  pass=%s" % [
		out["scenario"], out["frame_ms"]["p50"], out["frame_ms"]["p95"], out["frame_ms"]["p99"],
		out["frame_ms"]["max"], out["frame_ms"]["low1pct_fps"], str(out["pass"])])


func _git_hash() -> String:
	# Reads .git/HEAD next to project.godot. Returns "nogit" if not a repo; overlay shows it red.
	var head := FileAccess.open("res://.git/HEAD", FileAccess.READ)
	if head == null:
		return "nogit"
	var line := head.get_line().strip_edges()
	head.close()
	if line.begins_with("ref: "):
		var ref := line.substr(5)
		var rf := FileAccess.open("res://.git/" + ref, FileAccess.READ)
		if rf:
			var h := rf.get_line().strip_edges()
			rf.close()
			return h.substr(0, 7)
		# packed refs
		var pr := FileAccess.open("res://.git/packed-refs", FileAccess.READ)
		if pr:
			while not pr.eof_reached():
				var l := pr.get_line()
				if l.ends_with(" " + ref):
					pr.close()
					return l.substr(0, 7)
			pr.close()
		return "nogit"
	return line.substr(0, 7)


func open_bench_folder() -> void:
	DirAccess.make_dir_recursive_absolute("user://bench")
	OS.shell_open(ProjectSettings.globalize_path("user://bench"))
