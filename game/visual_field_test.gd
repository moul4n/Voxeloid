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
	if failures == 0:
		print("Visual field checks passed: stable counts, unchanged 720-column authority, exact mass and bounded draw budget.")
	quit(1 if failures else 0)
