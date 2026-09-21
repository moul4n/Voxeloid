# First Sun balance

`tools/sun_model.py` is the detailed planning model for the first Sun. It supersedes the coarse Sun stage inside `tools/progression_model.py` for design work. The campaign model still estimates the full run.

The playable prototype is documented in [Sun progression and presentation](SUN_PHASE.md). It now shares this model's seven layer requirements, 1,000 SMU target and fifteen-level Core cap. The live prototype temporarily allows ten ranks in each opening talent so production can be tested across a wider range. The Python timing results below still use the older 1/5/5 opening caps and must be rebalanced before they are treated as current pacing evidence.

## Physical anchors and game units

The finished body represents one solar mass and 1,000 Stellar Mass Units. The physical readout uses a solar mass of about \(1.989\times10^{30}\) kg, a radius near 695,700 km, and a finished core temperature of 15 million K. NASA gives the same order of magnitude for the Sun's mass, radius, and core temperature. It also describes hydrogen fusion into helium as the source of solar heat and light. [NASA Sun facts](https://science.nasa.gov/sun/facts/)

Sustained hydrogen burning begins at 75 SMU in the game. That is 0.075 solar masses. Modern low-mass stellar models place the solar-metallicity hydrogen-burning limit close to 0.075 solar masses, although the exact limit depends on composition and the equation of state. [Chabrier and colleagues, 2022](https://arxiv.org/abs/2212.07153)

Logical game mass is not kilograms and one visible hydrogen grain is not one literal atom. Seven fixed physical layers map 976,958 logical mass to 1,000 SMU:

| Layer | Logical mass | Cumulative mass | Layer SMU | Cumulative SMU |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 6,000 | 6,000 | 6.142 | 6.142 |
| 2 | 12,600 | 18,600 | 12.897 | 19.039 |
| 3 | 26,460 | 45,060 | 27.084 | 46.123 |
| 4 | 55,566 | 100,626 | 56.877 | 102.999 |
| 5 | 116,689 | 217,315 | 119.441 | 222.440 |
| 6 | 245,046 | 462,361 | 250.826 | 473.266 |
| 7 | 514,597 | 976,958 | 526.734 | 1,000.000 |

The requirements grow by 2.1 times while each compact multiplies production by 1.45. Later layers therefore remain longer projects even after earlier work becomes faster. A Dense Shells rank lowers the logical requirement by 8 percent. The layer still awards its fixed physical SMU. This is construction efficiency, not missing stellar mass.

## Baseline times

| Build | First compact | Ignition | Sun complete | Core levels | Peak Core overclock |
| --- | ---: | ---: | ---: | ---: | ---: |
| One click each second, no upgrades | 1:40:58 | 10:07:19 | 45:53:43 | 0 | 1.12x |
| Hold at nine activations each second, no upgrades | 0:12:12 | 1:14:12 | 5:25:50 | 0 | 1.12x |
| Automation first | 0:11:41 | 1:06:55 | 2:15:40 | 15 | 1.13x |
| Core mass first | 0:23:22 | 3:08:59 | 5:11:45 | 15 | 1.11x |
| Thermal overclock | 0:12:50 | 1:49:44 | 4:04:20 | 15 | 3.62x |
| Accretion first | 0:11:38 | 1:11:10 | 2:54:04 | 15 | 1.12x |

The click-only result means one activation every second without stopping for almost 46 hours. It is a diagnostic, not a reasonable play style. Holding is the useful no-upgrade comparison.

The automation build is the first-run speed route. The Core mass and thermal routes are slower during the Sun because they buy benefits meant to persist into later bodies. Their value cannot be judged from the Sun time alone.

## Why talent order matters

The automation route spends its first five Core points on Automatic Invocation and four Rapid Recovery ranks. It then buys Resonant Pull.

| Event | Elapsed time |
| --- | ---: |
| Automatic Invocation | 0:06 |
| Rapid Recovery rank 1 | 0:17 |
| Rapid Recovery rank 4 | 1:50 |
| Resonant Pull rank 3 | 7:40 |
| Automation exceeds nine manual activations per second | 7:41 |
| First compact | 11:41 |

The accretion route buys five Resonant Pull ranks before most Rapid Recovery ranks. It gets more mass per activation but waits until 20:48 for automation to beat the manual cap. It finishes 38 minutes later than the automation route.

This is the intended opening rhythm. Automation unlocks almost immediately but starts weak. The next few points make it usable. Around eight minutes, it becomes safe to stop holding and manage allocation, compaction, and the two talent trees instead.

## Core levels and points

Each Core level grants one persistent Core talent point. The Sun caps Core growth at level 15. The base cost is:

\[
C_n = 20\times1.8^{n-1}
\]

| Core level | Level cost | Cumulative cost |
| ---: | ---: | ---: |
| 1 | 20 | 20 |
| 2 | 36 | 56 |
| 3 | 65 | 121 |
| 4 | 117 | 237 |
| 5 | 210 | 447 |
| 6 | 378 | 825 |
| 7 | 680 | 1,506 |
| 8 | 1,224 | 2,730 |
| 9 | 2,204 | 4,934 |
| 10 | 3,967 | 8,901 |
| 11 | 7,141 | 16,042 |
| 12 | 12,854 | 28,896 |
| 13 | 23,137 | 52,032 |
| 14 | 41,646 | 93,678 |
| 15 | 74,963 | 168,641 |

Efficient Assimilation reduces future costs by 10 percent per rank. It does not refund levels already bought.

The current prototype Core tree contains 59 ranks after expanding its opening row. The Sun supplies at most 15 points, so no first-Sun build can take everything. The full campaign should add more branches and finish with fewer points than its total rank count. A build must leave useful nodes behind.

## Campaign point budget proposal

The next campaign model should test these cumulative Core-level caps:

| Completed site | Core level cap |
| --- | ---: |
| Sun | 15 |
| Rocky seed | 20 |
| Lava world | 24 |
| Ice ocean world | 28 |
| Gas or Hycean world | 32 |
| Carbon-rich world | 36 |
| Final life-bearing world | 40 |

That gives at most 40 Core points on a first run. The full Core tree should contain about 70 ranks across its six branches. A first run could buy roughly 57 percent even after reaching every level cap.

Each body should keep a separate tree near 21 ranks and award seven local points, one per compact. Those points last for that body and end in its transition protocol or legacy. This repeats a familiar level structure without letting the player fill every route.

## Core talent tree

The live tutorial requires one Automatic Invocation rank before the other two opening nodes. Later ranks follow the spent-point gates below.

| Talent | Ranks | Requires spent | Effect per rank |
| --- | ---: | ---: | --- |
| Automatic Invocation | 10 | 0 | Adds one automatic activation each second |
| Resonant Pull | 10 | 0 | 15 percent more mass per singularity activation; requires Automatic Invocation |
| Rapid Recovery | 10 | 0 | 1.6 times automatic activation rate; requires Automatic Invocation |
| Efficient Assimilation | 4 | 2 | 10 percent lower future Core level costs |
| Gravity Focus | 4 | 3 | 6 percent better singularity capture and 15 percent better ambient capture |
| Mass Lattice | 5 | 3 | Adds 0.06 to the logarithmic Core-mass benefit |
| Compression Harvest | 4 | 6 | Converts 1.5 percent of compacted mass into Core growth credit |
| Thermal Conduits | 4 | 6 | Adds 0.10 heat coupling and 0.07 safe heat |
| Echo Pull | 3 | 9 | 12 percent more mass per activation |
| Overclock Governor | 4 | 9 | Adds 0.55 overclock gain and 0.03 safe heat |
| Continuous Breach | 1 | 14 | Doubles automatic activation rate |

Compression Harvest grants growth credit, not physical matter. It cannot increase body mass or the physical mass of the Core. This keeps resource conservation exact.

## Core mass

Mass sent to the Core is unavailable for the Sun. In return, assimilated Core mass multiplies all captured production:

\[
B_{mass}=1+g\log_{10}\left(1+\frac{M_{core}}{1000}\right)
\]

The base value of \(g\) is 0.04. Each Mass Lattice rank adds 0.06. The logarithm prevents a Core-heavy build from scaling without limit.

The current Core-mass scenario sends 52 percent of incoming matter to the Core until level 15, then keeps sending 18 percent for direct mass growth. It ends with 265,167 logical Core mass and finishes in 5:11:45. That is intentionally slower than the automation route. It buys persistent Core strength, cheaper levels, and compaction growth credit for later bodies.

## Heat and overclocking

The body temperature rises from 0.2 million K to 4 million K at 75 SMU. It then follows a smoothed curve to 15 million K at completion.

Core heat is:

\[
H=\frac{T_{body}}{15\text{ MK}}C_{heat}+H_{compact}
\]

Each compact adds a short heat spike that halves every 45 seconds. Heat above 0.10 drives the Core overclock:

\[
B_{overclock}=1+max(0,H-0.10)G_{overclock}
\]

Heat above the safe limit reduces capture efficiency. Thermal Conduits raise coupling and the safe limit together. Overclock Governor raises the production gained from heat. A thermal build peaks at 3.62 times Core speed in the completed Sun. It still takes 4:04:20 because most of its power arrives after ignition. That late payoff should carry into planet construction through the persistent Core.

## Helium discovery and generation

The level begins with hydrogen-only singularity output. Ignition starts a separate passive solar-helium reserve. Once that reserve produces a 0.5 logical-mass-equivalent discovery signal, the Core learns the helium pattern and the singularity begins generating both elements automatically.

The unlocked singularity mix is fixed at 75 percent hydrogen and 25 percent helium by mass. This uses the approximate primordial composition of star-forming matter, not the composition of present-day solar wind. NASA educational material describes primordial matter as roughly 75 percent hydrogen and 25 percent helium by mass. [NASA primordial nucleosynthesis report](https://ntrs.nasa.gov/api/citations/19860021139/downloads/19860021139.pdf)

One logical helium grain has four times the mass of one hydrogen grain. The 75/25 mass mix therefore emits about twelve hydrogen grains for each helium grain:

\[
\frac{0.75/1}{0.25/4}=12
\]

The simulator tracks this split independently and tests the ratio. Ambient captures remain hydrogen during the first Sun. Passive solar helium is a discovery and export reserve. It does not increase compactable Sun mass, pay Core costs or break construction-mass conservation.

Passive solar production is:

\[
\dot M_{He}=0.1
\left(\frac{SMU}{1000}\right)^{0.8}
\left(\frac{T}{15\text{ MK}}\right)^2
B_{profile}B_{fusion}
\]

The 0.1 rate is a game unit at a finished balanced Sun, not a physical atomic conversion. Real solar fusion is vastly larger and slower in consequence than the compressed game timescale. NASA gives an order of roughly 600 million tons of hydrogen fused each second in the Sun. [NASA solar energy explainer](https://spdf.gsfc.nasa.gov/pub/documents/old/websites/sunearthday.nasa.gov/2007/locations/ttt_solarenergy.php)

The same automation route produces these results when only its stellar design changes:

| Design | Temperature multiplier | Helium-rate multiplier | Ignition | Helium learned | Sun complete | Passive helium at completion |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Cool | 0.94x | 0.55x | 1:33:43 | 1:41:48 | 2:15:52 | 23.2 |
| Balanced | 1.00x | 1.00x | 1:06:55 | 1:15:22 | 2:15:40 | 49.4 |
| Hot | 1.08x | 1.80x | 1:06:55 | 1:11:08 | 2:15:21 | 102.8 |

A cool design crosses the 4 MK ignition condition later because its temperature multiplier holds it below the threshold at 75 SMU. A hot design reaches the mass gate at the same time as balanced, then learns helium sooner and builds a larger reserve. Fusion Feedback multiplies passive helium production as well as post-ignition singularity production. The singularity's 75/25 mix stays fixed for all three designs so temperature choice affects supply speed rather than elemental correctness.

## Sun talent tree

Each compact grants one Sun talent point. These points last only for the Sun level. Seven points cannot fill the 21-rank tree.

| Talent | Ranks | Effect per rank |
| --- | ---: | --- |
| Accretion Channels | 3 | 12 percent better singularity capture |
| Dense Shells | 3 | 8 percent less logical mass required by later layers |
| Compression Drive | 3 | 8 percent stronger production reward from each compact |
| Gravitational Heating | 3 | Adds 0.08 Core heat coupling |
| Fusion Feedback | 3 | 15 percent more production after ignition |
| Retention Field | 2 | Reduces heat loss penalty by 30 percent |
| Ambient Funnel | 3 | 25 percent better ambient capture |
| System Seeding Protocol | 1 | Requires six spent points and consumes the seventh point to begin the transition to planet construction |

The simulator spends the seventh point on System Seeding Protocol in every upgraded route. The protocol still needs explicit fusion, gravity, rotation, and composition requirements when those systems exist. It is a transition unlock, not another short-term production multiplier.

## New Game Plus proposal

Body talent points reset with their body. Core points persist for the current run.

A first New Game Plus pass could carry 25 percent of spent Core points as Memory, rounded down and capped at 10. Memory can repurchase ordinary Core ranks but cannot bypass level, tier, element, or body gates. A fresh New Game carries no mechanical points. This is a proposal for the later campaign model, not a settled rule.

## Run the model

```powershell
python -B tools/sun_model.py
python -B tools/sun_model.py --scenario automation --verbose
python -B tools/sun_model.py --scenario automation --stellar-profile hot
python -B tools/sun_model.py --scenario click_no_upgrades --manual-rate 2.5
python -B tools/sun_model.py --scenario automation --layer-base 21000 --layer-growth 1.62
python -B tools/sun_model.py --scenario automation --layer-base 21000 --layer-growth 1.62 --core-cap 7
python -B tools/sun_model.py --json
python -B tools/sun_model.py --csv scratch/checks/sun-events.csv
python -B -m unittest discover -s tools -p "test_sun_model.py" -v
```

`--stellar-profile` compares cool, balanced and hot designs without changing the chosen build. `--manual-rate` tests a player's actual clicking speed without adding another scenario. `--manual-minutes` changes how long the player remains active. The layer and Core-cap overrides test alternate curves without editing either file.

## Decisions to test next

- Whether fifteen Core points arrive too quickly during the first Sun.
- Re-run every route after the temporary 10/10/10 opening talent caps are added to the Python model.
- Whether a 5 hour 26 minute no-upgrade hold run is an acceptable failure case or still too generous.
- Whether Core-mass and thermal builds need a small Sun benefit, or whether their later-body advantage is enough.
- Whether helium discovery should stay near eight minutes after ignition or become a talent-dependent milestone.
- Whether cool stars need a retention or volatile bonus large enough to offset their lower helium output.
- Which fusion, gravity, rotation, and composition checks gate System Seeding Protocol.
- Whether ignition should require an explicit player action after reaching 75 SMU and 4 million K.
