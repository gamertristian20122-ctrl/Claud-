shader_type canvas_item;
// Creatures: the hit-flash of enemy.gd (same `flash` / `tint` uniforms) with the banded pixel light.
// The incoming COLOR is texture x modulate. (enemy.gd's old shader read the bare texture, so the sprite's
// modulate was lost: champion tints, recoloured guardians and the spawn fade-in never showed.)
#include "res://scripts/game/pixel_light.gdshaderinc"

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = COLOR;
	COLOR = vec4(mix(c.rgb, tint.rgb, flash), c.a);
}
