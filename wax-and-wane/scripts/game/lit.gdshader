shader_type canvas_item;
// The shared lit material (lighting.gd): banded, dithered pixel light, and for room pieces (floor,
// walls, decor, obstacles, stains) the waning: as the wax runs low the house loses its colour.
// Fire, embers, the flame, shots and the HUD are unshaded or elsewhere, so they keep full colour.
#include "res://scripts/game/pixel_light.gdshaderinc"

uniform float wane : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// In Godot 4 the incoming COLOR is already texture x vertex colour x modulate.
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(g), wane);
	COLOR = c;
}
