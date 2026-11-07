shader_type canvas_item;
// Paper-burn dissolve for screen changes (main.gd) and the trapdoor fade (world.gd).
// Coverage comes from the rect's colour alpha (COLOR.a: 0 = clear, 1 = fully dark), so an ordinary
// `color:a` tween drives it. Cover: the picture burns away into darkness behind a glowing ember
// edge. Reveal: holes burn through the dark cover. The noise lives on a 2 px grid of the 384x216
// game screen, so the edge reads as chunky pixel art, never as a smooth gradient.

uniform bool reveal = false;
uniform float seed = 0.0;
uniform vec2 px_size = vec2(480.0, 216.0);
uniform float cell = 2.0;
uniform vec2 origin = vec2(0.0, 1.0);
uniform vec4 c_hot : source_color = vec4(0.992, 0.969, 0.929, 1.0);   // #fdf7ed
uniform vec4 c_yel : source_color = vec4(0.980, 0.796, 0.243, 1.0);   // #facb3e
uniform vec4 c_org : source_color = vec4(0.933, 0.557, 0.180, 1.0);   // #ee8e2e
uniform vec4 c_red : source_color = vec4(0.561, 0.251, 0.161, 1.0);   // #8f4029

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.618);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float cov = COLOR.a;
	vec3 ink = COLOR.rgb;
	vec2 g = floor(UV * px_size / cell);
	float n = vnoise(g / 10.0) * 0.62 + vnoise(g / 3.7) * 0.28 + hash(g) * 0.10;
	vec2 uv = g * cell / px_size;
	float far = distance(uv * vec2(px_size.x / px_size.y, 1.0), origin * vec2(px_size.x / px_size.y, 1.0));
	float v = clamp(n * 0.55 + far * 0.32, 0.0, 0.999);
	float e = 0.10;
	float t = (reveal ? (1.0 - cov) : cov) * (1.0 + e) - e;
	vec4 outc;
	if (v < t) {
		outc = reveal ? vec4(ink, 0.0) : vec4(ink, 1.0);
	} else if (v < t + e) {
		float k = (v - t) / e;
		if (k < 0.18) outc = c_hot;
		else if (k < 0.42) outc = c_yel;
		else if (k < 0.70) outc = c_org;
		else outc = c_red;
	} else {
		outc = reveal ? vec4(ink, 1.0) : vec4(ink, 0.0);
	}
	if (cov <= 0.001) outc.a = 0.0;
	if (cov >= 0.999) outc = vec4(ink, 1.0);
	COLOR = outc;
}
