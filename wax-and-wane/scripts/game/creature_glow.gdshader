shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
// The parts of a creature that ignore the room light (creature_glow.gd draws them over the sprite):
//  - glow: texels of the exact palette colours in glow_cols (eyes, eye-lights, a lantern, embers) give off
//    their own light: `glow` x their colour is added over the lit sprite (premultiplied alpha 0 = add),
//    so they shine in the dark and are never dimmer than the lit body in full light;
//  - rim: a 1 px rim just outside the sprite's dark outline, on the side that faces light_dir
//    (Tallow's candle), so a guardian or a marked foe never melts into a dark floor (opaque).
// The quad is the frame grown by 1 px on every side (room for the rim); texels are read whole with
// texelFetch, so every pixel is an exact palette colour (no filtering, no blending).

uniform vec4 glow_cols[4];
uniform int glow_n = 0;
uniform float glow = 1.0;
uniform vec4 rim_col : source_color = vec4(0.0);
uniform vec2 light_dir = vec2(-0.6, -0.8);   // screen space, unit vector toward the light
uniform float rim_min = 0.2;                 // how far round the silhouette the rim reaches (cos)
uniform bool flip = false;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;   // modulate (the spawn fade-in)
}

float alpha_at(sampler2D tex, ivec2 q, ivec2 sz) {
	if (q.x < 0 || q.y < 0 || q.x >= sz.x || q.y >= sz.y) {
		return 0.0;
	}
	return texelFetch(tex, q, 0).a;
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	ivec2 q = ivec2(floor(UV * vec2(sz + ivec2(2)))) - ivec2(1);
	if (flip) {
		q.x = sz.x - 1 - q.x;
	}
	vec4 o = vec4(0.0);
	if (alpha_at(TEXTURE, q, sz) > 0.5) {
		vec3 c = texelFetch(TEXTURE, q, 0).rgb;
		for (int i = 0; i < 4; i++) {
			if (i < glow_n && distance(c, glow_cols[i].rgb) < 0.01) {
				o = vec4(c * glow, 0.0);   // added light
			}
		}
	} else if (rim_col.a > 0.0) {
		vec2 n = vec2(0.0);
		n += vec2(1.0, 0.0) * alpha_at(TEXTURE, q + ivec2(1, 0), sz);
		n += vec2(-1.0, 0.0) * alpha_at(TEXTURE, q + ivec2(-1, 0), sz);
		n += vec2(0.0, 1.0) * alpha_at(TEXTURE, q + ivec2(0, 1), sz);
		n += vec2(0.0, -1.0) * alpha_at(TEXTURE, q + ivec2(0, -1), sz);
		if (dot(n, n) > 0.0) {
			vec2 outward = -normalize(n);
			if (flip) {
				outward.x = -outward.x;
			}
			if (dot(outward, light_dir) > rim_min) {
				o = rim_col;
			}
		}
	}
	COLOR = vec4(o.rgb * vcol.a, o.a * vcol.a);   // premultiplied; vcol.a = the spawn fade-in
}
