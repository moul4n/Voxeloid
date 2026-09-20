extends SceneTree
const Field := preload("res://core/material_field.gd")
const Profiles := preload("res://core/elements.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var field = Field.new(Profiles.HYDROGEN, 3)
	field.enable_sun_progression()
	var arrivals: Array[Dictionary] = [{"amount": 2, "angle": 0.0}, {"amount": 2, "angle": PI}]
	check(field.capture_ambient_batch(arrivals) == 3, "ambient capacity acceptance was not exact")
	check(field.count == 3 and field.settled_count == 3 and field.batches.is_empty(), "dust was duplicated into sky arrivals")
	check(field.compacted_count == 0 and field._total_collected_mass == 3.0, "dust compacted itself or missed lifetime mass")
	check(field.capture_ambient_batch(arrivals) == 0 and field.count == 3, "full storage accepted extra dust")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.voxels.seed_uniform(750000)
	var active: int = main.ambient_dust.active_count
	var origin: Vector2 = main.ambient_dust.positions[0]
	main.zoom_level = 0.1
	main.camera_pan = Vector2(200, -100)
	await process_frame
	await process_frame
	check(main.ambient_dust.active_count == active and main.ambient_dust.positions[0] == origin, "camera altered dust simulation")
	var draws: Dictionary = main.grain_renderer.get_draw_counts()
	check(int(draws.settled) + int(draws.air) + int(draws.rim) + main.ambient_dust.active_count <= 500000, "dust exceeded shared sample budget")
	main.ambient_dust.config.flux_per_second = 0.0
	main.ambient_dust.config.capture_multiplier = 1000.0
	main.ambient_dust.reset()
	# A real dust crossing must deposit exactly once through the live physics path.
	main.ambient_dust.prime(1)
	main.ambient_dust.positions[0] = Vector2(main.voxels.max_height + 2.0, 0)
	main.ambient_dust.velocities[0] = Vector2(-10000, 0)
	var before: int = main.voxels.count
	main._physics_process(1.0 / 60.0)
	check(main.voxels.count == before + 1 and main.dust_deposited == 1, "live flyby did not hand off exactly one grain")
	main._physics_process(1.0 / 60.0)
	check(main.voxels.count == before + 1, "captured mote was counted again")
	main.voxels.clear()
	await process_frame
	await process_frame
	check(main.dust_deposited == 0 and main.ambient_dust.captured_count == 0, "clear retained dust accounting")
	check(main.ambient_dust.active_count == 384, "clear did not restore background field")
	if DisplayServer.get_name() != "headless":
		main.voxels.seed_uniform(750000)
		main.camera_pan = Vector2.ZERO
		main.zoom_level = 0.25
		main.ambient_dust.config.flux_per_second = 24.0
		main.ambient_dust.config.capture_multiplier = 1.0
		for tick in 240:
			main._physics_process(1.0 / 60.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(main.dust_renderer.drawn_count > 0, "no dust was visible in the live viewport")
		root.get_texture().get_image().save_png("res://../scratch/checks/ambient-dust-live.png")
		print("DUST_RENDER visible=%d active=%d captured=%d" % [main.dust_renderer.drawn_count, main.ambient_dust.active_count, main.dust_deposited])
	if failures == 0:
		print("Ambient integration passed: live capture, capacity, exact mass, no automatic compaction, camera independence, budget and reset.")
	quit(1 if failures else 0)
