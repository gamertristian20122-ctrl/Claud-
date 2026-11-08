shader_type canvas_item;
// Creatures: the hit-flash of enemy.gd (same `flash` / `tint` uniforms) with the banded pixel light.
// The incoming COLOR is texture x modulate. (enemy.gd's old shader read the bare texture, so the sprite's
// modulate was lost: champion tints, recoloured guardians and the spawn fade-in never showed.)
// Shadow floor (fix/art, UX-03): a creature standing in Tallow's hard shadow keeps `shadow_floor` of the
// light his candle would give it, so it never sinks into the shadowed floor (1.25:1 before). It comes from
// a twin of his light that only creatures see (lighting.gd, marked by its height): where his light
// reaches, the twin adds nothing; in his shadow the engine swaps the twin's light for its shadow colour
// (white) times SHADOW_MODULATE, which is that share of his light. Rooms, Tallow and pickups are untouched.
#define PX_OWN_LIGHT
#include "res://scripts/game/pixel_light.gdshaderinc"

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 c = COLOR;
	COLOR = vec4(mix(c.rgb, tint.rgb, flash), c.a);
}

void light() {
	vec3 lit = px_light(LIGHT_COLOR, LIGHT_ENERGY, COLOR.rgb, FRAGCOORD.xy);
	if (LIGHT_POSITION.z > 4.0) {   // the creature twin of Tallow's light (lighting.gd TWIN_HEIGHT)
		LIGHT = vec4(0.0, 0.0, 0.0, 1.0);
		SHADOW_MODULATE = vec4(lit * shadow_floor, 1.0);
	} else {
		LIGHT = vec4(lit, 1.0);
	}
}
