# Live Sun phase

The playable `game/` scene now follows [First Sun balance](SUN_BALANCE.md), which supersedes the earlier 21,000 × 1.62 prototype. Both root launchers open this scene. The first Core talent row and automatic matter are active; full timing, later talents and allocation controls remain separate passes.

## Mass and compaction

The seven fixed logical requirements are **6,000; 12,600; 26,460; 55,566; 116,689; 245,046; 514,597**. They total **976,958** and award exactly **1,000 SMU** across the seven layers. The previous design prose total of 976,957 was a one-unit arithmetic error in the rounded table.

Each click consumes only the current requirement, leaving surplus loose for later layers or the player. The grain requirement is `ceil(required_mass / element.mass)`. Counts and stored mass remain exact. Layer physical SMU is separate from logical resource cost so future construction-efficiency talents can reduce cost without changing the intended stellar milestone. The HUD credits completed layer SMU plus the current loose layer's partial credit; excess reserves are shown in the grain counter, not counted as extra completed stellar layers.

Manual outer conversion retains 10% of the consumed cross-sectional area. This is a presentation ratio, not scientific radius/volume loss or lost matter. Dev Ctrl-click can compact less, but only credits the actual fraction; the milestone and its 1.45 production reward require the complete amount. Each completed compact now strengthens the useful bonus from every live Core talent by another 1.45 multiplier. The interface displays the combined compact multiplier.

Ignition becomes eligible at **75 SMU** after the active conversion has finished. The body-temperature baseline rises from 0.2 MK to 4 MK there, then follows the design's smoothed curve to 15 MK. Seven finished layers, ignition and 1,000 SMU expose solar stabilisation readiness. No final capstone or System Seeding transition is automated.

## Visible interior

Outer compactions now reveal the zones themselves: first the stellar core, then radiative interior, convective envelope and shallow photosphere. There is no need to press inner densification merely to see more than one band. Later outer conversions enlarge the envelope and put 2% of newly consumed mass/area into the photosphere. These allocations are readable game construction rules, not measured solar density fractions.

Inner densification remains a separate manual action at **18,600 bound mass**. It moves 90% of the current core count into 10% of its previous area, retaining the remainder in the surrounding interior. Each densification now adds a permanent **1.12×** multiplier to live Core-talent production and a temporary **0.08** contraction-heat pulse. The pulse halves every 45 seconds. The temperature bar, notification and combined `POWER` multiplier make both results visible. Optional inner automation still needs its separate upgrade. It never triggers outer conversion.

The visible sequence adds amber rings and short matter streaks collapsing around the player Core so the change remains readable even when the true stellar band is mostly hidden behind it. Loose radial lookups remain fixed during this bound-layer animation and are reconciled once at completion; this avoids rebuilding all 720 field regions on every animation tick.

Each section has a distinct procedural texture: fine core cells, restrained radial streaks in the radiative interior, soft moving convection cells in the envelope and fine photospheric granulation. Conversion adds a travelling compression highlight and inward threads only within the converting annulus. The existing local shrink and shudder remain. Textures evolve gently without rotating the body; spin is still zero until a future talent enables it. Scale rings remain outside the formed interior.

## Colour and HUD

The default balanced star follows the design's red-orange ignition to yellow-white mature-star direction. Cool and hot build modifiers remain future talent inputs. The core is ivory, the radiative interior amber, the envelope warm gold and the photosphere pale cream. Early bound material starts burnt amber and warms as the protostar heats.

H now starts as a simple warm amber grain (`f6b85f`); He uses lighter warm gold (`ffe2a8`). Heavy debug profiles use slate carbon (`7b8998`) and muted metallic iron (`b6a1a0`). Incoming particles keep the material tint; settled/rim particles pick up a modest warm tint near an ignited body. These are authored identification colours, not literal elemental emission spectra. No heavy-element progression was unlocked.

Teal identifies the separate player core and its HUD. Warm amber identifies body controls. Two compact HUD panels report physical Sun mass/layer and centre temperature, plus player mass/level and its independent temperature.

Player levels cost `ceil(20 * 1.8^level)` and now cap at **15**. Absorption transfers deposited loose matter only. Dev Ctrl-click grants a free level without inventing assimilated mass. Each level grants one Core point. Gentle Current, Stronger Pull and Faster Flow implement the balance model's first three talents; the later branches remain placeholders. First Matter does not unlock helium. First Ignition at 75 SMU now has a player-facing discovery message, but helium production and release remain hooks. The planning model specifies a tested 75/25 hydrogen/helium singularity mix after a later discovery threshold plus a separate heat-sensitive solar-helium reserve. Neither helium rule is active in Godot yet.

## Verification

`sun_progression_test.gd` checks exact requirements, physical credit, weighted materials, partial dev conversion, reserves, player transfer, ignition and reset. `sun_ui_test.gd` captures the seed, ignition, fourth/seventh conversions and finished Sun through the live scene. Core, nested-layer, arrival and control checks cover retained behavior. Captures are in ignored `scratch/checks/sun-*.png`.

The latest visual pass adds locally drifting convection granules, folded core filaments and radiative ribbons. Sun highlights, compression threads and the photosphere rim retain amber/orange tint; hue-preserving highlight scaling avoids white clipping. The generator rim takes the selected material colour, while the player highlight stays teal. The two compaction actions are labelled Compact next outer layer and Compress existing core: seven outer milestones share the first button; the second re-compresses existing core matter. Inner auto is a separate upgrade toggle, not another layer type.
