# Material animation baseline

Recorded on 2026-09-22 for stage 0 of [Material motion and living layers](MATERIAL_ANIMATION_PLAN.md).

## Comparison scene

Launch the deterministic review scene from the repository root:

```powershell
.\start-dev.bat res://material_animation_compare.tscn
```

The scene starts with ambient dust, automatic production and the space backdrop disabled. The field advances at fixed 60 Hz steps. Press 1 through 9 to select a scenario and Enter to restart it from the same state.

| Key | Scenario |
| ---: | --- |
| 1 | Empty start, followed by 1, 10, 100 and 1,000-grain arrivals |
| 2 | Thin shell with local impacts at eight angles, including the seam |
| 3 | Overlapping batches from different directions with a fixed camera offset |
| 4 | Repeated compaction, a thin loose shell and a renewed impact |
| 5 | 100,000 settled grains |
| 6 | 250,000 settled plus 250,000 arriving, followed by another 500,000 |
| 7 | Four formed Sun zones before ignition |
| 8 | Ignited Sun while its final outer conversion remains active |
| 9 | One billion stored grains with bounded drawing |

Controls:

- Q toggles field flow.
- W, E, T, Y and U toggle deposited grains, bulk fill, rim grains, impact effects and bonded patches.
- I toggles fixed-angle field-height markers. The long cyan line marks the angular seam.
- Space pauses. S switches between normal speed and quarter speed. P saves a still under `scratch/checks/`.
- The usual right-drag and wheel camera controls remain active.

The coloured markers track authoritative field height at fixed angles. They are not shader-grain identities. This distinction lets a reviewer compare genuine shape movement with grain remapping. Stage 1 will add the grain-locality diagnostic after changing the sampling model.

Use normal and quarter speed for motion review. This stage supplies a deterministic live replay and still capture. It does not record video clips inside Godot.

## What to review

Start with scenarios 2 and 4. Pause before an impact, toggle Q to stop real field flow, then replay. Watch whether grains away from the impact still move around the body. Toggle W while leaving E and I enabled to separate deposited-grain motion from the authoritative bulk shape.

In scenarios 1 and 2, follow an incoming grain into the rim. Look for the point where its flight identity disappears and a different deposited sample appears. In scenarios 7 and 8, watch whether core patterns read as local movement or as a texture sliding across static rings.

Stage 0 makes no renderer behaviour change. These faults remain present so the current and later candidates can be compared against the same replay.

## Reference performance

These are rendered Compatibility-mode runs at 1280 by 800 on an NVIDIA GeForce RTX 4070 and Intel Core Ultra 7 265KF using Godot 4.7.2. VSync was disabled. Each run used at least 120 warmup frames and 3 seconds of measurement. Ambient dust and backdrop were disabled in this isolated set.

| Scenario | Logical grains | Drawn settled | Drawn air | Median ms | p95 ms | p99 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Settled | 100,000 | 100,000 | 0 | 0.619 | 0.961 | 1.455 |
| Flow | 100,000 | 100,000 | 0 | 0.628 | 5.688 | 6.021 |
| Flow | 500,000 | 499,232 | 0 | 0.645 | 5.819 | 6.311 |
| Flight | 500,000 | 0 | 499,232 | 0.556 | 1.427 | 1.946 |
| Visual stress | 500,000 | 499,232 | 0 | 0.634 | 0.991 | 1.405 |

The visual-stress case held all 32 impact effects and 64 bonded patches active. The renderer reserves 768 of the shared 500,000 slots for ambient dust even when dust is disabled, which explains the 499,232 maximum.

Godot did not expose a reliable GPU-frame measurement through this test, so the table reports observed frame intervals. It must not be presented as isolated GPU cost. The high median rates describe this machine and resolution only. They do not certify weak hardware or 4K performance. The flow runs' slower p95 and p99 results are worth tracking during later stages.

An additional set with ambient dust and the backdrop enabled produced these p99 frame intervals: 6.293 ms for 100,000 settled, 6.585 ms for 100,000 flow, 6.919 ms for 500,000 flow, 1.794 ms for 500,000 flight and 6.710 ms for 500,000 visual stress. Ambient capture changes the exact logical and visible counts during those runs.

Reproduce an isolated measurement with:

```powershell
.\start.bat --script res://performance_test.gd -- --scenario=flow --grains=500000 --without-dust --without-backdrop
```

`performance_test.gd` now prints engine, rendering method, graphics adapter, processor, viewport, zoom, logical counts, drawn counts, median, p95 and p99. It prints `gpu_frame_ms=unavailable` instead of implying frame intervals are GPU timings.

## Stage 0 status

Implementation and local verification are complete. The nine scenarios load without script errors, the rendered comparison starts under Compatibility mode, and the billion-count case does not allocate a billion-sized drawing buffer. Stage 0 remains awaiting visual approval. Stage 1 must not replace the reference behaviour until scenarios 2 and 4 reproduce the motion the user wants fixed.
