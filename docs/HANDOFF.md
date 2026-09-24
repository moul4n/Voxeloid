# Development handoff

Updated 2026-09-24. This file is the short route back into the current work after moving machines. [Project](PROJECT.md) describes the full implementation. [Surface](SURFACE.md) describes the active material model. [Material motion plan](MATERIAL_ANIMATION_PLAN.md) records the staged review and [Todo](TODO.md) lists the open visual work.

## Resume on another machine

1. Clone the repository or run `git pull --ff-only origin main` in the existing checkout.
2. Install Godot 4.7.2. Set `GODOT_EXE` or update `godot.local.txt` if the executable is in a different location.
3. Run `start.bat` from the repository root for normal play.
4. Run `start-dev.bat` for free unlocks, element selection and large spawn amounts.
5. Run `start-dev.bat res://material_animation_compare.tscn` for deterministic visual review scenarios.

The active Godot project is `game/project.godot`. Work belongs in `game/`. Do not edit `scratch/voxbench`; it is the extracted baseline. Captures and local Godot data under `scratch/checks/` are ignored and will not move through Git.

## Current decisions

- The active material simulation is `game/core/material_field.gd`. It stores exact mass in 720 radial regions. Do not restore per-grain CPU physics for large populations.
- The shared visual budget remains 500,000. The playable scene reserves 768 slots for ambient dust, leaving at most 499,232 matter samples.
- Pre-ignition loose matter uses pressure-shaped grains. The old single-colour circular fill is disabled in normal play. It remains behind the `G` comparison toggle in the material-animation scene.
- Increasing pressure closes gaps, flattens contacts and then visually welds deep grains into an almost continuous mass. This is reversible drawing. It does not mark material as solid, molten or committed.
- Ignition crossfades uncommitted loose matter into a separate liquid reservoir. Incoming matter then creates bounded hot splashes and inward-sink effects. The planet and pre-ignition dot systems remain intact.
- Formed stellar zones use slow independent shader motion. Boundary heat counter-circulates without whole-body spin. External prominence loops and plumes follow the current liquid edge and remain visual only.
- Player Core mass, loose body matter, formed body layers and heat remain separate values. Construction spends loose matter only.

## Review controls

The material-animation comparison uses keys `1` through `9` for the main scenarios and `0` for the molten 500,000-grain impact. `G` switches pressure grains and the legacy loose fill. `Q` disables field flow. `W`, `E`, `T`, `Y` and `U` toggle grains, bulk, contact rim, impacts and patches. `R` switches the retained core-motion variants. `F` focuses the core. `D` reduces core motion. `S` enables quarter speed. `P` writes a capture to `scratch/checks/`.

## Latest verification

The following checks passed on 2026-09-24 with Godot 4.7.2 Compatibility and an RTX 4070:

```bat
start.bat --headless --script res://surface_test.gd
start.bat --script res://arrival_rim_test.gd
start.bat --script res://dense_transition_test.gd
start.bat --script res://pressure_compression_test.gd
start.bat --script res://layer_ui_test.gd
start.bat --script res://molten_arrival_test.gd
start.bat --script res://sun_ui_test.gd
start.bat --script res://stellar_ejection_test.gd
start.bat --script res://stellar_layer_motion_test.gd
```

The 500,000-grain settled run used 499,232 matter samples at 1280 by 800 and zoom 0.406. It measured 1.051 ms median, 6.898 ms p95 and 7.263 ms p99. The one-billion-grain run kept the same sample count at zoom 0.010 and measured 0.726 ms median, 1.671 ms p95 and 1.981 ms p99. These are whole-frame times. GPU-only timing was unavailable, and these results do not certify a low-end machine.

Godot reports a Windows certificate-store warning in restricted runs. Some rendered test harnesses also report resources still in use while exiting. The listed checks still return success. Treat new shader errors, parse errors or failed assertions as real failures.

## Next work

1. Review arrival, contact and graft effects at single, overlapping and large impacts. Check moving boundaries, seams and close or distant zoom.
2. Tune the pressure-welding depth for rocky materials when their phase rules exist. Do not treat the current visual weld as a solid-state simulation.
3. Define mass ownership, cooling, fallback and pool exhaustion before stellar ejections can move logical matter.
4. Add low, medium and high presentation budgets, then measure 1080p and 4K. A modest test machine is still required for the low-end target.

Do not delete the granular particle path. Planets and future solid material work still need it.
