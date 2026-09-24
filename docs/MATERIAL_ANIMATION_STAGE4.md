# Material animation stage 4

Stage 4 uses `PLUMES` for the first formed stellar layer. It does not affect the separate player Core. The older `BANDS` version remains available in the comparison scene. Neither treatment rotates the body or changes counts, radii, heat or progression.

`BANDS` is the restrained version of the existing core treatment. Counter-flowing angular folds move at different speeds. Thin hot cracks travel through them without turning the whole layer.

`PLUMES` uses broad cells that rise through a slowly deforming Cartesian noise field. Darker return lanes break up the bright regions. Its orange-to-gold range now shares the same palette as the flame crests. This costs two additional value-noise samples in the first body layer, but avoids polar pinching and a texture seam.

The first stellar boundary crossfades across a band derived from the formed layer dimensions. The band spans at least 55 percent of the first layer's width. It suppresses the hard inner shadow and bevel, then mixes a shared fire colour into both sides. Flame geometry no longer uses camera zoom. Before ignition, crests occupy about 38 percent of the available outer-layer depth. Ignition expands them to 84 percent and thickens their lines in proportion to the formed core and outer layers. They move at less than half their earlier angular speed. They remain shader animation, not ejected logical matter.

Run `start-dev.bat res://material_animation_compare.tscn`, select scenario 7 or 8, press F to focus the formed core and press R to compare the retained `BANDS` version. Press D to preview quarter-speed reduced motion. Other stellar zones retain their current treatments during this review.

The rendered motion test found 22,256 changed core pixels between variants in the focused view. Both moved over two seconds, retained exact mass and left stellar spin at zero. At 1280 by 800 with 500,000 grains in the compaction benchmark, `BANDS` measured 0.773 ms median, 6.496 ms p95 and 6.711 ms p99. `PLUMES` measured 0.778 ms median, 6.511 ms p95 and 6.685 ms p99. GPU-only timing was unavailable. The difference is within run variance on the RTX 4070 machine.

The full seven-layer, 976,958-grain stellar benchmark with the revised plume boundary and longer flames measured 0.800 ms median, 1.931 ms p95 and 2.383 ms p99 at zoom 0.281 on the same machine. It drew no loose-grain instances because all test matter was formed into layers. This is a rendered frame measurement, not isolated GPU timing.

`core_motion_variant_test.gd`, `sun_ui_test.gd`, `layer_ui_test.gd` and `nested_layer_ui_test.gd` pass under the Compatibility renderer. Surface ejections and pressure-driven grain deformation are recorded in `TODO.md`; neither is implied by these shader flames.

The remaining formed zones now use separate motion. The inner stellar zone has broad rising and returning ribbons. The outer zone uses luminous flow contours around broad upflows and narrow return lanes. The shallow zone uses a finer morphing network with sparse hot activity. Two smoothly crossfaded noise phases change the line art without rotating or sliding one texture around the star. Internal boundaries use a narrow shared-colour blend and suppress their hard bevels while retaining enough contrast to read each zone. `SOLAR_CUTAWAY_REVIEW.md` records the NASA and ESA references behind this mapping.

`stellar_layer_motion_test.gd` measures each annulus separately. In the latest rendered check, layers 0 through 3 changed 1,185, 3,113, 227,262 and 4,631 pixels over two seconds. Setting motion speed to zero left 39 changed pixels across the full annulus, within the 64-pixel Compatibility raster tolerance. Exact mass and zero stellar spin were preserved. After replacing the Voronoi background, the 976,958-grain stellar benchmark measured 0.810 ms median, 1.938 ms p95 and 2.142 ms p99 at 1280 by 800 and zoom 0.281. GPU-only timing remains unavailable.

Internal boundary heat now circulates slowly in alternating directions. This creates local shear without enabling body spin. Two-footpoint surface prominences use a fine hot thread, flowing highlights and breathing roots. Long plumes and loops remain visual effects attached to the current liquid edge. They do not own or eject matter.
