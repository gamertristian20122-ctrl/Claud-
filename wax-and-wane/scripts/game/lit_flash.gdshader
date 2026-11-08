shader_type canvas_item;
// Creatures: the hit-flash of enemy.gd (same uniforms, same maths) with the banded pixel light.
#include "res://scripts/game/pixel_light.gdshaderinc"

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, tint.rgb, flash), c.a);
}
