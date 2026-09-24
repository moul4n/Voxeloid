# Material animation stage 3

Stage 3 now uses pressure-shaped grains for loose matter. It no longer changes thick pre-ignition material into the old flat circular fill during normal play.

Thin material keeps distinct stable grains. Persistent positions blend into dense distribution positions between 30,000 and 50,000 logical grains. Local packing then drives two reversible visual ranges. The first regularises particle size, closes gaps and flattens contacts along the surface tangent. The second starts at high packing, increases overlap again and reduces per-grain colour variation. Deep material becomes almost continuous while the exposed edge stays particulate.

This is presentation only. It does not form a body layer, ignite a star, melt material or mark matter as solid. `consume_loose()` reverses the deformation as pressure falls. The logical population, 720-column field, pressure geometry and collision boundary remain authoritative.

The renderer draws every logical loose grain while the count fits the shared budget. Above the cap, each sample represents more grains by area. The close-view size cap grows by the same representation scale, so adding matter above the cap cannot make the body look more porous. The playable scene reserves 768 of the 500,000 shared slots for ambient dust, leaving at most 499,232 matter samples.

The legacy edge-budget and continuous-fill renderer remains only for comparison. Run `start-dev.bat res://material_animation_compare.tscn` and press `G` to switch between it and pressure grains. The normal game always starts in pressure-grain mode. Ignited loose stellar matter still crossfades into the separate molten-reservoir renderer.

`pressure_compression_test.gd` creates loose, medium, dense, welded, legacy-fill and returned captures under `scratch/checks/`. `dense_transition_test.gd` checks the reversible state change and exact mass. `layer_ui_test.gd` checks 100,000, 750,000 and one billion logical grains at close and distant zoom.

On the RTX 4070 test machine, 500,000 settled grains at 1280 by 800 and zoom 0.406 drew 499,232 matter samples. The run measured 1.051 ms median, 6.898 ms p95 and 7.263 ms p99 whole-frame times. One billion logical grains kept the same 499,232 samples at zoom 0.010 and measured 0.726 ms median, 1.671 ms p95 and 1.981 ms p99. GPU-only timing was unavailable.

The remaining review is artistic. Check the depth at which grains start to weld, the size of close-view representative grains and the edge porosity for future rocky materials. A later solid-state system should take over through an explicit material rule, not by silently re-enabling the old fill.
