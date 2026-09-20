# Development mode

Run `start-dev.bat` to start the game with `--dev`. `start.bat` stays in the normal hydrogen-only mode.

Clicking and holding are both intended opening controls. They share the same per-activation output. Automatic Invocation should overtake sustained manual input within a few minutes. See [Living game design](GAME_DESIGN.md) and [Progression model](PROGRESSION_MODEL.md).

The active field model holds up to 1,000,000,000 grains in both modes. The foreground orb starts at 10 grains per click and per second while held.

- Ctrl-click the orb to choose hydrogen, helium, carbon, or iron. The menu says that changing element clears the scene because the current solver uses one material profile.
- Ctrl-wheel over the orb changes the release amount. It moves in steps of 10 from 10 through 100, then steps of 100 through 10,000, steps of 10,000 through 100,000, and steps of 100,000 through the 500,000 maximum.

These are testing controls. They make existing material profiles reachable for inspection. They do not unlock progression or add features that are not in the game.

Every future paid or locked feature must support Ctrl-click to unlock it for free in development mode. Normal mode must keep its costs and unlock requirements. Record the gesture and check both modes when adding the feature.

The 500,000-grain release ceiling is separate from the one-billion-grain total capacity. Drawing uses at most 500,000 representative samples across incoming and deposited matter; the full material count and surface volume remain in the simulation. Large bursts can be much heavier than a settled pile. Press C to clear the material.

Compact outer matter is manual. The playable Sun uses fixed layer mass requirements and consumes only the current requirement; excess stays loose. Dev Ctrl-click bypasses readiness but still needs existing loose material. The generic planet mode retains full-ring and pressure requirements. C and element changes clear formed layers and Sun progression.

Absorb for core level transfers loose deposited material into the player's separate mass account. Dev Ctrl-click grants a level free without adding fake mass; normal Ctrl-click pays the normal cost. The Sun player-level cap is fifteen. Its talent rewards and thermal model remain deferred.

Nested body layers are separate from the player core. Densify planet / sun core has its own mass milestone; dev Ctrl-click bypasses it. Inner auto is locked until the player-upgrade hook grants it; Ctrl-click grants that upgrade free in dev mode. Enabling it never compacts loose outer matter. The automation unlock/toggle survive clear and element changes. Normal purchase costs await progression maths.
