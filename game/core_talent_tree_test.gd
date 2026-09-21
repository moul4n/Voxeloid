extends SceneTree

const CoreTalentTree := preload("res://progression/core_talent_tree.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var tree := CoreTalentTree.new()
	check(tree.available_points(1) == 1, "first Core level did not grant a talent point")
	check(not tree.buy(&"rapid_recovery", 1, 20.0), "Faster Flow was available before automatic calling")
	check(not tree.buy(&"resonant_pull", 1, 20.0), "Stronger Pull was available before the guided Flow pick")
	check(tree.buy(&"automatic_invocation", 1, 20.0), "first point could not buy Automatic Invocation")
	check(is_equal_approx(tree.automatic_rate(), 1.0), "Automatic Invocation did not start at one call per second")
	check(tree.available_points(1) == 0, "spent point remained available")
	check(not tree.buy(&"efficient_assimilation", 3, 20.0), "tier gate ignored gathered matter")
	check(tree.buy(&"resonant_pull", 3, 56.0), "second low-tier point could not be spent")
	check(tree.is_tier_open(1, 56.0), "second tier did not open after two spent points")
	check(not tree.buy(&"efficient_assimilation", 3, 56.0), "planned-only talent accepted a point")
	check(tree.manual_yield_multiplier() > 1.0, "Resonant Pull did not improve manual yield")
	var stacked := CoreTalentTree.new()
	for rank_index in 10:
		check(stacked.buy(&"automatic_invocation", 10, 100000.0), "Gentle Current stopped before rank 10")
	check(not stacked.buy(&"automatic_invocation", 11, 100000.0), "Gentle Current exceeded rank 10")
	check(is_equal_approx(stacked.automatic_rate(), 10.0), "stacked Gentle Current did not add one call per rank")
	var pull := CoreTalentTree.new()
	check(pull.buy(&"automatic_invocation", 11, 100000.0), "Stronger Pull setup could not unlock Flow")
	for rank_index in 10:
		check(pull.buy(&"resonant_pull", 11, 100000.0), "Stronger Pull stopped before rank 10")
	check(is_equal_approx(pull.manual_yield_multiplier(), 2.5), "rank 10 Stronger Pull has the wrong yield")
	var speed := CoreTalentTree.new()
	check(speed.buy(&"automatic_invocation", 11, 100000.0), "Faster Flow setup could not unlock automatic calling")
	for rank_index in 10:
		check(speed.buy(&"rapid_recovery", 11, 100000.0), "Faster Flow stopped before rank 10")
	check(is_equal_approx(speed.automatic_rate(), pow(1.6, 10)), "rank 10 Faster Flow has the wrong rate")
	var compacted := CoreTalentTree.new()
	check(compacted.buy(&"automatic_invocation", 2, 100.0), "compaction boost setup could not buy Flow")
	check(compacted.buy(&"resonant_pull", 2, 100.0), "compaction boost setup could not buy Pull")
	check(is_equal_approx(compacted.automatic_rate(1.45), 1.45), "first compact did not strengthen Flow")
	check(is_equal_approx(compacted.manual_yield_multiplier(1.45), 1.2175), "first compact did not strengthen Pull")
	if failures == 0:
		print("Core talent tree checks passed: points, tier gates, automatic calls and manual yield.")
	quit(1 if failures else 0)
