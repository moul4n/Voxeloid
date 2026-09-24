extends SceneTree

const SpaceBackdrop := preload("res://core/space_backdrop.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(backdrop: Node2D, suffix: String) -> Image:
	backdrop.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://../scratch/checks/stellar-ejection-%s.png" % suffix)
	return image

func exterior_signature(image: Image, center: Vector2, inner_radius: float, outer_radius: float) -> Vector2:
	var bright_count := 0.0
	var weighted_red := 0.0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var distance := Vector2(float(x), float(y)).distance_to(center)
			if distance < inner_radius or distance > outer_radius:
				continue
			var color := image.get_pixel(x, y)
			if color.r > 0.35 and color.r > color.g * 1.35 and color.g > color.b * 1.25:
				bright_count += 1.0
				weighted_red += color.r
	return Vector2(bright_count, weighted_red)

func run() -> void:
	var backdrop := SpaceBackdrop.new()
	root.add_child(backdrop)
	var interpolation_path := PackedVector2Array([Vector2.ZERO, Vector2(10.0, 4.0)])
	check(backdrop._sample_polyline(interpolation_path, 0.25).is_equal_approx(Vector2(2.5, 1.0)),
		"prominence light snapped between path samples instead of interpolating")
	var size := root.get_visible_rect().size
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.27
	var quiet_state := {"heat": 0.8, "ignited": false, "solar_progress": 0.7}
	backdrop.update_view(size, center, radius, 4.0, quiet_state)
	check(not backdrop.ejections_active(), "surface ejections started before ignition")
	var quiet := await capture(backdrop, "quiet")
	var quiet_signature := exterior_signature(quiet, center, radius + 8.0, radius + 180.0)

	var active_state := {"heat": 0.8, "ignited": true, "solar_progress": 0.7}
	backdrop.update_view(size, center, radius, 4.0, active_state)
	check(backdrop.ejections_active(), "ignition did not start surface ejections")
	var early := await capture(backdrop, "early")
	var early_signature := exterior_signature(early, center, radius + 8.0, radius + 180.0)
	check(early_signature.x > quiet_signature.x + 20.0,
		"ignited prominence ribbons did not add visible exterior pixels")

	backdrop.update_view(size, center, radius, 19.0, active_state)
	var later := await capture(backdrop, "later")
	var later_signature := exterior_signature(later, center, radius + 8.0, radius + 180.0)
	check(later_signature.distance_to(early_signature) > 3.0,
		"surface ribbons and plumes did not change over time")

	backdrop.update_view(size, center, 29.0, 19.0, active_state)
	check(not backdrop.ejections_active(), "tiny on-screen body drew unreadable ejections")
	if failures == 0:
		print("Stellar ejection render passed: ignition gate, smooth ribbon lights, rounded plumes, motion and small-body cutoff.")
	quit(1 if failures else 0)
