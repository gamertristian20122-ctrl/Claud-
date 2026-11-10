class_name UIShapes
## v2.10: the few HUD glyphs that used to be drawn pictures and are plain geometry now (the touch sticks and the
## pause key). `Art.tex` asks here when a "ui/" picture is not on disk; nothing here is a drawing of a thing.


static func make(path: String) -> Texture2D:
	match path:
		"ui/stick_base":
			return _ring(40, 2, Color(0.99, 0.97, 0.93, 0.9), Color(0.13, 0.08, 0.1, 0.35))
		"ui/stick_knob":
			return _ring(18, 2, Color(0.99, 0.97, 0.93, 1.0), Color(0.93, 0.56, 0.18, 0.9))
		"ui/btn_pause":
			return _pause()
	return null


## A disc with an edge: `d` px across, the edge `w` px wide.
static func _ring(d: int, w: int, edge: Color, fill: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d / 2.0, d / 2.0)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist <= r:
				img.set_pixel(x, y, edge if dist > r - w else fill)
	return ImageTexture.create_from_image(img)


## Two bars on a dark key.
static func _pause() -> Texture2D:
	var img := Image.create(13, 13, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.13, 0.08, 0.1, 0.85))
	for y in range(3, 10):
		for x in [3, 4, 8, 9]:
			img.set_pixel(x, y, Color(0.99, 0.97, 0.93))
	return ImageTexture.create_from_image(img)
