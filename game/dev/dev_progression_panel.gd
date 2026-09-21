class_name DevProgressionPanel
extends CanvasLayer

signal complete_objective_requested
signal reset_progression_requested
signal preview_notification_requested
signal tuning_changed

var tuning: ProgressionTuning
var panel: PanelContainer
var objective_label: Label
var unlock_label: Label
var _value_labels: Dictionary = {}

func setup(config: ProgressionTuning) -> void:
	tuning = config
	_build()
	visible = false

func toggle() -> void:
	visible = not visible

func set_debug_state(objective_title: String, unlock_count: int) -> void:
	if objective_label:
		objective_label.text = "Objective: " + (objective_title if not objective_title.is_empty() else "none")
	if unlock_label:
		unlock_label.text = "Granted unlocks: %d" % unlock_count

func _build() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(300, 20)
	panel.custom_minimum_size = Vector2(330, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Progression lab"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	objective_label = Label.new()
	box.add_child(objective_label)
	unlock_label = Label.new()
	box.add_child(unlock_label)
	_add_slider(box, "Metric refresh", "metric_refresh_hz", 1.0, 30.0, 0.5)
	_add_slider(box, "Completion hold", "objective_completion_hold_seconds", 0.0, 3.0, 0.05)
	_add_slider(box, "Opening zoom", "opening_zoom", 0.75, 1.25, 0.01)
	_add_slider(box, "Stellar reveal points", "stellar_backdrop_spent_points", 1.0, 10.0, 1.0)
	_add_slider(box, "HUD scale hook", "hud_scale", 0.75, 1.5, 0.05)
	_add_slider(box, "Unlock impact hook", "visual_unlock_intensity", 0.0, 2.0, 0.05)
	_add_slider(box, "Passive audio hook", "passive_music_db", -60.0, 6.0, 1.0)
	_add_slider(box, "Event audio hook", "event_music_db", -60.0, 6.0, 1.0)
	var complete := Button.new()
	complete.text = "Complete current objective"
	complete.pressed.connect(func(): complete_objective_requested.emit())
	box.add_child(complete)
	var preview := Button.new()
	preview.text = "Preview next guidance bubble"
	preview.pressed.connect(func(): preview_notification_requested.emit())
	box.add_child(preview)
	var reset := Button.new()
	reset.text = "Reset progression guidance"
	reset.pressed.connect(func(): reset_progression_requested.emit())
	box.add_child(reset)
	var help := Label.new()
	help.text = "F1 hides this panel. Ctrl-click keeps existing free dev actions."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	add_child(panel)

func _add_slider(box: VBoxContainer, label_text: String, property_name: StringName, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(tuning.get(property_name))
	slider.custom_minimum_size.x = 110
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 48
	row.add_child(value)
	_value_labels[property_name] = value
	_update_value(property_name, slider.value)
	slider.value_changed.connect(func(new_value: float):
		tuning.set(property_name, new_value)
		tuning.sanitize()
		_update_value(property_name, float(tuning.get(property_name)))
		tuning_changed.emit()
	)
	box.add_child(row)

func _update_value(property_name: StringName, value: float) -> void:
	var label: Label = _value_labels.get(property_name)
	if label:
		label.text = "%.2f" % value
