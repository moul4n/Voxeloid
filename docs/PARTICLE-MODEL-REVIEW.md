# Particle model review

Source: `D:\Users\Jason\Downloads\particle-testing.zip`, extracted separately to `scratch/particle-testing/voxbench`.

The runnable Godot scripts, shaders, and project settings match the original `scratch/voxbench` archive. The additions are particle-design and prior-art documents plus `tools/particle_scaling.js`; two README files also changed. This is design research and a JavaScript experiment, not a finished large-particle Godot implementation.

## Useful approach

Replace pair contacts with a small circular surface field. Airborne matter deposits into that field, and neighbouring regions exchange material according to slope and flow settings. Its cost follows the field resolution rather than the number of settled grains. Shaders can position visible grains without copying every position from GDScript each frame.

The supplied JavaScript script measured about 4.3 ms at 100,000 particles and 43.6 ms at one million on this machine. These are simulation-only JavaScript timings. They do not measure Godot, drawing, or the GPU. The cost is linear, not constant. The supplied prototype also loses mass in capped ejecta and height clipping; those behaviours must not be copied.

## Chosen implementation

Use 720 CPU surface regions holding conserved grain counts, with material-dependent flow. Schedule arrivals in batches and draw separate GPU instances for airborne and deposited grains. Rendering many individual discs does not require a separate CPU collision body for each disc. The active target is up to 500,000 instances, subject to measured performance.

This supersedes the earlier requirement to resolve every grain contact. The model describes an aggregate radial shell, not caves, overhangs, or independently colliding circles. Visible settled grains sample the field continuously; their positions and overlap are an approximation. Arrival times are scheduled, so flight is a visual trajectory rather than a tracked ballistic collision. Large instantaneous deposits may make the surface jump. Mixed elements and excavation remain future work.

Keep mass conservation, per-element tuning, the central player, camera controls, and developer gestures. Record rendered benchmarks separately from CPU timings, including the visible count, zoom, warmup, and measurement duration.

## Technical reference

The shader implementation uses Godot's [CanvasItem instance ID support](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/canvas_item_shader.html). It does not require compute shaders or switching away from Compatibility rendering.