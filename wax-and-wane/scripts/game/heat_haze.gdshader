shader_type canvas_item;
render_mode unshaded;
// Heat haze over a small patch (above a flame, a hearth, the Blowlamp jet): whole pixel rows of what is
// already on screen slide 1 px left or right, at a 10 fps cadence. Nothing is blurred or blended: every
// pixel is an exact copy of a neighbour, so the palette stays intact.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

void fragment() {
	float row = floor(FRAGCOORD.y);
	float tt = floor(TIME * 10.0) * 0.1;
	// none at the patch's sides and top, most just above the source (bottom middle)
	float side = clamp((1.0 - abs(UV.x * 2.0 - 1.0)) * 2.5, 0.0, 1.0);
	float w = strength * side * (0.3 + 0.7 * UV.y);
	// two slow waves climbing the rows
	float v = (sin(row * 1.37 + seed - tt * 7.0) * 0.7 + sin(row * 0.61 + seed * 1.7 - tt * 4.3) * 0.3) * w;
	float off = step(0.5, v) - step(0.5, -v);
	COLOR = texture(screen_tex, SCREEN_UV + vec2(off * SCREEN_PIXEL_SIZE.x, 0.0));
}
