// Pixel-art light for every lit canvas item (lighting.gd). Godot's own 2D light is a smooth radial ramp;
// here each light's strength is cut into flat bands (light_steps per unit of light) with a dithered seam
// between bands, on the game-pixel grid. Only the light factor is quantized: the sprite's own palette
// colour (COLOR) is untouched, and the light keeps its hue (chapel glass, ember red, moonlight).
// Same maths as the engine default otherwise: LIGHT = COLOR * LIGHT_COLOR * LIGHT_ENERGY, added.
// A shader that needs its own light() (lit_flash: the creatures' shadow floor) defines PX_OWN_LIGHT
// before including this and calls px_light() itself.
#include "res://scripts/game/px_dither.gdshaderinc"

uniform float light_steps : hint_range(1.0, 8.0) = 4.0;
uniform float light_seam : hint_range(0.0, 1.0) = 0.35;
// The waning (lighting.gd sets it on the room material only): 0 = full colour, 1 = grey. Both the
// surface and the light falling on it lose their colour, so the house itself greys while Tallow,
// creatures, pickups and every flame keep theirs.
uniform float wane : hint_range(0.0, 1.0) = 0.0;

// The banded light this light puts on a surface of colour `albedo` (the engine default, stepped).
vec3 px_light(vec4 light_color, float energy, vec3 albedo, vec2 frag) {
	vec3 lc = light_color.rgb * (light_color.a * energy);
	float s = max(lc.r, max(lc.g, lc.b));
	vec3 hue = lc / max(s, 0.0001);
	hue = mix(hue, vec3(dot(hue, vec3(0.299, 0.587, 0.114))), wane);
	float q = px_band(s * light_steps, light_seam, frag) / light_steps;
	return albedo * hue * q;
}

#ifndef PX_OWN_LIGHT
void light() {
	LIGHT = vec4(px_light(LIGHT_COLOR, LIGHT_ENERGY, COLOR.rgb, FRAGCOORD.xy), 1.0);
}
#endif
