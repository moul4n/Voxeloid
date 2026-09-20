# Surface and particle model

[Living game design](GAME_DESIGN.md) defines the target game. This file describes the active aggregate simulation and remains authoritative for its technical limits.

The current model follows the scale-first direction in `particle-testing.zip`. That archive adds design research, not a completed Godot implementation. See `PARTICLE-MODEL-REVIEW.md`.

## Simulation

`game/core/material_field.gd` stores grain counts in 720 angular regions. Each region's area determines its outer radius, using grain diameter and pressure-dependent packing. There is no maximum surface height that discards excess mass. See [Compaction](COMPACTION.md) for weight, depth layers, and tuning.

The surface advances at 60 fixed steps per second. Neighbouring regions exchange mass according to height differences, resting slope, gravity response, flow rate, friction, and damping. A fixed-size implicit solve advances this downhill flow without the old small-transfer limit. It preserves nonnegative mass and corrects numerical round-off while conserving the total. This is dissipative settling rather than a full fluid-wave solver. The edge from the final region back to the first is part of the same calculation.

Incoming matter is stored in bounded batches, not arrays of individual positions. A batch reserves its grain count immediately, then settles progressively through an eased landing interval (Hydrogen: 0.55 seconds, capped at 35% of flight). Repeated emissions in the same tick can merge. At the queue limit, later emissions merge into the last batch without losing their count. This makes arrival timing approximate when the queue is saturated.

## Drawing

The renderer allocates three MultiMeshes once: deposited grains, incoming grains, and a short-lived rim pool of at most 2,048 samples. Visible instances share a fixed 500,000-sample budget. Samples represent the material distribution; temporary rim grains overlap the deposited drawing during the handoff without adding logical matter. The full material count still determines surface volume, and flight sampling covers every batch rather than truncating the newest arrivals. Shaders calculate positions from instance IDs, a small cumulative-mass texture, and batch information. There are no per-frame CPU loops or buffer uploads for every grain.

Deposited grain positions sample the field continuously. They move as its distribution changes, but they are not individually simulated collision bodies. Overlap can occur; there are no exact inter-grain gaps, caves, overhangs, or local material mixing. Hydrogen remains a small pale round disc with no complex shading.

Flight follows a fixed inward path from the sky, fading where the growing surface overtakes it and during landing. Recent impact regions draw a thin skin of small moving grains, which slide downhill slightly, sink and fade into the field. This is a bounded GPU visual handoff, not a new per-grain collision solver. Large arrivals still change the aggregate surface, but deposited sample positions no longer use instance index divided by changing count, avoiding a sweep from the angular seam.

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

Impact loading uses a smooth start and finish to reduce whole-body jolts from concentrated bursts. Tune `impact_settle_seconds` per element: H 0.55, He 0.50, C 0.40 and Fe 0.35 seconds. Friction and downhill flow retain their existing settings. `impact_response_test.gd` compares a 0.2-second and 0.55-second eased landing onto 750,000 grains; a 500,000-grain burst reduced the largest per-tick radial change from 192.214 to 49.693 world units, with conserved mass.
