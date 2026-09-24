# Material animation stage 2

Stage 2 is implemented for visual review. The old column-generated rim has been replaced by a fixed pool of 256 GPU contact representatives.

Each landing records a bounded event with its batch seed, angle, spread, time and amount. The incoming and contact shaders share the field's landing interval. A representative keeps the same batch seed and local sample ID through the handoff, then makes a small local bounce or downhill slide before sinking into the deposited display. The authoritative radial field still owns all mass.

The pool is visual only. It creates no collision bodies and does not grow with stored population. If all 256 slots are occupied, older contacts finish instead of being displaced; the deposited field remains the fallback for later arrivals. Clearing or reseeding removes the events.

Verified with rendered `arrival_rim_test.gd`, `surface_locality_test.gd`, `impact_response_test.gd`, `singularity_source_test.gd` and `bonded_patch_test.gd`, plus headless `surface_test.gd`, `ambient_integration_test.gd` and `compaction_test.gd`. The certificate-store warning and forced-exit resource warnings remain test-harness noise.

Review scenarios 1 and 2 in `material_animation_compare.tscn`. Look for a continuous arrival-to-contact path, no random reappearance elsewhere on the body, and a short local bounce or slide. This version does field contact only. It does not simulate contact particles colliding with one another. That should be added only if the sparse comparison still needs it.

Follow-up sparse-shell work makes the low-density Hydrogen front visible over its normal travel time. A 1,000-grain regression covers all 720 angular regions after settling without increasing solver speed. Stable samples are also thinned proportionally around the body when loose matter is consumed, preventing a one-sided visual gap.
