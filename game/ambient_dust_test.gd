extends SceneTree

const AmbientDust := preload("res://core/ambient_dust.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func make_dust(options: Dictionary, seed: int = 8127) -> RefCounted:
	return AmbientDust.new(options, seed)

func _low_surface(_angle: float) -> float:
	return 2.0

func _initialize() -> void:
	var no_mass := make_dust({
		"flux_per_second": 30.0,
		"minimum_speed": 600.0,
		"maximum_speed": 600.0,
		"lifetime_seconds": 20.0,
	})
	no_mass.set_bounds(Rect2(-100.0, -100.0, 200.0, 200.0))
	var no_mass_captures: Array[Dictionary] = no_mass.step(4.0, 0.0, 10.0)
	check(no_mass_captures.is_empty() and no_mass.captured_count == 0, "zero-mass body captured ambient dust")
	check(no_mass.escaped_count > 0, "unbound flybys did not escape the fixed world bounds")

	var high_speed_options := {
		"flux_per_second": 60.0,
		"base_direction": Vector2.RIGHT,
		"minimum_speed": 24000.0,
		"maximum_speed": 24000.0,
		"gravity_multiplier": 0.0,
		"capture_mass_scale": 1000.0,
	}
	var high_speed := make_dust(high_speed_options)
	high_speed.set_bounds(Rect2(-100.0, -2.0, 200.0, 4.0))
	var high_speed_captures: Array[Dictionary] = high_speed.step(1.0 / 60.0, 1000000000.0, 10.0)
	check(high_speed_captures.size() == 1 and high_speed_captures[0].amount == 1,
		"continuous segment test missed a high-speed surface crossing")
	check(high_speed.active_count == 0 and high_speed.captured_count == 1,
		"captured flyby remained available for duplicate reward")
	high_speed.config["flux_per_second"] = 0.0
	check(high_speed.step(1.0, 1000000000.0, 10.0).is_empty() and high_speed.captured_count == 1,
		"captured flyby awarded mass twice")

	var multiplier_zero := make_dust(high_speed_options.merged({"capture_multiplier": 0.0}, true))
	var multiplier_high := make_dust(high_speed_options.merged({"capture_multiplier": 1.0}, true))
	multiplier_zero.set_bounds(Rect2(-100.0, -2.0, 200.0, 4.0))
	multiplier_high.set_bounds(Rect2(-100.0, -2.0, 200.0, 4.0))
	check(multiplier_zero.step(1.0 / 60.0, 1000000000.0, 10.0).is_empty(), "zero capture multiplier still captured dust")
	check(multiplier_high.step(1.0 / 60.0, 1000000000.0, 10.0).size() == 1,
		"capture multiplier did not raise capture chance")
	var uneven_surface := make_dust(high_speed_options)
	uneven_surface.set_bounds(Rect2(-100.0, 3.0, 200.0, 4.0))
	var uneven_callable := Callable(self, "_low_surface")
	check(uneven_surface.step(1.0 / 60.0, 1000000000.0, 10.0, uneven_callable).is_empty(),
		"height sampler captured dust above a low surface sector")
	var interior_options := {"flux_per_second": 60.0, "base_direction": Vector2.RIGHT,
		"minimum_speed": 6000.0, "maximum_speed": 6000.0, "gravity_multiplier": 0.0,
		"capture_multiplier": 0.0}
	var interior := make_dust(interior_options)
	interior.set_bounds(Rect2(-100.0, -2.0, 300.0, 4.0))
	interior.step(1.0 / 60.0, 1000.0, 10.0)
	interior.step(1.0 / 60.0, 1000.0, 10.0)
	check(interior.capture_attempted[0] == 1 and interior.captured_count == 0,
		"mote inside the body was retried before exiting its surface")

	var near_options := {"flux_per_second": 60.0, "base_direction": Vector2.RIGHT,
		"minimum_speed": 90.0, "maximum_speed": 90.0}
	var near := make_dust(near_options)
	var far := make_dust(near_options)
	near.set_bounds(Rect2(-200.0, -50.0, 400.0, 100.0))
	far.set_bounds(Rect2(-2000.0, -50.0, 4000.0, 100.0))
	near.step(1.0 / 60.0, 1000.0, 1.0)
	far.step(1.0 / 60.0, 1000.0, 1.0)
	check(near.velocities[0].x > far.velocities[0].x, "softened inverse-square gravity did not weaken with distance")
	var weak_gravity := make_dust(near_options.merged({"gravity_multiplier": 0.0}, true))
	weak_gravity.set_bounds(Rect2(-200.0, -50.0, 400.0, 100.0))
	weak_gravity.step(1.0 / 60.0, 1000.0, 1.0)
	check(near.velocities[0].x > weak_gravity.velocities[0].x, "gravity multiplier did not change attraction")

	var standard_flux := make_dust({"flux_per_second": 24.0})
	var doubled_flux := make_dust({"flux_per_second": 24.0, "source_flux_multiplier": 2.0})
	standard_flux.step(1.0, 0.0, 0.0)
	doubled_flux.step(1.0, 0.0, 0.0)
	check(standard_flux.active_count == 24 and doubled_flux.active_count == 48, "source flux multiplier did not change emission rate")

	var bounded := make_dust({"flux_per_second": 1000000.0, "minimum_speed": 0.0,
		"maximum_speed": 0.0, "lifetime_seconds": 100.0})
	bounded.set_bounds(Rect2(-100000.0, -100000.0, 200000.0, 200000.0))
	bounded.prime(384)
	check(bounded.active_count == 384, "prime did not populate requested initial flybys")
	check(bounded.step(1.0, 0.0, 0.0).is_empty(), "primed motes produced rewards without a body")
	check(bounded.active_count == AmbientDust.POOL_CAPACITY, "dust pool exceeded its fixed capacity")
	bounded.reset()
	check(bounded.active_count == 0 and bounded.escaped_count == 0 and bounded.captured_count == 0,
		"reset did not clear dust and lifetime counters")
	bounded.prime(900)
	check(bounded.active_count == AmbientDust.POOL_CAPACITY, "prime did not respect pool capacity")

	if failures == 0:
		print("Ambient dust checks passed: zero-mass escape, mass capture, segment crossings, multipliers, bounded pool and reset.")
	quit(1 if failures else 0)
