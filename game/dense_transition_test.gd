extends SceneTree

const Field := preload("res://core/material_field.gd")
const Renderer := preload("res://core/field_renderer.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture_stage(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../scratch/checks/pressure-%s.png" % name)

func run() -> void:
	var field = Field.new()
	field.material = field.material.duplicate(true)
	field.material.flow_rate = 0.0
	field.seed_uniform(7200)
	var renderer = Renderer.new(500000)
	root.add_child(renderer)
	renderer.update_field(field, Vector2(640, 400), 1.0)
	var thin: Dictionary = renderer.get_draw_counts()
	check(int(thin.settled) == 7200, "thin shell retired distinct grains")
	check(float(thin.dense_fill_blend) == 0.0, "thin shell entered the dense pressure state")
	await capture_stage("thin")

	var growth: Array[Dictionary] = []
	for column in 720:
		growth.append({"amount": 35 if column < 520 else 34, "angle": (float(column) + 0.5) * TAU / 720.0})
	field.capture_ambient_batch(growth)
	renderer.update_field(field, Vector2(640, 400), 1.0)
	await capture_stage("loaded")
	var previous_draw: int = renderer.drawn_settled_count
	var largest_draw_step := 0
	for tick in 90:
		field.step(1.0 / 60.0)
		renderer.update_field(field, Vector2(640, 400), 1.0)
		var current_draw: int = renderer.drawn_settled_count
		largest_draw_step = maxi(largest_draw_step, absi(current_draw - previous_draw))
		previous_draw = current_draw
	var dense: Dictionary = renderer.get_draw_counts()
	check(float(dense.dense_fill_blend) > 0.99, "thick shell did not finish its dense pressure transition")
	check(bool(dense.pressure_grain_mode), "pressure-shaped grain replacement was not active")
	check(int(dense.settled) == int(dense.settled_logical), "compressed shell retired visible grains below the shared cap")
	check(largest_draw_step < 1000, "dense transition changed draw count in one visible jump")
	await capture_stage("continuous")

	check(field.consume_loose(25000) == 25000, "thin-return setup consumed the wrong amount")
	for tick in 90:
		field.step(1.0 / 60.0)
		renderer.update_field(field, Vector2(640, 400), 1.0)
	var returned: Dictionary = renderer.get_draw_counts()
	check(float(returned.dense_fill_blend) < 0.01, "thin shell did not leave the dense pressure state")
	check(int(returned.settled) == 7200, "thin shell did not restore distinct grain drawing")
	check(absf(field.total_mass() - 7200.0) < 0.01, "presentation transition changed logical mass")
	await capture_stage("returned")
	print("DENSE transition draws: thin=%d dense=%d budget=%d largest_step=%d returned=%d" % [
		int(thin.settled), int(dense.settled), int(dense.settled_detail_budget), largest_draw_step, int(returned.settled)])
	if failures == 0:
		print("Dense transition checks passed: pressure grains, timed state change, reversible drawing and exact mass.")
	quit(1 if failures else 0)
