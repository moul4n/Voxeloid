# Material motion and living layers

Status: stages 1 through 4 are implemented. The user approved the direction through the pressure-grain replacement on 2026-09-24. Arrival polish, real ejecta mechanics and quality presets remain open.

## Start here, Sol

Use this document to improve the motion of arriving grains, thin deposits and formed body layers in small, reviewable steps. Start with stage 0. Complete one stage, run its checks, provide a playable comparison and wait for the user's explicit approval before beginning the next stage. Approval of this document does not approve every visual treatment or future mechanic.

For each stage, report what changed, how to launch the comparison, what to look for, measured costs and unresolved problems. Offer an explicit decision of approve, revise or reject. Record the user's decision in the table below. A passing automated test does not substitute for visual approval. Fix failures inside the current stage without repeatedly asking permission for routine edits or checks.

Read root `AGENTS.md`, [Surface model](SURFACE.md), [Compaction](COMPACTION.md), [Sun balance](SUN_BALANCE.md) and [Sun phase](SUN_PHASE.md). Inspect the actual code before editing. Some older descriptions in project documents lag behind implementation. Sun requirements and current progression are outside this visual redesign.

| Stage | Deliverable | Decision |
| --- | --- | --- |
| 0 | Reproducible comparison scene and measured baseline | Implemented |
| 1 | Stable settled grains and diagnostic isolation of global motion | Revised and accepted as the active direction |
| 2 | Continuous arrival, contact and settlement | Implemented; final impact polish remains in `TODO.md` |
| 3 | Pressure-shaped grains replacing the blurred loose fill | Implemented and active; legacy fill remains a dev comparison |
| 4 | Living core and distinct moving body layers | Implemented; plume version is active |
| 5 | Local surface response, if still needed | Bounded local-flow candidate is active; revisit only if settling still looks wrong |
| 6 | Optional material-state and ejecta experiments | Pending, separate mechanic approval required |
| 7 | Quality settings, integration and release checks | Pending |

## Direction

Keep the aggregate body model and GPU drawing. Add persistent motion where the player can follow an individual grain. Dense loose matter now stays grain-first. Pressure closes gaps and visually welds deep grains without using the old flat circular fill. Ignited stellar liquid and committed body layers keep their own continuous renderers. Give formed layers slow, coherent internal motion that differs by material and depth.

The total stored population must not determine the size of a particle physics loop. Use a fixed active-particle budget, compact field data and bounded shader work. Retain Compatibility rendering for the first implementation. Treat compute shaders or a renderer change as a separately measured proposal.

There are three different transitions:

| Transition | Trigger | Effect on gameplay |
| --- | --- | --- |
| Visual blending | Local packing, thickness and projected grain size | Changes how existing matter is drawn only |
| Material phase change | An approved temperature and material model, potentially influenced by pressure | Changes material behaviour, with conserved matter |
| Body-layer formation | Existing player action and progression requirements | Transfers loose matter into a formed layer |

Automatic blending must never silently form a body layer, complete a Sun requirement or grant a reward. Actual melting also does not imply automatic layer formation. Inner densification automation remains upgrade-gated. Camera zoom and graphics quality must not change income, mass, readiness or material state.

## Findings to verify and fix

The initial investigation inspected code and reproduced the settled-position mapping numerically. It did not establish the exact contribution of every effect to the user's observed anticlockwise twitch.

- `game/core/field_surface.gdshader` assigns angles from the whole body's cumulative mass distribution. A local addition therefore moves unrelated samples. For an initially uniform 720-column ring, adding 10 percent of its total mass at column 600 moved a sample from 180 to 198 degrees without any simulated flow.
- Its reverse search uses the complementary quantile. This gives the same angle as the forward search, apart from numerical edge cases. It does not produce the opposite motion claimed by the comments in that shader and `field_renderer.gd`.
- `field_air.gdshader`, `field_rim.gdshader` and the deposited shader do not carry one grain identity through contact. Air sample identities can change as batch weights and drawing counts change. Rim slots are rebuilt from active columns. Both deserve explicit continuity checks.
- CPU landing and GPU fading have different timing rules for large arrivals. `_land_due_batches()` scales the landing interval with batch size, while the air shader uses the base interval and a different cap. Align their event definitions rather than tuning independent fades.
- `_redistribute()` is a dissipative mass redistribution solve with no persistent momentum. Improving sampling alone will not produce bounce, rolling contacts or liquid waves.
- The current bulk shader already includes time-dependent noise, bands, granules and heat crests. The complaint is about perceived motion and quality, not a complete absence of animation. Measure screen-space speed and contrast before adding more effects.
- Existing tests cover conservation, budgets and some rendered visibility. They do not establish identity continuity, convincing motion or low-end performance.

## Shared rules

Keep exact logical counts, the billion-grain storage cap, bounded arrival storage, reset behaviour and cache invalidation. Keep all drawn grain pools, including ambient dust, inside the shared 500,000 maximum. Ambient dust already reserves 768 slots. New surface samples must replace or share existing allocations. Do not silently add a second particle budget.

Keep player, loose matter and body layers separate. Preserve material area during movement of unaffected layers. Restrict conversion shudder and flicker to the converting section. Retain normal controls and dev Ctrl-click paths for any new unlock. Later elements remain dev previews until their progression is requested.

Use one owner for each unit of logical matter. A visual sample can represent many units, but must not add them a second time. Render-only duplicates during a fade own zero additional mass. If a preview uses actual active parcels, define whether their mass is incoming or deposited and transfer it exactly once. Test pool exhaustion and queue merging, not just the ideal case.

Keep accepted and candidate modes available in a dev comparison scene until the candidate is approved. Production should not accumulate several permanent solvers. Preserve the original `scratch/voxbench` baseline unchanged.

## Stage 0: establish the comparison

Create a repeatable dev scene with fixed seeds, fixed simulation steps and a visible scenario selector. Start from the current implementation as the reference. Freeze ambient income and automatic production for isolated tests, then provide a separate scenario with them enabled.

Required scenarios:

1. Empty start, single grains, then 10, 100 and 1,000-grain arrivals.
2. A thin deposit around a large formed body, with a small local impact. Repeat at eight angles including the angular seam.
3. Held input and overlapping batches from different directions. Include a source moved by camera pan.
4. A thick body, manual compaction, a thin remaining layer, then renewed arrivals. Repeat several times.
5. Settled, flowing and arriving populations at 100,000 and 500,000. Include a million stored grains and a billion-count capacity check without billion-sized buffers.
6. Formed core alone, all four body zones, pre-ignition and ignited Sun, both idle and converting.

Provide toggles for flow, deposited grains, bulk fill, rim, impacts and patches. Add a small set of coloured tracking samples and field-height markers. Hold camera and input constant while toggling rendering so genuine geometry movement can be separated from sample remapping.

Capture short clips at normal speed and slow playback. Stills are useful for style, but cannot approve motion. Store captures and logs under ignored `scratch/checks/`. If clip capture is unavailable, supply a deterministic live replay and state that limitation.

Measure a baseline using the existing `game/performance_test.gd`, extending it only where needed. Record hardware, engine, renderer, actual viewport resolution, zoom, logical counts, drawn counts by pool, warmup and measurement duration. Report median, p95 and p99 frame time. Separate CPU simulation cost from GPU time where supported. A frame interval or physics-disabled comparison alone is not a GPU timing measurement.

Approval gate: the user can reproduce the disliked motion, compare the thin and thick cases and agree which scenes must improve. Save the baseline before changing behaviour.

## Stage 1: stop unrelated grains moving

Replace whole-ring inverse-distribution positioning with persistent local samples. Prototype fixed angular sectors with stable sample IDs, radial fractions and a deterministic reserve of candidate samples per sector. Change sector occupancy gradually as local mass changes. Do not divide identities by a changing draw count or repack IDs globally when a pool grows.

A sample should remain attached to its local material unless local flow moves it. Carry samples across sector boundaries continuously when needed, or fade old and new representatives within that same neighbourhood. Thin deposits need stable spacing; a stationary random cloud with obvious overlaps is not sufficient.

Use a bounded coarse motion field or a small active sample pool if advection is needed. Do not update every one of 500,000 sample positions in GDScript each frame. First prove a cheap stable representation, then compare its visual limits against the active-particle prototype in stage 2.

Checks:

- With flow disabled and no mass change in a sector, its existing sample angles remain unchanged after a remote deposit. Suggested diagnostic tolerance is 0.1 screen pixel at the recorded zoom, excluding an explicitly identified sample birth or retirement.
- No seam jump when crossing column 719 to 0. No global sweep when draw counts change or a layer is compacted.
- Symmetric inputs produce symmetric field behaviour within numerical tolerance. Track field movement separately from drawing movement.
- Clear and material change invalidate all sample state. Mass and drawing budgets remain unchanged.

Run `surface_test.gd`, `visual_field_test.gd`, `compaction_test.gd` and rendered seam checks. Add tests for the diagnosed mapping fault and locality; a test that only verifies a reverse texture exists is insufficient.

Approval gate: local arrivals no longer cause unrelated grains to slide around the ring. Compare thin deposits first. Correct the misleading comments and documentation when the implementation changes.

## Stage 2: make arrivals contact and stay

Prototype a fixed pool of active contact particles. The first candidate uses 256 GPU field-contact representatives. They use packed event data and do not add per-grain CPU collision objects. The legacy solver already has a spatial hash and repeated contact iterations; copying it unchanged will not establish an improvement.

Preserve identity through flight, contact, short bounce or slide, and settlement. Use the current local surface boundary for contact, including during contraction. Carry the same event position and time into deposited appearance. Use field-only collision first, then add local particle contacts if the sparse case still lacks convincing interaction.

At low counts, aim to show each visible grain settling. At high counts, use representative particles with explicit mass weights or render-only tracers tied to authoritative batch delivery. Choose one accounting scheme and document it before implementation. A tracer must not independently trigger a second deposit. Pool saturation must merge or fall back locally, conserve the batch and avoid teleporting existing visible particles.

Use one landing schedule shared by the field and shaders. Remove or reduce the old rim overlay where it duplicates the new contact display. Test multiple overlapping batches, moving boundaries, reset during flight and a full pool.

Run `arrival_rim_test.gd`, `surface_test.gd`, `ambient_integration_test.gd`, `singularity_source_test.gd` and `bonded_patch_test.gd`. Update assertions if the old rim is deliberately replaced, while preserving conservation and bounded-storage checks.

Approval gate: a tracked grain reaches the surface and visibly settles there. The thin layer recovers the satisfying contact behaviour without CPU cost growing with stored population. If the target machine cannot afford contacts, show the cheaper field-contact option and its limits before expanding the solver.

### Molten arrival handoff

The arrival review must cover two presentations instead of extending granular grafts through the whole Sun phase.

Before ignition, retain the granular route: flight, contact, a short bounce or slide, a bonded patch and stable deposited grains. This is the readable early-game matter-building phase.

At the current first-ignition milestone, crossfade the loose presentation into a molten reservoir. This is initially a progression-driven visual state, not a claim that the project has a complete thermal simulation. If the later material-state model supplies a real melt fraction, it can replace this visual gate without changing mass ownership.

After the handoff:

- Incoming representatives remain visible through flight and first contact.
- Contact drives a local depression, rounded splash crown or short inward streak instead of a dry mound.
- The delivered count enters the same logical loose reservoir exactly once. It does not become a formed body layer until the existing player action commits it.
- Deposited dots and bonded graft patches fade out as the reservoir joins the liquid envelope. Its volume must still use the authoritative loose count and field geometry.
- Player Core feeding can consume this uncommitted reservoir. Consumption lowers the liquid contribution proportionally around the body and updates the HUD, rather than cutting a hole opposite the arrival source.
- Small impacts make a brief hot contact response. Large batches can drive a stronger, longer local flame or plume response using a bounded event pool. This is fuel-entering-fire feedback; it must not unlock ignition, add heat, create production or award mass a second time unless a later gameplay rule explicitly does so.
- Reset, material change and loss of the molten state clear or crossfade the visual events without changing conserved counts.

Use a short hysteretic transition so ignition does not replace a visible particle shell in one frame. During the blend, particle opacity must fall at the same rate that liquid-envelope opacity rises. Collision and arrival contact continue to use one live outer boundary.

Add rendered cases for the last granular arrival, ignition with an existing loose reserve, the first molten arrival, overlapping molten impacts, a 500,000-grain molten batch, player feeding from the reservoir and reset during a splash. Check logical loose, incoming, committed and player-owned mass before and after every case.

Approval gate: the early body still shows satisfying particles, while the ignited body accepts matter like a liquid fuel layer. No persistent dot crust, dry graft mound, duplicated delivery or one-sided consumption gap remains after the molten handoff.

## Stage 3: compress dense matter automatically

This stage changes presentation only. Use local packing and local layer thickness to deform, overlap and visually weld grains. Use projected grain size to control drawing detail. Keep those physical and camera inputs separate in code.

Retain distinct grains at the exposed edge and in sparse deposits. Blend persistent sparse positions into stable dense positions as pressure grows. First regularise size, close gaps and flatten contacts along the surface tangent. At higher pressure, increase overlap and reduce colour variation so the deepest material approaches a single mass. Reverse the same changes as pressure falls.

Keep profile settings for packing thresholds, edge depth, detail scale and transition duration tunable. Choose values from the comparison scene. Do not use a single global grain-count threshold: 1,000 grains spread around a large body differ from 1,000 concentrated in a small pile.

For hydrogen, describe the result as dense or flowing material. Avoid claiming that enough hydrogen automatically becomes molten rock. For dev rock previews, support granular and cohesive appearances without unlocking later progression or inventing a thermal simulation.

Checks: repeated zoom, growth and compaction produce no popping, opacity holes, duplicate bright edges or changes to mass. The grain renderer and field simulation share the same radial geometry and packing convention. At the drawing cap, representative grain area grows with the logical-to-drawn ratio so additional matter cannot make the body more porous.

Run `pressure_compression_test.gd`, `dense_transition_test.gd`, `layer_ui_test.gd`, `compaction_test.gd` and `surface_test.gd`.

Approval gate: both a thin rim and a dense body look intentional. The old continuous loose fill remains comparison-only. This approval authorizes visual compression only, not automatic melting or layer formation.

## Stage 4: make the interior feel alive

Prioritize coherent motion and contrast over additional noise. Supply two restrained variants for the core first. Approve one before applying it to all zones. The central player must remain visually distinct from the stellar or planetary core.

Suggested art direction:

| Region | Motion to test | Avoid |
| --- | --- | --- |
| Stellar core | Slow deforming bright structures, local rising and returning paths, restrained heat variation | Whole-ring rotation, blinking lava wallpaper, uniform pulsing |
| Inner stellar zone | Broad slowly evolving ribbons with separate speeds and phases | Identical texture at a different tint |
| Outer stellar zone | Readable convection-like cells that grow and dissolve locally | Fine static speckle and obvious repeating tiles |
| Shallow stellar surface | Smaller evolving granules and sparse local edge activity | Full-screen sparks or an opaque glow hiding the grains |
| Future molten rock preview | Broad viscous folds with cooler persistent islands | Reusing the Sun shader unchanged |
| Future solid rock preview | Stable grain, fractures and local heat response | Making all cold rock churn to look alive |

These are art treatments, not claims of physically simulated stellar convection. Keep global spin at zero unless existing progression enables it. Local circulation can remain active without rotating the body or altering counts.

Shader approach to compare:

- Sample a small repeatable noise or flow texture once or twice, with slow coordinate deformation. Compare its cost against the existing procedural noise and nine-site granule search.
- Use two offset animation phases with a smooth crossfade to hide resets. Test that this produces evolving structures rather than two visibly sliding images.
- Anchor texture coordinates to the body and layer. Preserve phase through resizing. Define how material follows radial compression so patterns do not jump when a layer boundary moves.
- Use shared simulation time for pause, slow motion and replay. Pass only a few layer parameters such as speed, scale, contrast and seed. Avoid CPU texture regeneration each frame.
- Add readable relief and narrow local glow selectively. Keep diffuse colour, hot features and boundaries distinguishable. Test glow disabled before considering an extra pass.
- Mask effects to the correct layer. Keep boundaries legible, eliminate the polar seam and handle the small-radius region without pinching or exploding detail.

Motion must be visible in a normal-speed five-to-ten-second idle view at ordinary zoom, including before ignition. It should remain calm enough to watch for minutes. Provide reduced-motion settings that retain material identity while lowering animation speed and removing pulses.

GPU work has a budget too. A full-body fragment shader can become expensive at 4K. Avoid adding expensive calculations for invisible layers or subpixel detail. Compare a small offscreen body texture for costly interior effects against direct shading only if measurements justify it; keep crisp grains and UI at native resolution.

Run rendered `sun_ui_test.gd`, `layer_ui_test.gd`, `nested_layer_ui_test.gd` and `visual_field_test.gd`. Compare idle, conversion and ignition clips. Check pause/resume, pan/zoom, reset and unchanged geometry with effects disabled.

Approval gate: the user can see distinct internal movement without the core resembling a rotating picture. Keep only approved effects, with measured costs and a readable low-quality version.

## Stage 5: improve local flow only if required

Review the corrected visuals first. If the shape still pulls inward too broadly, isolate `_redistribute()` and compare the existing response against a local conservative flow model.

Prototype per-edge flux and damped surface velocity on the fixed angular field. Limit transfers by available mass and use bounded stable steps. Tune viscosity, yield threshold and damping by profile. Preserve nonnegative mass and test the periodic boundary. This can suggest shallow flow and waves; it cannot model overturning liquid, detached droplets or full interior convection.

Do not hide a conservation error with cosmetic radius smoothing. Keep the authoritative geometry and collision boundary consistent with the rendered shape. If display interpolation is used, document its lag and how contacts follow it.

Checks: a local impulse travels visibly to neighbours, symmetric impacts have no preferred handedness, a settled ring does not generate energy, and long-running flow conserves counts. Recheck all compaction and surface tests, including burst loading and thin remaining layers.

Approval gate: the new model provides a visible improvement over stage 4 at an acceptable measured cost. Otherwise retain the simpler accepted solver.

## Stage 6: optional material-state and ejecta experiments

Prepare the following as separate dev experiments only after the earlier motion is accepted. Ask for mechanic approval before connecting them to normal play. [Future worlds](FUTURE_WORLDS.md) remains research, not a newly approved campaign.

For melting, use a coarse material state with temperature or stored thermal energy, composition and phase fraction. Material amount may influence pressure, heat retention and heating; it should not alone trigger a universal melt threshold. Define heating, cooling, latent-heat treatment and separate melt/freeze thresholds before tuning. If a simplified heat proxy is chosen, label it as a game model and document its limits. Existing progression-driven stellar colour is not a complete thermal solver.

Use a small angular-by-depth grid only if local melting, cooling or sinking are required. Start with one material. Keep thermal update frequency and grid resolution bounded, then interpolate shader inputs. Measure before selecting their values. A shader can display a phase fraction but cannot serve as the authoritative simulation of cooling and mixing.

For solidification, persistent patches need material, location, phase and mass ownership. Today's dissolving bonded-patch effect is visual only. Reuse its bounded drawing techniques, not its temporary lifecycle as the material database. Decide how frozen loose matter affects flow without silently turning it into a formed progression layer.

For ejecta, remove mass from the source once and place it in bounded travelling parcels. Keep it in total owned mass while airborne. Re-deposit once at the actual return location, carrying composition and thermal state. Define escape explicitly. Pool exhaustion must merge parcels or reduce visual representatives, never delete excess mass. Camera changes must not change the result.

Approval gates are separate for melting, solid patches and ejecta. Each needs a deterministic replay, a conservation check, a saturated-pool case where relevant, measured cost and a user-approved gameplay rule before production integration.

## Stage 7: quality settings and integration

Offer low, medium and high presentation budgets that change active visual contacts, grain samples, shader detail and optional effects. The shared maximum stays 500,000. Choose actual limits from measurements. Keep logical simulation and outcomes identical across settings. If visual contacts own logical parcels, changing their count must preserve trajectories and delivery semantics or be redesigned as cosmetic sampling.

Proposed performance targets for user review are 60 FPS at 1080p on the development machine and 30 FPS at 720p on an identified modest machine. These are targets, not measured claims. Record p95 and p99 alongside median times; do not approve a visibly stuttering case on average FPS alone. Agree acceptable stage regressions against stage 0 before accepting additional effects.

Use rendered tests at 100,000 and 500,000 grains for settled, flow, flight and visual-stress scenarios. Test 4K for fill cost. A reduced resolution run on a powerful GPU does not certify weak-hardware performance. If no modest machine is available, record that approval as provisional.

Existing launch examples:

```powershell
.\start.bat --headless --script res://surface_test.gd
.\start.bat --script res://arrival_rim_test.gd
.\start.bat --script res://sun_ui_test.gd
.\start.bat --script res://performance_test.gd -- --grains=100000 --scenario=flow
.\start.bat --script res://performance_test.gd -- --grains=500000 --scenario=flight
.\start.bat --script res://performance_test.gd -- --grains=500000 --scenario=visual-stress
```

Use the configured engine through the launchers. For restricted runs, use process-local `APPDATA` under `scratch/checks/appdata` as described in `AGENTS.md`. New comparison commands must be documented after they exist; the stages above are not existing CLI switches.

Run focused tests during each stage. Before integration, run the applicable surface, arrival, ambient, core-layer, nested-layer, compaction, Sun progression, UI and dev-control suites. Inspect runtime warnings and shader errors. Update [Project](PROJECT.md) with accepted controls, measured results and remaining limits, and update [Surface](SURFACE.md) for the accepted model. Do not describe unapproved experiments as shipped features.

Final approval requires the complete loop: empty start, growth, repeated compaction into a thin layer, continued arrivals and ignition. Include an idle view of each body zone. The result must preserve satisfying close-up motion as well as the large-body appearance.

## Per-stage handoff record

Copy this into the review notes for each stage:

```text
Stage and candidate revision:
Previous approved revision:
Changed behaviour:
Launch command and scenario:
What the user should watch:
Before/after clips or deterministic replay:
Hardware, resolution, zoom and quality:
Logical mass, active contacts and drawn counts:
Median / p95 / p99 frame time:
CPU simulation and GPU timing, or unavailable:
Conservation and regression checks:
Known limitations:
Recommendation: approve / revise / reject
User decision and date:
Next stage permitted:
```

Keep rejected candidates recoverable through normal version control. Do not reset unrelated user changes, delete the original baseline or commit without the project's applicable authorization.
