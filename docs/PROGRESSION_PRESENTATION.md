# Progression and presentation

Voxeloid now has a separate progression layer between the simulation and the interface. The simulation remains authoritative for mass, heat, layers, capture and player Core state. Progression reads those facts, grants unlocks once, and selects the current target. Presentation reads the resulting state and decides what the player can see.

This split keeps balance and interface changes out of the billion-grain field model.

## Player and developer starts

`start.bat` is the player start. It opens on the initial Core and singularity with no developer labels, element selector, free unlock gestures, clear key or decorative star field. The player sees one useful action and one current target. Later interface sections appear when their information becomes useful.

`start-dev.bat` keeps the existing Ctrl-click and Ctrl-wheel overrides. F1 opens the progression lab. Objective timing, metric refresh and opening zoom work now. HUD scale, visual impact and future audio levels are labelled hooks for the render and playback work that remains. The lab can also complete the current target, replay guidance and reset the progression presentation without changing release defaults.

## Runtime structure

- `progression/metric_registry.gd` owns stable named measurements and records their source and revision.
- `progression/progression_director.gd` evaluates typed conditions and keeps the current target pinned.
- `progression/unlock_registry.gd` grants actions and interface sections once.
- `progression/progression_tuning.gd` holds the main flow and feel controls.
- `progression/core_talent_tree.gd` owns Core points, documented spend tiers and the first live talent effects.
- `presentation/player_hud.gd` draws the player-facing target, simple indicators, layered talent tree and guidance bubble.
- `presentation/notification_tour.gd` stores dismissible guided steps by semantic target rather than screen coordinates.
- `presentation/audio_director.gd` and `presentation/visual_cue_registry.gd` record future sound and art requests without requiring assets.

## Sun growth targets

The first targets introduce one idea at a time.

1. Call the first spark.
2. Gather at least 20 mass, then reveal the mass bar and Feed Core action.
3. Feed the heart.
4. Wake the Core, reveal its highlighted point box, then let the player open and learn the talent tree.
5. Catch a drifter.
6. Gather mass for First Matter.
7. Make the first permanent layer hold.

First Matter is the first stable layer, not the helium unlock. After it forms, the Quest card continues through the remaining gather and compact steps. Each completed compact multiplies the useful part of every Core talent by 1.45, and the talent launcher shows the current combined multiplier.

At 75 Stellar Mass Units, the fourth-layer route pauses for First Ignition. Its guidance says that the mass has ignited, heat is flooding the system and helium is beginning to form. Usable helium comes later, after a separate discovery threshold; the live game does not yet produce or release it.

The separate `DENSIFY STELLAR CORE` action becomes available once enough matter is already bound. It does not spend or create mass. It packs 90 percent of the existing central band into 10 percent of its former area and moves the remainder into the surrounding interior. Each use adds 1.12 times to the combined talent-power multiplier and creates a visible heat pulse that fades with a 45-second half-life. The button states this reward before purchase; afterward the temperature bar, `POWER` readout and short guidance bubble show the result.

The opening target shows only a short name, one bar and its current number. Explanations move into short guidance bubbles or later hover details. Persistent mass and heat bars do not reset when the target changes. Actions that transform the body remain explicit clicks.

The permanent-layer action sits in the left action rail below Feed Core. It is a compact button labelled `FORM FIRST MATTER` for the first layer and `COMPACT NEXT LAYER` afterward. The Quest introduces the requirement before this action appears. `Shape Shell` is no longer used because it sounds like a general editor rather than a committed progression step.

Feeding the Core now draws loose matter streaming inward from the body and produces a short central glow. This makes the transfer visible without using a full-screen flash. World particles and impact flashes remain behind all Quest, talent and guidance panels.

## Core talents

Each Core level grants one point. The compact Core launcher opens a layered tree with small placeholder nodes. Only the first row is playable in this pass:

- Gentle Current (`Automatic Invocation` in the balance model) adds one automatic call each second per rank. Its Flow node is highlighted and is the required first pick.
- Stronger Pull (`Resonant Pull`) adds 15 percent matter per manual call and carries fractional gains between calls.
- Faster Flow (`Rapid Recovery`) multiplies the automatic call rate by 1.6 per rank.

Each of these opening talents currently accepts ten ranks. This deliberately gives all fifteen first-Sun Core points somewhere useful to go while the production curve is being tuned.

The first tree-opening hint is recorded as a one-time tutorial unlock. Closing and reopening Talents does not replay it; resetting progression guidance intentionally clears it.

The later documented tiers remain visible as dim planned nodes. Their existing spent-point gates are 2, 3, 6, 9 and 14. Gathered-mass milestones reveal their depth, but do not create a second point currency. The faint stellar backdrop appears after three points have been spent. Its guidance explains that the heavier Core is reaching farther and may eventually attract dangerous large bodies. This visual reward costs no separate point. Development mode can Ctrl-click a live node to grant its rank without requirements.

## Main tuning controls

`ProgressionTuning` contains the first editable values:

- metric refresh rate
- completion hold time
- early body-mass target
- first shell mass target
- stellar backdrop spent-point requirement
- opening zoom and unlocked range
- camera transition time and target fill
- HUD scale
- low-population particle display size and fade range
- visual unlock intensity
- passive and event audio levels

These values are presentation and pacing controls. They do not change logical grain counts, mass conservation, physical field radii or the 500,000-sample drawing limit.

## Interface rule

The normal interface should answer three questions: what can I do now, what transformation is approaching, and what will this choice improve? Introduce each mechanic as a target first. Reveal its button only after the player meets that target. The target card uses a distinct Quest treatment; persistent Mass and Core controls use their own system styling. Do not show disabled systems long before the player can use them.

This takes the useful part of incremental-game presentation: start with one legible action, reveal capability when it becomes relevant, and retain only the measurements needed for the current decision. The player should discover scale through the game rather than receive the finished dashboard on the first frame.
