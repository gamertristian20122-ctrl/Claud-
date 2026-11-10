extends Node
## Texture + animation loader with caching. Missing art falls back to a visible placeholder so the
## game always runs while assets are still being made.

const D72 := "res://assets/0x72/frames/"
const ART := "res://assets/art/"

var _tex := {}
var _frames := {}
var font: Font
var font_small: Font
var light_tex: Texture2D
## One shared "ignore lighting" material (fire, bullets, explosions).
var unshaded: CanvasItemMaterial


func _ready() -> void:
	font = load("res://assets/fonts/kenney_pixel.ttf")
	font_small = load("res://assets/fonts/kenney_mini.ttf") if ResourceLoader.exists("res://assets/fonts/kenney_mini.ttf") else font
	light_tex = _make_light()
	for f in [font, font_small]:
		if f is FontFile:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			f.hinting = TextServer.HINTING_NONE
	unshaded = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED


func has(path: String) -> bool:
	return ResourceLoader.exists(_full(path))


func _full(path: String) -> String:
	if path.begins_with("res://"):
		return path
	if path.begins_with("0x72/"):
		return D72 + path.substr(5) + ".png"
	return ART + path + ".png"


## tex("hero/holder"), tex("0x72/crate")
func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var full := _full(path)
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = load(full)
	else:
		t = UIShapes.make(path) if path.begins_with("ui/") else null   # a few HUD glyphs are plain shapes now
		if t == null:
			t = _placeholder(path)
	_tex[path] = t
	return t


func _placeholder(_path: String) -> Texture2D:
	# v2.10: a picture that is not there shows nothing (many of the house's drawn props were taken out when
	# the art moved to free packs; a coloured square in their place would be worse than an empty spot)
	if _blank == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_blank = ImageTexture.create_from_image(img)
	return _blank


var _blank: Texture2D


## Array of textures prefix_f0.. until a frame is missing (at least one).
func seq(prefix: String, max_frames := 16) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in max_frames:
		var p := "%s_f%d" % [prefix, i]
		if not has(p):
			break
		out.append(tex(p))
	if out.is_empty():
		out.append(tex(prefix))
	return out


## SpriteFrames with "idle" and "run" for a 0x72 creature (e.g. "goblin", "muddy", "big_demon").
func creature(name: String) -> SpriteFrames:
	if _frames.has(name):
		return _frames[name]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var idle := "0x72/%s_idle_anim" % name
	var run := "0x72/%s_run_anim" % name
	var single := "0x72/%s_anim" % name
	var have_idle := has(idle + "_f0")
	for anim in ["idle", "run"]:
		sf.add_animation(anim)
		sf.set_animation_loop(anim, true)
		sf.set_animation_speed(anim, 7.0 if anim == "idle" else 10.0)
		var src := single
		if have_idle:
			src = idle if anim == "idle" else (run if has(run + "_f0") else idle)
		for t in seq(src):
			sf.add_frame(anim, t)
	_frames[name] = sf
	return sf


## Simple looping SpriteFrames from one prefix.
func anim(prefix: String, fps := 8.0, loop := true) -> SpriteFrames:
	var key := "%s@%s@%s" % [prefix, fps, loop]
	if _frames.has(key):
		return _frames[key]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	for t in seq(prefix):
		sf.add_frame("default", t)
	_frames[key] = sf
	return sf


func _make_light() -> Texture2D:
	if has("fx/light/soft_light"):
		return tex("fx/light/soft_light")
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	return gt
