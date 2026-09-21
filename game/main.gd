extends Node2D

const VoxelSystemScript := preload("res://core/material_field.gd")
const GrainRendererScript := preload("res://core/field_renderer.gd")
const ElementsData := preload("res://core/elements.gd")
const SunHud := preload("res://core/sun_hud.gd")
const SpaceBackdrop := preload("res://core/space_backdrop.gd")
const ProgressionTuningScript := preload("res://progression/progression_tuning.gd")
const ProgressionDirectorScript := preload("res://progression/progression_director.gd")
const ProgressionCatalog := preload("res://progression/first_matter_catalog.gd")
const CoreTalentTreeScript := preload("res://progression/core_talent_tree.gd")
const PlayerHud := preload("res://presentation/player_hud.gd")
const NotificationTour := preload("res://presentation/notification_tour.gd")
const AudioDirector := preload("res://presentation/audio_director.gd")
const VisualCueRegistry := preload("res://presentation/visual_cue_registry.gd")
const DevProgressionPanel := preload("res://dev/dev_progression_panel.gd")
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
var progression_tuning: Resource
var progression_director: RefCounted
var notification_tour: RefCounted
var audio_director: RefCounted
var visual_cues: RefCounted
var dev_progression_panel: CanvasLayer
var _progression_clock := 0.0
var _last_completed_objectives: Dictionary = {}
var _completion_hold_remaining := 0.0
var _completed_objective_title := ""
var _completed_objective_description := ""
var core_talent_tree: RefCounted
var talent_tree_open := false
var _manual_spawn_credit := 0.0
var _automatic_spawn_credit := 0.0
const CORE_FEED_DURATION := 1.1
var _core_feed_remaining := 0.0
var _core_feed_source_radius := 90.0
var _core_feed_amount := 0

var count: int:
	get: return voxels.count

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	developer_mode = OS.get_cmdline_user_args().has("--dev")
	progression_tuning = ProgressionTuningScript.new()
	progression_tuning.sanitize()
	core_talent_tree = CoreTalentTreeScript.new()
	zoom_level = 1.0 if developer_mode else progression_tuning.opening_zoom
	_setup_progression()
	active_profile = ElementsData.HYDROGEN
	voxels = VoxelSystemScript.new(active_profile, DEV_CAPACITY if developer_mode else VoxelSystemScript.MAX_PARTICLES)
	voxels.enable_sun_progression()
	space_backdrop = SpaceBackdrop.new()
	space_backdrop.visible = developer_mode
	add_child(space_backdrop)
	ambient_dust = AmbientDust.new()
	dust_renderer = DustRenderer.new()
	dust_renderer.z_index = -2
	dust_renderer.visible = developer_mode
	add_child(dust_renderer)
	_reset_ambient_dust()
	grain_renderer = GrainRendererScript.new(mini(voxels.capacity, GrainRendererScript.RENDER_INSTANCE_BUDGET - DUST_VISUAL_BUDGET))
	# Keep every renderer child, including its positive-z impact flashes, below
	# the player interface drawn by this node.
	grain_renderer.z_index = -3
	add_child(grain_renderer)
	RenderingServer.set_default_clear_color(Color("050914"))
	font = ThemeDB.fallback_font
	if developer_mode:
		spawn_amount = DEV_MIN_SPAWN_AMOUNT
		create_element_menu()
		_setup_dev_progression_panel()
	queue_redraw()

func _setup_progression() -> void:
	var objectives: Array = ProgressionCatalog.create(
		progression_tuning.opening_body_mass_target, progression_tuning.first_shell_mass_target)
	progression_director = ProgressionDirectorScript.new(objectives)
	notification_tour = NotificationTour.new()
	audio_director = AudioDirector.new()
	visual_cues = VisualCueRegistry.new()
	audio_director.set_passive_track("music.void", 0.0)
	notification_tour.start_tour("first_start", [{
		"id": "release_first_grain",
		"target_id": "spawn_orb",
		"title": "Start here",
		"body": "Click H. Hold it to call more.",
	}])
	progression_director.evaluate()

func _setup_dev_progression_panel() -> void:
	dev_progression_panel = DevProgressionPanel.new()
	dev_progression_panel.setup(progression_tuning)
	dev_progression_panel.complete_objective_requested.connect(_dev_complete_current_objective)
	dev_progression_panel.reset_progression_requested.connect(_dev_reset_progression)
	dev_progression_panel.preview_notification_requested.connect(_dev_preview_notification)
	dev_progression_panel.tuning_changed.connect(_dev_tuning_changed)
	add_child(dev_progression_panel)

func _physics_process(delta: float) -> void:
	time_accum += delta
	if not developer_mode and core_talent_tree != null:
		_automatic_spawn_credit += delta * core_talent_tree.automatic_rate(_compaction_power())
		var automatic_amount := int(_automatic_spawn_credit)
		if automatic_amount > 0:
			_automatic_spawn_credit -= automatic_amount
			_spawn_from_singularity(automatic_amount)
	if holding_orb:
		if developer_mode:
			spawn_clock += delta * spawn_amount
			var emitted := int(spawn_clock)
			if emitted > 0:
				spawn_clock -= emitted
				_spawn_from_singularity(emitted)
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
	_core_feed_remaining = maxf(_core_feed_remaining - _delta, 0.0)
	_completion_hold_remaining = maxf(_completion_hold_remaining - _delta, 0.0)
	_layer_status_clock -= _delta
	if _layer_status_clock <= 0.0:
		_layer_status = voxels.layer_status()
		_inner_status = voxels.inner_layer_status()
		_body_layers = voxels.get_body_layers()
		_layer_status_clock = 0.2
	_progression_clock -= _delta
	if _progression_clock <= 0.0:
		_refresh_progression()
		_progression_clock = progression_tuning.metric_refresh_seconds()
	grain_renderer.update_field(voxels, get_viewport_rect().size * 0.5 + camera_pan, zoom_level)
	if space_backdrop.visible:
		space_backdrop.update_view(get_viewport_rect().size, get_viewport_rect().size * 0.5 + camera_pan,
			voxels.compacted_radius * zoom_level if voxels.compacted_count > 0 else 0.0, voxels.time, voxels.get_sun_visual_state())
	dust_renderer.update_view(ambient_dust, get_viewport_rect().size * 0.5 + camera_pan, zoom_level, get_viewport_rect().size)
	dust_renderer.visible = developer_mode or _is_unlocked(&"indicator.ambient_capture")
	queue_redraw()

func reset_view() -> void:
	camera_pan = Vector2.ZERO
	zoom_level = 1.0 if developer_mode else progression_tuning.opening_zoom

func orb_rect(view_size: Vector2) -> Rect2:
	if not developer_mode:
		return Rect2(Vector2(view_size.x - 104, 32), Vector2(64, 64))
	return Rect2(Vector2(view_size.x - ORB_MARGIN.x - ORB_SIZE.x, ORB_MARGIN.y), ORB_SIZE)

func singularity_screen_position() -> Vector2:
	var rect := orb_rect(get_viewport_rect().size)
	return rect.position + Vector2(34, 43) if developer_mode else rect.get_center()

func singularity_source() -> Dictionary:
	var world_centre_screen := get_viewport_rect().size * 0.5 + camera_pan
	var screen_offset := singularity_screen_position() - world_centre_screen
	if screen_offset.length_squared() < 0.0001:
		screen_offset = Vector2.RIGHT
	return {
		"angle": screen_offset.angle(),
		"radius": screen_offset.length() / maxf(zoom_level, 0.001),
	}

func _spawn_from_singularity(amount: int) -> void:
	var source := singularity_source()
	voxels.spawn_grains(amount, float(source.angle), float(source.radius))

func layer_button_rect(view_size: Vector2) -> Rect2:
	if not developer_mode:
		return Rect2(Vector2(34, 340), Vector2(250, 52))
	return Rect2(Vector2(view_size.x - ORB_MARGIN.x - ORB_SIZE.x, ORB_MARGIN.y + 100), Vector2(224, 76))

func inner_button_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2(view_size.x - ORB_MARGIN.x - ORB_SIZE.x, ORB_MARGIN.y + 190), Vector2(224, 76))

func automation_button_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2(view_size.x - ORB_MARGIN.x - ORB_SIZE.x, ORB_MARGIN.y + 280), Vector2(224, 64))

func core_action_rect() -> Rect2:
	return SunHud.player_button_rect() if developer_mode else PlayerHud.core_action_rect()

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
	if developer_mode or core_talent_tree == null:
		_spawn_from_singularity(spawn_amount)
		return
	_manual_spawn_credit += core_talent_tree.manual_yield_multiplier(_compaction_power())
	var amount := int(floor(_manual_spawn_credit + 0.000001))
	_manual_spawn_credit -= amount
	if amount > 0:
		_spawn_from_singularity(amount)

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

func _refresh_progression() -> void:
	if progression_director == null or voxels == null:
		return
	var unit_mass := float(active_profile.get("mass", 1.0))
	var sun: Dictionary = voxels.get_sun_visual_state()
	_layer_status = voxels.layer_status()
	_inner_status = voxels.inner_layer_status()
	if bool(_inner_status.get("ready", false)):
		progression_director.state.unlocks.grant(&"action.compact_inner")
	if voxels.inner_automation_unlocked:
		progression_director.state.unlocks.grant(&"action.inner_automation")
	var loose_count := int(_layer_status.get("loose_count", maxi(voxels.settled_count - voxels.compacted_count, 0)))
	var core_mass := float(sun.get("player_mass", 0.0))
	progression_director.publish_metric(&"mass.total_gathered", float(voxels.count) * unit_mass + core_mass, &"material_field")
	progression_director.publish_metric(&"mass.body", float(voxels.settled_count) * unit_mass, &"material_field")
	progression_director.publish_metric(&"mass.loose", float(loose_count) * unit_mass, &"material_field")
	progression_director.publish_metric(&"mass.core", core_mass, &"material_field")
	progression_director.publish_metric(&"core.level", float(sun.get("player_level", 0)), &"sun_progression")
	progression_director.publish_metric(&"capture.ambient_total", float(dust_deposited) * unit_mass, &"ambient_dust")
	_publish_optional_metric(&"body.smu", float(sun.get("body_smu", 0.0)))
	_publish_optional_metric(&"body.temperature_mk", float(sun.get("temperature", 300.0)) / 1000000.0)
	_publish_optional_metric(&"body.heat", float(sun.get("heat", 0.0)))
	_publish_optional_metric(&"body.layers", float(sun.get("layers", 0)))
	_publish_optional_metric(&"body.compactions", float(sun.get("layers", 0)))
	_publish_optional_metric(&"body.rotation", float(sun.get("spin", 0.0)))
	_publish_optional_metric(&"production.manual_rate", float(spawn_amount) if developer_mode else ((1.0 / 0.11) * core_talent_tree.manual_yield_multiplier(_compaction_power())))
	_publish_optional_metric(&"production.automatic_rate", 0.0 if developer_mode else core_talent_tree.automatic_rate(_compaction_power()))
	var completed: Array = progression_director.evaluate()
	for objective_id in completed:
		_on_objective_completed(objective_id)
	if developer_mode and dev_progression_panel:
		var objective = _current_objective()
		dev_progression_panel.set_debug_state(objective.title if objective != null else "", progression_director.state.unlocks.granted_ids().size())

func _publish_optional_metric(metric_name: StringName, value: Variant) -> void:
	if progression_director.metric_registry.has(metric_name):
		var definition: Dictionary = progression_director.metric_registry.definition(metric_name)
		progression_director.publish_metric(metric_name, value, StringName(definition.get("owner", "")))

func _current_objective():
	if progression_director == null:
		return null
	if progression_director.has_method("current_objective"):
		return progression_director.current_objective()
	var current_id: StringName = progression_director.state.pinned_objective_id
	for objective in progression_director.objectives:
		if objective.objective_id == current_id:
			return objective
	return null

func _is_unlocked(unlock_id: StringName) -> bool:
	return progression_director != null and progression_director.state.unlocks.is_unlocked(unlock_id)

func _on_objective_completed(objective_id: StringName) -> void:
	if _last_completed_objectives.has(objective_id):
		return
	_last_completed_objectives[objective_id] = true
	for definition in progression_director.objectives:
		if definition.objective_id == objective_id:
			_completed_objective_title = String(definition.title)
			_completed_objective_description = String(definition.description)
			break
	_completion_hold_remaining = progression_tuning.objective_completion_hold_seconds
	audio_director.request_event("objective_complete", "event.objective_complete", 0.15)
	var target_id := "objective_panel"
	var title := "Target complete"
	var body := "A new part of the system is now available."
	var objective_text := String(objective_id)
	if objective_text.begins_with("sun.gather_layer_"):
		target_id = "compact_outer"
		title = "The next layer is ready"
		body = "Compact it to strengthen every Core talent again."
		visual_cues.request_cue("layer_ready")
	elif objective_text.begins_with("sun.compact_layer_"):
		target_id = "world_core"
		title = "Power runs through the Core"
		body = "All talent production is now x%.2f stronger." % _compaction_power()
		visual_cues.request_cue("compaction_talent_boost")
	match objective_id:
		&"sun.call_matter":
			target_id = "world_core"
			title = "There it is"
			body = "Let it settle."
			visual_cues.request_cue("first_matter_gathered")
		&"sun.hold_material":
			target_id = "core_action"
			title = "The Core is ready"
			body = "You gathered enough. Feed it when you are ready."
		&"sun.feed_core":
			target_id = "core_action"
			title = "The Core stirs"
			body = "Feed it to grow stronger."
			visual_cues.request_cue("core_awakened")
		&"sun.awaken_core":
			target_id = "talent_panel"
			title = "Ooh, a Core point"
			body = "That mass made your Core grow. Click Talents to spend the point."
			visual_cues.request_cue("talent_unlocked")
		&"sun.catch_wanderer":
			target_id = "world_core"
			title = "Something is drifting by"
			body = "Your pull can catch passing matter."
		&"sun.first_shell":
			target_id = "compact_outer"
			title = "First Matter is ready"
			body = "Choose Form First Matter to bind the loose mass into a permanent layer."
		&"sun.preserve_layer":
			target_id = "world_core"
			title = "First Matter holds"
			body = "Compaction made every Core talent 45% stronger. You can now look farther out."
			visual_cues.request_cue("compaction_talent_boost")
		&"sun.first_ignition":
			target_id = "world_core"
			title = "Ooh, the mass has ignited"
			body = "Heat floods the system. Your compact boosts still power every talent, and helium is beginning to form."
			visual_cues.request_cue("first_ignition")
			audio_director.request_event("first_ignition", "event.first_ignition", 0.4)
	_start_single_notification(String(objective_id), target_id, title, body)

func _start_single_notification(id: String, target_id: String, title: String, body: String) -> void:
	notification_tour.start_tour("unlock." + id, [{
		"id": id,
		"target_id": target_id,
		"title": title,
		"body": body,
	}], true)

func _objective_snapshot() -> Dictionary:
	var sun: Dictionary = voxels.get_sun_visual_state()
	var objective = _current_objective()
	var body_mass := float(progression_director.state.metrics.get("mass.body", 0.0))
	var visible: Array = []
	for unlock_id in progression_director.state.unlocks.granted_ids():
		if String(unlock_id).begins_with("indicator.") or String(unlock_id).begins_with("ui."):
			visible.append(unlock_id)
	var snapshot := {
		"phase_title": str(sun.get("phase", "First Matter")),
		"phase_completed": int(sun.get("layers", 0)),
		"phase_count": 7,
		"objective_title": "First Matter complete" if objective == null else objective.title,
		"objective_description": "Prepare for the next transformation." if objective == null else objective.description,
		"objective_progress": 1.0 if objective == null else progression_director.progress_for(objective.objective_id),
		"objective_state": "Complete" if objective == null else "In progress",
		"body_mass": body_mass,
		"body_mass_display": clampf(log(1.0 + body_mass) / log(1000001.0), 0.0, 1.0),
		"visible_indicators": visible,
	}
	if _completion_hold_remaining > 0.0 and not _completed_objective_title.is_empty():
		snapshot["objective_title"] = _completed_objective_title
		snapshot["objective_description"] = _completed_objective_description
		snapshot["objective_progress"] = 1.0
		snapshot["objective_state"] = "Complete"
		snapshot["objective_current"] = ""
		snapshot["objective_target"] = ""
		return snapshot
	if objective != null and not objective.conditions.is_empty():
		var condition = objective.conditions[0]
		if not condition.metric_name.is_empty():
			var current: Variant = progression_director.state.metrics.get(String(condition.metric_name), 0.0)
			snapshot["objective_current"] = short_count(int(current)) if current is float or current is int else str(current)
			snapshot["objective_target"] = short_count(int(condition.value)) if condition.value is float or condition.value is int else str(condition.value)
	return snapshot

func _total_gathered() -> float:
	if progression_director == null:
		return 0.0
	return float(progression_director.state.metrics.get("mass.total_gathered", 0.0))

func _talent_snapshot() -> Dictionary:
	return core_talent_tree.snapshot(int(voxels.get_sun_visual_state().get("player_level", 0)), _total_gathered(), _compaction_power())

func _compaction_power() -> float:
	if voxels == null:
		return 1.0
	return float(voxels.get_sun_visual_state().get("total_production_reward", 1.0))

func _hovered_talent(view_size: Vector2) -> StringName:
	if not talent_tree_open:
		return &""
	for node in _talent_snapshot().get("nodes", []):
		if PlayerHud.talent_node_rect(view_size, node).has_point(get_local_mouse_position()):
			return StringName(node.get("id", &""))
	return &""

func _buy_talent(talent_id: StringName, free: bool = false) -> bool:
	var level := int(voxels.get_sun_visual_state().get("player_level", 0))
	var bought: bool = bool(core_talent_tree.grant(talent_id)) if free else bool(core_talent_tree.buy(talent_id, level, _total_gathered()))
	if not bought:
		return false
	if core_talent_tree.spent_points() >= progression_tuning.stellar_backdrop_spent_points and not _is_unlocked(&"visual.starfield"):
		space_backdrop.visible = true
		progression_director.state.unlocks.grant(&"visual.starfield")
		visual_cues.request_cue("stellar_pull_revealed")
		audio_director.request_event("stellar_pull", "event.stellar_pull", 0.2)
		_start_single_notification("stellar_pull", "world_core", "Your pull reaches farther", "Your Core is getting heavier. One day it may pull in something bigger than you can handle.")
	_progression_clock = 0.0
	queue_redraw()
	return true

func _notification_anchor(step: Dictionary, view_size: Vector2) -> Rect2:
	match str(step.get("target_id", "objective_panel")):
		"spawn_orb": return orb_rect(view_size)
		"body_mass": return PlayerHud.indicator_rect()
		"core_action": return core_action_rect()
		"talent_panel":
			if talent_tree_open:
				return Rect2(PlayerHud.talent_tree_rect(view_size).position + Vector2(0, 44), Vector2.ONE)
			return PlayerHud.talent_rect(view_size)
		"talent_tree": return Rect2(PlayerHud.talent_tree_rect(view_size).position + Vector2(0, 44), Vector2.ONE)
		"first_talent":
			for node in _talent_snapshot().get("nodes", []):
				if StringName(node.get("id", &"")) == &"automatic_invocation":
					return PlayerHud.talent_node_rect(view_size, node)
			return PlayerHud.talent_tree_rect(view_size)
		"compact_outer": return layer_button_rect(view_size)
		"world_core": return Rect2(view_size * 0.5 + camera_pan - Vector2(24, 24), Vector2(48, 48))
	return PlayerHud.objective_rect()

func _dev_complete_current_objective() -> void:
	var objective = _current_objective()
	if objective == null:
		return
	progression_director.state.mark_completed(objective.objective_id)
	progression_director.evaluate()
	_on_objective_completed(objective.objective_id)
	_progression_clock = 0.0

func _dev_reset_progression() -> void:
	_last_completed_objectives.clear()
	_completion_hold_remaining = 0.0
	_completed_objective_title = ""
	_completed_objective_description = ""
	_setup_progression()
	_progression_clock = 0.0

func _dev_preview_notification() -> void:
	var objective = _current_objective()
	var title: String = "Presentation preview" if objective == null else String(objective.title)
	var body: String = "Guidance bubbles use semantic targets and can be dismissed without blocking play." if objective == null else String(objective.description)
	_start_single_notification("preview", "objective_panel", title, body)

func _dev_tuning_changed() -> void:
	for objective in progression_director.objectives:
		if objective.conditions.is_empty():
			continue
		if objective.objective_id == &"sun.hold_material":
			objective.conditions[0].value = progression_tuning.opening_body_mass_target
			objective.title = "Gather at least %d mass" % int(progression_tuning.opening_body_mass_target)
		elif objective.objective_id == &"sun.first_shell":
			objective.conditions[0].value = progression_tuning.first_shell_mass_target
	zoom_level = progression_tuning.opening_zoom
	_progression_clock = 0.0

func _unhandled_input(event: InputEvent) -> void:
	var panel := orb_rect(get_viewport_rect().size)
	if event is InputEventMouseButton:
		if not developer_mode and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var guide_step: Dictionary = notification_tour.current_step()
			if not guide_step.is_empty():
				var guide_anchor := _notification_anchor(guide_step, get_viewport_rect().size)
				if PlayerHud.next_button_rect(get_viewport_rect().size, guide_anchor).has_point(event.position):
					notification_tour.next()
					get_viewport().set_input_as_handled()
					return
				if PlayerHud.dismiss_button_rect(get_viewport_rect().size, guide_anchor).has_point(event.position):
					notification_tour.dismiss_current()
					get_viewport().set_input_as_handled()
					return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_unlocked(&"ui.talents"):
			if PlayerHud.talent_rect(get_viewport_rect().size).has_point(event.position):
				holding_orb = false
				talent_tree_open = not talent_tree_open
				if talent_tree_open and core_talent_tree.available_points(int(voxels.get_sun_visual_state().get("player_level", 0))) > 0 and not _is_unlocked(&"tutorial.talent_tree_opened"):
					progression_director.state.unlocks.grant(&"tutorial.talent_tree_opened")
					_start_single_notification("talent_tree_opened", "first_talent", "Start with Flow", "Flow begins pulling matter for you. Spend your first point here.")
				get_viewport().set_input_as_handled()
				return
			if talent_tree_open:
				for node in _talent_snapshot().get("nodes", []):
					if PlayerHud.talent_node_rect(get_viewport_rect().size, node).has_point(event.position):
						_buy_talent(StringName(node.get("id", &"")), developer_mode and event.ctrl_pressed)
						get_viewport().set_input_as_handled()
						return
		if core_action_rect().has_point(event.position):
			if not developer_mode and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_refresh_progression()
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and (developer_mode or _is_unlocked(&"action.feed_core")):
				holding_orb = false
				var loose_before := int(voxels.layer_status().get("loose_count", 0))
				var feed_radius := maxf(voxels.max_height * zoom_level, 70.0)
				if voxels.assimilate_player_core(developer_mode and event.ctrl_pressed):
					_core_feed_amount = maxi(loose_before - int(voxels.layer_status().get("loose_count", 0)), 1)
					_core_feed_source_radius = clampf(feed_radius, 70.0, 220.0)
					_core_feed_remaining = CORE_FEED_DURATION
				_layer_status_clock = 0.0
				get_viewport().set_input_as_handled()
				return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			holding_orb = false
		if inner_button_rect(get_viewport_rect().size).has_point(event.position):
			if not developer_mode and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_refresh_progression()
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and (developer_mode or _is_unlocked(&"action.compact_inner")):
				holding_orb = false
				if voxels.compact_inner_layer(developer_mode and event.ctrl_pressed):
					progression_director.state.unlocks.grant(&"indicator.heat")
					var dense_state: Dictionary = voxels.get_sun_visual_state()
					_start_single_notification("inner_density_%d" % int(dense_state.get("densification_count", 0)),
						"world_core", "The centre tightens", "Pressure releases heat. Every Core talent is now powered at x%.2f." % float(dense_state.get("total_production_reward", 1.0)))
					visual_cues.request_cue("inner_densification_reward")
				_layer_status_clock = 0.0
				get_viewport().set_input_as_handled()
				return
		if automation_button_rect(get_viewport_rect().size).has_point(event.position):
			if not developer_mode and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_refresh_progression()
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and (developer_mode or _is_unlocked(&"action.inner_automation")):
				holding_orb = false
				if developer_mode and event.ctrl_pressed:
					voxels.unlock_inner_automation()
				voxels.set_inner_automation(not voxels.inner_automation_enabled)
				_layer_status_clock = 0.0
				get_viewport().set_input_as_handled()
				return
		if layer_button_rect(get_viewport_rect().size).has_point(event.position):
			if not developer_mode and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_refresh_progression()
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and (developer_mode or _is_unlocked(&"action.compact_outer")):
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
				var limits := _zoom_limits()
				zoom_level = clampf(zoom_level * 1.12, limits.x, limits.y)
			else:
				var limits := _zoom_limits()
				zoom_level = clampf(zoom_level / 1.12, limits.x, limits.y)
	if event is InputEventMouseMotion and dragging:
		camera_pan = (pan_origin + event.position - drag_origin).clamp(Vector2(-420, -320), Vector2(420, 320))
	if event is InputEventKey and event.pressed and not event.echo:
		if developer_mode and event.keycode == KEY_F1 and dev_progression_panel:
			dev_progression_panel.toggle()
		elif event.keycode == KEY_R:
			reset_view()
		elif developer_mode and event.keycode == KEY_C:
			voxels.clear()

func _zoom_limits() -> Vector2:
	if developer_mode:
		return Vector2(0.002, 2.2)
	if _is_unlocked(&"camera.wide"):
		return Vector2(0.35, 1.6)
	return Vector2(progression_tuning.opening_min_zoom, progression_tuning.opening_max_zoom)

func _draw() -> void:
	var size := get_viewport_rect().size

	var center := size * 0.5 + camera_pan
	draw_world(center)
	draw_hud(size)

func draw_world(center: Vector2) -> void:
	var guide := Color(0.22, 0.39, 0.58, 0.25)
	if developer_mode or _is_unlocked(&"camera.wide"):
		for radius in range_ring_radii(get_viewport_rect().size, center):
			if radius <= voxels.compacted_radius:
				continue # Scale guides should not cut across the interior textures.
			draw_arc(center, radius * zoom_level, 0.0, TAU, 128, guide, 1.0)
			var label_pos := center + Vector2(radius * zoom_level + 4.0, -5.0)
			if label_pos.x < get_viewport_rect().size.x - 40.0:
				draw_string(font, label_pos, short_count(int(radius)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.45, 0.62, 0.77, 0.65))
	var physics_radius := VoxelSystemScript.PLAYER_RADIUS * zoom_level
	var visual_world_radius := VoxelSystemScript.PLAYER_RADIUS if developer_mode else 30.0
	var visual_radius := visual_world_radius * zoom_level
	draw_arc(center, physics_radius, 0.0, TAU, 96, Color(0.35, 0.72, 0.72, 0.30), 1.0)
	if not developer_mode:
		draw_arc(center, (visual_world_radius + 5.0) * zoom_level, 0.2, 2.5, 40, Color(0.40, 0.88, 0.81, 0.18), 1.0)
		draw_arc(center, (visual_world_radius + 8.0) * zoom_level, 3.3, 5.7, 40, Color(0.40, 0.88, 0.81, 0.10), 1.0)
	draw_circle(center, visual_radius, Color("102b32"))
	draw_circle(center, maxf(visual_radius - 5.0 * zoom_level, 1.0), Color("20444a"))
	draw_circle(center + Vector2(-visual_world_radius * 0.28, -visual_world_radius * 0.34) * zoom_level,
		maxf(visual_world_radius * 0.13 * zoom_level, 1.0), Color(0.40, 0.88, 0.81, 0.35))
	if developer_mode and zoom_level >= 0.5:
		draw_string(font, center + Vector2(-19, 4) * zoom_level, "PLAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10 * zoom_level, Color("a9c5df"))
	_draw_inner_densification(center, visual_radius)
	_draw_core_feed_animation(center, visual_radius)

func _draw_inner_densification(center: Vector2, player_radius: float) -> void:
	if not voxels.compaction_active or voxels.compaction_kind != "inner":
		return
	var progress := clampf(voxels.compaction_progress, 0.0, 1.0)
	var strength := sin(progress * PI)
	# Give the reward a readable screen-space travel distance even when the
	# physical stellar band is mostly hidden behind the fixed player Core.
	var source_radius := maxf(voxels.animation_outer_radius * zoom_level, player_radius + 50.0)
	var target_radius := player_radius + 7.0
	var ring_radius := lerpf(source_radius, target_radius, progress * progress * (3.0 - 2.0 * progress))
	var warm := Color("f2b45f")
	draw_arc(center, ring_radius, 0.0, TAU, 64, Color(warm, 0.86 * strength), 2.5)
	draw_arc(center, lerpf(source_radius * 1.18, target_radius, progress), 0.0, TAU, 64, Color(warm, 0.24 * strength), 1.0)
	for index in 18:
		var angle := float(index) * TAU / 18.0 + sin(float(index) * 2.7) * 0.08
		var stagger := fmod(progress * 1.25 + float(index % 5) * 0.08, 1.0)
		var radius := lerpf(source_radius * (0.92 + 0.10 * sin(float(index) * 1.9)), target_radius, stagger)
		var head := center + Vector2.from_angle(angle) * radius
		var tail := center + Vector2.from_angle(angle) * minf(radius + 8.0 + 10.0 * strength, source_radius * 1.2)
		draw_line(tail, head, Color(warm, strength * 0.62), 1.6)
		draw_circle(head, 2.1, Color("ffe0a0", strength * 0.82))
	draw_circle(center, player_radius + 5.0 * strength, Color(warm, strength * 0.09))

func _draw_core_feed_animation(center: Vector2, core_radius: float) -> void:
	if _core_feed_remaining <= 0.0:
		return
	var progress := 1.0 - _core_feed_remaining / CORE_FEED_DURATION
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var fade := sin(progress * PI)
	var outer := lerpf(_core_feed_source_radius, maxf(core_radius + 5.0, 18.0), eased)
	var tint := Color("71c9c3")
	draw_arc(center, outer, 0.0, TAU, 72, Color(tint, fade * 0.32), 2.0)
	for index in 14:
		var phase := fmod(float(index) * 2.39996 + progress * (1.2 + float(index % 3) * 0.18), TAU)
		var stagger := fmod(progress * 1.35 + float(index) / 14.0, 1.0)
		var travel := stagger * stagger * (3.0 - 2.0 * stagger)
		var radius := lerpf(_core_feed_source_radius * (0.82 + 0.16 * sin(float(index) * 3.1)), maxf(core_radius * 0.45, 8.0), travel)
		var point := center + Vector2.from_angle(phase) * radius
		draw_circle(point, lerpf(2.5, 1.2, travel), Color(tint, fade * (0.55 + 0.35 * travel)))
	draw_circle(center, core_radius + 7.0 * fade, Color(tint, fade * 0.13))
	draw_arc(center, core_radius + 5.0 * fade, 0.0, TAU, 48, Color("c9eeea", fade * 0.7), 1.5)

func range_ring_radii(view_size: Vector2, center: Vector2) -> Array[float]:
	var desired := 110.0 / zoom_level
	var decade := pow(10.0, floor(log(desired) / log(10.0)))
	var ratio := desired / decade
	var spacing := decade * (2.0 if ratio <= 2.0 else (5.0 if ratio <= 5.0 else 10.0))
	var far_corner := Vector2(maxf(absf(center.x), absf(view_size.x - center.x)), maxf(absf(center.y), absf(view_size.y - center.y)))
	var reach := far_corner.length() / zoom_level
	var rings: Array[float] = []
	var occupied_radius := maxf(voxels.max_height, voxels.compacted_radius)
	for i in range(1, mini(int(ceil(reach / spacing)) + 1, 32)):
		var radius := float(i) * spacing
		if radius > occupied_radius:
			rings.append(radius)
	return rings


func draw_hud(size: Vector2) -> void:
	if not developer_mode:
		draw_player_hud(size)
		return
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
	if _is_unlocked(&"ui.talents"):
		PlayerHud.draw_talents(self, font, size, _talent_snapshot(), talent_tree_open, _hovered_talent(size))

func draw_player_hud(size: Vector2) -> void:
	var snapshot := _objective_snapshot()
	var step: Dictionary = notification_tour.current_step()
	var anchor := _notification_anchor(step, size) if not step.is_empty() else PlayerHud.objective_rect()
	PlayerHud.draw(self, font, size, snapshot, voxels.get_sun_visual_state(), _talent_snapshot(), talent_tree_open,
		_hovered_talent(size), step, anchor)
	draw_string(font, Vector2(35, size.y - 21), "R  RESET VIEW    /    RMB DRAG  PAN    /    WHEEL  INSPECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("708aa6"))
	var rect := orb_rect(size)
	var orb_center := rect.get_center()
	var orb_tint: Color = active_profile.get("color", Color("f6b85f"))
	draw_circle(orb_center, 30, Color(orb_tint, 0.09))
	draw_circle(orb_center, 23, Color("010308"))
	draw_arc(orb_center, 24, 0.0, TAU, 48, orb_tint, 1.5)
	draw_string(font, orb_center + Vector2(-5, 5), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eff8ff"))
	if rect.has_point(get_local_mouse_position()):
		var hint := "Hold to call more" if voxels.count > 0 else "Click me"
		draw_string(font, rect.position + Vector2(-82, 38), hint, HORIZONTAL_ALIGNMENT_RIGHT, 72, 9, Color("a9bfc8"))
	if _is_unlocked(&"action.compact_outer"):
		_draw_player_compaction_action(size)
	if _is_unlocked(&"action.feed_core"):
		_draw_player_core_action()
	if _is_unlocked(&"action.compact_inner"):
		_draw_player_inner_action(size)
	if _is_unlocked(&"action.inner_automation"):
		_draw_player_automation_action(size)

func _draw_player_core_action() -> void:
	var rect := PlayerHud.core_action_rect()
	var sun: Dictionary = voxels.get_sun_visual_state()
	var ready := int(voxels.layer_status().get("loose_count", 0)) >= int(sun.get("player_cost", 20.0))
	draw_rect(rect, Color("17434a") if ready else Color("111e2e"))
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), Color("71c9c3") if ready else Color("29405a"))
	draw_rect(rect, Color("71c9c3") if ready else Color("29405a"), false, 1.0)
	draw_string(font, rect.position + Vector2(14, 15), "CORE", HORIZONTAL_ALIGNMENT_LEFT, 70, 8, Color("71c9c3") if ready else Color("60758a"))
	draw_string(font, rect.position + Vector2(14, 34), "FEED CORE", HORIZONTAL_ALIGNMENT_LEFT, 130, 11, Color("c9eeea") if ready else Color("7e94aa"))
	draw_string(font, rect.position + Vector2(178, 34), short_count(int(sun.get("player_cost", 20.0))), HORIZONTAL_ALIGNMENT_RIGHT, 56, 11, Color("c9eeea") if ready else Color("7e94aa"))

func _draw_player_compaction_action(size: Vector2) -> void:
	var rect := layer_button_rect(size)
	var ready := bool(_layer_status.get("ready", false)) and not voxels.compaction_active
	var layers := int(voxels.get_sun_visual_state().get("layers", 0))
	draw_rect(rect, Color("3a2c20") if ready else Color("111e2e"))
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), Color("c5a567") if ready else Color("29405a"))
	draw_rect(rect, Color("c5a567") if ready else Color("29405a"), false, 1.0)
	var label := "FORM FIRST MATTER" if layers == 0 else "COMPACT NEXT LAYER"
	draw_string(font, rect.position + Vector2(14, 21), label, HORIZONTAL_ALIGNMENT_LEFT, 214, 11, Color("f1dfb9") if ready else Color("7e94aa"))
	var detail := "Bind %s loose mass" % short_count(int(_layer_status.get("layer_grains", 0))) if ready else "Gather the mass shown in your Quest"
	if voxels.compaction_active:
		detail = "Forming... %d%%" % int(voxels.compaction_progress * 100.0)
	draw_string(font, rect.position + Vector2(14, 40), detail, HORIZONTAL_ALIGNMENT_LEFT, 214, 9, Color("9ab4bd"))

func _draw_player_inner_action(size: Vector2) -> void:
	var rect := inner_button_rect(size)
	var ready := bool(_inner_status.get("ready", false)) and not voxels.compaction_active
	draw_rect(rect, Color("24363b") if ready else Color("111e2e"))
	draw_rect(rect, Color("71c9c3") if ready else Color("29405a"), false, 1.0)
	draw_string(font, rect.position + Vector2(12, 25), "DENSIFY STELLAR CORE", HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color("c9eeea") if ready else Color("7e94aa"))
	var detail := "+12% talent power and a heat pulse" if ready else str(_inner_status.get("reason", "Build more structure"))
	draw_string(font, rect.position + Vector2(12, 49), detail, HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("9ab4bd"))

func _draw_player_automation_action(size: Vector2) -> void:
	var rect := automation_button_rect(size)
	draw_rect(rect, Color("183c43") if voxels.inner_automation_enabled else Color("111e2e"))
	draw_rect(rect, Color("71c9c3"), false, 1.0)
	draw_string(font, rect.position + Vector2(12, 25), "INNER DENSIFICATION   " + ("ON" if voxels.inner_automation_enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, 200, 11, Color("c9eeea"))
	draw_string(font, rect.position + Vector2(12, 47), "Click to toggle the granted upgrade", HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("9ab4bd"))

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
