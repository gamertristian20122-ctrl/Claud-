// 4x4 ordered (Bayer) dither on the game-pixel grid. FRAGCOORD is in viewport pixels, and with the
// "viewport" stretch mode the viewport is the 384x216 (phones ~480x216) game screen: one game pixel each.
// Values are kept small (mod 4) so mediump floats stay exact.

float px_m2(vec2 v) {
	return mod(2.0 * v.x + 3.0 * v.y, 4.0);   // 2x2 Bayer: 0 2 / 3 1
}

// threshold in (0, 1): (k + 0.5) / 16 for k = 0..15
float px_bayer4(vec2 frag) {
	vec2 a = mod(floor(frag), 4.0);
	return (4.0 * px_m2(mod(a, 2.0)) + px_m2(floor(a * 0.5)) + 0.5) / 16.0;
}

// Round x to a whole step, with a dithered seam `seam` wide (0..1 of a step) around each midpoint:
// flat bands, and a 4x4 checker of the two neighbouring bands only where they meet.
float px_band(float x, float seam, vec2 frag) {
	float b = floor(x);
	float t = clamp((x - b - 0.5) / max(seam, 0.001) + 0.5, 0.0, 1.0);
	return b + step(px_bayer4(frag), t);
}
