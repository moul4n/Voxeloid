# If I Was Building a Model

## Living Game Design Document

**Document status:** Foundation draft 0.2
**Last updated:** 20 September 2026
**Purpose:** This is the canonical record of the game's agreed direction. New ideas should be reconciled with this document instead of accumulating as disconnected systems.

## Authority and implementation status

This file is the canonical design target. [Project status](PROJECT.md), [Surface model](SURFACE.md), and [Compaction](COMPACTION.md) describe what the current prototype actually does. When an older plan conflicts with this file, this file controls future work. Current implementation limits remain facts until code and tests replace them.

Decision labels used throughout:

- **Stable:** Part of the current identity of the game.
- **Tunable:** The design is accepted, but its numbers will need playtesting.
- **Open:** A useful direction that has not yet been committed to.

---

## 1. High concept

**Stable**

*If I Was Building a Model* is a short, replayable idle game about using an unexplained spherical machine-creature, called the **Core** in this document, to build a star and then a sequence of planets particle by particle.

The player begins tightly zoomed in on the Core in an otherwise empty void. Beside it is an unexplained black singularity. The player commands the singularity to emit the first hydrogen particles. Only gradually, as the camera pulls back, does the astronomical scale of the construction become apparent.

The current celestial body is always shown as a two-dimensional cut-through view of a three-dimensional sphere. Loose particles visibly fall, orbit, collide and settle. When enough material forms an outer layer, the player **compacts** it into the existing body. Compaction is the game's recurring local prestige: an old layer becomes a permanent interior band, production jumps, and construction of the next layer begins.

The intended first playthrough is approximately **10–13 hours**. Strong specialisation and good compaction timing should permit substantially faster runs. Passive waiting should remain viable, but active investment and good talent combinations should be noticeably faster.

### Design pillars

1. **Particles make progress visible.** Growth is seen rather than represented only by counters.
2. **Compaction is the heartbeat.** Every compact preserves history, increases power and makes the previous challenge easier.
3. **Old difficulty becomes automation.** Every major phase automates an earlier verb and introduces one new difficult process.
4. **The player's build changes the model.** Talent choices alter colours, layers, rotation, atmosphere, structures and later bodies in the sky.
5. **Science supplies understandable rules, not obligations.** Real concepts anchor the fantasy, while timescales, element access and the singularity are intentionally fictionalised.
6. **No logistics administration.** Transport, trade and collection networks can be unlocked and seen, but they act as modifiers rather than requiring route management.

---

## 2. The nested progression structure

**Stable**

There are three nested forms of progression.

### 2.1 Layer compaction: frequent local prestige

The player builds one active outer layer from simulated particles. At the required mass, the player may compact it. Compaction:

- converts active particles into a permanent aggregate layer;
- increases density, pressure, heat and production;
- awards a point for the current body's talent tree;
- raises the requirement for the next layer;
- preserves the compacted layer's dominant composition and build choices visually;
- keeps active rendering and arrival work bounded for the next layer.

The player may overfill a layer before compacting. Overfilling gives a better reward, but with diminishing returns, so waiting is valid without always being optimal.

### 2.2 Celestial completion: level prestige

Completing the target mass and final challenge of a star or planet ends that level. The completed body:

- remains in the system and is visible in later skies;
- retains the player's colour, composition, spin and major structures;
- supplies one or two passive legacy effects;
- automates the processes that defined its level;
- unlocks the next construction site.

The Core moves to the centre of the next body and persists unchanged.

### 2.3 Full-run completion and replay

**Open**

The completed system ends a run. A later design pass will determine exactly what persists between runs. Good candidates are cosmetic records, alternative Core starting geometries, a small number of blueprint modifiers, and challenge modes. Full-run prestige must not erase the visual record of a completed system without preserving it in a gallery or system archive.

---

## 3. Resources and the central decision

**Stable**

All arriving matter begins as **Loose Mass**. The player has three uses for it:

```text
Loose Mass
├── Body construction: build the current layer and reach the next compact
├── Core assimilation: gain persistent Core levels and Core talent points
└── Structures: purchase local or orbital production modifiers
```

- **Body construction** produces the fastest immediate progress.
- **Core assimilation** produces permanent benefits across all bodies in the current run.
- **Structures** are medium-term investments whose value depends on how long the current level remains.

The design should avoid additional currencies unless they create a genuinely different decision. Energy may be displayed and used as an operating limit, but it should mostly modify rates rather than become another inventory the player repeatedly empties.

### Recommended allocation interface

Initially, spending is manual. Automation later unlocks allocation presets such as:

- Finish the current layer first.
- Reserve enough for the next Core level.
- Maintain structure construction, then send the remainder to the body.
- Custom percentage split.

These rules express advanced automation without becoming logistics management.

---

## 4. Particle and layer model

### 4.1 Two-dimensional presentation, three-dimensional quantities

**Stable**

The view is a two-dimensional cross-section, but mass, density and gravity should be described as properties of a three-dimensional sphere.

For total body mass \(M\) and radius \(R\):

\[
V = \frac{4}{3}\pi R^3
\]

\[
\rho = \frac{M}{V}
\]

Surface gravity is:

\[
g = \frac{GM}{R^2}
\]

Escape velocity is:

\[
v_e = \sqrt{\frac{2GM}{R}}
\]

The game does not need to integrate every particle using literal astronomical gravity. These values provide the baseline from which readable gameplay modifiers are derived.

### 4.2 Active particles and compacted layers

**Stable**

Current loose material and the active outer layer remain logically distinct grains, but the engine does not create a CPU physics object for each grain. The active implementation stores exact counts in 720 mass-conserving radial regions, schedules arrivals in bounded batches, and draws representative GPU samples within one shared 500,000-sample budget. A compact operation moves exact logical counts into an aggregate layer record containing:

- total mass;
- inner and outer radius;
- density;
- temperature;
- elemental/material composition;
- colour and visual texture seed;
- structural traits gained from the relevant body tree.

This lets the game represent up to one billion stored grains while drawing at most 500,000 samples. Orbit, collision, settling, and flow are readable aggregate effects. They are not claims that every logical grain has an independent trajectory or collision body. Compacted layers retain exact counts and aggregate properties, not individual rigid bodies.

### 4.3 Layer thresholds

**Tunable**

An initial geometric requirement is recommended:

\[
M_{layer,n} = M_{layer,0}\,q^n
\]

where:

- \(n\) is the number of completed compactions on this body;
- \(q\) begins around **1.55–1.75**;
- body-tree nodes may reduce the effective requirement or increase the mass credited per particle.

Geometric thresholds make visible layers take similar real-world time despite exponential production.

Let the overfill ratio be:

\[
x = \frac{M_{actual}}{M_{required}}, \qquad x \ge 1
\]

A possible reward formula is:

\[
Reward_n = BaseReward_n\left(1 + 0.35\ln x\right)
\]

This rewards idle accumulation without allowing waiting twice as long to dominate timely compaction. The coefficient is a balance value, not a fixed design commitment.

### 4.4 Compaction multiplier

**Tunable**

Each compact adds pressure and production. A simple early prototype formula is:

\[
P_{after} = P_{before}\left(1 + c_b + c_t + c_o\right)
\]

where:

- \(c_b\) is the body's base compaction bonus;
- \(c_t\) is the bonus from body talents;
- \(c_o\) is the overfill bonus.

A starting total multiplier of **1.35–1.65× per compact** should make the result immediately perceptible. Exact values must be tuned alongside the rising layer requirement.

### 4.5 Visual compaction sequence

**Stable**

1. Loose particles stop arriving briefly or hang in slowed time.
2. The active layer glows and fractures into streams.
3. Material moves inward around the Core.
4. Existing bands compress and the new band locks into place.
5. The Core grows or exposes a newly purchased feature.
6. Production numbers jump and particle flow resumes at the new rate.

Compaction is a reward animation, not a menu reset.

---

## 5. The Core: persistent character progression

### 5.1 Core growth

**Stable**

Mass fed directly to the Core fills a Core Growth bar. Each Core level awards one talent point and makes the object visibly more complex. A proposed cost curve is:

\[
C_{core,n} = C_{core,0}\,r^n
\]

with \(r\) initially around **1.7–1.9**. Level or phase gates prevent the player from converting the entire early game into Core investment.

Core size should grow logarithmically rather than in direct proportion to absorbed mass:

\[
R_{core,visual} = R_0\left(1 + a\ln(1 + M_{assimilated}/M_0)\right)
\]

This keeps the Core visible without allowing it to obscure the surrounding body. By the end of the game it may occupy roughly 5–10% of the displayed cutaway radius. Its interior may be spatially impossible; the game does not explain how.

### 5.2 Core production relationship

**Tunable**

The useful incoming mass rate can be expressed as:

\[
\dot M_{useful} = F_{pull}\,M_{pull}\,E_{capture}\,E_{sort}
\]

where:

- \(F_{pull}\) is singularity activations per minute;
- \(M_{pull}\) is emitted mass per activation;
- \(E_{capture}\) is the fraction captured rather than lost;
- \(E_{sort}\) is the effective value after elemental targeting and processing.

This gives different upgrade families multiplicative relationships and creates strong focused combinations.

### 5.3 Opening cadence and ambient capture

**Stable direction; numbers tunable**

Normal progression begins with manual singularity activation. The player may click repeatedly or hold the control to repeat at a capped rate. Both inputs release the same mass per activation. Holding is an accessibility and comfort option, not a separate production upgrade. Batch spawning remains a development tool.

Automatic Invocation is the first relief from repeated manual input. Its initial rate must be slower than an active player clicking or holding. Within a few minutes, the first production talents and compaction reward should make automatic production faster than sustained manual input. From that point, attention moves toward allocation, Core talents, body talents, structures, and compaction timing.

Ambient matter is independent of singularity output. The wider view should contain many uncaptured particles crossing the construction area. Early body mass captures almost none of them. Total accumulated body mass increases the capture chance, so building a planet creates a passive gravitational benefit even before a talent or structure multiplies it.

A first balance model uses:

\[
\dot M_{ambient} = F_{flyby}\,M_{flyby}\,P_{capture}(M_{body})\,E_{gravity}\,E_{net}
\]

where \(F_{flyby}\) is the visible flyby rate, \(M_{flyby}\) is average useful mass, and the two efficiencies come from Core talents and structures. A bounded logarithmic starting curve is:

\[
P_{capture}(M_{body}) = min\left(P_{max}, P_0 + k\log_{10}\left(1 + \frac{M_{body}}{M_{scale}}\right)\right)
\]

`M_body` counts accumulated matter in the current planet or star, including compacted layers. Mass spent on the player Core does not increase body gravity. Body completion may preserve part of the benefit as a legacy multiplier for later construction sites.

### 5.4 Core talent branches

**Stable direction; individual nodes tunable**

#### Singularity Control

Early nodes:

- **Resonant Pull:** More mass per activation.
- **Rapid Recovery:** More activations per minute.
- **Stable Aperture:** Less variation between pulls.
- **Echo Pull:** Chance for an automatic second emission.

Advanced nodes:

- **Automatic Invocation:** Pull without player input.
- **Compound Aperture:** Several emissions per activation.
- **Elemental Tuning:** Bias the source toward an unlocked element or material class.
- **Continuous Breach:** Replace pulses with a steady stream.
- **Distributed Singularities:** Multiple visible source points feed the body.

#### Gravitational Manipulation

Early nodes:

- **Gravity Focus:** Faster particle arrival.
- **Capture Radius:** Increase the mass-based ambient capture chance and acquire matter from farther away.
- **Collision Damping:** Reduce bounced or escaped particles.
- **Mass Anchor:** Retain more matter during compaction.

Advanced nodes:

- **Directed Gravity:** Prefer incomplete parts of the active layer.
- **Orbital Capture:** Convert near misses into temporary orbiting matter.
- **Gravity Well:** Attract asteroids and larger objects.
- **Compression Field:** Reduce effective compaction requirements.
- **System Influence:** Completed bodies assist with capture.

#### Assimilation and Internal Growth

Early nodes:

- **Efficient Assimilation:** Reduce Core level costs.
- **Material Analysis:** Reveal composition and likely unlocks.
- **Internal Storage:** Preserve loose mass across compaction.
- **Selective Digestion:** Gain an additional effect from selected elements.

Advanced nodes:

- **Adaptive Architecture:** Core modules respond to the current body type.
- **Self-Repair:** Resist heat and impact penalties.
- **Internal Foundry:** Produce simple construction components.
- **Matter Recycling:** Recover some replaced structure cost.
- **Impossible Interior:** Greatly increase capacity without proportionate visual size.

#### Rotation and Angular Momentum

Early nodes:

- **First Motion:** Begin visible Core rotation.
- **Torque Pulse:** Singularity activation adds spin.
- **Angular Storage:** Retain rotation through compaction.
- **Particle Sweep:** Rotation improves local collection.

Advanced nodes:

- **Spin Transfer:** Rotate the surrounding star or planet.
- **Equatorial Accretion:** Improve collection around the equator.
- **Spin Governor:** Automatically maintain a selected rotation range.
- **Differential Rotation:** Increase stellar magnetic activity and energy.
- **Axial Control:** Influence planetary tilt and seasonal strength.
- **Momentum Exchange:** Use moons, asteroids or structures to modify spin.

#### Energy and Thermal Control

Early nodes:

- **Heat Absorption:** Convert surrounding heat into production.
- **Thermal Shielding:** Survive stellar ignition.
- **Energy Reservoir:** Store energy between active actions.
- **Compression Heating:** Gain extra energy from compaction.

Advanced nodes:

- **Fusion Tap:** Extract power directly from the star.
- **Radiative Collector:** Use completed-star light during planet levels.
- **Heat Routing:** Warm cold planetary regions.
- **Cooling Vanes:** Remove excess heat.
- **Climate Cycling:** Regulate planetary temperature cycles.
- **Deep-Core Reactor:** Supply power independently of local conditions.

#### Construction and Automation

Early nodes:

- **Particle Net:** Multiply ambient capture without replacing the benefit from body mass.
- **Mass Sorter:** Favour a selected material.
- **Surface Conveyor:** Move deposits toward thin regions.
- **Compression Scaffold:** Improve the next compact.

Advanced nodes:

- **Asteroid Tug:** Redirect passing asteroids.
- **Orbital Collector:** Capture dust and stellar ejecta.
- **Solar Array:** Turn starlight into production bonuses.
- **Construction Drones:** Automatically construct simple structures.
- **Orbital Foundry:** Use iron and silicon for advanced construction.
- **Autonomous Swarm:** Automate routine capture and building.

### 5.5 Rotation model

**Stable concept; tunable implementation**

For angular speed \(\omega\), the displayed day length is:

\[
DayLength = \frac{2\pi}{\omega}
\]

Rotation should initially be nearly invisible and become recognisably planetary only late in the campaign. Moderate rotation improves temperature distribution, atmospheric circulation and some collection methods. Rotation also contributes to a magnetic dynamo when combined with a convecting conductive core, although rotation alone does not create a magnetic field.

Excessive rotation can introduce trade-offs:

- equatorial bulging;
- particles having more difficulty settling at the equator;
- stronger stellar activity or planetary storms;
- eventual shedding of material.

The final Earth-like level can use day length, atmosphere and oceans together to damp hot/cold cycles. The mechanic should use a preferred range, not demand one exact scientifically correct value.

---

## 6. Structures

**Stable direction**

Structures consume Loose Mass and occupy a small number of slots. Begin with approximately three slots and expand toward six. A structure provides a direct modifier and a visible object; it does not create a manual supply chain.

Candidate structures:

| Structure | Primary effect |
|---|---|
| Particle Net | Improves passive collection |
| Compression Frame | Strengthens the next compact |
| Mass Sorter | Favours a selected element/material |
| Surface Conveyor | Redistributes uneven deposits |
| Solar Collector | Converts completed-star light into production |
| Asteroid Beacon | Increases useful asteroid encounters |
| Impact Guide | Reduces destructive collision losses |
| Torque Ring | Adds or removes spin |
| Heat Radiator | Removes excess heat |
| Atmospheric Collector | Captures and retains gases |
| Orbital Foundry | Automates advanced construction |

Structures persist through compactions on the current body. At celestial completion, most are abstracted into the body's legacy bonus rather than remaining individually simulated.

---

## 7. Sun level

The current numerical pass lives in [First Sun balance](SUN_BALANCE.md). It owns the provisional logical layer masses, Core costs, talent ranks, heat overclock, build comparisons, and real-time results.

### 7.1 Scientific reference values

**Stable reference; gameplay is scaled**

- Solar mass: \(M_\odot = 1.989\times10^{30}\) kg.
- Solar radius: \(R_\odot = 6.957\times10^8\) m.
- Approximate sustained hydrogen-burning threshold: \(0.075–0.080\,M_\odot\).
- Minimum-star ignition radius: approximately \(0.1\,R_\odot\), comparable to Jupiter's radius.
- Approximate hydrogen-ignition core temperature: a few million kelvin.
- Present solar core temperature: approximately \(1.5\times10^7\) K.
- Primordial star-forming material was mostly hydrogen with roughly one quarter helium by mass; the game intentionally begins with hydrogen alone.

For readable units, define:

\[
1\ Stellar\ Mass\ Unit\ (SMU) = 0.001\,M_\odot
\]

Then:

- first sustained ignition occurs around **75–80 SMU**;
- Sun completion occurs at **1,000 SMU**.

The exact displayed unit name is open. The scientific readout may show both SMU and solar masses.

### 7.2 Radius curve

**Tunable**

For the stable low-mass star through Sun-like range, a suitable visual baseline is:

\[
\frac{R}{R_\odot} = \left(\frac{M}{M_\odot}\right)^{0.8}
\]

This produces approximately:

| Mass | Approximate radius |
|---:|---:|
| \(0.08M_\odot\) | \(0.13R_\odot\) |
| \(0.25M_\odot\) | \(0.33R_\odot\) |
| \(0.50M_\odot\) | \(0.57R_\odot\) |
| \(1.00M_\odot\) | \(1.00R_\odot\) |

Pre-ignition radius is presentation-led: the active cloud may be larger and diffuse, then contract dramatically before ignition. The camera should use smoothed logarithmic zoom rather than track radius linearly.

### 7.3 Luminosity and power curve

**Tunable scientific baseline**

For main-sequence stars below one solar mass, use a piecewise approximation:

\[
\frac{L}{L_\odot} = 0.23\left(\frac{M}{M_\odot}\right)^{2.3}, \qquad M < 0.43M_\odot
\]

\[
\frac{L}{L_\odot} = \left(\frac{M}{M_\odot}\right)^4, \qquad 0.43M_\odot \le M \le 1M_\odot
\]

Raw luminosity should not directly determine progression because the early values are extremely small. Convert it into a game power value with a floor and talent multipliers:

\[
Power_{game} = P_0 + k\left(\frac{L}{L_\odot}\right)^\gamma
\]

where \(0 < \gamma < 1\) compresses the range for readability. Compaction bonuses and Core talents then multiply this baseline.

### 7.4 Simplified core temperature

**Tunable**

An order-of-magnitude relationship from gravitational compression is:

\[
T_{core} \approx \frac{\mu m_p}{3k_B}\frac{GM}{R}
\]

where \(\mu\) represents average particle mass in units of proton mass. The simulation may use this for direction while applying smoothing and phase limits.

For a predictable campaign curve after ignition, interpolate between approximately 4 million K and 15 million K:

\[
u = clamp\left(\frac{M/M_\odot - 0.08}{0.92},0,1\right)
\]

\[
T_{core,game} = 4\times10^6 + 11\times10^6\,smoothstep(u)
\]

Talents modify the temperature around this baseline. A hotter build gains power and advanced-material opportunities but increases ejection and retention losses. A cooler build retains material and supports later volatiles but develops more slowly.

### 7.5 Hydrogen-to-helium progression

**Stable concept**

Once ignition begins:

\[
4\,{}^1H \rightarrow {}^4He + energy
\]

In reality only a small fraction of stellar hydrogen is fused over immense timescales. In the game, visible helium production is accelerated. The star's fusion output supplies a helium discovery rate:

\[
\dot M_{He,discovery} = k_{He}\,Power_{fusion}\,E_{fusionTalent}
\]

Reaching the discovery requirement teaches the singularity the helium pattern. It then generates hydrogen and helium automatically at a fixed 75/25 mass split, equivalent to about twelve hydrogen grains per helium grain. This uses the approximate primordial mix for star-forming matter. Ambient captures remain hydrogen during the first Sun.

The star also retains a small passive helium reserve. Its rate scales with Sun mass, temperature, the chosen cool, balanced or hot profile, and Fusion Feedback. That reserve is used for discovery and later system seeding. It is not added to the compactable construction mass. This is an explicit fictional rule: the source can manifest only matter patterns previously synthesised or analysed by the Core. Exact rates and simulated timings live in [First Sun balance](SUN_BALANCE.md).

The Sun-like star produces helium but does not normally fuse helium during this level. Carbon and heavier fusion belong to later stellar conditions or to the game's fictional high-heat specialisations.

### 7.6 Sun phase progression

**Stable structure; timings tunable**

#### Phase 1: The First Matter

- Manual singularity activation.
- Hydrogen only.
- Core and particles fill most of the view, concealing the true scale.
- First Core choices improve pull mass, pull frequency, capture or assimilation.
- First layer compaction reveals the persistent band system.

#### Phase 2: Gravitational Seed

- Compacted layers increase attraction.
- Particles begin orbiting and colliding before settling.
- The camera reveals a diffuse spherical cloud.
- Rotation begins almost imperceptibly.
- Automatic pulling becomes attainable but is not yet complete.

#### Phase 3: Protostar

- Contraction becomes the main visual theme.
- Compaction produces strong heat and light.
- Thermal shielding and compression structures become relevant.
- Helium is not yet available from the singularity.
- Reaching approximately 75–80 SMU prepares the ignition event.

#### Phase 4: First Ignition

- Sustained hydrogen fusion begins.
- The body changes from a contracting cloud to a luminous red dwarf-like star.
- Helium synthesis and fusion power appear.
- Previous manual mass creation is increasingly automated.
- The player chooses an early hot, cool or balanced stellar tendency.

#### Phase 5: Main-sequence Growth

- The star grows from minimum stellar mass toward one solar mass.
- Radius, luminosity and fusion power rise nonlinearly.
- Layers become plasma bands with composition and temperature differences.
- Helium unlocks as an incoming material after its discovery milestone.
- Stellar rotation, magnetic activity and controlled ejection enter the talent tree.
- Builds become visually distinct.

#### Phase 6: Solar Stabilisation

- The target approaches \(1M_\odot\) and \(1R_\odot\).
- Final branch nodes stabilise fusion, gravity, rotation and material sorting.
- The star meets its completion requirements, but the level does not transition immediately.
- All Sun talent branches visibly converge on one final capstone.

#### Phase 7: System Seeding

- Duration target: approximately **3–6 minutes** on a first run.
- The convergent capstone unlocks a dramatic controlled ejection sequence.
- Repeated prominences and large mass ejections throw matter into orbit.
- Existing loose material, stored enriched matter and the remaining accretion envelope spread into rings, belts and dust.
- The player briefly directs or accelerates ejections while planet-building collection systems activate.
- The camera pulls back far enough to reveal the new protoplanetary construction space.
- Planet Level 1 begins with the completed star visible in the background.

Large ejections alone would not realistically supply an entire rocky planetary system. The semi-real explanation is that the capstone releases the **remaining accretion envelope and stored matter**, while stellar ejections distribute and energise it. The sequence may be spectacular without calling the event a supernova.

### 7.7 Sun body tree

**Stable direction**

The Sun tree has four routes. The player may buy from all four, but focused depth creates stronger combinations.

#### Accretion route

- Particle capture
- Orbital interception
- Collision retention
- Larger useful mass per pull
- Accretion-disk control

#### Compression route

- Denser layers
- Lower effective compact thresholds
- Stronger compact multipliers
- More heat from contraction
- Reduced mass loss during layer collapse

#### Fusion and thermal route

- Earlier or stronger ignition
- Faster helium discovery
- Higher stellar power
- Heat resistance
- Hot-star and cool-star specialisations

#### Rotation and ejection route

- Angular momentum retention
- Magnetic activity
- Controlled prominences
- Useful stellar ejecta
- Greater final system-seeding yield

The final nodes of all four routes connect to:

### **System Seeding Protocol**

Requirements:

- complete solar mass milestone;
- stable fusion;
- stable gravity and compression;
- controlled rotation;
- controlled composition/ejection capability.

Effect: begins the final System Seeding phase and constructs the belts, dust fields and captured matter used by Planet Level 1.

### 7.8 Stellar build consequences

| Build | Strength | Cost | Later appearance/effect |
|---|---|---|---|
| Hot | High energy, rapid fusion, better advanced-material potential | More mass loss and worse volatile retention | Blue-white, active surface, harsher planetary heating |
| Cool | Strong retention and idle accumulation | Slower fusion and element discovery | Red-orange, calmer surface, easier volatile survival |
| Balanced | Flexible and stable | No extreme multiplier | Yellow-white, moderate planetary conditions |

This is intentionally more flexible than strict stellar classification. The completed star's actual colour and activity must remain visible during every planet level.

---

## 8. Planet construction framework

[Future world research](FUTURE_WORLDS.md) records candidate planet types and sources. It is a backlog, not a replacement for the stable shared loop below.

### 8.1 Shared planetary loop

**Stable**

Every planet uses the same foundational verbs:

1. Pull or capture particles, dust and larger bodies.
2. Show representative collision, orbit and settling while conserving aggregate mass.
3. Spend Loose Mass between body growth, Core growth and structures.
4. Compact the active layer into the planet.
5. Spend the awarded body point on a planetary route.
6. Repeat until the required mass and the planet's unique late challenge are complete.

Each new planet changes the desired composition and final stability problem, not the entire control scheme.

### 8.2 Shared planet routes

#### Dense/metallic

- Iron and nickel retention
- Stronger compression
- Denser core
- Better magnetic dynamo potential
- Smaller, heavier-looking body

#### Thermal/geological

- More internal heat
- Faster differentiation
- Stronger volcanism or convection
- Better molten-material processing
- Greater risk of losing gases and water

#### Mineral/crustal

- More silicates
- Better crust formation
- More construction feedstock
- Silicon and sodium enrichment
- Improved industrial structures

Planets do not normally manufacture sodium through fusion. **Sodium Enrichment** means that the Core tunes the singularity toward sodium-bearing matter and concentrates it into accessible crustal deposits.

#### Volatile/atmospheric

- Better capture of water, ice and gases
- Thicker atmosphere
- Reduced impact loss
- Improved ocean potential
- Greater vulnerability to excessive stellar heat

These routes change visible layer colours, core size, surface state, atmosphere and the final body's legacy effect.

### 8.3 Refined planet sequence

The exact number of planets remains tunable. The following five-level sequence supports a 10–13 hour first run without requiring a separate management game for every body.

#### Planet 1: Rocky Seed

Purpose: teach solid accretion and introduce asteroids.

Primary materials:

- dust;
- silicates;
- iron and nickel;
- small quantities of volatiles.

New features:

- belts and dust created by System Seeding;
- passing asteroids;
- impact capture;
- separation of a dense core from a rocky mantle;
- first transport and sorting structures.

Late challenge: **Differentiation**. Accumulate enough internal heat for metals to sink and silicates to form the mantle without losing too much mass to impacts.

Completion legacy: unlock iron/silicon construction, basic automated machinery and improved solid-material capture.

#### Planet 2: Gas Giant

Purpose: use the star's automated hydrogen/helium economy at a much larger scale.

Primary materials:

- hydrogen;
- helium;
- an initial rocky or icy core;
- captured moons and ring material.

New features:

- atmospheric layers rather than a solid surface;
- pressure, storms and rapid rotation;
- gravitational capture of moons and asteroids;
- large-scale gas collectors.

Late challenge: **Atmospheric Retention**. Reach the target mass and controlled spin without excessive heating, turbulence or equatorial shedding.

Completion legacy: passive gas harvesting, improved gravitational capture and assistance redirecting objects elsewhere in the system.

Gas giants do not create heavy elements by fusion. Their gameplay value is gas collection, high-pressure states, powerful gravity and orbital control.

#### Planet 3: Ice World or Ocean Moon

Purpose: introduce volatiles and temperature-dependent material states.

Primary materials:

- water ice;
- ammonia and methane abstractions;
- silicates;
- a modest metallic core.

New features:

- the system's snow-line concept;
- ice layers;
- tidal or internal heating;
- subsurface liquid water;
- volatile-preservation structures.

Late challenge: **Buried Ocean**. Balance crust thickness and internal heating so that a stable liquid layer forms beneath the ice.

Completion legacy: improved water/volatile collection and thermal storage.

#### Planet 4: Volcanic Terrestrial World

Purpose: combine dense core, mineral mantle, atmosphere and controlled heat.

Primary materials:

- iron/nickel core material;
- silicate mantle;
- atmospheric gases;
- later water delivery.

New features:

- volcanic outgassing;
- crust cooling;
- magnetic dynamo;
- atmospheric loss;
- optional moon-forming impacts.

Late challenge: **Living Interior, Stable Surface**. Preserve enough internal motion for a magnetic field and geology while cooling the surface sufficiently to retain an atmosphere.

Completion legacy: geothermal power, atmospheric processing and advanced planetary engineering.

#### Planet 5: Earth-like World

Purpose: final synthesis of all prior systems.

Required conditions are ranges rather than exact values:

- suitable orbit relative to the player's completed star;
- sufficient mass for atmospheric retention;
- moderate greenhouse effect;
- stable rotation and day/night cycle;
- magnetic protection;
- liquid-water surface range;
- carbon compounds and useful mineral chemistry;
- controlled bombardment.

New features:

- surface oceans;
- weather and climate cycling;
- water and organic delivery from asteroids/comets;
- early biosphere or abiogenesis milestone.

Late challenge: **Stable Liquid Water**, followed by the final **Conditions for Life** milestone. Asteroids may deliver water and organic ingredients; the game should not assert that complex life itself simply arrives on them.

Completion legacy: finishes the first full system and unlocks run completion/replay.

### 8.4 Planetary temperature baseline

**Optional scientific layer**

For star luminosity \(L\), orbital distance \(d\), albedo \(A\) and the Stefan–Boltzmann constant \(\sigma\), an approximate equilibrium temperature is:

\[
T_{eq} = \left(\frac{L(1-A)}{16\pi\sigma d^2}\right)^{1/4}
\]

The displayed surface temperature then adds atmosphere, internal heat, oceans and day/night variation. This need not become a detailed climate simulator. It supplies understandable directions:

- more stellar luminosity raises temperature;
- greater distance lowers it;
- reflective clouds or ice increase albedo and lower it;
- greenhouse atmosphere raises surface temperature;
- oceans, atmosphere and faster rotation reduce day/night extremes.

---

## 9. Element and material progression

**Stable direction**

The player should not manually balance a complete periodic table. Individual discoveries feed a small number of understandable material classes.

| Class | Examples | Primary use |
|---|---|---|
| Light gas | Hydrogen, helium | Stars and gas giants |
| Metal | Iron, nickel | Dense cores, magnetism, machinery |
| Silicate/mineral | Silicon, oxygen compounds, sodium-bearing minerals | Mantles, crusts, construction |
| Volatile | Water, methane, ammonia, atmospheric gases | Ice, atmosphere, oceans |
| Carbon chemistry | Carbon compounds and organics | Advanced chemistry and life conditions |

Each discovered element receives an abundance weight. Active weights are normalised to determine incoming composition. A starting example is:

| Material | Relative weight |
|---|---:|
| Hydrogen | 1.000 |
| Helium | 0.300 |
| Carbon-bearing matter | 0.030 |
| Oxygen/silicate-bearing matter | 0.020 |
| Later specialist material | 0.001–0.010 |

The exact values are balance data. The principle is that later discoveries form progressively smaller fractions of incoming mass, while Core tuning, planet routes and structures can enrich the desired fraction.

---

## 10. Build expression and replay combinations

**Stable direction**

Everything should be completable with a reasonable mixed build. Focused combinations should be significantly faster or produce unusual bodies.

Examples:

- **Rapid Accretor:** Pull frequency + automatic invocation + particle nets + compact speed.
- **Dense Dynamo:** Gravity focus + angular momentum + metallic route + molten core.
- **Hot Forge:** Thermal control + fusion talents + mineral enrichment + solar collection.
- **Cold Collector:** Wide capture + volatile retention + calm star + stable slow-to-moderate spin.
- **Orbital Engineer:** Assimilation + construction drones + solar energy + asteroid capture.
- **Extreme Spinner:** Torque + equatorial accretion + circulation bonuses, balanced against shedding and storms.

Visual consequences must persist:

- star colour and activity;
- planet size and density;
- thickness and colour of compacted layers;
- core-to-mantle ratio;
- atmosphere, ice or ocean coverage;
- rotation speed and axial presentation;
- structures, rings and moons;
- completed bodies visible in later skies.

---

## 11. Pacing target

**Tunable**

Normal play starts with manual singularity output through clicking or holding. Automatic Invocation should unlock early at less throughput than sustained manual input, then overtake it within a few minutes after upgrades. Suggested first-run distribution:

| Section | Target time |
|---|---:|
| First particles and first compact | 10–15 minutes |
| First ignition | 60–90 minutes |
| Completed Sun and System Seeding | 2–3 hours total |
| Early planet levels | 60–90 minutes each |
| Complex terrestrial level | 90–120 minutes |
| Earth-like final level | Around 2 hours |
| Complete first run | 10–13 hours |

An effective specialist route should reduce total time to approximately 6–8 hours. Later balance tests may support still faster challenge runs.

During layer growth, the player should normally have at least one meaningful action available:

- activate or retune the singularity;
- allocate Loose Mass;
- choose a Core or body talent;
- construct or replace a structure;
- influence spin or heat;
- react to an asteroid or rare particle event;
- inspect the growing cross-section.

The game must remain safe to leave idle. Missing an event should lose an optimisation opportunity, not cause irreversible failure.

---

## 12. Current boundaries

The following are deliberately outside the present design unless later testing proves they are needed:

- manual trade routes;
- worker assignment;
- detailed factory conveyor networks;
- individually simulated particles inside compacted layers;
- exact orbital-mechanics navigation;
- full atmospheric chemistry;
- mandatory balancing of every element;
- realistic astronomical timescales;
- punishment for leaving the game idle.

Transport networks, mining fleets and orbital industry may appear visually and provide bonuses, but their routine operation is automatic.

---

## 13. Open design questions

1. Final name and nature of the Core/player character.
2. Exact number and ordering of planet levels.
3. Whether the ice world is a full planet or a moon of the gas giant.
4. What persists between completed-system runs.
5. Whether orbital distance is selected by the player or authored per level.
6. How many structure slots produce meaningful choices without busywork.
7. Whether active particle steering is direct, ability-based or entirely gravitational.
8. Exact relationship between hot-star specialisation and access to heavier materials.
9. Whether life is the final completion state or the opening of a later biological era.

---

## 14. Immediate prototype priorities

The radial field renderer, exact mass accounting, manual outer compaction, pressure packing, and nested body layers now exist. The next work is:

1. Keep the 720-region field model and shared 500,000-sample drawing budget as the engine base.
2. Build and calibrate the deterministic [progression model](PROGRESSION_MODEL.md) before setting purchase costs in Godot.
3. Implement the manual opening and the first Core levels while preserving click and hold input.
4. Add Automatic Invocation and the first four working talents: Resonant Pull, Rapid Recovery, Gravity Focus, and Efficient Assimilation. Automatic Invocation must begin below manual throughput.
5. Add the three-way Loose Mass allocation between body construction, Core assimilation, and structures.
6. Add mass-based ambient flybys and capture. Most early flybys remain uncaptured.
7. Replace fixed prototype layer costs with tuned geometric requirements, overfill rewards, body points, and production gains.
8. Connect progression state to the existing manual outer compaction and gated inner automation without allowing automation to compact loose outer matter.
9. Prototype zoom transitions from intimate particle scale to recognisable protostar scale.

Fusion, later elements, and planet-specific challenges remain later work. The first playable should prove the opening handoff from clicking to automation, the Core versus body allocation choice, visible accumulation, and satisfying compaction.
