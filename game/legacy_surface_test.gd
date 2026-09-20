extends SceneTree

const VoxelSystemScript := preload("res://core/voxel_system.gd")
const ElementsData := preload("res://core/elements.gd")

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true

func advance(system: VoxelSystemScript, seconds: float) -> void:
	for _tick in int(round(seconds * 60.0)):
		system.step(1.0 / 60.0)

func place(system: VoxelSystemScript, index: int, position: Vector2, velocity := Vector2.ZERO) -> void:
	system.positions[index] = position
	system.velocities[index] = velocity

func free_material() -> Dictionary:
	var data := ElementsData.HYDROGEN.duplicate()
	data.gravity_response = 0.0
	data.damping = 0.0
	return data

func finite_and_separated(system: VoxelSystemScript, tolerance := 0.05) -> bool:
	for index in system.count:
		var position := system.positions[index]
		if not check(is_finite(position.x) and is_finite(position.y), "non-finite grain coordinate"):
			return false
		if not check(position.length() >= system.collision_radius - tolerance, "grain crossed the core boundary"):
			return false
		for other in index:
			if not check(position.distance_to(system.positions[other]) >= system.grain_size - tolerance, "circular grains remained overlapped"):
				return false
	return true

func _initialize() -> void:
	# Gap filling uses three independently simulated circles. The arriving grain
	# reaches a real gap between supports, with no angular slot available to it.
	var gap: VoxelSystemScript = VoxelSystemScript.new(ElementsData.HYDROGEN)
	gap.spawn_grains(3)
	place(gap, 0, Vector2(-2.45, 42.94))
	place(gap, 1, Vector2(2.45, 42.94))
	place(gap, 2, Vector2(0.18, 53.0), Vector2(-0.4, -45.0))
	advance(gap, 0.65)
	if not finite_and_separated(gap): return
	if not check(abs(gap.positions[2].x) < 1.5 and gap.positions[2].length() < 46.0, "grain did not fill a gap between supports"):
		return

	# Contact does not create a frozen state: a quiet grain can roll sideways.
	var lateral: VoxelSystemScript = VoxelSystemScript.new(free_material())
	lateral.spawn_grains(1)
	place(lateral, 0, Vector2(0.0, lateral.collision_radius), Vector2(32.0, 0.0))
	lateral.step(1.0 / 30.0)
	if not check(lateral.positions[0].x > 0.7 and lateral.velocities[0].length() > 1.0, "contact grain lost lateral motion"):
		return

	# A later offset impact reactivates a grain that was previously quiet.
	var impact: VoxelSystemScript = VoxelSystemScript.new(free_material())
	impact.spawn_grains(2)
	place(impact, 0, Vector2(0.0, impact.collision_radius))
	advance(impact, 0.15)
	var resting_x := impact.positions[0].x
	place(impact, 1, Vector2(1.5, 54.0), Vector2(-5.0, -170.0))
	advance(impact, 0.12)
	if not finite_and_separated(impact): return
	if not check(abs(impact.positions[0].x - resting_x) > 0.08 or abs(impact.velocities[0].x) > 0.5, "impact did not move a quiet grain"):
		return

	# A free grain keeps an arbitrary world position; there are no terrain slots.
	var arbitrary: VoxelSystemScript = VoxelSystemScript.new(free_material())
	arbitrary.spawn_grains(1)
	var free_position := Vector2(73.37, 17.91)
	place(arbitrary, 0, free_position)
	advance(arbitrary, 0.2)
	if not check(arbitrary.positions[0].is_equal_approx(free_position), "free grain was snapped to a slot"):
		return

	# The cached list keeps a near-but-not-yet-contacting pair. They approach
	# inside the skin buffer before a rebuild is needed, then resolve normally.
	var buffered: VoxelSystemScript = VoxelSystemScript.new(free_material())
	buffered.spawn_grains(2)
	place(buffered, 0, Vector2(100.0, 0.0), Vector2(10.0, 0.0))
	place(buffered, 1, Vector2(102.7, 0.0), Vector2(-10.0, 0.0))
	buffered.step(1.0 / 60.0)
	if not check(buffered._pairs.size() == 1, "skin cache omitted an approaching non-contact pair"):
		return
	advance(buffered, 0.08)
	if not finite_and_separated(buffered): return

	# Moving existing public positions by more than the skin must rebuild the
	# cached candidates before resolving a new overlap.
	var moved: VoxelSystemScript = VoxelSystemScript.new(free_material())
	moved.spawn_grains(2)
	place(moved, 0, Vector2(100.0, 0.0))
	place(moved, 1, Vector2(108.0, 0.0))
	moved.step(1.0 / 60.0)
	if not check(moved._pairs.is_empty(), "distant pair entered the initial cache"):
		return
	place(moved, 1, Vector2(101.0, 0.0))
	moved.step(1.0 / 60.0)
	if not finite_and_separated(moved): return

	# Count changes invalidate a prebuilt list, so a newly spawned overlapping
	# grain cannot be hidden by an old one-particle cache.
	var spawned: VoxelSystemScript = VoxelSystemScript.new(free_material())
	spawned.spawn_grains(1)
	place(spawned, 0, Vector2(100.0, 0.0))
	spawned.step(1.0 / 60.0)
	spawned.spawn_grains(1)
	place(spawned, 1, Vector2(101.0, 0.0))
	spawned.step(1.0 / 60.0)
	if not finite_and_separated(spawned): return

	var boundary: VoxelSystemScript = VoxelSystemScript.new(free_material())
	boundary.spawn_grains(1)
	place(boundary, 0, Vector2.ZERO)
	boundary.step(1.0 / 60.0)
	if not check(boundary.positions[0].length() >= boundary.collision_radius - 0.001 and is_finite(boundary.positions[0].x), "core boundary failed at centre"):
		return
	# Two 2 px circles still exchange contact at an ordinary 300 px/s arrival.
	var fast: VoxelSystemScript = VoxelSystemScript.new(free_material())
	fast.spawn_grains(2)
	place(fast, 0, Vector2(100.0, 0.0))
	place(fast, 1, Vector2(105.0, 0.0), Vector2(-300.0, 0.0))
	advance(fast, 0.04)
	if not finite_and_separated(fast): return
	if not check(fast.positions[1].x > fast.positions[0].x, "300 px/s grain tunneled through a contact"):
		return
	for speed in [240.0, 330.0, 360.0]:
		var arrival: VoxelSystemScript = VoxelSystemScript.new(free_material())
		arrival.spawn_grains(2)
		# 4.3 px starts each impact between substep samples, avoiding a coincident
		# centre while still covering ordinary rapid arrivals.
		place(arrival, 0, Vector2(100.0, 0.0))
		place(arrival, 1, Vector2(104.3, 0.0), Vector2(-speed, 0.0))
		advance(arrival, 0.04)
		if not finite_and_separated(arrival): return
		if not check(arrival.positions[1].x > arrival.positions[0].x, "%.0f px/s grain tunneled through a non-coincident contact" % speed):
			return

	# The seven material knobs have distinct, observable circle-physics effects.
	var no_gravity_data := free_material()
	var gravity_data := free_material()
	gravity_data.gravity_response = 1.0
	var no_gravity: VoxelSystemScript = VoxelSystemScript.new(no_gravity_data)
	var gravity: VoxelSystemScript = VoxelSystemScript.new(gravity_data)
	no_gravity.spawn_grains(1)
	gravity.spawn_grains(1)
	place(no_gravity, 0, Vector2(100.0, 0.0))
	place(gravity, 0, Vector2(100.0, 0.0))
	advance(no_gravity, 0.25)
	advance(gravity, 0.25)
	if not check(gravity.positions[0].length() < no_gravity.positions[0].length() - 1.0, "gravity_response did not affect falling"):
		return
	var large_data := free_material()
	large_data.grain_size = 4.0
	var large: VoxelSystemScript = VoxelSystemScript.new(large_data)
	large.spawn_grains(2)
	place(large, 0, Vector2(0.0, large.collision_radius))
	place(large, 1, Vector2(0.0, large.collision_radius + 1.0))
	large.step(1.0 / 60.0)
	if not check(large.collision_radius > boundary.collision_radius and large.positions[0].distance_to(large.positions[1]) >= 3.94, "grain_size did not set diameter"):
		return
	var drag_data := free_material()
	drag_data.damping = 8.0
	var drag: VoxelSystemScript = VoxelSystemScript.new(drag_data)
	var no_drag: VoxelSystemScript = VoxelSystemScript.new(free_material())
	drag.spawn_grains(1)
	no_drag.spawn_grains(1)
	place(drag, 0, Vector2(100.0, 0.0), Vector2(80.0, 0.0))
	place(no_drag, 0, Vector2(100.0, 0.0), Vector2(80.0, 0.0))
	advance(drag, 0.2)
	advance(no_drag, 0.2)
	if not check(drag.velocities[0].length() < no_drag.velocities[0].length() - 20.0, "damping did not affect air drag"):
		return
	var rough_data := free_material()
	rough_data.repose_slope = 2.0
	rough_data.surface_friction = 0.9
	rough_data.flow_rate = 0.0
	var smooth_data := free_material()
	smooth_data.repose_slope = 0.0
	smooth_data.surface_friction = 0.0
	smooth_data.flow_rate = 1800.0
	var rough: VoxelSystemScript = VoxelSystemScript.new(rough_data)
	var smooth: VoxelSystemScript = VoxelSystemScript.new(smooth_data)
	rough.spawn_grains(1)
	smooth.spawn_grains(1)
	place(rough, 0, Vector2(0.0, rough.collision_radius), Vector2(40.0, 0.0))
	place(smooth, 0, Vector2(0.0, smooth.collision_radius), Vector2(40.0, 0.0))
	advance(rough, 0.3)
	advance(smooth, 0.3)
	if not check(smooth.positions[0].x > rough.positions[0].x + 2.0, "repose_slope, friction, and flow_rate did not affect rolling"):
		return
	var soft_data := free_material()
	soft_data.mass = 0.2
	soft_data.impact_spread = 0.0
	var lively_data := free_material()
	lively_data.mass = 8.0
	lively_data.impact_spread = 1.5
	var soft: VoxelSystemScript = VoxelSystemScript.new(soft_data)
	var lively: VoxelSystemScript = VoxelSystemScript.new(lively_data)
	for system in [soft, lively]:
		system.spawn_grains(2)
		place(system, 0, Vector2(100.0, 0.0))
		place(system, 1, Vector2(104.0, 0.0), Vector2(-100.0, 0.0))
	advance(soft, 0.04)
	advance(lively, 0.04)
	if not check(lively.velocities[1].x > soft.velocities[1].x + 5.0, "mass and impact_spread did not affect collision response"):
		return

	var whole: VoxelSystemScript = VoxelSystemScript.new(ElementsData.HYDROGEN)
	var split: VoxelSystemScript = VoxelSystemScript.new(ElementsData.HYDROGEN)
	whole.spawn_grains(1)
	split.spawn_grains(1)
	place(whole, 0, Vector2(120.0, 0.0), Vector2(-20.0, 3.0))
	place(split, 0, whole.positions[0], whole.velocities[0])
	whole.step(1.0 / 30.0)
	split.step(1.0 / 60.0)
	split.step(1.0 / 60.0)
	if not check(whole.positions[0].is_equal_approx(split.positions[0]) and whole.velocities[0].is_equal_approx(split.velocities[0]), "fixed stepping changed with frame chunking"):
		return

	# A dense circular pack exercises the broad phase and solver at the 1,200 cap.
	var full: VoxelSystemScript = VoxelSystemScript.new(ElementsData.HYDROGEN)
	full.spawn_grains(VoxelSystemScript.MAX_PARTICLES)
	var index := 0
	var ring := 0
	while index < full.count:
		var radius := full.collision_radius + float(ring) * 2.12
		var around := maxi(8, int(floor(TAU * radius / 2.12)))
		for point in around:
			if index >= full.count:
				break
			var angle := TAU * (float(point) + (0.5 if ring % 2 else 0.0)) / float(around)
			place(full, index, Vector2.RIGHT.rotated(angle) * radius)
			index += 1
		ring += 1
	# Dev mode raises capacity without changing the normal game cap.
	var dev: VoxelSystemScript = VoxelSystemScript.new(ElementsData.HYDROGEN, 10000)
	dev.spawn_grains(11000)
	if not check(dev.count == 10000 and dev.positions.size() == 10000, "dev capacity failed"):
		return
	dev.clear()
	if not check(dev.count == 0, "dev clear failed"):
		return
	var began := Time.get_ticks_usec()
	advance(full, 3.0)
	var elapsed_ms := float(Time.get_ticks_usec() - began) / 1000.0
	if not finite_and_separated(full, 0.12): return
	if not check(full.count == VoxelSystemScript.MAX_PARTICLES, "particle conservation failed at capacity"):
		return
	full.spawn_grains(10)
	if not check(full.count == VoxelSystemScript.MAX_PARTICLES, "particle cap failed"):
		return
	full.clear()
	if not check(full.count == 0 and full.settled_count == 0, "clear did not remove grains"):
		return
	full.spawn_hydrogen(1)
	if not check(full.count == 1, "spawn failed after clear"):
		return
	print("Voxeloid free-grain check passed: gap fill, lateral contact, impact reactivation, arbitrary centres, boundary, material knobs, fixed stepping, dense cap, and clear. 1200 grains / 3 s simulated in %.1f ms" % elapsed_ms)
	quit(0)
