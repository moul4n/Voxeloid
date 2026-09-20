extends Node2D

const VoxelSystemScript := preload("res://core/material_field.gd")
const GrainRendererScript := preload("res://core/field_renderer.gd")
const ElementsData := preload("res://core/elements.gd")
const SunHud := preload("res://core/sun_hud.gd")
const SpaceBackdrop := preload("res://core/space_backdrop.gd")
var space_backdrop: Node2D
const AmbientDust := preload("res://core/ambient_dust.gd")
const DustRenderer := preload("res://core/ambient_dust_renderer.gd")
const DUST_VISUAL_BUDGET := 768
var ambient_dust: RefCounted
var dust_renderer: Node2D
var _dust_solver_id := 0
var _dust_epoch := -1
var dust_deposited := 0
const ORB_SIZE := Vector2(224, 86)
const ORB_MARGIN := Vector2(40, 32)
const DEV_CAPACITY := 1000000000
const DEV_MIN_SPAWN_AMOUNT := 10
const DEV_MAX_SPAWN_AMOUNT := 500000

var voxels: VoxelSystemScript
var developer_mode := false
var spawn_amount := 1
var active_profile: Dictionary = ElementsData.HYDROGEN
var zoom_level := 1.0
var camera_pan := Vector2.ZERO
var dragging := false
var drag_origin := Vector2.ZERO
var pan_origin := Vector2.ZERO
var time_accum := 0.0
var spawn_clock := 0.0
var holding_orb := false
var font: Font
var element_menu: PopupMenu
var grain_renderer
var _layer_status: Dictionary = {}
var _inner_status: Dictionary = {}
var _body_layers: Array = []
var _layer_status_clock := 0.0

var count: int:
	get: return voxels.count

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	developer_mode = OS.get_cmdline_user_args().has("--dev")
	active_profile = ElementsData.HYDROGEN
	voxels = VoxelSystemScript.new(active_profile, DEV_CAPACITY if developer_mode else VoxelSystemScript.MAX_PARTICLES)
	voxels.enable_sun_progression()
	space_backdrop = SpaceBackdrop.new()
	add_child(space_backdrop)
	ambient_dust = AmbientDust.new()
	dust_renderer = DustRenderer.new()
	dust_renderer.z_index = -2
	add_child(dust_renderer)
	_reset_ambient_dust()
	grain_renderer = GrainRendererScript.new(mini(voxels.capacity, GrainRendererScript.RENDER_INSTANCE_BUDGET - DUST_VISUAL_BUDGET))
	grain_renderer.z_index = -1
	add_child(grain_renderer)
	RenderingServer.set_default_clear_color(Color("050914"))
	font = ThemeDB.fallback_font
	if developer_mode:
		spawn_amount = DEV_MIN_SPAWN_AMOUNT
		create_element_menu()
	queue_redraw()

func _physics_process(delta: float) -> void:
	time_accum += delta
	if holding_orb:
		if developer_mode:
			spawn_clock += delta * spawn_amount
			var emitted := int(spawn_clock)
			if emitted > 0:
				spawn_clock -= emitted
				voxels.spawn_grains(emitted, -PI * 0.25)
		else:
			spawn_clock += delta
			while spawn_clock >= 0.11:
				spawn_clock -= 0.11
				release_grains()
	voxels.step(delta)
	_sync_ambient_dust()
	var body_mass := float(voxels.settled_count) * float(active_profile.get("mass", 1.0))
	var captures: Array[Dictionary] = ambient_dust.step(delta, body_mass, voxels.max_height, Callable(voxels, "sample_height"))
	dust_deposited += voxels.capture_ambient_batch(captures)
	queue_redraw()

func _reset_ambient_dust() -> void:
	ambient_dust.reset()
	ambient_dust.prime(384)
	dust_deposited = 0
	_dust_solver_id = voxels.get_instance_id()
	_dust_epoch = voxels.epoch

func _sync_ambient_dust() -> void:
	if _dust_solver_id != voxels.get_instance_id() or _dust_epoch != voxels.epoch:
		_reset_ambient_dust()

func _process(_delta: float) -> void:
	_sync_ambient_dust()
	_layer_status_clock -= _delta
	if _layer_status_clock <= 0.0:
		_layer_status = voxels.layer_status()
		_inner_status = voxels.inner_layer_status()
		_body_layers = voxels.get_body_layers()
		_layer_status_clock = 0.2
	grain_renderer.update_field(voxels, get_viewport_rect().size * 0.5 + camera_pan, zoom_level)
	space_backdrop.update_view(get_viewport_rect().size, get_viewport_rect().size * 0.5 + camera_pan,
		voxels.compacted_radius * zoom_level if voxels.compacted_count > 0 else 0.0, voxels.time, voxels.get_sun_visual_state())
	dust_renderer.update_view(ambient_dust, get_viewport_rect().size * 0.5 + camera_pan, zoom_level, get_viewport_rect().size)
	queue_redraw()

func reset_view() -> void:
	camera_pan = Vector2.ZERO
	zoom_level = 1.0

func orb_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2(view_size.x - ORB_MARGIN.x - ORB_SIZE.x, ORB_MARGIN.y), ORB_SIZE)

func layer_button_rect(view_size: Vector2) -> Rect2:
	return Rect2(orb_rect(view_size).position + Vector2(0, 100), Vector2(224, 76))

func inner_button_rect(view_size: Vector2) -> Rect2:
	return Rect2(orb_rect(view_size).position + Vector2(0, 190), Vector2(224, 76))

func automation_button_rect(view_size: Vector2) -> Rect2:
	return Rect2(orb_rect(view_size).position + Vector2(0, 280), Vector2(224, 64))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		holding_orb = false
		dragging = false

func create_element_menu() -> void:
	if element_menu:
		return
	element_menu = PopupMenu.new()
	element_menu.name = "DeveloperElementMenu"
	element_menu.add_item("Change element (clears scene)", -1)
	element_menu.set_item_disabled(0, true)
	element_menu.add_separator()
	element_menu.add_item("Hydrogen (H)", 0)
	element_menu.add_item("Helium (He)", 1)
	element_menu.add_item("Carbon (C)", 2)
	element_menu.add_item("Iron (Fe)", 3)
	element_menu.id_pressed.connect(change_element)
	add_child(element_menu)

func release_grains() -> void:
	voxels.spawn_grains(spawn_amount, -PI * 0.25)

func show_element_menu(position: Vector2) -> void:
	holding_orb = false
	element_menu.position = Vector2i(position)
	element_menu.popup()

func change_element(id: int) -> void:
	var profiles := [ElementsData.HYDROGEN, ElementsData.HELIUM, ElementsData.CARBON, ElementsData.IRON]
	if id < 0 or id >= profiles.size():
		return
	active_profile = profiles[id]
	var auto_unlocked := voxels.inner_automation_unlocked
	var auto_enabled := voxels.inner_automation_enabled
	# One solver instance has one material profile. The menu label makes this reset explicit.
	voxels = VoxelSystemScript.new(active_profile, DEV_CAPACITY)
	voxels.enable_sun_progression()
	if auto_unlocked:
		voxels.unlock_inner_automation()
		voxels.set_inner_automation(auto_enabled)
	_layer_status_clock = 0.0
	spawn_clock = 0.0
	holding_orb = false
	queue_redraw()

func adjust_spawn_amount(direction: int) -> void:
	if direction == 0:
		return
	var step_size := 100000
	var boundary_amount := spawn_amount - 1 if direction < 0 else spawn_amount
	if boundary_amount < 100:
		step_size = 10
	elif boundary_amount < 10000:
		step_size = 100
	elif boundary_amount < 100000:
		step_size = 10000
	spawn_amount = clampi(spawn_amount + direction * step_size, DEV_MIN_SPAWN_AMOUNT, DEV_MAX_SPAWN_AMOUNT)

func short_count(value: int) -> String:
	if value >= 1000000000: return "%.2fB" % (float(value) / 1000000000.0)
	if value >= 1000000: return "%.2fM" % (float(value) / 1000000.0)
	if value >= 10000: return "%.1fk" % (float(value) / 1000.0)
	return str(value)
func _unhandled_input(event: InputEvent) -> void:
	var panel := orb_rect(get_viewport_rect().size)
	if event is InputEventMouseButton:
		if SunHud.player_button_rect().has_point(event.position):
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				holding_orb = false
				voxels.assimilate_player_core(developer_mode and event.ctrl_pressed)
				_layer_status_clock = 0.0
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			holding_orb = false
		if inner_button_rect(get_viewport_rect().size).has_point(event.position):
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				holding_orb = false
				voxels.compact_inner_layer(developer_mode and event.ctrl_pressed)
				_layer_status_clock = 0.0
			get_viewport().set_input_as_handled()
			return
		if automation_button_rect(get_viewport_rect().size).has_point(event.position):
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				holding_orb = false
				if developer_mode and event.ctrl_pressed:
					voxels.unlock_inner_automation()
				voxels.set_inner_automation(not voxels.inner_automation_enabled)
				_layer_status_clock = 0.0
			get_viewport().set_input_as_handled()
			return
		if layer_button_rect(get_viewport_rect().size).has_point(event.position):
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				holding_orb = false
				voxels.form_core_layer(developer_mode and event.ctrl_pressed)
				_layer_status = voxels.layer_status()
				_layer_status_clock = 0.2
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and panel.has_point(event.position):
				if developer_mode and event.ctrl_pressed:
					show_element_menu(event.position)
				else:
					release_grains()
					holding_orb = true
					spawn_clock = 0.0
				get_viewport().set_input_as_handled()
			elif not event.pressed:
				holding_orb = false
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not event.pressed:
				dragging = false
			elif panel.has_point(event.position):
				dragging = false
				get_viewport().set_input_as_handled()
			else:
				dragging = true
				drag_origin = event.position
				pan_origin = camera_pan
		if (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and event.pressed:
			if panel.has_point(event.position):
				if developer_mode and event.ctrl_pressed:
					adjust_spawn_amount(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_level = clampf(zoom_level * 1.12, 0.002, 2.2)
			else:
				zoom_level = clampf(zoom_level / 1.12, 0.002, 2.2)
	if event is InputEventMouseMotion and dragging:
		camera_pan = (pan_origin + event.position - drag_origin).clamp(Vector2(-420, -320), Vector2(420, 320))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_view()
		elif event.keycode == KEY_C:
			voxels.clear()

func _draw() -> void:
	var size := get_viewport_rect().size

	var center := size * 0.5 + camera_pan
	draw_world(center)
	draw_hud(size)

func draw_world(center: Vector2) -> void:
	var guide := Color(0.22, 0.39, 0.58, 0.25)
	for radius in range_ring_radii(get_viewport_rect().size, center):
		if radius <= voxels.compacted_radius:
			continue # Scale guides should not cut across the interior textures.
		draw_arc(center, radius * zoom_level, 0.0, TAU, 128, guide, 1.0)
		var label_pos := center + Vector2(radius * zoom_level + 4.0, -5.0)
		if label_pos.x < get_viewport_rect().size.x - 40.0:
			draw_string(font, label_pos, short_count(int(radius)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.45, 0.62, 0.77, 0.65))
	draw_arc(center, VoxelSystemScript.PLAYER_RADIUS * zoom_level, 0.0, TAU, 96, Color("81c9c7"), 1.0)
	draw_circle(center, VoxelSystemScript.PLAYER_RADIUS * zoom_level, Color("102b32"))
	draw_circle(center, (VoxelSystemScript.PLAYER_RADIUS - 5.0) * zoom_level, Color("20444a"))
	draw_circle(center + Vector2(-12, -14) * zoom_level, 5.5 * zoom_level, Color(0.40, 0.88, 0.81, 0.35))
	if zoom_level >= 0.5:
		draw_string(font, center + Vector2(-19, 4) * zoom_level, "PLAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10 * zoom_level, Color("a9c5df"))

func range_ring_radii(view_size: Vector2, center: Vector2) -> Array[float]:
	var desired := 110.0 / zoom_level
	var decade := pow(10.0, floor(log(desired) / log(10.0)))
	var ratio := desired / decade
	var spacing := decade * (2.0 if ratio <= 2.0 else (5.0 if ratio <= 5.0 else 10.0))
	var far_corner := Vector2(maxf(absf(center.x), absf(view_size.x - center.x)), maxf(absf(center.y), absf(view_size.y - center.y)))
	var reach := far_corner.length() / zoom_level
	var rings: Array[float] = []
	for i in range(1, mini(int(ceil(reach / spacing)) + 1, 32)):
		rings.append(float(i) * spacing)
	return rings


func draw_hud(size: Vector2) -> void:
	draw_string(font, Vector2(34, 47), "VOXELOID", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("e5f2ff"))
	draw_string(font, Vector2(35, 69), "RADIAL MATTER STUDY   /   01", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("7796b8"))
	draw_string(font, Vector2(35, size.y - 41), "RMB DRAG  PAN    /    WHEEL  ZOOM    /    R  RESET VIEW    /    C  CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8fa7c4"))
	var rect := orb_rect(size)
	draw_rect(Rect2(rect.position - Vector2.ONE, rect.size + Vector2(2, 2)), Color("172a43"), true)
	draw_rect(rect, Color("0d192a"), true)
	var orb_center := rect.position + Vector2(34, 43)
	var orb_tint: Color = active_profile.get("color", Color("f6b85f"))
	draw_circle(orb_center, 28, Color(orb_tint, 0.12))
	draw_circle(orb_center, 22, Color("03070d"))
	draw_arc(orb_center, 23, 0.0, TAU, 48, orb_tint, 1.6)
	draw_arc(orb_center, 26, 3.6, 5.1, 24, orb_tint.darkened(0.15), 1.0)
	draw_string(font, rect.position + Vector2(70, 29), str(active_profile.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eff8ff"))
	draw_string(font, rect.position + Vector2(70, 49), "CLICK / HOLD TO RELEASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("89a8c6"))
	var detail := "%s  -  ONE SIMPLE GRAIN" % active_profile.id
	if developer_mode:
		detail = "%d/CLICK  %d/SEC" % [spawn_amount, spawn_amount]
	draw_string(font, rect.position + Vector2(70, 67), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a9bfc8"))
	draw_rect(Rect2(35, 93, 190, 62), Color(0.035, 0.07, 0.12, 0.82), true)
	draw_string(font, Vector2(49, 111), "%s ATOMS" % str(active_profile.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("86a3c0"))
	draw_string(font, Vector2(49, 128), "%04d" % voxels.count, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e3f5ff"))
	draw_string(font, Vector2(49, 145), "%s DEPOSITED / %s INCOMING" % [short_count(voxels.settled_count), short_count(voxels.count - voxels.settled_count)], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("86a3c0"))
	if developer_mode:
		draw_string(font, Vector2(35, 171), "DEV: CTRL+CLICK ELEMENTS  /  CTRL+WHEEL AMOUNT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("d5b77a"))
	var layer_rect := layer_button_rect(size)
	var ready := bool(_layer_status.get("ready", false)) and not voxels.compaction_active
	draw_rect(layer_rect, Color("3a2c20") if ready else Color("111e2e"))
	draw_rect(layer_rect, Color("c5a567") if ready else Color("29405a"), false, 1.0)
	draw_string(font, layer_rect.position + Vector2(12, 22), "COMPACT NEXT OUTER LAYER", HORIZONTAL_ALIGNMENT_LEFT, 204, 12, Color("f1dfb9") if ready else Color("7e94aa"))
	var readiness := str(_layer_status.get("reason", "Gather and compact matter"))
	if voxels.compaction_active:
		readiness = "Compacting... %d%%" % int(voxels.compaction_progress * 100.0) if voxels.compaction_kind == "outer" else "Inner conversion in progress"
	elif readiness == "Solar layers complete":
		readiness = "Solar stabilisation ready" if bool(voxels.get_sun_visual_state().get("stabilisation_available", false)) else "Layers complete / grow to 1,000 SMU"
	elif ready:
		readiness = "Click to bind %s grains" % short_count(int(_layer_status.get("layer_grains", 100000)))
	elif int(_layer_status.get("loose_count", 0)) < int(_layer_status.get("minimum_settled", 250000)):
		readiness = "Need %s loose grains" % short_count(int(_layer_status.get("minimum_settled", 250000)))
	elif readiness == "inner ring needs compaction":
		readiness = "Compaction %d%% / %d%%" % [int(float(_layer_status.get("normalized_inner_packing", 0)) * 100), int(float(_layer_status.get("minimum_packing", 0.45)) * 100)]
	draw_string(font, layer_rect.position + Vector2(12, 42), readiness, HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color("9ab4bd"))
	var layer_detail := "%s BOUND" % short_count(voxels.compacted_count)
	if voxels.sun_progression != null:
		var step_index := mini(int(voxels.sun_progression.completed_layers), 6)
		var zones := ["CORE", "RADIATIVE", "CONVECTIVE", "ENVELOPE + SURFACE"]
		layer_detail = "STEP %d/7  /  %s" % [step_index + 1, zones[mini(step_index, 3)]]
		if int(voxels.sun_progression.completed_layers) >= 7:
			layer_detail = "ALL OUTER LAYERS COMPLETE"
		if voxels.compaction_active and voxels.compaction_kind == "outer":
			layer_detail = "FORMING CURRENT OUTER LAYER"
	if developer_mode:
		layer_detail = "CTRL+CLICK TO BYPASS REQUIREMENT"
	draw_string(font, layer_rect.position + Vector2(12, 62), layer_detail, HORIZONTAL_ALIGNMENT_LEFT, 205, 9, Color("88a6ad"))
	draw_inner_controls(size)
	SunHud.draw(self, font, voxels.get_sun_visual_state())

func draw_inner_controls(size: Vector2) -> void:
	var rect := inner_button_rect(size)
	var ready := bool(_inner_status.get("ready", false)) and not voxels.compaction_active
	draw_rect(rect, Color("3a2c20") if ready else Color("111e2e"))
	draw_rect(rect, Color("c5a567") if ready else Color("29405a"), false, 1.0)
	draw_string(font, rect.position + Vector2(12, 22), "COMPRESS EXISTING CORE", HORIZONTAL_ALIGNMENT_LEFT, 204, 12, Color("f1dfb9") if ready else Color("7e94aa"))
	var detail := str(_inner_status.get("reason", "Build the planet core first"))
	if voxels.compaction_active:
		detail = "Densifying... %d%%" % int(voxels.compaction_progress * 100.0) if voxels.compaction_kind == "inner" else "Outer conversion in progress"
	elif ready:
		detail = "%d%% of core mass moves inward" % int(float(active_profile.get("inner_layer_mass_fraction", 0.9)) * 100.0)
	elif float(_inner_status.get("next_automation_mass", 0.0)) > float(_inner_status.get("total_collected_mass", 0.0)):
		detail = "Mass %s / %s" % [short_count(int(_inner_status.get("total_collected_mass", 0))), short_count(int(_inner_status.get("next_automation_mass", 0)))]
	draw_string(font, rect.position + Vector2(12, 43), detail, HORIZONTAL_ALIGNMENT_LEFT, 204, 10, Color("9ab4bd"))
	draw_string(font, rect.position + Vector2(12, 62), "%d%% AREA  /  INNER CONVERSION" % int(float(active_profile.get("inner_layer_area_ratio", 0.1)) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, 204, 9, Color("88a6ad"))
	rect = automation_button_rect(size)
	draw_rect(rect, Color("183c43") if voxels.inner_automation_enabled else Color("111e2e"))
	var auto_label := "INNER AUTO: ON" if voxels.inner_automation_enabled else "INNER AUTO: OFF"
	draw_string(font, rect.position + Vector2(12, 22), auto_label, HORIZONTAL_ALIGNMENT_LEFT, 204, 12, Color("d7eee8"))
	detail = "Click to toggle" if voxels.inner_automation_unlocked else "Player upgrade required"
	if developer_mode and not voxels.inner_automation_unlocked:
		detail = "CTRL+CLICK TO UNLOCK FREE"
	draw_string(font, rect.position + Vector2(12, 44), detail, HORIZONTAL_ALIGNMENT_LEFT, 204, 10, Color("9ab4bd"))
	draw_rect(Rect2(rect.position + Vector2(0, 76), Vector2(224, 124)), Color("0d192a"))
	var legend := rect.position + Vector2(12, 88)
	draw_string(font, legend, "PLAYER CORE IS SEPARATE", HORIZONTAL_ALIGNMENT_LEFT, 204, 10, Color("7796b8"))
	for index in _body_layers.size():
		var layer: Dictionary = _body_layers[index]
		draw_string(font, legend + Vector2(0, 22 + index * 19), "%s  %s" % [layer.name, short_count(int(layer.count))], HORIZONTAL_ALIGNMENT_LEFT, 204, 11, Color("b1cbd1"))
