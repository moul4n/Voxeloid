# Solar cutaway visual review

The game should borrow the Sun's large-scale structure without claiming to simulate solar magnetohydrodynamics.

NASA divides the solar interior into a fusion core, a radiative zone and an outer convection zone. Energy moves through the radiative zone mainly by radiation. The convection zone occupies the outer part of the interior, where hot plasma rises, cools and sinks. Those motions become visible at the photosphere as granules and supergranules. The Sun has no solid surface. Sources: [NASA solar interior](https://solarscience.msfc.nasa.gov/interior.shtml), [NASA Sun facts](https://science.nasa.gov/sun/facts/), [NASA Heliopedia](https://science.nasa.gov/reference/the-heliopedia/) and [ESA anatomy of the Sun](https://www.esa.int/ESA_Multimedia/Images/2020/01/Anatomy_of_the_Sun).

That suggests this art mapping:

| Game region | Visual treatment | Scientific reference |
| --- | --- | --- |
| First formed stellar layer | Bright rising plumes and darker returns | Fusion-powered hot central region, presented as readable motion rather than literal observed structure |
| Inner stellar zone | Calm broad ribbons and slow diffusion | Radiative transport should read smoother and less turbulent |
| Outer stellar zone | Large morphing flow contours with rising centres and sinking lanes | Deep convection zone |
| Shallow stellar zone | Finer changing cells and sparse bright lanes | Photospheric granulation |
| Future exterior | Spicules, prominences and bounded ejections | Chromosphere, corona and magnetic activity |

The exterior prominence pass begins at ignition. Long-lived ribbons keep both footpoints on the photosphere while light packets travel in opposite directions along them. Each loop grows from the surface to a seeded height, holds, then fades before its slot chooses another position. Staggered eruption cycles do the same for the long radial plumes, which varies the visible count over time. Two crossfading flow waves bend each thread without rotating the whole structure. NASA observations support that split: stable prominences can persist as plasma follows magnetic loops, while unstable structures rise, erupt or drain back to the surface. This pass does not transfer body mass.

The old Voronoi pattern made the outer zones resemble cracked ground because its dark borders stayed legible while the sites moved only slightly. Stage 4 replaces that background with two-phase procedural flow fields. Their contours morph without sliding around the whole star. The shallow layer keeps a finer network, but its lines brighten and change instead of reading as dry cracks.

This remains an artistic radial cutaway. Real solar layers do not have crisp visible borders, and the actual radiative interior cannot be directly photographed. The renderer therefore uses soft transitions, restrained colour differences and motion appropriate to each energy-transport region.
