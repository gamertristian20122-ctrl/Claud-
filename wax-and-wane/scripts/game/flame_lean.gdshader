shader_type canvas_item;
render_mode unshaded;
// Leans the candle flame by shifting whole pixel rows sideways (more at the tip).
uniform float lean = 0.0;

void fragment() {
	float rows = 1.0 / TEXTURE_PIXEL_SIZE.y;
	float row_from_base = floor((1.0 - UV.y) * rows);
	vec2 uv = UV;
	uv.x -= round(lean * row_from_base / rows * 2.4) * TEXTURE_PIXEL_SIZE.x;
	vec4 c = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.x > 1.0) {
		c.a = 0.0;
	}
	COLOR = c * COLOR;
}
