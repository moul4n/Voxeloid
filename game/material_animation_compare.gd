extends Node2D

const MAIN_SCENE := preload("res://main.tscn")
const ElementsData := preload("res://core/elements.gd")

const SCENARIOS := [
	"Sparse arrivals: 1, 10, 100, 1,000",
	"Thin shell: impacts at eight angles",
	"Overlapping arrivals with camera offset",
	"Repeated compaction, thin shell, new impact",
	"100,000 settled grains",
	"500,000 flow and arrival",
	"Formed Sun zones before ignition",
	"Ignited Sun during conversion",
	"One billion stored grains, bounded drawing",
	"Molten Sun: 500,000-grain fuel impact",
]
const FIXED_STEP := 1.0 / 60.0

var main: Node2D
var scenario_index := 0
var scenario_tick := 0
var reference_markers := true
var flow_enabled := true
var paused := false
var slow_motion := false
var original_flow_rate := 0.0
var status_label: Label
var help_label: Label
var notice_label: Label
var notice_seconds := 0.0
var core_variant := 1
var core_focus := false
var overview_zoom := 1.0
var reduced_core_motion := false

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--dev"):
		push_warning("Material animation comparison is intended to run through start-dev.bat.")
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.z_index = -10
	main.set_physics_process(false)
	_freeze_unrelated_systems()
	_build_hud()
	var initial_scenario := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			initial_scenario = clampi(argument.trim_prefix("--scenario=").to_int() - 1, 0, SCENARIOS.size() - 1)
	_load_scenario(initial_scenario)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if paused:
		return
	scenario_tick += 1
	main.voxels.step(FIXED_STEP)
	_run_timeline()
	main.queue_redraw()
	queue_redraw()

func _process(delta: float) -> void:
	if notice_seconds > 0.0:
		notice_seconds = maxf(notice_seconds - delta, 0.0)
		notice_label.visible = notice_seconds > 0.0
	_update_status()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		_load_scenario(int(key.keycode - KEY_1))
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_0:
		_load_scenario(9)
		get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_ENTER:
			_load_scenario(scenario_index)
		KEY_Q:
			flow_enabled = not flow_enabled
			_apply_flow_toggle()
		KEY_W:
			_toggle_node(main.grain_renderer._surface_instances)
		KEY_E:
			_toggle_node(main.grain_renderer._bulk)
		KEY_T:
			_toggle_node(main.grain_renderer._rim_instances)
		KEY_Y:
			_toggle_node(main.grain_renderer._impact_instances)
		KEY_U:
			_toggle_node(main.grain_renderer._patch_instances)
		KEY_I:
			reference_markers = not reference_markers
			queue_redraw()
		KEY_SPACE:
			paused = not paused
		KEY_S:
			slow_motion = not slow_motion
			Engine.time_scale = 0.25 if slow_motion else 1.0
		KEY_P:
			_capture_still()
		KEY_R:
			core_variant = (core_variant + 1) % 2
			main.grain_renderer.core_motion_variant = core_variant
			_show_notice("Core motion: %s" % _core_variant_name())
		KEY_F:
			_toggle_core_focus()
		KEY_D:
			reduced_core_motion = not reduced_core_motion
			main.grain_renderer.core_motion_speed = 0.25 if reduced_core_motion else 1.0
			_show_notice("Core motion speed: %s" % ("reduced" if reduced_core_motion else "normal"))
		KEY_G:
			main.grain_renderer.pressure_grain_mode = not main.grain_renderer.pressure_grain_mode
			_show_notice("Dense loose matter: %s" % ("compressed grains" if main.grain_renderer.pressure_grain_mode else "legacy continuous fill"))
		_:
			return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _freeze_unrelated_systems() -> void:
	main.ambient_dust.reset()
	main.ambient_dust.config.flux_per_second = 0.0
	main.dust_renderer.visible = false
	main.space_backdrop.visible = false
	main.holding_orb = false
	main._automatic_spawn_credit = 0.0

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(14, 14)
	panel.size = Vector2(530, 126)
	panel.color = Color(0.018, 0.035, 0.065, 0.92)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	status_label = Label.new()
	status_label.position = Vector2(14, 10)
	status_label.size = Vector2(500, 54)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_label)
	help_label = Label.new()
	help_label.position = Vector2(14, 67)
	help_label.size = Vector2(500, 48)
	help_label.text = "1-0 scenario   Enter replay   Space pause   S slow   P still   R core   F focus   D reduced\nG grains/fill   Q flow   W grains   E bulk   T rim   Y impacts   U patches   I markers"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.modulate = Color("9fb6ce")
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(help_label)
	notice_label = Label.new()
	notice_label.position = Vector2(14, 148)
	notice_label.add_theme_font_size_override("font_size", 14)
	notice_label.modulate = Color("ffd487")
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.visible = false
	layer.add_child(notice_label)

func _load_scenario(index: int) -> void:
	scenario_index = clampi(index, 0, SCENARIOS.size() - 1)
	scenario_tick = 0
	paused = false
	core_focus = false
	main.camera_pan = Vector2.ZERO
	main.zoom_level = 1.0
	main.active_profile = ElementsData.HYDROGEN
	main.voxels.material = ElementsData.HYDROGEN.duplicate()
	main.voxels.clear()
	main.grain_renderer.core_motion_variant = core_variant
	main.grain_renderer.core_motion_speed = 0.25 if reduced_core_motion else 1.0
	_freeze_unrelated_systems()
	_reset_visibility()
	match scenario_index:
		0:
			main.zoom_level = 1.25
		1:
			main.voxels.seed_uniform(24000)
			main.zoom_level = 1.2
		2:
			main.voxels.seed_uniform(18000)
			main.camera_pan = Vector2(-145.0, 80.0)
			main.zoom_level = 1.05
		3:
			_setup_repeated_compaction()
		4:
			main.voxels.seed_uniform(100000)
			_fit_body()
		5:
			main.voxels.seed_uniform(250000)
			main.voxels.spawn_grains(250000, -PI * 0.25)
			_fit_body(500000)
		6:
			_setup_sun(false, false)
		7:
			_setup_sun(true, true)
		8:
			main.voxels.seed_uniform(1000000000)
			_fit_body(1000000000)
		9:
			_setup_sun(true, false)
			main.zoom_level = 0.25
			main.space_backdrop.visible = true
	original_flow_rate = float(main.voxels.material.get("flow_rate", 0.0))
	overview_zoom = main.zoom_level
	flow_enabled = true
	_apply_flow_toggle()
	main.grain_renderer.update_field(main.voxels, _world_center(), main.zoom_level)
	_show_notice("Loaded %d: %s" % [scenario_index + 1, SCENARIOS[scenario_index]])
	queue_redraw()

func _run_timeline() -> void:
	match scenario_index:
		0:
			if scenario_tick == 20: main.voxels.spawn_grains(1, 0.0)
			if scenario_tick == 150: main.voxels.spawn_grains(10, PI * 0.5)
			if scenario_tick == 300: main.voxels.spawn_grains(100, PI)
			if scenario_tick == 450: main.voxels.spawn_grains(1000, PI * 1.5)
		1:
			if scenario_tick >= 30 and scenario_tick < 750 and (scenario_tick - 30) % 90 == 0:
				var impact := (scenario_tick - 30) / 90
				main.voxels.spawn_grains(100, float(impact) * TAU / 8.0)
		2:
			if scenario_tick in [30, 42, 54, 66, 78]:
				var wave := int((scenario_tick - 30) / 12)
				main.voxels.spawn_grains(800 + wave * 200, -1.25 + float(wave) * 0.55)
		3:
			if scenario_tick == 40:
				main.voxels.spawn_grains(1000, -PI * 0.25)
		5:
			if scenario_tick == 360:
				main.voxels.spawn_grains(500000, PI * 0.72)
		9:
			if scenario_tick == 60:
				main.voxels.spawn_grains(500000, -0.55)
		_:
			pass

func _setup_repeated_compaction() -> void:
	main.voxels.seed_uniform(1000000)
	for layer in 7:
		main.voxels.form_core_layer(true)
		_step_field(100)
	main.zoom_level = 0.82

func _setup_sun(ignite: bool, leave_converting: bool) -> void:
	main.voxels.seed_uniform(976958)
	for layer in 7:
		main.voxels.form_core_layer(true)
		if layer < 6 or not leave_converting:
			_step_field(100)
	if ignite:
		main.voxels.sun_progression.ignition_unlocked = true
		main.voxels.sun_progression.completed_smu = 1000.0
	_fit_body()

func _step_field(ticks: int) -> void:
	for tick in ticks:
		main.voxels.step(FIXED_STEP)

func _fit_body(logical_count: int = -1) -> void:
	var count: int = logical_count if logical_count >= 0 else int(main.voxels.count)
	var column_mass := float(count) / float(main.voxels.COLUMNS)
	var radius: float = sqrt(float(main.voxels.radius_squared_for_mass(column_mass, column_mass)))
	main.zoom_level = minf(1.2, 300.0 / maxf(radius, 1.0))

func _apply_flow_toggle() -> void:
	main.voxels.material["flow_rate"] = original_flow_rate if flow_enabled else 0.0

func _toggle_node(node: CanvasItem) -> void:
	node.visible = not node.visible

func _reset_visibility() -> void:
	for node in [main.grain_renderer._surface_instances, main.grain_renderer._bulk,
		main.grain_renderer._rim_instances, main.grain_renderer._impact_instances,
		main.grain_renderer._patch_instances]:
		node.visible = true

func _world_center() -> Vector2:
	return get_viewport_rect().size * 0.5 + main.camera_pan

func _draw() -> void:
	if not reference_markers or main == null or main.voxels == null:
		return
	var center := _world_center()
	for index in 16:
		var angle := float(index) * TAU / 16.0
		var radius: float = float(main.voxels.sample_height(angle)) * float(main.zoom_level)
		var radial := Vector2.from_angle(angle)
		var color := Color.from_hsv(float(index) / 16.0, 0.72, 1.0, 0.92)
		draw_line(center + radial * maxf(radius - 8.0, 0.0), center + radial * (radius + 9.0), color, 1.2)
		draw_circle(center + radial * radius, 2.8, color)
	# The long cyan ray fixes the zero-angle seam in screen space.
	draw_line(center, center + Vector2.RIGHT * 120.0, Color(0.2, 0.95, 1.0, 0.42), 1.0)

func _update_status() -> void:
	if main == null or main.voxels == null:
		return
	var draws: Dictionary = main.grain_renderer.get_draw_counts()
	status_label.text = "%d. %s\nlogical %s  settled %s  draw %s/%s/%s  zoom %.3f  %s%s" % [
		scenario_index + 1, SCENARIOS[scenario_index], _short_count(main.voxels.count),
		_short_count(main.voxels.settled_count), _short_count(int(draws.settled)),
		_short_count(int(draws.air)), _short_count(int(draws.rim)), main.zoom_level,
		"PAUSED  " if paused else "", ("SLOW" if slow_motion else "NORMAL") + "  CORE " + _core_variant_name() + (" REDUCED" if reduced_core_motion else "")]

func _capture_still() -> void:
	await RenderingServer.frame_post_draw
	var directory := DirAccess.open("res://../scratch/checks")
	if directory == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../scratch/checks"))
	var path := "res://../scratch/checks/material-motion-s%02d-t%05d.png" % [scenario_index + 1, scenario_tick]
	var error := get_viewport().get_texture().get_image().save_png(path)
	_show_notice("Saved %s" % path if error == OK else "Screenshot failed: %s" % error_string(error))

func _show_notice(message: String) -> void:
	notice_label.text = message
	notice_label.visible = true
	notice_seconds = 3.0

func _short_count(value: int) -> String:
	if value >= 1000000000:
		return "%.2fB" % (float(value) / 1000000000.0)
	if value >= 1000000:
		return "%.2fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fk" % (float(value) / 1000.0)
	return str(value)

func _core_variant_name() -> String:
	return "BANDS" if core_variant == 0 else "PLUMES"

func _toggle_core_focus() -> void:
	var layers: Array = main.voxels.get_body_layers()
	if layers.is_empty():
		_show_notice("Core focus needs a formed body")
		return
	core_focus = not core_focus
	if core_focus:
		overview_zoom = main.zoom_level
		var core_outer := float(layers[0].outer_radius)
		main.zoom_level = clampf(210.0 / maxf(core_outer, 1.0), 0.1, 6.0)
	else:
		main.zoom_level = overview_zoom
	_show_notice("Core focus %s" % ("on" if core_focus else "off"))
