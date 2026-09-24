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

func run() -> void:
	var field = Field.new()
	field.material["flow_rate"] = 0.0
	field.seed_uniform(7200)
	var renderer = Renderer.new(20000)
	root.add_child(renderer)
	renderer.update_field(field, Vector2(640, 400), 1.0)
	check(bool(renderer.get_draw_counts().stable_surface), "thin field did not enable persistent local samples")
	var before: Array[Color] = []
	for index in 7200:
		before.append(renderer._surface_multimesh.get_instance_custom_data(index))
	var deposited := field.capture_ambient_batch([{"amount": 720, "angle": 0.0}])
	check(deposited == 720, "locality setup did not deposit its full batch")
	renderer.update_field(field, Vector2(640, 400), 1.0)
	var unchanged_far_samples := 0
	var checked_far_samples := 0
	var unchanged_original_samples := 0
	for index in 7200:
		var old_data := before[index]
		if renderer._surface_multimesh.get_instance_custom_data(index).is_equal_approx(old_data):
			unchanged_original_samples += 1
		var old_column := int(floor(old_data.r * 720.0))
		if old_column > 120 and old_column < 600:
			checked_far_samples += 1
			if renderer._surface_multimesh.get_instance_custom_data(index).is_equal_approx(old_data):
				unchanged_far_samples += 1
	check(checked_far_samples > 0, "locality check found no remote samples")
	check(unchanged_far_samples == checked_far_samples, "remote deposit remapped settled samples outside its neighbourhood")
	check(unchanged_original_samples == 7200, "new landing matter borrowed an existing settled sample identity")
	check(field.total_mass() == 7920.0, "locality presentation changed logical mass")
	var flowing_field = Field.new()
	flowing_field.seed_uniform(7200)
	var flowing_renderer = Renderer.new(20000)
	root.add_child(flowing_renderer)
	flowing_renderer.update_field(flowing_field, Vector2(640, 400), 1.0)
	var flowing_before := PackedInt32Array()
	flowing_before.resize(7200)
	for index in 7200:
		flowing_before[index] = int(floor(flowing_renderer._surface_multimesh.get_instance_custom_data(index).r * 720.0))
	flowing_field.spawn_grains(720, 0.0)
	for tick in 125:
		flowing_field.step(1.0 / 60.0)
		flowing_renderer.update_field(flowing_field, Vector2(640, 400), 1.0)
	var largest_existing_transfer := 0
	for index in 7200:
		var after_column := int(floor(flowing_renderer._surface_multimesh.get_instance_custom_data(index).r * 720.0))
		var transfer := absi(after_column - flowing_before[index])
		largest_existing_transfer = maxi(largest_existing_transfer, mini(transfer, 720 - transfer))
	print("LOCALITY largest existing transfer during landing: ", largest_existing_transfer, " columns")
	check(largest_existing_transfer <= 24, "landing reassigned an existing sample across a distant part of the body")
	var widest_new_sample := 0
	for index in range(7200, 7920):
		var column := int(floor(flowing_renderer._surface_multimesh.get_instance_custom_data(index).r * 720.0))
		widest_new_sample = maxi(widest_new_sample, mini(column, 720 - column))
	print("LOCALITY widest new landing sample: ", widest_new_sample, " columns from impact")
	check(widest_new_sample <= 120, "new landing samples appeared around a distant part of the body")
	var settling_field = Field.new()
	settling_field.spawn_grains(1000, 0.0)
	for tick in 132:
		settling_field.step(1.0 / 60.0)
	var landing_peak: float = settling_field.max_height
	for tick in 240:
		settling_field.step(1.0 / 60.0)
	print("LOCALITY 1,000-grain settling: peak ", landing_peak, " -> ", settling_field.max_height,
		" opposite mass ", settling_field.masses[360])
	var base_radius := float(settling_field.PLAYER_RADIUS) + float(settling_field.grain_size) * 0.5
	check(settling_field.max_height - base_radius < (landing_peak - base_radius) * 0.45,
		"small hydrogen arrival retained a tall side pile")
	check(settling_field.masses[360] > 0.0, "small hydrogen arrival never propagated around the body")
	var settling_renderer = Renderer.new(2000)
	root.add_child(settling_renderer)
	settling_renderer.update_field(settling_field, Vector2(640, 400), 1.0)
	var occupied_columns := PackedByteArray()
	occupied_columns.resize(720)
	for index in settling_renderer.drawn_settled_count:
		var column := int(floor(settling_renderer._surface_multimesh.get_instance_custom_data(index).r * 720.0))
		occupied_columns[clampi(column, 0, 719)] = 1
	var visible_coverage := 0
	for occupied in occupied_columns:
		visible_coverage += occupied
	print("LOCALITY 1,000-grain visible angular coverage: ", visible_coverage, "/720 columns")
	check(visible_coverage >= 600, "thin hydrogen flow needs too many layers before circling the body")
	var sparse_field = Field.new()
	var sparse_renderer = Renderer.new(1000)
	root.add_child(sparse_renderer)
	sparse_field.capture_ambient_batch([{"amount": 1, "angle": 0.0}])
	sparse_renderer.update_field(sparse_field, Vector2(640, 400), 1.0)
	var first_identity: Color = sparse_renderer._surface_multimesh.get_instance_custom_data(0)
	sparse_field.capture_ambient_batch([{"amount": 1, "angle": PI}])
	sparse_field.step(1.0 / 60.0)
	sparse_renderer.update_field(sparse_field, Vector2(640, 400), 1.0)
	check(sparse_renderer.drawn_settled_count == 2, "second sparse landing replaced the first visible sample")
	check(sparse_renderer._surface_multimesh.get_instance_custom_data(0).is_equal_approx(first_identity),
		"second sparse landing moved or deleted the first settled identity")
	var consumed_field = Field.new()
	consumed_field.seed_uniform(7200)
	var consumed_renderer = Renderer.new(10000)
	root.add_child(consumed_renderer)
	consumed_renderer.update_field(consumed_field, Vector2(640, 400), 1.0)
	check(consumed_field.consume_loose(3600) == 3600, "uniform consumption setup returned the wrong amount")
	consumed_renderer.update_field(consumed_field, Vector2(640, 400), 1.0)
	var quarter_counts := PackedInt32Array([0, 0, 0, 0])
	for index in consumed_renderer.drawn_settled_count:
		var column := int(floor(consumed_renderer._surface_multimesh.get_instance_custom_data(index).r * 720.0))
		quarter_counts[clampi(int(column / 180), 0, 3)] += 1
	for quarter in 4:
		check(quarter_counts[quarter] > 800, "consumption removed stable samples from one side of the shell")
	field.seed_uniform(100)
	renderer.update_field(field, Vector2(640, 400), 1.0)
	check(renderer._stable_sample_columns.size() == 100, "field reset retained stale persistent samples")
	if failures == 0:
		print("Surface locality checks passed: remote deposits preserve thin-layer identities and reset invalidates sample state.")
	quit(1 if failures else 0)
