# Ambient dust

The live scene now has an initial interstellar dust stream. It is independent of the generator and uses a bounded world-space simulation in `game/core/ambient_dust.gd`. This is a first-Sun prototype and a foundation for later planet inputs, not a complete stellar-ejection economy.

## Flight and capture

The default sector is 8,000 × 8,000 world units centred on the body. At reset, 384 motes are spread through it. New motes enter its upstream edge at 24 per second. They share direction `(0.96, 0.28)` and random speeds from 90 to 180 world units per second. Uncaptured motes leave the sector or expire after 90 seconds. Direction and velocity only bend due to gravity. Pan and zoom never change emission, positions or capture eligibility.

Deposited body mass supplies gravity; airborne matter and player-core mass do not. The softened inward acceleration is `min(1200, 200 * body_mass * gravity_multiplier / (distance² + 48²))`. This is an authored game approximation, not a calibrated astrophysics solver. Zero body mass means no pull and no capture.

Each actual surface encounter has capture probability `clamp(body_mass / (body_mass + 1000) * capture_multiplier, 0, 1)`. This is conditional on reaching the surface, not the fraction of all flybys. Distance affects deflection through the gravity law, and speed affects how long the mote stays in its influence. A continuous segment check prevents fast particles skipping through the body. An angular surface sample narrows the hit to the current uneven pile. It is still an approximate radial surface test, not per-grain collision physics.

Capture is attempted once per entry, rather than repeatedly rolling while inside. Captured motes disappear from the dust pool and hand off at their impact angle to deposited loose matter and the existing rim animation. `capture_ambient_batch()` accepts only available capacity, updates exact count and lifetime collected mass once, and never creates another sky flight or automatically compacts a layer. At full storage, the rejected arrival is discarded. Uncaptured motes behind the body are visually occluded and can reappear downstream.

## Adjustable inputs

| Config key | Effect |
|---|---|
| `flux_per_second` | Baseline incoming stream density |
| `base_direction` | Direction of newly entering motes |
| `minimum_speed`, `maximum_speed` | Speed range |
| `gravity_multiplier` | External gravity or attraction bonuses |
| `capture_multiplier` | Retention, nets or collection bonuses |
| `source_flux_multiplier` | Environmental supply modifier |
| `stellar_output` | Later Sun supply: multiplies flux by `1 + stellar_output`; defaults to zero |
| `capture_mass_scale` | How quickly contact capture strengthens with body mass |
| `gravity_strength`, `gravity_softening` | Attraction scale and near-core smoothing |
| `maximum_gravity_acceleration` | Stable upper acceleration limit |
| `lifetime_seconds` | Maximum flyby lifetime |

Future planet setup can set these through `main.ambient_dust.config` using the completed Sun's output and other factors. `set_bounds(Rect2)` is an explicit level/world setting, never a camera setting. Larger later worlds must choose suitable bounds, speeds and lifetime together. The default sector targets the first Sun; arbitrary billion-grain debug clouds can outgrow it. No later Sun-output, planet, talent purchase or ejection event is enabled by this prototype.

## Cost and limits

Only 768 motes can exist. Their lightweight trajectory work runs at 60 Hz and does not scale with stored grains. Each mote currently represents one incoming grain of the scene's active material. There is no mixed-element capture yet. Supply beyond a full pool is dropped, not accumulated into a huge deferred spawn. Extreme future injection rates will need separately balanced representative mass before this can model a high-throughput economy.

The shared drawing limit remains 500,000 samples: the main field reserves 768 slots for dust and draws at most 499,232 surface/air/rim samples. Dust drawing culls offscreen motes and uses small tinted tails. Clear and dev material changes reset dust accounting and reseed the visual field.

`ambient_dust_test.gd` checks flythrough, gravity, distance, varied speeds, multipliers, continuous capture, one-time rewards, pool bounds and reset. `ambient_integration_test.gd` checks the live handoff, capacity, mass, camera independence and shared budget; its rendered mode saves `scratch/checks/ambient-dust-live.png`.

## Visual pass and measurements

The backdrop uses a small precomputed noise texture, dim stars and gentle parallax. Stars and dust sit behind the body and HUD. Layer bevels, soft directional shading and texture relief add depth to the cutaway. Amber halo and slow solar prominence loops appear after ignition without enabling body spin. Loose aggregate matter also shades gradually toward its interior.

A local rendered RTX 4070 run at zoom 0.334 averaged 175.5 FPS over 3.418 seconds with 750,039 deposited grains, 499,232 shared field samples and 421 active dust motes (41 visible). The 95th-percentile frame time was 9.297 ms. Dust had added 39 grains. This was a short flowing-field check, not a guarantee for every zoom, layer or future injection rate. Benchmark flags `--without-dust` and `--without-backdrop` isolate the additions. The final far-dust broad-phase optimisation was checked separately for correctness.
