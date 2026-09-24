# Surface and particle model

[Living game design](GAME_DESIGN.md) defines the target game. This file describes the active aggregate simulation and remains authoritative for its technical limits.

The current model follows the scale-first direction in `particle-testing.zip`. That archive adds design research, not a completed Godot implementation. See `PARTICLE-MODEL-REVIEW.md`.

## Simulation

`game/core/material_field.gd` stores grain counts in 720 angular regions. Each region's area determines its outer radius, using grain diameter and pressure-dependent packing. There is no maximum surface height that discards excess mass. See [Compaction](COMPACTION.md) for weight, depth layers, and tuning.

The surface advances at 60 fixed steps per second. Regions exchange mass according to height differences, resting slope, gravity response, flow rate, friction and damping. Hydrogen uses four bounded spatial scales of one, four, sixteen and thirty-two columns. The widest transfer spans sixteen degrees, so pressure can level a fluid shell promptly without solving the opposite side of the body in the impact tick. Positive-repose materials cross adjacent edges only and can retain a pile. Each pass limits its response and leaves at least half of a source column in place. The solver preserves nonnegative mass, corrects numerical round-off and includes the edge between columns 719 and 0. This is dissipative settling rather than a full fluid-wave solver.

Incoming matter is stored in bounded batches, not arrays of individual positions. A batch reserves its grain count immediately, then settles progressively through an eased landing interval. Hydrogen arrivals through 10,000 grains retain the 0.55-second base interval. Larger batches scale that interval up to 2.2 times at 500,000 grains, capped at 68 percent of flight. Their deposition footprint grows to 3.1 times the material's normal arc and the global flow response is temporarily damped. This spreads a large load at the impact site instead of pulling a narrow spike from the whole ring. Repeated emissions in the same tick can merge. At the queue limit, later emissions merge into the last batch without losing their count. This makes arrival timing approximate when the queue is saturated.

## Drawing

The renderer allocates three MultiMeshes once: deposited grains, incoming grains, and a short-lived contact pool of at most 256 samples. Visible instances share a fixed 500,000-sample budget. Contact samples reuse the incoming batch seed and local sample ID, then bounce, slide and sink against the live field surface. They do not own logical matter. One field landing schedule drives both the incoming fade and contact birth. The full material count still determines surface volume, and flight sampling covers every batch rather than truncating the newest arrivals. There are no per-frame CPU loops or buffer uploads for every stored grain.

Deposited grain positions sample the field continuously. Thin loose layers keep persistent local sample assignments for their full visible population. The first 256 settled samples stay pinned while the layer is sparse, so a later drop cannot replace or reposition an earlier visible grain. Samples transfer only when the authoritative column distribution changes, and new landing matter uses new identities before existing samples can move. Thin zero-repose material gradually softens its presentation weights after landing, making the low-density leading edge visible as it travels without accelerating the mass solver. When gameplay consumes loose matter, stable samples are selected proportionally around the field instead of truncating the newest side of the sample array. Reset or material changes invalidate the assignments. Neither drawing path uses independently simulated collision bodies. Overlap can occur; there are no exact inter-grain gaps, caves, overhangs, or local material mixing.

Dense loose matter now remains grain-first instead of switching to the former blurred circular fill. Persistent positions transition into dense distribution positions between 30,000 and 50,000 logical grains. Local packing progressively regularises size, enlarges contact and flattens each grain along the surface tangent. A second nonlinear range at high packing increases overlap again and converges colour variation, visually welding the deepest grains into an almost continuous mass. The low-pressure outer surface remains particulate. Consuming matter reverses both ranges. Neither range declares the material solid or ignited. Drawing uses the logical population up to the shared sample cap; above it, each sample grows to represent its share of the full population. The old edge-budget plus continuous-fill path remains available only through the comparison scene's `G` toggle while this candidate is reviewed. Both paths use the same radial lookup, so presentation does not change collision or conserved volume.

Sun ignition adds a separate reversible presentation mode; it does not remove or replace the granular renderer used by planets and pre-ignition bodies. Over roughly 2.2 seconds, loose dots fade into a liquid reservoir whose radius comes from the same exact uncommitted count, particle area and loose packing. The liquid view distributes that volume around the formed body instead of drawing the aggregate field's temporary one-sided impact pile. The authoritative 720-column masses remain unchanged. Incoming particles stay visible until contact, then the fixed contact pool, impact pool and graft pool switch to liquid contact, hot splash and inward-sink shapes. Fully hidden settled instances retire from the drawing budget.

The bulk mesh extent includes both the authoritative field height and the liquid reservoir radius. This prevents large molten reserves from clipping into a rounded square. The liquid shader combines slow morphing folds with finer counter-moving currents, eddy boundaries and hot threads. These extra structures affect colour only; they do not deform the conserved boundary or rotate the body.

The active stellar edge is the liquid radius while a reserve exists and the formed photosphere when it does not. The halo, prominence ribbons and long plume ejections use that same visual radius. Two-footpoint loops now carry a fine hot thread, smoothly interpolated flowing filaments and breathing roots in addition to their counter-streaming packets. A moving crest and shallow turbulent aura remain on the exposed edge after player feeding empties the liquid reserve. A separate wavy transition band bridges the formed body and liquid reservoir while both exist. Its heat pattern and the formed-zone boundaries circulate very slowly in counter-directions, producing local shear without rotating the body or changing its outline.

The molten reservoir remains logical loose matter. Forming a body layer still requires the existing player action, and feeding the Player Core consumes it through the existing proportional `consume_loose()` path. Large hot impacts extend the local visual flare for at most four seconds; they do not grant heat, ignition, production or extra mass.

Flight follows a fixed inward path from the sky, fading where the growing surface overtakes it and during landing. Recent impact regions draw a thin skin of small moving grains, which slide downhill slightly, sink and fade into the field. This is a bounded GPU visual handoff, not a new per-grain collision solver. Large arrivals still change the aggregate surface, but deposited sample positions no longer use instance index divided by changing count, avoiding a sweep from the angular seam.

Angular geometry now blends adjacent field columns in the settled and bulk shaders. The wrap between columns 719 and 0 uses the same interpolation. The CPU solver remains at 720 columns. Stable hashes from instance ID, field epoch and batch seed provide small differences in size, brightness, warmth, glow, trail length and animation phase. These values affect drawing only.

Two fixed visual pools handle larger arrivals. Up to 32 impact events draw short flashes and shock arcs. Up to 64 bonded patches draw seeded mounds that attach to the live surface and dissolve over 0.8 to 3 seconds. Patch vertices sample the live radius across their width, curving the base around the body. Settled grains draw over their feathered upper edge. One qualifying batch creates one event, nearby entries merge, and clear or epoch changes empty both pools. Their textures are 32 by 2 and 64 by 2 RGBA float images. They do not own mass or alter field heights. The contact pool is capped at 256 samples inside the shared 500,000 grain budget; impact and patch pools are separate bounded effect instances.

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

Run rendered `surface_locality_test.gd` for persistent thin-layer assignments. The headless rendering backend does not preserve MultiMesh custom data, so this check requires a rendered Compatibility run.

Impact loading uses a smooth start and finish to reduce jolts from concentrated bursts. Tune the base `impact_settle_seconds` per element: H 0.55, He 0.50, C 0.40 and Fe 0.35 seconds. Batch-size scaling starts above 10,000 grains, so ordinary input is unchanged. Friction and downhill flow retain their material settings after the temporary impact damping decays. `impact_response_test.gd` compares 0.2-second and 0.55-second base values on a 500,000-grain burst into 750,000 grains. With the four-scale local-flow candidate, the measured peak per-tick radial changes were 92.575 and 26.751 world units respectively, with conserved mass. These are CPU correctness results from the development machine, not a visual approval or weak-hardware benchmark.
