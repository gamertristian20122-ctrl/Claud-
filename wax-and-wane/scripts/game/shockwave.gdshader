shader_type canvas_item;
render_mode unshaded;
// A blast ring: pixels on an expanding ring are pushed outward by a whole number of pixels (1-2 at most).
// Every pixel is an exact copy of a screen pixel at most `amp` away: no blur, palette intact.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec2 size = vec2(64.0, 64.0);   // the patch in pixels (the ring's centre is its middle)
uniform float radius = 8.0;             // ring radius, pixels
uniform float width = 4.0;              // half thickness, pixels
uniform float amp = 2.0;                // push at the ring's crest, pixels

void fragment() {
	vec2 d = (UV - 0.5) * size;
	float r = length(d);
	float k = clamp(1.0 - abs(r - radius) / width, 0.0, 1.0);
	float push = floor(k * amp + 0.5);
	vec2 off = floor(d / max(r, 0.001) * push + 0.5);
	COLOR = texture(screen_tex, SCREEN_UV - off * SCREEN_PIXEL_SIZE);
}
