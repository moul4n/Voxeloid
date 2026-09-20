# voxbench — phase 0 stress bed

The first demo project for the vox speed game. It has **no gameplay**. Its only job is to
throw thousands of animated voxel sprites around at very high frame rates and leave a
compact, comparable record of every run.

Read `docs/voxeloid-design.html` first — that's the game. Then `phase0-build-plan.html`
(this project), `vox-speed-bible.html` (rendering, art and systems) and
`stacking-and-scaling.html` (the buff system research) and `voxeloid-prior-art.html`
(what else exists). `docs/README.md` says which parts of the older three have been
overtaken by the design doc.

## Day one on the dev PC

1. Install **Godot 4.4.1 standard** (not .NET). Open `project.godot`, let it import, press F5.
2. `git init && git add -A && git commit -m "phase 0 baseline"` — the overlay's git hash turns
   red and every run says `nogit` until you do.
3. Window at exactly 2× (1920×1080) on your fastest monitor, V-Sync off in the GPU driver panel for Godot.
4. Press **F5** in the app. About 75 s later you have five run folders. Run it three times.
5. Fill in the header of `BENCH.md` (GPU, driver, CPU, monitor Hz) and paste the `late` line.

Python 3 on PATH for `tools/compare.py`, `tools/buildsim.py` and `tools/curve.py`;
Pillow for `art/bake/bake.py` (`pip install pillow`). No other dependencies.
The three tools need no arguments — just run them.

## Layout

```
core/       metrics.gd (autoload: ring-buffer recorder → user://bench/<run>/)  seeded_rng.gd
render/     swarm.gd + swarm.gdshader (MultiMesh, GPU-integrated motion)  actors.gd (pooled tier)
            rig.gd (hero part rig, procedural tweens)  atlas.gd (procedural stand-in art)
bench/      stress.tscn / stress.gd (scenario runner + keys)  overlay.gd  scenarios.json
            reference/   ← commit the first PASSING run folder per scenario here
art/        vox/debris/*.vox (generated)  bake/gen_debris.py  bake/bake.py  atlas/debris.png+json
tools/      compare.py (diff runs, flag regressions)  buildsim.py (buff-pool simulator)
            curve.py (layer cost curve — threshold vs density vs buildings)
            particle_scaling.js (node: particle sim cost vs count — no deps)
docs/       the six design documents, offline copies (start with voxeloid-design)
BENCH.md    one line per commit tested — the project's performance history
```

## Keys

| Key | Does |
|---|---|
| F5 / F6 / F7 | Run suite / run current scenario / manual record toggle |
| F8 | Open the bench output folder |
| Tab | Cycle scenario (without running) |
| 1–6, 0 | Toggle visual layer bit / all-off, all-on |
| Q W E R | Spawn 100 / 1k / 10k / 50k swarm now |
| A / S | +100 actors / clear actors |
| O | Toggle Area2D overlap on actors (measure its cost alone) |
| G | Swarm CPU ↔ GPU path |
| H | Overlay on/off |
| L | Type a run label, Enter to set |
| C | Clear everything |
| Esc | Quit |

## Command line

```
godot --path . ++ --suite --label=first-pass --quit
godot --path . ++ --bench=late --gpu=0 --label=cpu-path --quit
godot --path . ++ --bench=spike --seed=42 --quit
```

Output goes to Godot's user data folder (`%APPDATA%\Godot\app_userdata\voxbench\bench` on
Windows, `~/.local/share/godot/app_userdata/voxbench/bench` on Linux). `compare.py` finds it
automatically.

```
python tools/compare.py --all                 # one row per run
python tools/compare.py --latest late         # newest late run vs bench/reference/late
python tools/compare.py <runA> <runB>         # explicit pair; exit code 1 on >5% p99 regression
```

## What "done" means for phase 0

The `late` scenario (10,000 swarm, 500 actors, all six layers) records **p99 frame time ≤ 3.33 ms**
(≥ 300 fps) on the dev PC, three runs in a row. Then commit that run folder to `bench/reference/late/`
and everything after is measured against it.

## Known state of this skeleton

- Runs end-to-end under headless Godot 4.4.1 (suite, CSV/JSON output, compare.py all exercised),
  but it has **not** been run with a real GPU yet. First real run may surface shader or
  MultiMesh issues; the overlay and `[metrics]` console lines will say where.
- Headless frame times are meaningless (dummy renderer), so the shipped sample runs are
  for format only.
- The swarm's spike path spawns via per-instance setters. If `spike` fails on the dev PC,
  the plan-B in the build plan is a single `MultiMesh.buffer` write; the layout is
  `[xx, yx, 0, ox, xy, yy, 0, oy, r, g, b, a, c0, c1, c2, c3]` per instance.
- `rendering/driver/threads/thread_model` is set to Safe (1). Try Separate (2) in the
  renderer shoot-out step; it crashed under headless but may be fine with a real driver.
- The procedural art (`atlas.gd`) is a stand-in; `art/atlas/debris.png` (baked from generated
  .vox by `bake.py`) is used when present, which it is.

## The bench is behind the design

This skeleton was built before the game settled on a radial cross-section. The design doc's
"What this changes in the build" section is the full list, but the short version:

- Gravity needs to point at a centre point, not downwards. A couple of lines in `swarm.gdshader`.
- There is no collision system and there should never be one. Particles test against a
  720-column radial height field — one array read each. See docs/voxeloid-particles.html;
  that document supersedes anything here about actor collision for loose material.
- The Compatibility renderer has no compute shaders, no RenderingDevice, no particle SDF
  collision and no emit_particle(). The particle design does not need any of them, but the
  renderer choice should be re-weighed deliberately rather than inherited.
- The camera needs to zoom out over a run, and that zoom should itself be benchmarked —
  thousands of tiny sprites across a range of zoom levels is not the same problem as one zoom.
- Material flows both ways: inward as accretion, outward from the centre as refined material.
  The spawner handles it; `scenarios.json` doesn't model it yet.
- Settled rings bake to static images and there will never be more than eight or nine of them,
  so the static cost has a hard ceiling. The frame budget is "how much is still in the air".
- The hardest frame is mid-world, not at the end. The `late` scenario currently assumes the
  worst case is the last one.
- The machine should be drawn at a fixed size on screen while the world scales around it.

None of this changes the phase 0 pass/fail bar, which is still about raw density.
