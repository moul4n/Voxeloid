# Surface and particle model

[Living game design](GAME_DESIGN.md) defines the target game. This file describes the active aggregate simulation and remains authoritative for its technical limits.

The current model follows the scale-first direction in `particle-testing.zip`. That archive adds design research, not a completed Godot implementation. See `PARTICLE-MODEL-REVIEW.md`.

## Simulation

`game/core/material_field.gd` stores grain counts in 720 angular regions. Each region's area determines its outer radius, using grain diameter and pressure-dependent packing. There is no maximum surface height that discards excess mass. See [Compaction](COMPACTION.md) for weight, depth layers, and tuning.

The surface advances at 60 fixed steps per second. Neighbouring regions exchange mass according to height differences, resting slope, gravity response, flow rate, friction, and damping. A fixed-size implicit solve advances this downhill flow without the old small-transfer limit. It preserves nonnegative mass and corrects numerical round-off while conserving the total. This is dissipative settling rather than a full fluid-wave solver. The edge from the final region back to the first is part of the same calculation.

Incoming matter is stored in bounded batches, not arrays of individual positions. A batch reserves its grain count immediately, then settles progressively through an eased landing interval. Hydrogen arrivals through 10,000 grains retain the 0.55-second base interval. Larger batches scale that interval up to 2.2 times at 500,000 grains, capped at 68 percent of flight. Their deposition footprint grows to 3.1 times the material's normal arc and the global flow response is temporarily damped. This spreads a large load at the impact site instead of pulling a narrow spike from the whole ring. Repeated emissions in the same tick can merge. At the queue limit, later emissions merge into the last batch without losing their count. This makes arrival timing approximate when the queue is saturated.

## Drawing

The renderer allocates three MultiMeshes once: deposited grains, incoming grains, and a short-lived rim pool of at most 2,048 samples. Visible instances share a fixed 500,000-sample budget. Samples represent the material distribution; temporary rim grains overlap the deposited drawing during the handoff without adding logical matter. The full material count still determines surface volume, and flight sampling covers every batch rather than truncating the newest arrivals. Shaders calculate positions from instance IDs, small forward and reverse cumulative-mass textures, and batch information. Paired deposited samples use complementary quantiles so both begin in the same local area, then search those distributions in opposite directions as mass changes. A local influx therefore rebalances from both sides instead of sweeping predictably clockwise. There are no per-frame CPU loops or buffer uploads for every grain.

Deposited grain positions sample the field continuously. They move as its distribution changes, but they are not individually simulated collision bodies. Overlap can occur; there are no exact inter-grain gaps, caves, overhangs, or local material mixing. Hydrogen remains a small pale round disc with no complex shading.

Flight follows a fixed inward path from the sky, fading where the growing surface overtakes it and during landing. Recent impact regions draw a thin skin of small moving grains, which slide downhill slightly, sink and fade into the field. This is a bounded GPU visual handoff, not a new per-grain collision solver. Large arrivals still change the aggregate surface, but deposited sample positions no longer use instance index divided by changing count, avoiding a sweep from the angular seam.

Angular geometry now blends adjacent field columns in the settled and bulk shaders. The wrap between columns 719 and 0 uses the same interpolation. The CPU solver remains at 720 columns. Stable hashes from instance ID, field epoch and batch seed provide small differences in size, brightness, warmth, glow, trail length and animation phase. These values affect drawing only.

Two fixed visual pools handle larger arrivals. Up to 32 impact events draw short flashes and shock arcs. Up to 64 bonded patches draw seeded mounds that attach to the live surface and dissolve over 0.8 to 3 seconds. Patch vertices sample the live radius across their width, curving the base around the body. Settled grains draw over their feathered upper edge. One qualifying batch creates one event, nearby entries merge, and clear or epoch changes empty both pools. Their textures are 32 by 2 and 64 by 2 RGBA float images. They do not own mass or alter field heights. The rim remains capped at 2,048 samples inside the shared 500,000 grain budget; impact and patch pools are separate bounded effect instances.

## Material settings

| Setting | Current role |
| --- | --- |
| `mass` | Adds overburden weight and slows the response to a surface slope |
| `grain_size` | Disc diameter and material area per grain |
| `gravity_response` | Inward-flight duration, downhill-flow strength, and overburden weight |
| `repose_slope` | Slope threshold for strong sliding; a small creep rate keeps rough material moving below it |
| `surface_friction` | Resistance to downhill flow |
| `flow_rate` | Response strength of surface redistribution; zero disables flow |
| `damping` | Additional resistance to downhill flow |
| `impact_spread` | Arrival fan and deposition footprint width |

These are game parameters rather than a physical chemistry model. A simulation uses one profile. Dev mode clears the scene when selecting another element.

## Limits and checks

The stored capacity is 1,000,000,000 in both modes; rendering stays bounded at 500,000 samples. The dev release amount ranges from 10 to 500,000. C clears all incoming and deposited material, resets scheduling, and invalidates the renderer's field cache.

Run `surface_test.gd` for the active field model, `compaction_test.gd` for all four materials and pressure geometry, and `performance_test.gd` for rendered counts and timings. The former circle solver and `legacy_surface_test.gd` remain as references; their contact tests do not describe the new model. Heat, sealing, excavation, and progression remain outside this step.

Run `visual_field_test.gd` for the render-field invariants and `bonded_patch_test.gd` for event creation, seam merging, pool limits, count conservation and invalidation. `performance_test.gd -- --scenario=visual-stress --grains=500000` holds all 32 impact events and 64 patches active for the measured interval.

Impact loading uses a smooth start and finish to reduce whole-body jolts from concentrated bursts. Tune the base `impact_settle_seconds` per element: H 0.55, He 0.50, C 0.40 and Fe 0.35 seconds. Batch-size scaling starts above 10,000 grains, so ordinary input is unchanged. Friction and downhill flow retain their material settings after the temporary impact damping decays. `impact_response_test.gd` compares 0.2-second and 0.55-second base values on a 500,000-grain burst into 750,000 grains. The current wide-impact model measured peak per-tick radial changes of 76.580 and 21.213 world units respectively, with conserved mass.
