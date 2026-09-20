# Compaction

[Living game design](GAME_DESIGN.md) defines the target progression. The playable Sun now uses [Sun phase rules](SUN_PHASE.md), with progression-owned fixed Sun layer requirements and preserved excess loose matter. The fixed thresholds below describe the retained generic planet test mode, not the Sun. The pressure/geometry model and local animations remain shared.

[First Sun balance](SUN_BALANCE.md) tests a faster opening and steeper late-layer curve entirely in Python. Its proposed requirements are not live Godot settings.

The player core is the small object at the centre. It is separate from the **planet or sun core**, inner mantle, outer mantle, and shallow crust or surface. Those body layers hold collected matter; they are not player upgrades themselves.

More grains above a layer mean more weight pressing down on it. Increasing the element's mass or gravity response adds pressure without changing the number of grains. Higher pressure reduces the space occupied by each grain, so the inner material becomes denser and the whole pile occupies less space.

This is a game model for the radial cutaway. It uses the weight above each depth within a surface region, divided by that region's core arc length times grain diameter. Pressure is in game units. It does not calculate real stellar pressure or temperature.

Edit each element in `game/core/elements.gd` to tune it:

| Setting | Effect |
| --- | --- |
| `mass` | Weight contributed by each grain; also retains its existing effect on movement |
| `gravity_response` | Scales weight as well as flight and surface flow |
| `compaction_loose_packing` | Initial density without pressure; higher values leave less space |
| `compaction_stage_pressures` | Three pressure scales; increase one to require more weight for that stage |
| `compaction_stage_packings` | Three successively denser packing targets |
| `compaction_response` | Multiplies pressure for packing; zero disables compression |
| `compaction_depth_darkening` | Strength of compression shading; zero preserves the original tint |
| `compaction_creep` | Slow flow below the resting slope, allowing rough material to spread past flat patches |
| `core_layer_min_grains` | Minimum loose deposited grains before the button becomes available |
| `core_layer_grains` | Grains bound into a permanent core shell per click |
| `core_layer_min_packing` | Required inner compaction, measured between loose packing and completely filled space |
| `core_layer_area_ratio` | Final area divided by the consumed material's actual area before conversion; currently 0.10 |
| `core_layer_duration` | Seconds for the shuddering shrink animation; currently 1.4 |
| `inner_layer_min_mass` | Provisional mass milestone for inner conversion; currently 200,000 |
| `inner_layer_mass_fraction` | Share of the current body core transferred into a denser core; currently 0.90 |
| `inner_layer_area_ratio` | Final area of that consumed share relative to its original area; currently 0.10 |
| `inner_layer_duration` | Duration of inner conversion, independently of outer compaction |
| `inner_automation_multiplier` | Growth needed between inner milestones; currently 1.75 |
| `inner_mantle_fraction`, `outer_mantle_fraction`, `surface_fraction` | Initial division of the residual material; currently 60/35/5 percent |
| `body_kind`, `surface_kind` | Labels for Planet/Sun and Crust/Gas surface/Water surface |

Stages blend smoothly rather than switching at a hard threshold. At each stage the blend is `pressure / (pressure + stage_pressure)`, after scaling pressure by `compaction_response`. Keep pressure scales and target packing values increasing. The defaults make heavier elements denser and easier to compact while retaining their original friction, flow rate, and resting slope. These settings are editable data, not yet in-game sliders.

The surface and grain renderer use the same depth-to-volume mapping. Material counts remain exact, including at the billion-grain cap. Drawing still uses at most 500,000 representative samples.

The implementation caches a 512-interval cumulative volume curve and 16 depth intervals per surface region. A numerical integration check verifies the volume curve to within 0.1 percent for the tested loads. The shader reads the depth lookup rather than integrating pressure per grain. Dense grain footprints also blend together visually; their drawn overlap is an approximation of continuous material, not individual hard-circle contact.

Loose compaction follows the current load and is reversible when material flows away. A continuous colour fill appears as the grains overlap densely, with individual grain detail fading into it. Default pressure thresholds have been lowered so this is visible at 750,000 hydrogen grains. Drawing samples continue to represent their full share of the population at every zoom. The inner colour shift represents compression only; a later heat system can replace or combine it with a temperature colour.

Permanent conversion currently requires clicking **Compact outer matter** below the generator. By default, it needs at least 250,000 loose deposited grains, at least 100,000 grains distributed around the complete ring, and inner compaction of 45 percent in the least-loaded region. The button reports the missing condition. Each click binds 100,000 existing grains into a solid core shell. There is no automatic conversion and no loss or creation of matter. Further arrivals settle outside the new core. Additional layers require another click and the conditions must be met again. The target design later replaces the fixed amount with a geometric requirement, optional overfill, one body talent point, and a production reward while keeping the action manual.

Each conversion now shrinks the consumed shell to 10 percent of its original occupied **area** in this 2D cutaway. This is not 10 percent of its radius or of the whole planet. The footprint is measured from the pressure-packed material before conversion, and already formed layers keep their stored area. The new layer contracts over 1.4 seconds with a damped shudder and a small brightness flicker. Surrounding grains move inward with the changing core boundary. Counts transfer into the core immediately and remain conserved throughout the animation. Another conversion is blocked until it finishes, including in dev mode; arrivals may continue. Clear cancels the animation.

In dev mode, Ctrl-click bypasses the unlock requirements. It still needs some settled material around the full ring and never creates free matter. C clears both loose grains and formed layers. Choosing another element also resets both. Pressure uses the original core reference area so forming a shell does not suddenly release pressure throughout the remaining material.

Each field currently contains one element. Choosing another element in the dev menu clears it. These are depth layers of that element, not persistent layers of mixed elements.

## Inner layers and automation

**Compact outer matter** always requires the player to click. It binds loose material into the initial planet or sun core. After the body has mantles, further outer compaction adds to the outer mantle beneath the shallow surface. Inner automation never calls this action.

**Densify planet / sun core** acts on already bound material at its own milestone. The first conversion moves 90 percent of the core's grains into a denser core, with 10 percent of that consumed portion's area. The residual 10 percent retains its occupied area and is divided into an inner mantle, outer mantle, and shallow surface. For example, a 200,000-grain core becomes a 180,000-grain denser core, 12,000-grain inner mantle, 7,000-grain outer mantle, and 1,000-grain surface. The final combined area is 19 percent of the source core's area. These provisional ratios can change when the progression maths is ready.

Later inner conversions densify the body core again and add the residual to the inner mantle. Existing outer mantle and surface material keep their counts and occupied areas. Their boundaries may move inward as space is freed. Shudder and flicker are restricted to the converting section; the player and unrelated layers do not flash. Conversions are serialized so two animations cannot consume the same matter.

Inner automation starts locked. The player-upgrade system can grant it through `unlock_inner_automation()`, after which it can be toggled on or off. Dev Ctrl-click on **Inner auto** grants the upgrade for free. Normal play does not yet connect this hook to a Core talent or purchase. The first balance model defines Core costs but does not assign this inner automation unlock yet. The first implementation milestone requires enough bound body mass. Later milestones track lifetime collected mass, including material subsequently spent on construction. A new growth milestone is required after each inner conversion, preventing an automatic chain from repeatedly consuming the same core at an unchanged collected amount.

Construction and upgrade code can call `consume_loose(amount)`. It can spend only loose deposited material, never incoming grains or bound core/mantle/surface matter. No upgrade costs or construction purchases are added by this step. Clear and element selection reset body material and milestones, while keeping the player automation unlock and toggle.

Run `start.bat --headless --script res://compaction_test.gd` to check all four demo elements, weight scaling, compacted geometry, and conservation. Use `start-dev.bat`, Ctrl-click the orb to select an element, and Ctrl-wheel to adjust the incoming amount.

Run `start.bat --headless --script res://core_layer_test.gd` for layer conservation and gating, and `start.bat --script res://layer_ui_test.gd` for button, dev bypass, zoom rings, and rendered layer checks. Range rings use labelled world distances and adapt to the visible range while zooming out.

Nested-layer checks are `start.bat --headless --script res://nested_layer_test.gd` and `start.bat --script res://nested_layer_ui_test.gd`. They cover the inner mass split, separate animated geometry, shallow surface, growth milestones, upgrade gating and loose-only spending.
