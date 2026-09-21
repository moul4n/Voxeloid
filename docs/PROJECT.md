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

The renderer now blends neighbouring angular columns, so the 720-region simulation does not draw hard pie sections. Particles use stable shader variation for size, tint, selective local halo and incoming trails. The rim has several hashed sink, slide, bounce and spark motions. Large arrivals create one bounded impact event and one bonded patch when landing begins. Patch bases curve along the live body and settled grains cover their feathered upper edges. Arrivals above 10,000 grains gain a wider footprint, longer landing and temporary global-flow damping, reducing inward puckering. The pools hold at most 32 impacts and 64 patches, stay attached to the live surface, and clear with the field. They are visual only and do not change counts, pressure or gameplay queries.

Element parameters remain in `core/elements.gd`. The current simulation uses one element at a time. Sealing, heat, element fusion, mixed materials, purchase progression, ambient flybys, saves, caves, and overhangs are not implemented.

The player core is separate from the planet or sun's body. Body matter now occupies a core, inner mantle, outer mantle and shallow crust/surface. Outer compaction remains manual. Inner densification transfers 90 percent of the current body core into a denser core, with 10 percent of the consumed portion's area, and preserves residual matter in surrounding layers. It also grants a permanent 1.12 multiplier to Core-talent production and a temporary contraction-heat pulse, both shown in the player HUD. Only the converting section shudders and flickers. Layer sizes, mass thresholds, residual splits and labels are profile settings.

The inner automation upgrade has a callable unlock and on/off switch. Normal purchases await progression costs; dev Ctrl-click grants it free. It advances only at new collected-mass milestones and never binds loose outer material. `consume_loose(amount)` is the construction spending hook and cannot consume incoming or bound matter. Player automation settings survive clear and element changes.

Nested-layer validation passed: conservation, 90/10 area split, four separate rings, shallow surface retention, animated radii matching the body boundary, local pulses, automation milestones, loose-only spending, UI gating and dev unlock. Existing core, compaction, smoke, dev-control and rendered seam checks also passed. The new ratios and milestones remain provisional game settings.

All four demo elements now support pressure compaction and retain their existing friction and flow settings. Small creep rates prevent helium, carbon, and iron from stalling at flat contacts. Deeper grains pack more tightly under the weight above them, with three adjustable pressure stages and a compression tint. See [Compaction](COMPACTION.md) for the settings and current limits.

Dense loose interiors now merge into a continuous colour fill, visible at 750,000 hydrogen grains. Labelled range rings extend as the camera zooms out. A ring and its number disappear while the material edge covers that radius and return if the body shrinks inside it. The Compact outer matter button binds existing matter into a permanent solid shell only after an explicit click and readiness checks. Dev Ctrl-click bypasses those checks but still needs material. Clear and element changes reset formed layers too.

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

The newer planning-only Sun model calculates 45:53:43 for one click per second with no upgrades, 5:25:50 for holding at nine activations per second with no upgrades, and 2:15:40 for the automation-first route. It models helium discovery, an unlocked 75/25 hydrogen/helium singularity mix, and separate passive helium production for cool, balanced and hot stars. The live scene shares its layer curve and now applies each 1.45 compact reward to live talent output. Helium production and mixed output remain planned. See [First Sun balance](SUN_BALANCE.md).

## Progression and launch presentation

The playable scene now has a data-driven Sun progression layer. Simulation values publish into a typed metric registry. Objectives evaluate those values, grant idempotent unlocks and drive a separate player HUD. The opening seven targets cover releasing matter, holding body mass, feeding and levelling the player Core, ambient capture, first-shell readiness and first compaction. Further gather and compact quests continue through all seven Sun layers, with a First Ignition explanation at 75 SMU. Persistent indicators do not reset when the current target changes.

`start.bat` uses the clean player presentation. It starts with the Core, a small `H` orb, one target bar and dismissible guidance. Decorative background stars, ambient-dust rendering, later controls, technical range rings and the talent tree stay hidden until their presentation unlock. Ambient dust simulation remains active and count-conserving while hidden. The C clear key and all free bypasses remain unavailable in player mode.

Matter called by clicking, holding or automatic talents now begins behind the fixed-screen `H` orb. Each release converts the current orb position through camera pan and zoom into a world angle and radius. Moving or zooming the camera therefore changes the world-side arrival path while the source remains visually attached to the orb. The arrival fan stays closed until particles clear the button.

`start-dev.bat` retains the existing element, amount and free-unlock gestures. F1 opens the progression lab. Metric refresh, completion hold and opening zoom are live controls. HUD scale, unlock impact and passive/event audio levels are labelled hooks until their final renderers and assets exist. The lab can complete the current target, preview guidance and reset progression guidance. See [Progression and presentation](PROGRESSION_PRESENTATION.md), [Audio brief](AUDIO_BRIEF.md), and [Visual unlock brief](VISUAL_UNLOCK_BRIEF.md).

Audio and final unlock art remain placeholders. The Core talent tree now spends the point granted by each Core level. Its highlighted launcher appears first; clicking it opens the tree and guides the required first point into Flow so passive matter starts immediately. The first live row then provides stackable automatic matter, stronger manual calls and faster automatic calls, with ten working ranks in each. Later documented tiers remain dim placeholders. Spending three points reveals the stellar backdrop and introduces the Core's growing pull toward future large bodies. The widened opening ranks are intentionally awaiting a balance pass.

## Checks

[Ambient dust](AMBIENT_DUST.md) is active in the live scene, with directional drift, gravitational deflection, exact loose-material capture and external supply/capture/gravity hooks. A fixed pool shares the existing rendering limit. The visual pass adds a precomputed space backdrop, layer relief and colour-tinted solar halo/prominences; body spin remains locked off.

The playable scene now enables [Sun progression](SUN_PHASE.md): seven manual mass-gated compactions, separate player assimilation, stellar zone labels, thermal colour/texture progression and compact Sun/player HUD panels. Requirements live in `core/sun_progression.gd`; generic field tests keep the earlier planet settings. Renderer-owned heat and ignition values approach new targets over roughly 1.6 and 2.2 seconds, so completed layers no longer switch the body directly between red and yellow. Compact rewards now multiply live talent bonuses and appear on the talent UI. First Ignition explains that helium is beginning to form, while actual fusion chemistry, helium output, spin unlocks and the final capstone remain deferred. Player temperature is an independent 300 K placeholder.

The `performance_test.gd` compaction scenario can hold conversion active for measurement. A trial that paused arrivals, ambient capture and surface flow during conversion was rolled back after it failed to improve the high-resolution result. At the 9,116 by 5,697 target produced by this PC's Windows scaling, the existing effect measured 55.1 median FPS and 36.446 ms p95; the pause prototype measured 50.8 FPS and 51.901 ms. The procedural Sun shader, not the 720-column CPU solve, remains the main high-resolution compaction cost.

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
start.bat --headless --script res://progression_system_test.gd
start.bat --headless --script res://presentation_hooks_test.gd
start.bat --headless --script res://progression_integration_test.gd
start.bat --script res://progression_ui_test.gd
start.bat --headless --script res://impact_response_test.gd
start.bat --headless --script res://compaction_test.gd
start.bat --headless --script res://core_layer_test.gd
start.bat --headless --script res://nested_layer_test.gd
start.bat --script res://nested_layer_ui_test.gd
start.bat --script res://layer_ui_test.gd
start.bat --script res://arrival_rim_test.gd
start-dev.bat --headless --script res://dev_test.gd
start-dev.bat --headless --script res://dev_progression_panel_test.gd
start.bat --script res://performance_test.gd -- --grains=500000 --capture
start.bat --script res://performance_test.gd -- --grains=100000 --scenario=flow
start.bat --script res://performance_test.gd -- --grains=500000 --scenario=flight
python -B tools/sun_model.py
python -B -m unittest discover -s tools -p "test_*model.py" -v
```

`surface_test.gd` runs the new field tests: conservation, capacity, arrivals, clear, periodic edges, material flow, fixed time steps, and footprint tuning. Smoke and rendered input checks cover startup, camera, spawning, developer controls, and reset. Images and logs are in ignored `scratch/checks/`.

Arrival checks cover a 500,000-grain burst onto 750,000 deposited grains: gradual landing, visible rim motion, exact counts, shared drawing cap, fading and reset. Stable surface sampling removes the angular birth seam. Bulk fill uses mesh coordinates so uneven deposits align with their grains. On September 20, a separate rendered 750,000-grain flow check at zoom 0.334 drew 500,000 samples, averaging 417 FPS over three seconds (95th-percentile frame time 7.327 ms). That timing covers deposited flow, not the peak arrival effect.

On September 21, 2026, the visual upgrade was measured on a different PC: Intel Core i9-10900, NVIDIA GeForce RTX 3070 with driver 595.95, Godot 4.7.2 Compatibility and VSync off. Each run used at least one second of warmup, 600 measured frames and at least three measured seconds. Ambient dust remained enabled. Counts can rise slightly from captured dust during the longer close-view runs.

| Scenario | Untouched median FPS / p95 | Upgraded median FPS / p95 | Final drawn state |
| --- | ---: | ---: | --- |
| 100,000 settled | 58.4 / 31.392 ms | 61.5 / 25.900 ms | 100,032 settled |
| 500,000 settled | 57.2 / 30.365 ms | 59.6 / 26.851 ms | 498,437 settled, 795 rim |
| 500,000 incoming | 208.8 / 6.868 ms | 230.7 / 5.965 ms | 499,232 incoming |
| 500,000 one-sided flow | 57.4 / 29.163 ms | 59.5 / 27.323 ms | 498,155 settled, 1,077 rim |
| 1 billion logical settled | 280.1 / 5.647 ms | 247.2 / 6.966 ms | 499,232 settled at zoom 0.010 |
| 500,000 visual stress | n/a | 58.4 / 28.482 ms | 498,179 settled, 1,053 rim, 32 impacts, 64 patches |

Normal close and medium scenarios improved on this PC. The isolated billion-grain far-view repeat was slower than its initial baseline and exceeded the 10 percent p95 investigation threshold. Its instance count and logical work stayed bounded, but the run-to-run GPU variance remains unresolved. Treat that row as a follow-up measurement, not a claimed improvement.

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
