# Progression model

`tools/progression_model.py` runs the planned campaign as deterministic maths. It reports real elapsed time for Core levels, automation crossover, every compact, and all six body completions. It does not run Godot or approximate frame performance.

This remains the coarse campaign envelope. [First Sun balance](SUN_BALANCE.md) and `tools/sun_model.py` now own detailed Sun timing and may produce a different Sun duration.

The balance data lives in `tools/progression_balance.json`. All values are provisional. They exist so timing discussions can use one reproducible model instead of disconnected guesses.

## Opening rules

- Normal progression begins with manual singularity activation.
- The player may click repeatedly or hold to repeat at a capped rate. Both use the same manual rate in the model.
- No automatic source runs before Core level 1.
- Core level 1 costs 20 mass and grants Automatic Invocation.
- Automatic Invocation starts at one activation per second. This is below both modelled manual rates.
- Rapid Recovery multiplies that base by 11. The resulting 11 activations per second is the deliberate early handoff from manual input to automation.
- The best envelope reaches that handoff at 26 seconds. The conservative envelope reaches it at 1 minute 52 seconds.
- Mass can go to the body or Core assimilation. The two supplied strategies use different allocations and talent orders.

The opening multiplier is large because it handles the whole manual-to-automatic handoff. Later talents should use smaller gains or different mechanics. An 11 times tooltip would look arbitrary, so the game UI should show the rate change from 1 to 11 per second or use several named ranks.

## Current timing envelope

The configuration produces this baseline:

| Milestone | Best envelope | Conservative envelope |
| --- | ---: | ---: |
| Automatic rate beats the scenario's manual rate | 0:26 | 1:52 |
| First outer compact | 12:17 | 38:55 |
| Sun complete | 2:42:58 | 4:42:18 |
| Rocky Seed complete | 3:14:04 | 5:48:59 |
| Gas Giant complete | 4:11:00 | 7:39:14 |
| Ice World complete | 5:08:53 | 9:14:11 |
| Volcanic World complete | 6:36:03 | 10:53:26 |
| Earth-like World complete | 7:47:52 | 12:09:45 |

The best result fits the 6 to 8 hour specialist target. The conservative result fits the 10 to 13 hour first-run target. The first compact target applies to an active opening. Low manual input, utility-first spending, deliberate overfill, and delayed compaction extend it to 39 minutes in the conservative envelope.

The conservative envelope is not the slowest mathematically possible play. A player who stops before buying Automatic Invocation cannot progress. A player who refuses to compact can also wait forever. The model compares two complete, reasonable routes.

## Sources and ambient capture

Singularity production is:

\[
M_{source}/s = (F_{manual} + F_{automatic}) M_{pull} E_{capture} P_{compact} P_{legacy}
\]

`F_manual` represents repeated clicks or the capped hold rate. The scenario yield multiplier represents the difference between a focused build with clean capture and a less efficient build. It remains explicit in the JSON.

Ambient matter uses the mass curve from the living design document:

\[
P_{capture} = min(P_{max}, P_0 + k\log_{10}(1 + M_{body}/M_{scale}))
\]

The default wider view shows 24 flybys per second. At zero body mass, only 0.05 percent are captured. Current body mass raises this chance toward a 12 percent cap. Gravity talents and Particle Nets multiply capture. Loose and compacted body mass both count. Matter assimilated by the player Core does not count as planet or star gravity.

In the current envelopes, ambient space supplies about 44,288 mass in the best run and 67,830 in the conservative run. The slower route captures more over wall-clock time and buys ambient talents earlier. This gives slower players some catch-up without erasing the faster production build.

## Compaction

Layer requirements grow geometrically. The default production reward is 1.45 times per compact. Overfill uses the living design formula:

\[
Reward = 1 + 0.35\ln(M_{actual}/M_{required})
\]

This campaign simulator retains its coarse overfill model. The live Sun now follows the newer fixed physical-layer model in [First Sun balance](SUN_BALANCE.md), consuming only the current logical requirement and retaining excess loose matter. See [live Sun implementation](SUN_PHASE.md). Production and talent effects remain deferred in Godot.

## Core talent data

The first model includes twelve Core nodes from the living design. Effects use named multipliers rather than custom code per scenario:

- source mass and automatic activation rate;
- singularity and ambient capture;
- future Core level cost;
- layer requirement;
- the Automatic Invocation unlock.

The supplied best route buys source production early. The conservative route buys assimilation and ambient capture first. Body talents, structure purchases, energy, heat, rotation, element composition, unique late challenges, offline progress, and random events are not modelled yet.

## Run it

From the repository root:

```powershell
python -B tools/progression_model.py
python -B tools/progression_model.py --scenario best --verbose
python -B tools/progression_model.py --json
python -B tools/progression_model.py --csv scratch/checks/progression-events.csv
python -B -m unittest discover -s tools -p "test_progression_model.py" -v
```

Use `--config` to test a copied balance file. JSON output contains all events and source totals, so a later optimiser or chart can consume it without parsing console text.

## Next modelling pass

Add body talent points and one unique completion condition per body before implementing later campaign systems. Then add structures and allocation presets. Keep randomness outside the base calculation. A seeded variance runner can compare lucky and unlucky flyby sequences after the deterministic economy is stable.
