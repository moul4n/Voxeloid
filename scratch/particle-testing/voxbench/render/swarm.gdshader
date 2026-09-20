shader_type canvas_item;
render_mode blend_mix;

// Per-instance data (MultiMesh custom data, INSTANCE_CUSTOM):
//   r = t0      spawn time in seconds (same clock as `now`, set by swarm.gd every frame)
//   g = vx      initial velocity x, px/s
//   b = vy      initial velocity y, px/s
//   a = packed  frame (0..63) + life_tenths*64 + seed*16384   (see Swarm.pack())
// COLOR = instance color (tint from the strongest buff), alpha unused.
// The instance transform holds the SPAWN ORIGIN; the shader adds the ballistic offset.

uniform float now = 0.0;
uniform float gravity = 900.0;
uniform float floor_y = 520.0;       // in this node's local space; swarm.gd sets it
uniform float bounce = 0.35;
uniform float quad_size = 8.0;
uniform float atlas_grid = 8.0;
uniform int   layer_mask = 0;        // 1 tint · 2 glow · 4 pulse · 8 wobble · 16 stretch-trail · 32 emit (particles, not here)
uniform vec4  glow_col : source_color = vec4(1.0, 0.63, 0.29, 1.0);
uniform bool  gpu_path = true;       // false: CPU wrote the live position into the transform

varying float v_age01;
varying vec2  v_frame_uv;
varying float v_seed;

void vertex() {
	vec4 d = INSTANCE_CUSTOM;
	float packed = d.a;
	float frame  = mod(packed, 64.0);
	float life   = floor(mod(packed / 64.0, 256.0)) * 0.1;
	float seed   = floor(packed / 16384.0) / 255.0;
	v_seed = seed;

	float t = max(now - d.r, 0.0);
	float age01 = clamp(t / max(life, 0.05), 0.0, 1.0);
	v_age01 = age01;
	v_frame_uv = vec2(mod(frame, atlas_grid), floor(frame / atlas_grid));

	// VERTEX already includes the instance transform. Split it into centre + local corner.
	vec2 local  = (UV - 0.5) * quad_size;
	vec2 center = VERTEX - local;

	vec2 p = vec2(0.0);
	vec2 vel = vec2(0.0);
	if (gpu_path) {
		p = vec2(d.g * t, d.b * t + 0.5 * gravity * t * t);
		vel = vec2(d.g, d.b + gravity * t);
		float over = (center.y + p.y) - floor_y;
		if (over > 0.0) { p.y -= over * (1.0 + bounce); vel.y = -vel.y * bounce; }
	}

	float s = 1.0;
	if ((layer_mask & 4) != 0) { s += 0.18 * sin(now * 9.0 + seed * 6.283); }
	if ((layer_mask & 8) != 0) { local.x += 1.2 * sin(now * 14.0 + seed * 6.283 + local.y * 0.4); }
	if ((layer_mask & 16) != 0) {
		float sp = length(vel);
		if (sp > 1.0) {
			vec2 dir = vel / sp;
			float k = clamp(sp / 600.0, 0.0, 1.5);
			local += dir * dot(local, dir) * k;
		}
	}
	VERTEX = center + p + local * s;
	if (age01 >= 1.0) { VERTEX = vec2(1.0e6); }   // dead: off-screen until the slot is reused
}

void fragment() {
	vec2 uv = (v_frame_uv + UV) / atlas_grid;
	vec4 c = texture(TEXTURE, uv);
	if ((layer_mask & 1) != 0) { c.rgb *= COLOR.rgb; }
	if ((layer_mask & 2) != 0) { c.rgb += glow_col.rgb * 0.45 * step(0.5, c.a) * (0.6 + 0.4 * sin(now * 6.0 + v_seed * 6.283)); }
	c.a *= 1.0 - smoothstep(0.7, 1.0, v_age01);
	COLOR = c;
}
