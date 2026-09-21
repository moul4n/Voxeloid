extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.voxels.seed_uniform(500000)
	var mass_before: float = float(main.voxels.total_mass())
	main.grain_renderer.update_field(main.voxels, Vector2(640, 400), 0.4)
	var first: Dictionary = main.grain_renderer.get_draw_counts()
	main.grain_renderer.update_field(main.voxels, Vector2(640, 400), 0.4)
	var second: Dictionary = main.grain_renderer.get_draw_counts()
	check(first == second, "stable field produced unstable visual counts")
	check(int(first.settled) + int(first.air) + int(first.rim) <= 500000, "visual presentation exceeded shared grain budget")
	check(is_equal_approx(main.voxels.total_mass(), mass_before), "visual presentation changed logical mass")
	check(main.grain_renderer._surface_image.get_width() == 720, "visual smoothing changed authoritative field resolution")
	check(main.grain_renderer._surface_image.get_height() == 18, "visual smoothing changed radial lookup layout")
	check(is_equal_approx(main.grain_renderer._surface_image.get_pixel(719, 0).r, 1.0),
		"forward visual CDF does not end at one")
	check(is_equal_approx(main.grain_renderer._surface_image.get_pixel(0, 0).a, 1.0),
		"reverse visual CDF does not end at one")
	check(main.grain_renderer._surface_image.get_pixel(719, 0).a < 0.01,
		"reverse visual CDF is not stored in reverse order")
	var initial_heat: float = main.grain_renderer._visual_heat
	main.voxels.sun_progression.completed_layers = 7
	main.voxels.sun_progression.completed_smu = 1000.0
	main.voxels.sun_progression.ignition_unlocked = true
	main.voxels.time += 1.0 / 60.0
	main.grain_renderer.update_field(main.voxels, Vector2(640, 400), 0.4)
	check(main.grain_renderer._visual_heat > initial_heat and main.grain_renderer._visual_heat < 1.0,
		"thermal colour jumped directly to its target")
	check(main.grain_renderer._visual_ignition > 0.0 and main.grain_renderer._visual_ignition < 1.0,
		"ignition colour changed in one frame")
	if failures == 0:
		print("Visual field checks passed: stable counts, unchanged 720-column authority, exact mass and bounded draw budget.")
	quit(1 if failures else 0)
