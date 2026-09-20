extends SceneTree

const VoxelSystemScript := preload("res://core/material_field.gd")
const ElementsScript := preload("res://core/elements.gd")

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game_script: Script = load("res://main.gd")
	if not check(game_script != null, "main script failed to load"): return
	if not check(game_script.can_instantiate(), "main script failed to compile"): return
	var game: Node2D = game_script.new()
	root.add_child(game)
	var system: VoxelSystemScript = game.get("voxels") as VoxelSystemScript
	if not check(system != null, "voxel system did not initialise"): return
	if not check(system.count == 0, "the scene should start empty"): return
	if not check(ElementsScript.HYDROGEN.cells.size() == 1, "hydrogen should use exactly one voxel cell"): return

	system.spawn_hydrogen(-4)
	if not check(system.count == 0, "negative spawn amount should do nothing"): return
	system.spawn_hydrogen(1)
	if not check(system.count == 1, "one click should create one hydrogen voxel"): return
	if not check(system.batches.size() == 1 and system.settled_count == 0, "new matter should start incoming"): return
	var arrival: Dictionary = system.batches[0]
	if not check(arrival.start_radius > arrival.end_radius and arrival.duration > 0.0, "arrival should move inward"): return
	for tick in 180:
		system.step(1.0 / 60.0)
	if not check(system.settled_count == 1 and absf(system.total_mass() - 1.0) < 0.0001, "arrival should deposit exactly once"): return
	for height in system.heights:
		if not check(is_finite(height) and height >= VoxelSystemScript.PLAYER_RADIUS, "surface crossed the core boundary"): return
	game.set("camera_pan", Vector2(180.0, -90.0))
	game.set("zoom_level", 1.8)
	game.call("reset_view")
	if not check(game.get("camera_pan") == Vector2.ZERO and is_equal_approx(game.get("zoom_level"), 1.0), "reset view should restore pan and zoom"): return
	if not check(system.count == 1, "reset view should preserve matter"): return

	system.spawn_hydrogen(VoxelSystemScript.MAX_PARTICLES)
	if not check(system.count == VoxelSystemScript.MAX_PARTICLES, "particle count should stop at the fixed capacity"): return
	system.spawn_hydrogen(10)
	if not check(system.count == VoxelSystemScript.MAX_PARTICLES, "particle count should stay capped"): return
	print("Voxeloid smoke check passed: initial state, scheduled arrivals, mass, core boundary, reset, and cap")
	quit(0)
