# Stage 1 thin-layer motion candidate

Status: revised after the first visual review and ready for another review. This candidate has not yet been accepted as the permanent surface treatment.

## Change

Loose layers with up to 25,000 drawn grains now keep persistent sample identities. Each sample stores its angular column, position inside that column and radial fraction in MultiMesh custom data. Adding matter creates new samples in the affected columns. It no longer changes every existing sample's angle through the whole-body cumulative distribution.

The first 256 settled samples remain pinned. This sparse rule was added after review found that the one and two-drop particles disappeared when the next drop landed. The matter count was intact, but exact proportional rebalancing reused the earlier visual identity. Sparse growth now allocates new identities and permits its drawn distribution to lag the aggregate field until enough grains exist for rebalancing to look continuous.

When authoritative field flow moves mass between columns, the renderer transfers the minimum number of samples needed to match the new distribution. Samples in unaffected columns keep their identity and position. Clear, material selection and field epoch changes discard the assignments.

Dense bodies above 25,000 settled grains retain the previous inverse-distribution sampling for now. This keeps the 100,000 and 500,000-grain paths fast while the new thin-layer motion is judged. It also means the old global remapping can still occur above the threshold. Do not describe stage 1 as a complete replacement for dense-body sampling.

The old paired forward and reverse search did not create opposing movement as its comments claimed. The dense fallback now uses one direct forward search and no longer claims otherwise.

The first review found that scenario 4 looked acceptable but scenario 1 still showed the real fault. The persistent allocator was borrowing old surface identities for new landing matter, while the implicit field solver spread the landing through the whole periodic ring in one tick. The revision makes two changes:

- New logical matter uses new sample identities before the renderer considers transferring an existing sample. Existing transfers choose the nearest donor column.
- Hydrogen flow now uses conservative local passes across offsets of one, four, sixteen and thirty-two columns. The first two-scale review left visible side piles, so wider bounded passes were added to restore prompt settling. The widest step covers sixteen degrees rather than the whole body. Rough materials use adjacent edges only. No active flow solve can place matter directly on the opposite side in one tick.

The local response was originally scheduled for stage 5. It moved forward because scenario 1 proved that renderer sampling and field motion caused the same visible failure. This does not approve a later temperature or full fluid system.

## Review

Run:

```powershell
.\start-dev.bat res://material_animation_compare.tscn
```

Use scenario 1 first. Follow the 1, 10, 100 and 1,000-grain arrivals. Newly landed grains should remain near the impact and spread outward instead of appearing around the body. Press Q and Enter to compare the same replay with material flow disabled.

Scenario 4 finishes seven compactions with about 23,000 loose grains, then adds a local 1,000-grain arrival. It remains useful for checking a thin shell around a large formed body.

Use scenario 2 for eight local impacts on a thin 24,000-grain shell. Toggle W to compare the deposited samples against the bulk boundary and I markers. Scenario 5 remains on the dense fallback and is useful for checking the transition in visual character.

The threshold is deliberately visible in the status readout through the settled count. Crossing it changes sampling modes and may still pop. That transition is an open problem, not an approved effect. Stage 3 will address visual transitions after contact continuity is resolved.

## Verification

Rendered `surface_locality_test.gd` deposits 720 grains at zero radians into a uniform 7,200-grain field. With flow disabled, all 7,200 original sample identities remain unchanged. With flow enabled through a complete landing, existing samples do not cross columns and new landing samples remain within 117 of the 720 columns from the impact. A separate 1,000-grain arrival loses more than 55 percent of its excess peak height within four seconds and reaches the opposite side with a small propagated amount. A one-grain deposit followed by a second deposit retains the first sample's exact custom data and draws both identities. The test also checks exact mass and reset invalidation.

The smoke, surface, visual-field, compaction and arrival-rim tests pass. The comparison scene runs under the Compatibility renderer with no shader error.

Reference results at 1280 by 800 on the RTX 4070, with ambient dust and backdrop disabled:

| Flow case | Mode | Median ms | p95 ms | p99 ms |
| --- | --- | ---: | ---: | ---: |
| 25,000 | Persistent local samples and local flow | 0.658 | 7.724 | 8.472 |
| 100,000 | Dense fallback and local flow | 0.644 | 5.893 | 6.318 |
| 500,000 | Dense fallback and local flow | 0.637 | 6.022 | 6.465 |

An earlier 100,000-sample trial produced 22.691 ms p99 during flow. The limit was reduced to 25,000 rather than accepting that cost. These frame intervals do not isolate GPU time and do not certify weak hardware.

## Approval gate

Approve this stage if scenario 1 no longer sends landing grains around the body and scenario 4 remains acceptable. Request revision if samples still appear away from the spreading impact, the local pile now spreads too slowly, or the mode transition is too obvious. Stage 2 will then preserve identity through flight, contact and settlement.
