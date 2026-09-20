# Initial project evaluation

Reviewed on 2026-09-19. Extracted `.ignore/voxeloid.zip` into `scratch/voxbench`. The archive and extracted source files were left unchanged.

## Verdict

Keep this as the rendering and measurement starting point. It is a small benchmark project, not a playable game. It has 8 GDScript files with 930 lines, one scene, one shader, and 5 Python tools with 760 lines. The extraction contains 106 files.

The strongest parts are the separation of rendering from measurement, reusable debris assets, seeded random generation, and command-line benchmark controls. The performance claims still need a real GPU run. Gameplay systems described in the design documents are mostly absent.

## What exists

- A Godot 4.4 project using the Compatibility renderer.
- MultiMesh debris rendering with GPU and CPU movement paths, a machine rig, and a separate actor stress test.
- Scenario controls, an overlay, CSV capture, JSON summaries, and a comparison tool.
- 64 voxel debris assets, a baked sprite atlas, and a software baking tool. The Blender backend is a stub.
- Python models for growth curves and buff combinations.
- Design documents covering material collection, eating or sealing layers, merging, heat, stars, worlds, and life.

The Python simulations are separate tools. They are not implemented game systems.

## Findings to fix before trusting the benchmark

These findings come from code inspection unless a test is stated.

1. **Repeated runs can overwrite results.** `voxbench/core/metrics.gd:142` builds IDs using the minute, scenario, and Git hash. Two captures of the same scenario in one minute write the same files. Use a unique capture ID and check write errors. The writer currently prints success even if opening the files failed.
2. **Controls can invalidate a capture.** `voxbench/bench/stress.gd:68` and `:73` start a new run without finalising an active recording. The next `Metrics.start()` resets its samples. Controls at `:175-203` also allow renderer, density, and effects changes during capture without updating the starting metadata. Lock measured runs or record changes and mark the capture invalid. Define explicit cancellation behaviour.
3. **Empty recordings can pass.** `voxbench/core/metrics.gd:108-110` returns zero timing values when no samples remain. `:100` treats that zero p99 as a pass. Require a minimum sample count and capture duration.
4. **A seed does not identify a repeatable scenario by itself.** `voxbench/core/seeded_rng.gd:13` seeds once at startup. Starting another scenario does not reset it. Workload generation also depends on frame updates. Record the run sequence or reset scenario streams and use a defined spawn schedule where repeatability matters.
5. **The comparison tool can accept unsuitable results.** `voxbench/tools/compare.py:60-74` bases its exit status only on a relative p99 increase. Missing values bypass the regression check, and a failed absolute performance target can still produce an `ok` verdict. Validate samples and distinguish regression status from the absolute performance target. Reject or flag incompatible run settings.

Lower priority: negative swarm capacity is not clamped at `voxbench/render/swarm.gd:50`. Bundled scenarios use positive values, so this is a future configuration validation issue.

The review also checked a suspected directory API problem and rejected it. Godot supports `user://` paths in these APIs. See the [Godot 4.4 DirAccess reference](https://docs.godotengine.org/en/4.4/classes/class_diraccess.html).

## Gap between the benchmark and the game

The current shader applies downward acceleration and a floor response. The newer game design needs movement around a centre, inward and outward matter flows, camera zoom, and settled rings. Those workloads need their own benchmark scenarios. The design's suggestion that radial gravity is only a few lines should not be treated as an implementation estimate. The current GPU path derives position directly from age; ongoing attraction towards a centre needs an explicit motion model.

Player interaction, material inventories, eat/seal decisions, layer merging, heat rules, progression, save/load, and the full game interface still need implementation. The older speed document describes short runs, while the newer design describes runs lasting 45 to 90 minutes. Treat `docs/voxeloid-design.html` as the provisional design authority and resolve conflicts before implementing progression.

## Checks completed

- All five Python files passed syntax parsing.
- All bundled JSON files parsed.
- Literal resource path checking found no missing game assets. Missing `.git` paths are expected for this extracted archive.
- `tools/curve.py` completed successfully.
- `tools/buildsim.py --runs 100 --exhaustive-k 2` completed successfully. This was a smoke check, not a balance study.
- `tools/compare.py --bench docs/sample-runs --all` completed successfully and read both supplied samples.
- The supplied samples are labelled headless and both have `pass: false`. They establish output format only.

Godot was not found in PATH or the checked installation locations. No local engine import, GDScript compile, shader compile, visual check, or GPU performance measurement was completed. This review does not certify that the project runs locally.

## Suggested build order

1. Establish a version-controlled working project outside the scratch baseline. Confirm the Godot version and import it. Fix capture integrity and exercise both rendering paths. Store real GPU baselines with hardware and settings recorded.
2. Build one short playable loop. Move the machine, collect one material, and choose to eat or seal it. Show mass and the resulting ring. Use this to test whether the central decision is enjoyable before adding long progression.
3. Add inward and outward matter movement, bounded camera zoom, and ring merging. Benchmark the busiest middle stage of a world. Decide which moving items need gameplay state and which are visual debris.
4. Add heat, material combinations, upgrades, and save/load. Test deterministic rule calculations separately from rendering.
5. Expand into star ignition, world runs, and life only after the short loop holds up in playtests.

The next implementation milestone should be a reliable benchmark plus the smallest playable eat/seal loop. Building all three acts now would commit too much work before the central mechanic has been tested.
