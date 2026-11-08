shader_type canvas_item;
render_mode unshaded;
// The dark closing in as the wax runs low: a dithered vignette in three steps of the house's own dark
// (the clear colour around the rooms), drawn over the game, under the HUD. `amount` 0 = off, 1 = the
// tightest (an empty candle).
#include "res://scripts/game/px_dither.gdshaderinc"

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus = vec2(0.5, 0.5);     // screen UV the dark closes in on (between the centre and Tallow)
uniform vec4 shade : source_color = vec4(0.035, 0.027, 0.035, 1.0);   // the clear colour

void fragment() {
	vec2 sz = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = floor(FRAGCOORD.xy) + 0.5;
	// distance in half-heights, a little wider than tall
	float d = length((p - focus * sz) / vec2(sz.y * 0.62, sz.y * 0.5));
	float edge = mix(1.5, 0.55, amount);           // where the dark begins
	float x = (d - edge) / 0.42 * 3.0;              // three steps over 0.42 half-heights
	float lv = clamp(floor(x) + step(px_bayer4(FRAGCOORD.xy), fract(x)), 0.0, 3.0);
	COLOR = vec4(shade.rgb, lv / 3.0 * 0.9);
}
