class_name Stains
extends Sprite2D
## Persistent floor stains for one room: every splat, scorch and wax drop is baked into a single
## Image (one texture, one draw call however many stains there are). The Image is kept by Juice
## per floor, so a room still shows its history when you come back to it.
##
## Splat/gib art (assets/art/fx/splat_*.png, gib_*.png, tools/art_fx2.py) is drawn in a neutral
## 3-step ramp and recoloured here per material by exact colour index.

## The stain image covers the room interior (room-local px).
const ORIGIN := Vector2i(16, 32)
const SIZE := Vector2i(240, 144)
const MAX_STAMPS := 900
const SPLATS := 8
const GIBS := 6
## Author ramp in the PNGs (hi, mid, lo).
const KEY := [Color("#b6cbcf"), Color("#7b8994"), Color("#314152")]
## Materials: hi, mid, lo (all from the 0x72 palette).
const RAMPS := {
	"ash": [Color("#b6cbcf"), Color("#7b8994"), Color("#483b3a")],
	"goo": [Color("#4ba747"), Color("#3d734f"), Color("#314152")],
	"blood": [Color("#8f4029"), Color("#62232f"), Color("#21141b")],
	"red": [Color("#da4e38"), Color("#8f4029"), Color("#62232f")],
	"wax": [Color("#fdf7ed"), Color("#e2b694"), Color("#b58057")],
	"pumpkin": [Color("#ee8e2e"), Color("#c56025"), Color("#8f4029")],
	"ice": [Color("#72d6ce"), Color("#417089"), Color("#314152")],
	"soot": [Color("#333333"), Color("#222222"), Color("#111111")],
	"ichor": [Color("#9f294e"), Color("#5f2d56"), Color("#21141b")],
}
## Who leaves what (Enemy.DEFS may override with a "stain" key: a Color or one of the names above).
const KIND := {
	"tiny_zombie": "goo", "goblin": "red", "tiny_slug": "goo", "slug": "goo", "muddy": "goo",
	"swampy": "goo", "imp": "blood", "skelet": "ash", "pumpkin_dude": "pumpkin", "chort": "blood",
	"wogol": "blood", "orc_shaman": "red", "masked_orc": "red", "necromancer": "ash", "doc": "goo",
	"ice_zombie": "ice", "mimic": "red", "big_zombie": "goo", "ogre": "red", "necro_boss": "ichor",
	"big_demon": "blood",
}
const PALETTE := ["#222222", "#483b3a", "#fdf7ed", "#da4e38", "#775c55", "#8f4029", "#3d734f", "#aa8d7a",
	"#72d6ce", "#4ba747", "#facb3e", "#62232f", "#314152", "#d3bfa9", "#9f294e", "#5698cc", "#ee8e2e",
	"#417089", "#49a790", "#c56025", "#fccba3", "#d8a57d", "#5956bd", "#5f2d56", "#333333", "#b58057",
	"#111111", "#97da3f", "#b6cbcf", "#2a2a3a", "#c38d70", "#8a503e", "#dc4a7b", "#e2b694", "#21141b",
	"#e46e33", "#7b8994"]

static var _imgs := {}       # "splat_3|goo" -> Image
static var _texs := {}       # same key -> ImageTexture (gibs in flight)
static var _custom := {}     # Color html -> ramp

var room: Node2D
var img: Image
var stamps := 0
var _dirty := false


## Material name for a creature: DEFS "stain" first, then the table, then a guess from the name.
static func material_of(kind: String) -> String:
	var d: Dictionary = Enemy.DEFS.get(kind, {})
	if d.has("stain"):
		var s = d["stain"]
		if s is Color:
			return _register(s)
		if str(s) in RAMPS:
			return str(s)
	if KIND.has(kind):
		return KIND[kind]
	var k := kind.to_lower()
	for pair in [["wax", "wax"], ["candle", "wax"], ["tallow", "wax"], ["slug", "goo"], ["slime", "goo"],
			["zomb", "goo"], ["swamp", "goo"], ["mud", "goo"], ["skel", "ash"], ["bone", "ash"],
			["ghost", "ash"], ["necro", "ash"], ["imp", "blood"], ["demon", "blood"], ["chort", "blood"],
			["fiend", "blood"], ["ice", "ice"], ["frost", "ice"], ["pumpkin", "pumpkin"], ["bat", "blood"]]:
		if k.contains(pair[0]):
			return pair[1]
	return "red"


## A custom Color becomes a hi/mid/lo ramp snapped to the 0x72 palette.
static func _register(c: Color) -> String:
	var key := "c" + c.to_html(false)
	if not _custom.has(key):
		_custom[key] = [_snap(c.lightened(0.25)), _snap(c), _snap(c.darkened(0.5))]
	return key


static func _snap(c: Color) -> Color:
	var best := Color.BLACK
	var bd := 99.0
	for h in PALETTE:
		var p := Color(h)
		var d := (p.r - c.r) * (p.r - c.r) * 0.3 + (p.g - c.g) * (p.g - c.g) * 0.59 + (p.b - c.b) * (p.b - c.b) * 0.11
		if d < bd:
			bd = d
			best = p
	return best


static func ramp_of(mat: String) -> Array:
	if RAMPS.has(mat):
		return RAMPS[mat]
	if _custom.has(mat):
		return _custom[mat]
	return RAMPS["red"]


## The splat/gib art recoloured for a material (cached).
static func image(art: String, mat: String) -> Image:
	var key := art + "|" + mat
	if _imgs.has(key):
		return _imgs[key]
	var src: Image
	var t := Art.tex("fx/" + art)
	src = t.get_image() if t else null
	if src == null:
		src = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		src.fill(KEY[1])
	src = src.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var ramp := ramp_of(mat)
	var keys := [KEY[0].to_rgba32(), KEY[1].to_rgba32(), KEY[2].to_rgba32()]
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				src.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var i := keys.find(c.to_rgba32())
			if i >= 0:
				src.set_pixel(x, y, ramp[i])
	_imgs[key] = src
	return src


static func tex_of(art: String, mat: String) -> Texture2D:
	var key := art + "|" + mat
	if not _texs.has(key):
		_texs[key] = ImageTexture.create_from_image(image(art, mat))
	return _texs[key]


func _init() -> void:
	centered = false
	position = Vector2(ORIGIN)
	z_index = 0


## Use (or start) the stain image for this room. `stored` comes from Juice's per-floor store.
func setup(r: Node2D, stored: Image) -> void:
	room = r
	if stored:
		img = stored
		stamps = int(img.get_meta("stamps", 0))
		texture = ImageTexture.create_from_image(img)


func _ensure() -> void:
	if img == null:
		img = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		texture = ImageTexture.create_from_image(img)


## True when a stain may land at this room-local point (not in a pit, a wall or off the floor).
func _floor_ok(lp: Vector2) -> bool:
	if lp.x < ORIGIN.x or lp.y < ORIGIN.y or lp.x >= ORIGIN.x + SIZE.x or lp.y >= ORIGIN.y + SIZE.y:
		return false
	if room and room.has_method("char_at") and room.has_method("cell_of"):
		var ch: String = room.char_at(room.cell_of(lp))
		if ch == "P" or ch == "#":
			return false
	return true


## Bake `src` centred on the world position. Returns false if the spot is not floor.
func stamp_image(src: Image, wp: Vector2, flip := false) -> bool:
	if stamps >= MAX_STAMPS:
		return false
	var lp := wp - room.global_position
	if not _floor_ok(lp):
		return false
	_ensure()
	var s := src
	if flip:
		s = src.duplicate() as Image
		s.flip_x()
	var at := Vector2i(lp.round()) - ORIGIN - Vector2i(s.get_width() / 2, s.get_height() / 2)
	img.blend_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), at)
	stamps += 1
	_dirty = true
	return true


func splat(wp: Vector2, mat: String, big := false) -> void:
	var v := randi_range(4, 7) if big else randi_range(0, 4)
	stamp_image(image("splat_%d" % v, mat), wp, randf() < 0.5)


func gib(wp: Vector2, idx: int, mat: String) -> void:
	stamp_image(image("gib_%d" % (idx % GIBS), mat), wp)


## A 1-2 px drop (Tallow's drips, spilled wax).
func dot(wp: Vector2, mat := "wax", n := 1) -> void:
	if stamps >= MAX_STAMPS:
		return
	var lp := wp - room.global_position
	if not _floor_ok(lp):
		return
	_ensure()
	var ramp := ramp_of(mat)
	var p := Vector2i(lp.round()) - ORIGIN
	var c: Color = ramp[1]
	_put(p, c)
	if n >= 2:
		_put(p + Vector2i(1, 0), ramp[2])
	if n >= 3:
		_put(p + Vector2i(0, -1), ramp[0])
	stamps += 1
	_dirty = true


func _put(p: Vector2i, c: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < SIZE.x and p.y < SIZE.y:
		img.set_pixelv(p, c)


func _process(_dt: float) -> void:
	if _dirty and img:
		_dirty = false
		img.set_meta("stamps", stamps)
		(texture as ImageTexture).update(img)
