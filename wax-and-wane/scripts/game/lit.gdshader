shader_type canvas_item;
// The shared lit material (lighting.gd): banded, dithered pixel light, and for room pieces (floor,
// walls, decor, obstacles, stains) the waning: as the wax runs low the house loses its colour and the
// dark closes in from the edges (a vignette in three dithered steps, folded in here so it costs no
// extra full-screen pass). Fire, embers, the flame, shots and the HUD are unshaded or elsewhere, and
// Tallow, creatures and pickups use the actor material, so they keep full colour.
#include "res://scripts/game/pixel_light.gdshaderinc"

uniform float vig_amount : hint_range(0.0, 1.0) = 0.0;   // 0 = off, 1 = the tightest (an empty candle)
uniform vec2 vig_focus = vec2(0.5, 0.5);                  // screen UV the dark closes in on
uniform vec4 vig_shade : source_color = vec4(0.035, 0.027, 0.035, 1.0);   // the house's own dark

void fragment() {
	// In Godot 4 the incoming COLOR is already texture x vertex colour x modulate.
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(g), wane);
	if (vig_amount > 0.0) {
		vec2 sz = 1.0 / SCREEN_PIXEL_SIZE;
		vec2 p = floor(FRAGCOORD.xy) + 0.5;
		float d = length((p - vig_focus * sz) / vec2(sz.y * 0.62, sz.y * 0.5));
		float x = (d - mix(1.5, 0.55, vig_amount)) / 0.42 * 3.0;
		float lv = clamp(floor(x) + step(px_bayer4(FRAGCOORD.xy), fract(x)), 0.0, 3.0);
		c.rgb = mix(c.rgb, vig_shade.rgb, lv / 3.0 * 0.9);
	}
	COLOR = c;
}
