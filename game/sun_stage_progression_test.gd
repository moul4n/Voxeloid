extends SceneTree

const MainScene := preload("res://main.tscn")
const Catalog := preload("res://progression/first_matter_catalog.gd")
const Director := preload("res://progression/progression_director.gd")
const Registry := preload("res://progression/metric_registry.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var registry := Registry.new()
	var director := Director.new(Catalog.create(), registry)
	for pair in [
		[&"mass.total_gathered", 6000.0], [&"mass.body", 6000.0], [&"mass.core", 20.0],
		[&"core.level", 1.0], [&"capture.ambient_total", 1.0], [&"mass.loose", 6000.0],
		[&"body.compactions", 1.0], [&"body.smu", 6.14],
	]:
		director.set_metric(pair[0], pair[1])
	director.evaluate()
	check(director.current_objective().objective_id == &"sun.gather_layer_2", "progression stopped after First Matter")
	director.set_metric(&"mass.loose", 12600.0)
	director.evaluate()
	check(director.current_objective().objective_id == &"sun.compact_layer_2", "second layer did not move from gathering to compaction")
	director.set_metric(&"body.compactions", 2.0)
	director.set_metric(&"mass.loose", 0.0)
	director.set_metric(&"body.smu", 19.0)
	director.evaluate()
	check(director.current_objective().objective_id == &"sun.gather_layer_3", "second compact did not open the third layer")
	director.set_metric(&"mass.loose", 26460.0)
	director.evaluate()
	director.set_metric(&"body.compactions", 3.0)
	director.set_metric(&"body.smu", 46.0)
	director.evaluate()
	check(director.current_objective().objective_id == &"sun.first_ignition", "third compact did not begin the ignition stage")
	director.set_metric(&"body.smu", 75.0)
	director.evaluate()
	check(director.current_objective().objective_id == &"sun.gather_layer_4", "ignition did not continue into stellar growth")

	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	check(main.core_talent_tree.grant(&"automatic_invocation"), "could not prepare Flow for compact boost")
	check(main.core_talent_tree.grant(&"resonant_pull"), "could not prepare Pull for compact boost")
	main.voxels.seed_uniform(6000)
	check(main.voxels.form_core_layer(), "first layer could not compact for talent boost")
	check(is_equal_approx(main._compaction_power(), 1.45), "first compact did not expose its production multiplier")
	check(is_equal_approx(main.core_talent_tree.automatic_rate(main._compaction_power()), 1.45), "compact did not boost Flow")
	check(is_equal_approx(main.core_talent_tree.manual_yield_multiplier(main._compaction_power()), 1.2175), "compact did not boost Pull")
	if failures == 0:
		print("Sun stage checks passed: post-First-Matter quests, ignition handoff and compaction talent boost.")
	quit(1 if failures else 0)
