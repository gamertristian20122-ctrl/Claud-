shader_type canvas_item;
render_mode unshaded;
// Turns a smooth alpha ramp (a gradient overlay such as the HUD's low-wax glow) into `levels` flat
// steps with an ordered dither between them, on the game-pixel grid. The colour is unchanged.
#include "res://scripts/game/px_dither.gdshaderinc"

uniform float levels : hint_range(1.0, 8.0) = 4.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float x = c.a * levels;
	COLOR = vec4(c.rgb, (floor(x) + step(px_bayer4(FRAGCOORD.xy), fract(x))) / levels);
}
