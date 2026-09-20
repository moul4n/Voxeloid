# Voxeloid

A Godot game about gathering matter around a central player in a radial cutaway view.

[Living game design](GAME_DESIGN.md) is the authority for planned mechanics and pacing. This file reports the current implementation. [Progression model](PROGRESSION_MODEL.md) holds the coarse campaign envelope. [First Sun balance](SUN_BALANCE.md) contains the detailed planning model; [Sun progression](SUN_PHASE.md) records the different values currently wired into Godot.

## Project files

- `game/` is the active project. `start.bat` launches it; `start-dev.bat` enables testing controls.
- `godot.local.txt` or `GODOT_EXE` selects the installed engine. The configured version is Godot 4.7.2.
- `docs/SKILL.md` contains the user's writing guide. Root `AGENTS.md` records startup instructions.
- `scratch/voxbench` preserves the original archive. `scratch/particle-testing/voxbench` preserves the new particle research archive. See `scratch/EVALUATION.md` and `docs/PARTICLE-MODEL-REVIEW.md`.

## Current model

The player is a round placeholder. The foreground black orb releases hydrogen from the upper right. Normal play exposes hydrogen; dev mode also exposes the existing helium, carbon, and iron profiles.

The active model stores up to 1,000,000,000 grains. Drawing uses a shared budget of 500,000 representative samples, so a billion-grain count does not allocate a billion instances. `core/material_field.gd` stores mass in 720 circular surface regions and redistributes it according to the selected material. Incoming batches settle progressively through an eased interval (0.55 seconds for Hydrogen). A thin animated rim layer fades those arrivals into the deposited field. `core/field_renderer.gd` and its shaders sample the full incoming and deposited distributions on the GPU, without per-grain CPU integration or contact checks. Up to the drawing budget, grains retain individual instances; above it, samples represent groups of grains.

This replaces the earlier circle-collision solver. Settled positions sample the material field rather than represent independent collision bodies. Local overlap and arrivals are approximate. Material flows toward neighbouring regions with lower radial height. Hydrogen spreads around the core; rough profiles retain steeper slopes. Arrivals remain scheduled approximations. See `docs/SURFACE.md` for the model and limits. The previous solver remains in `core/voxel_system.gd`, with `legacy_surface_test.gd`, for reference.

Element parameters remain in `core/elements.gd`. The current simulation uses one element at a time. Sealing, heat, element fusion, mixed materials, purchase progression, ambient flybys, saves, caves, and overhangs are not implemented.

The player core is separate from the planet or sun's body. Body matter now occupies a core, inner mantle, outer mantle and shallow crust/surface. Outer compaction remains manual. Inner densification transfers 90 percent of the current body core into a denser core, with 10 percent of the consumed portion's area, and preserves residual matter in surrounding layers. Only the converting section shudders and flickers. Layer sizes, mass thresholds, residual splits and labels are profile settings.

The inner automation upgrade has a callable unlock and on/off switch. Normal purchases await progression costs; dev Ctrl-click grants it free. It advances only at new collected-mass milestones and never binds loose outer material. `consume_loose(amount)` is the construction spending hook and cannot consume incoming or bound matter. Player automation settings survive clear and element changes.

Nested-layer validation passed: conservation, 90/10 area split, four separate rings, shallow surface retention, animated radii matching the body boundary, local pulses, automation milestones, loose-only spending, UI gating and dev unlock. Existing core, compaction, smoke, dev-control and rendered seam checks also passed. The new ratios and milestones remain provisional game settings.

All four demo elements now support pressure compaction and retain their existing friction and flow settings. Small creep rates prevent helium, carbon, and iron from stalling at flat contacts. Deeper grains pack more tightly under the weight above them, with three adjustable pressure stages and a compression tint. See [Compaction](COMPACTION.md) for the settings and current limits.

Dense loose interiors now merge into a continuous colour fill, visible at 750,000 hydrogen grains. Labelled range rings extend as the camera zooms out. The Compact outer matter button binds existing matter into a permanent solid shell only after an explicit click and readiness checks. Dev Ctrl-click bypasses those checks but still needs material. Clear and element changes reset formed layers too.

Layer formation now contracts the consumed material to 10 percent of its measured pre-conversion area over 1.4 seconds. A damped shudder and gentle brightness flicker accompany the shrinking boundary, and outer grains follow it inward. Counts remain unchanged. Ratio and duration are per-element settings. Rendering also wraps the angular texture index at three o'clock to prevent an out-of-range sample at the circular seam. Rendered seam scans, animation captures, core conservation checks, UI checks, and startup smoke tests passed.

## Controls

- Click the black orb to release one grain; hold to continue.
- Right-drag to pan. Wheel outside the orb to zoom, including wider views for large populations.
- R resets the camera while preserving matter. C clears matter.
- In dev mode, Ctrl-click the orb selects an element and clears the scene. Ctrl-wheel changes the release amount from 10 to 500,000 per click and per second held. Larger scroll steps apply above 10,000. See `docs/DEVELOPMENT.md`.

Clicking and holding are both intended manual inputs for the early game. Automatic Invocation later replaces repeated input as the main source.

## Progression maths

The standalone Python model covers the Sun and five planned planets. Its current deterministic envelope is 7:47:52 for a focused route and 12:09:45 for a conservative route. Automatic production overtakes the configured manual rate at 0:26 and 1:52 respectively. The focused first compact lands at 12:17. These are balance targets, not implemented game progression.

Run `python -B tools/progression_model.py` for the summary or see [Progression model](PROGRESSION_MODEL.md) for assumptions and limits.

The newer planning-only Sun model calculates 45:53:43 for one click per second with no upgrades, 5:25:50 for holding at nine activations per second with no upgrades, and 2:15:40 for the automation-first route. It now models helium discovery, an unlocked 75/25 hydrogen/helium singularity mix, and separate passive helium production for cool, balanced and hot stars. The live scene shares its layer curve but does not yet run its production, talent or helium rules. See [First Sun balance](SUN_BALANCE.md).

## Checks

[Ambient dust](AMBIENT_DUST.md) is active in the live scene, with directional drift, gravitational deflection, exact loose-material capture and external supply/capture/gravity hooks. A fixed pool shares the existing rendering limit. The visual pass adds a precomputed space backdrop, layer relief and colour-tinted solar halo/prominences; body spin remains locked off.

The playable scene now enables [Sun progression](SUN_PHASE.md): seven manual mass-gated compactions, separate player assimilation, stellar zone labels, thermal colour/texture progression and compact Sun/player HUD panels. Requirements live in `core/sun_progression.gd`; generic field tests keep the earlier planet settings. Production rewards and helium eligibility are recorded, while talents, fusion chemistry, spin unlocks and the final capstone remain deferred. Player temperature is an independent 300 K placeholder.

Sun progression and rendered HUD tests passed on September 20, alongside pressure compaction, generic core/nested layers, arrival, surface and smoke checks. Captures cover the empty scene, seed, ignition and solar target. This validates state and rendering, not scientific heat transport or gameplay pacing.

From the repository root:

```bat
start.bat --headless --editor --import --quit
start.bat --headless --script res://smoke_test.gd
start.bat --headless --script res://surface_test.gd
start.bat --headless --script res://ambient_dust_test.gd
start.bat --script res://ambient_integration_test.gd
start.bat --headless --script res://sun_progression_test.gd
start.bat --script res://sun_ui_test.gd
start.bat --headless --script res://impact_response_test.gd
start.bat --headless --script res://compaction_test.gd
start.bat --headless --script res://core_layer_test.gd
start.bat --headless --script res://nested_layer_test.gd
start.bat --script res://nested_layer_ui_test.gd
start.bat --script res://layer_ui_test.gd
start.bat --script res://arrival_rim_test.gd
start-dev.bat --headless --script res://dev_test.gd
start.bat --script res://performance_test.gd -- --grains=500000 --capture
start.bat --script res://performance_test.gd -- --grains=100000 --scenario=flow
start.bat --script res://performance_test.gd -- --grains=500000 --scenario=flight
python -B tools/sun_model.py
python -B -m unittest discover -s tools -p "test_*model.py" -v
```

`surface_test.gd` runs the new field tests: conservation, capacity, arrivals, clear, periodic edges, material flow, fixed time steps, and footprint tuning. Smoke and rendered input checks cover startup, camera, spawning, developer controls, and reset. Images and logs are in ignored `scratch/checks/`.

Arrival checks cover a 500,000-grain burst onto 750,000 deposited grains: gradual landing, visible rim motion, exact counts, shared drawing cap, fading and reset. Stable surface sampling removes the angular birth seam. Bulk fill uses mesh coordinates so uneven deposits align with their grains. On September 20, a separate rendered 750,000-grain flow check at zoom 0.334 drew 500,000 samples, averaging 417 FPS over three seconds (95th-percentile frame time 7.327 ms). That timing covers deposited flow, not the peak arrival effect.

On September 20, 2026, rendered tests on the local RTX 4070 used Compatibility, VSync off, at least one second of warmup and three seconds of measurement:

| Scenario | GPU instances | Average FPS | 95th-percentile frame |
| --- | ---: | ---: | ---: |
| Uniform deposited hydrogen | 100,000 | 718 | 2.23 ms |
| Uniform deposited hydrogen | 500,000 | 739 | 2.19 ms |
| Sustained incoming hydrogen | 500,000 | 707 | 2.12 ms |

The deposited benchmarks fit the complete surface in the view, at zoom 0.899 and 0.404 respectively. The incoming test deliberately lowers gravity response to keep every grain airborne for the measurement. These are short local checks, not guarantees for every material, arrival shape, zoom, machine, or long session. The renderer reported the full instance counts; screenshots confirmed actual drawn material. Uneven-arrival tests preserved mass, but some material extended outside the viewport, so their FPS is not used as proof that every grain was on screen.

The benchmark also supports `--physics-off` for drawing alone and `--manual-step` for per-step CPU timing. Manual-step FPS does not represent normal play. Scoped test runs use process-local `APPDATA=scratch/checks/appdata`.

After the cap and flow changes, a rendered settled test with one billion logical grains and 500,000 visible samples averaged 716 FPS, with a 2.44 ms 95th-percentile frame, at zoom 0.009. Those counts have different meanings; this is not a billion independently simulated or drawn bodies. The earlier table records the previous version.

With compaction enabled, the flow regression releases 500,000 hydrogen grains from one side. After six simulated seconds, the smallest and largest surface radii are 787.07 and 790.71; after twelve seconds both are approximately 788.89. Total material stays at 500,000. A continuing source can maintain a temporary mound, which levels after feeding stops. Hydrogen has zero resting slope so it pools around the core; rougher elements retain their own slope thresholds and slow creep. Smoke, surface, compaction, and maximum dev click/hold checks pass.

Compaction rendered checks on the same machine averaged 513 FPS for the 500,000-grain flow scenario at zoom 0.389, with a 6.93 ms 95th-percentile frame. One billion settled logical grains using 500,000 samples averaged 743 FPS at zoom 0.010, with a 2.38 ms 95th-percentile frame. These are short local measurements. Screenshots checked hydrogen, helium, carbon, and iron at 10,000 and 500,000 grains, plus the billion-grain view.

After the continuous-fill and manual-layer changes, a rendered 750,000-grain settled check averaged 680 FPS, with a 2.52 ms 95th-percentile frame at zoom 0.334 and 500,000 grain samples. Layer, UI, surface, compaction, smoke, and dev-control checks pass. The UI test verifies drawing coverage across 100,000, 750,000, and one billion logical grains at close and distant zoom.

## Art tools

Blender 5.2.0 LTS is installed at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. Keep the current player placeholder until art work is requested.

The live Sun now uses the detailed Sun balance: 6,000 through 514,597 logical mass across seven layers, ignition at 75 SMU and player cap 15. Manual outer actions reveal the four interior zones without first requiring inner densification. Layer-specific texture, local conversion threads and a balanced yellow-white palette were checked through the actual main scene, alongside core/nested controls and arrival checks. Root launchers both target this project. See SUN_PHASE.md for the current rules and retained placeholders.

Warm early particles and colour-tinted glow are now active. Folded core filaments, radiative ribbons and drifting convection granules distinguish compressed zones. The generator ring follows material colour; Sun highlights stay amber and player highlights teal. Rendered Sun checks passed for early particles, conversion and the finished body. Two compaction buttons remain intentional: next outer layer versus existing core compression.
