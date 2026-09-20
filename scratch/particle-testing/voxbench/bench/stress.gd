extends Node2D
## Scenario runner + key bindings for the phase 0 stress bed.
## Reads bench/scenarios.json. F5 runs the suite, F6 the current scenario, F7 free-record.
## Command line (after ++):  --bench=late  --suite  --seed=7  --label=name  --quit  --gpu=0
## e.g.  godot --path . ++ --suite --label=first-pass --quit

@onready var swarm: Swarm = $Swarm
@onready var actors: Actors = $Actors
@onready var rig: Rig = $Rig
@onready var emit: GPUParticles2D = $Emit
@onready var overlay: CanvasLayer = $Overlay

var cfg: Dictionary = {}
var scenario_names: Array = []
var current := 0
var layer_mask := 0

enum Phase { IDLE, WARMUP, CAPTURE, COOLDOWN }
var phase := Phase.IDLE
var phase_t := 0.0
var queue: Array = []          # scenario names still to run
var running_name := ""
var running: Dictionary = {}
var quit_after := false
var _spawn_accum := 0.0
var _spike_t := 0.0
var _label_entry := false
var _label_buf := ""


func _ready() -> void:
	overlay.runner = self
	var f := FileAccess.open("res://bench/scenarios.json", FileAccess.READ)
	cfg = JSON.parse_string(f.get_as_text())
	f.close()
	scenario_names = cfg["scenarios"].keys()
	rig.position = Vector2(480, 470)
	rig.swung.connect(_on_swing)
	swarm.position = Vector2(480, 460)
	emit.position = Vector2(480, 460)
	emit.emitting = false
	get_window().title = "voxbench  git %s" % Metrics.git_hash()
	_parse_cmdline()


func _parse_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var one := ""
	for a in args:
		if a.begins_with("--bench="):
			one = a.substr(8)
		elif a == "--suite":
			queue = cfg["suite"].duplicate()
		elif a.begins_with("--label="):
			Metrics.label = a.substr(8)
		elif a == "--quit":
			quit_after = true
		elif a == "--gpu=0":
			swarm.set_gpu_path(false)
	if one != "":
		queue = [one]
	if queue.size() > 0:
		call_deferred("_next_in_queue")


# --------------------------------------------------------------- scenario flow

func run_suite() -> void:
	queue = cfg["suite"].duplicate()
	_next_in_queue()


func run_one(name: String) -> void:
	queue = [name]
	_next_in_queue()


func _next_in_queue() -> void:
	if queue.is_empty():
		phase = Phase.IDLE
		if quit_after:
			get_tree().quit()
		return
	running_name = queue.pop_front()
	running = cfg["scenarios"][running_name]
	_apply_scenario(running)
	phase = Phase.WARMUP
	phase_t = 0.0
	_spike_t = 0.0
	print("[bench] %s: warm-up" % running_name)


func _apply_scenario(s: Dictionary) -> void:
	swarm.set_capacity(int(s.get("capacity", 20000)))
	swarm.clear()
	actors.clear()
	actors.spawn(int(s.get("actors", 0)))
	set_layer_mask(int(s.get("layers", 0)))
	if not s.get("spike", false):
		swarm.spawn(int(s.get("swarm", 0)), Vector2.ZERO)


func _process(dt: float) -> void:
	if phase == Phase.IDLE:
		return
	phase_t += dt
	_top_up(dt)
	match phase:
		Phase.WARMUP:
			if phase_t >= float(cfg.get("warmup_s", 3.0)):
				phase = Phase.CAPTURE
				phase_t = 0.0
				Metrics.start(running_name, {
					"warmup_s": 0.0, "pass_p99_ms": float(running.get("pass_p99_ms", 3.33)),
					"layers": layer_mask, "swarm_max": int(running.get("swarm", 0)),
					"actors": actors.live, "seed": SeededRng.seed_value,
				})
				print("[bench] %s: capture" % running_name)
		Phase.CAPTURE:
			if phase_t >= float(cfg.get("capture_s", 10.0)):
				Metrics.stop()
				phase = Phase.COOLDOWN
				phase_t = 0.0
		Phase.COOLDOWN:
			if phase_t >= float(cfg.get("cooldown_s", 1.0)):
				_next_in_queue()


func _top_up(dt: float) -> void:
	# keep the swarm at the scenario's target density; spike mode bursts instead
	if running.is_empty():
		return
	if running.get("spike", false):
		_spike_t += dt
		if _spike_t >= float(running.get("spike_every_s", 2.5)):
			_spike_t = 0.0
			swarm.clear()
			swarm.spawn(int(running.get("swarm", 10000)), Vector2.ZERO)
		return
	var target := int(running.get("swarm", 0))
	var rate := float(running.get("spawn_rate", 0))
	if swarm.live < target and rate > 0.0:
		_spawn_accum += rate * dt
		var n := int(_spawn_accum)
		if n > 0:
			_spawn_accum -= n
			swarm.spawn(mini(n, target - swarm.live), Vector2.ZERO)


func _on_swing() -> void:
	# the rig's tool hit: a small burst so idle isn't static
	if phase == Phase.IDLE:
		swarm.spawn(6, Vector2(30, -20), 220.0, 1.5)


# --------------------------------------------------------------- layers

func set_layer_mask(m: int) -> void:
	layer_mask = m
	swarm.set_layer_mask(m)
	actors.apply_layers(m)
	emit.emitting = (m & 32) != 0
	emit.amount = 512 if (m & 32) else 8


# --------------------------------------------------------------- input

func _unhandled_input(ev: InputEvent) -> void:
	if _label_entry:
		_label_input(ev)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.keycode
		match k:
			KEY_F5: run_suite()
			KEY_F6: run_one(scenario_names[current])
			KEY_F7:
				if Metrics.recording:
					Metrics.stop()
				else:
					Metrics.start("free", {"warmup_s": 0.0, "layers": layer_mask, "actors": actors.live, "seed": SeededRng.seed_value})
			KEY_F8: Metrics.open_bench_folder()
			KEY_TAB:
				current = (current + 1) % scenario_names.size()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				set_layer_mask(layer_mask ^ (1 << (k - KEY_1)))
			KEY_0:
				set_layer_mask(0 if layer_mask != 0 else 63)
			KEY_Q: swarm.spawn(100, Vector2.ZERO)
			KEY_W: swarm.spawn(1000, Vector2.ZERO)
			KEY_E: swarm.spawn(10000, Vector2.ZERO)
			KEY_R: swarm.spawn(50000, Vector2.ZERO)
			KEY_A: actors.spawn(100)
			KEY_S: actors.clear()
			KEY_O: actors.set_use_area(not actors.use_area)
			KEY_G: swarm.set_gpu_path(not swarm.gpu_path)
			KEY_H: overlay.visible = not overlay.visible
			KEY_L:
				_label_entry = true
				_label_buf = Metrics.label
			KEY_C:
				swarm.clear(); actors.clear(); running = {}; phase = Phase.IDLE
			KEY_ESCAPE: get_tree().quit()


func _label_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			Metrics.label = _label_buf
			_label_entry = false
		elif ev.keycode == KEY_ESCAPE:
			_label_entry = false
		elif ev.keycode == KEY_BACKSPACE:
			_label_buf = _label_buf.left(_label_buf.length() - 1)
		elif ev.unicode > 31:
			_label_buf += char(ev.unicode)


func status_line() -> String:
	if _label_entry:
		return "label> " + _label_buf + "_"
	var ph: String = ["idle", "WARM-UP", "CAPTURE", "cool"][phase]
	var sname: String = running_name if not running.is_empty() else str(scenario_names[current])
	return "scenario %s  [%s %.1fs]  queue %d" % [sname, ph, phase_t, queue.size()]
