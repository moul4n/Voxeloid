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

func capture_close(field, renderer, suffix: String, zoom: float = 3.0) -> Image:
	var size := root.get_visible_rect().size
	# Put the right-hand surface through the middle of the frame. Dense bodies
	# can therefore be inspected at true close zoom without fitting the circle.
	var surface_x := size.x * 0.68
	var center := Vector2(surface_x - float(field.max_height) * zoom, size.y * 0.5)
	renderer.update_field(field, center, zoom)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://../scratch/checks/pressure-close-%s.png" % suffix)
	return image

func set_count(field, count: int) -> void:
	field.clear()
	field.seed_uniform(count)

func run() -> void:
	var field = Field.new()
	field.material = field.material.duplicate(true)
	field.material.flow_rate = 0.0
	var renderer = Renderer.new(500000)
	renderer.pressure_grain_mode = true
	root.add_child(renderer)

	set_count(field, 7200)
	await capture_close(field, renderer, "loose")
	var loose := renderer.get_draw_counts()
	check(int(loose.settled) == 7200, "loose comparison did not draw every grain")

	set_count(field, 100000)
	await capture_close(field, renderer, "medium")
	var medium := renderer.get_draw_counts()
	check(int(medium.settled) == 100000, "medium-pressure comparison retired grains")

	set_count(field, 500000)
	for tick in 90:
		field.step(1.0 / 60.0)
		renderer.update_field(field, Vector2.ZERO, 3.0)
	await capture_close(field, renderer, "dense")
	var dense := renderer.get_draw_counts()
	check(bool(dense.pressure_grain_mode), "dense comparison did not use compressed grains")
	check(int(dense.settled) == 500000, "dense comparison did not use the complete shared cap")

	set_count(field, 2000000)
	for tick in 90:
		field.step(1.0 / 60.0)
		renderer.update_field(field, Vector2.ZERO, 3.0)
	await capture_close(field, renderer, "welded")
	var welded := renderer.get_draw_counts()
	check(int(welded.settled) == 500000, "welded comparison exceeded or underused the shared cap")

	renderer.pressure_grain_mode = false
	await capture_close(field, renderer, "legacy-fill")
	var legacy := renderer.get_draw_counts()
	check(int(legacy.settled) <= int(legacy.settled_detail_budget) + 1,
		"legacy comparison did not isolate the old continuous-fill path")

	renderer.pressure_grain_mode = true
	check(field.consume_loose(1992800) == 1992800, "reverse comparison consumed the wrong amount")
	for tick in 90:
		field.step(1.0 / 60.0)
		renderer.update_field(field, Vector2.ZERO, 3.0)
	await capture_close(field, renderer, "returned")
	var returned := renderer.get_draw_counts()
	check(int(returned.settled) == 7200, "consumption did not restore the loose grain population")
	check(absf(field.total_mass() - 7200.0) < 0.01, "compression comparison changed logical mass")

	print("PRESSURE comparison draws: loose=%d medium=%d dense=%d welded=%d legacy=%d returned=%d" % [
		int(loose.settled), int(medium.settled), int(dense.settled), int(welded.settled), int(legacy.settled), int(returned.settled)])
	if failures == 0:
		print("Pressure compression checks passed: close stages, legacy comparison, reversal and exact mass.")
	quit(1 if failures else 0)
