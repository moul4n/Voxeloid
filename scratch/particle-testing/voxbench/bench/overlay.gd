extends CanvasLayer
## Debug HUD. Updated 10× a second so it doesn't distort what it measures. Key H toggles.

var _label: Label
var _accum := 0.0
var _fr := PackedFloat32Array()   # rolling 1 s of frame times for the live p99
var _fi := 0
var runner: Node   # set by stress.gd


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(6, 4)
	_label.add_theme_font_size_override("font_size", 11)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Menlo", "monospace"])
	_label.add_theme_font_override("font", mono)
	_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	_fr.resize(1200)


func _process(dt: float) -> void:
	_fr[_fi] = dt * 1000.0
	_fi = (_fi + 1) % _fr.size()
	_accum += dt
	if _accum < 0.1:
		return
	_accum = 0.0
	var sorted := _fr.duplicate()
	sorted.sort()
	# only the last ~1 s worth is meaningful at high fps; approximate with the whole ring
	var p99 := sorted[int(sorted.size() * 0.99)]
	var fps := Engine.get_frames_per_second()
	var draw := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var git := Metrics.git_hash()
	var rec := "REC" if Metrics.recording else "   "
	var sc: String = runner.status_line() if runner else ""
	_label.text = "%s fps %5d  frame %5.2f ms  p99 %5.2f  proc %5.2f  phys %5.2f  draw %d\nswarm %d/%d (%s)  actors %d  layers %s  %s\n%s  git %s  %s" % [
		rec, fps, dt * 1000.0, p99,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		draw,
		Metrics.live_swarm_now, runner.swarm.capacity if runner else 0, Metrics.swarm_path,
		Metrics.live_actors_now, _mask_str(runner.layer_mask if runner else 0),
		RenderingServer.get_video_adapter_name(),
		sc, git, ("label: " + Metrics.label) if Metrics.label != "" else ""]
	_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5) if git == "nogit" else Color(0.92, 0.94, 1.0))


func _mask_str(m: int) -> String:
	var s := ""
	for b in range(6):
		s += str(b + 1) if (m & (1 << b)) else "."
	return s
