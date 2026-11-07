class_name Costumes
extends Node2D
## Relics you can see on Tallow: a glass chimney round the flame, a tin reflector behind it, a pipe,
## a knitted scarf, a feather in the dish, a wind-up key... A child of the Player, placed in the
## same coordinates as Player._draw (feet at 0,0), so every piece follows the shrinking candle.
## Pieces are tiny sprites from tools/art_items2.py (assets/art/items/costume/); bands that must
## fit the candle's width are drawn here with the same palette.

const INK := Color("#21141b")
const PIECES := {
	"glass_chimney": "chimney", "tin_sconce": "sconce", "old_pipe": "pipe", "phoenix_feather": "feather",
	"love_letter": "bow", "stopped_clock": "key", "jet_brooch": "brooch", "nightshade": "berries",
	"both_ends": "flame_small",
}

var p: Player
var back: Node2D     # behind the flame (z 1, under the flame's z 2)
var front: Node2D    # over the flame (the glass chimney)
var _wear: Array = []
var _n := -1
var _rites := -1
var _pale_done := false


func _ready() -> void:
	p = get_parent() as Player
	z_index = 1
	back = Node2D.new()
	back.z_index = 0
	add_child(back)
	front = Node2D.new()
	front.z_index = 2
	add_child(front)
	draw.connect(_draw_mid)
	back.draw.connect(_draw_back)
	front.draw.connect(_draw_front)


func _process(_dt: float) -> void:
	if p == null:
		return
	if p.relics.size() != _n or p.rites.size() != _rites:
		_n = p.relics.size()
		_rites = p.rites.size()
		_wear = p.relics.filter(func(r): return r in PIECES or r in ["wax_coat", "lace_fan", "bell_wire", "scalding_wax", "pale_taper"])
		if "pale_taper" in p.relics and not _pale_done:
			_pale_done = true
			# a ghost-pale taper
			p.set("c_hi", Color("#fdf7ed"))
			p.set("c_wax", Color("#cae6f5"))
			p.set("c_sh", Color("#b6cbcf"))
			p.set("c_deep", Color("#7b8994"))
		if "seance" in p.rites and p.light:
			p.light.color = Color(0.8, 0.7, 1.0)
	var on := not _wear.is_empty() or "household" in p.rites or "seance" in p.rites
	visible = on and not p.dead
	if on:
		queue_redraw()
		back.queue_redraw()
		front.queue_redraw()
	# blink with the body while invulnerable
	modulate.a = p.self_modulate.a


## Body geometry, the same sums Player._draw makes: [top, base, L, R, face_y].
func _geo() -> Array:
	var h := p.body_height()
	var bob := -1 if sin(float(p.get("_bob"))) > 0.3 else 0
	var base := -5 + bob
	var top := base - h
	var L := -p.body_w / 2
	var R := L + p.body_w
	var fy := top + clampi(2 + h / 5, 2, 5)
	return [top, base, L, R, fy, h]


func _tex(name: String, frame := -1) -> Texture2D:
	var path := "items/costume/" + name + (("_f%d" % frame) if frame >= 0 else "")
	return Art.tex(path) if Art.has(path) else null


func _put(node: CanvasItem, name: String, at: Vector2, frames := 0, fps := 6.0) -> void:
	var f := -1
	if frames > 0:
		f = int(Time.get_ticks_msec() / 1000.0 * fps) % frames
	var t := _tex(name, f)
	if t:
		node.draw_texture(t, at)


func _r(node: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	node.draw_rect(Rect2(x, y, w, h), c)


# ---------------------------------------------------------------- behind the flame

func _draw_back() -> void:
	var g := _geo()
	var top: int = g[0]
	if "tin_sconce" in _wear:
		_put(back, "sconce", Vector2(-5, top - 15))


# ---------------------------------------------------------------- on the body

func _draw_mid() -> void:
	var g := _geo()
	var top: int = g[0]
	var base: int = g[1]
	var L: int = g[2]
	var R: int = g[3]
	var fy: int = g[4]
	var h: int = g[5]
	var t := Time.get_ticks_msec() / 1000.0
	if "bell_wire" in _wear and h >= 6:
		# copper wire wound twice round the body
		for k in 2:
			var y := top + 3 + k * maxi(3, h / 3)
			if y > base - 2:
				break
			_r(self, L, y, R - L, 1, Color("#c56025"))
			_r(self, L + 1, y, 2, 1, Color("#ee8e2e"))
			_r(self, R - 2, y, 1, 1, Color("#8f4029"))
			_r(self, R, y, 1, 2, INK)
			_r(self, L - 1, y - 1, 1, 2, INK)
	if "scalding_wax" in _wear and h >= 6:
		# red-hot drips over the rim and a bubble that pops in the pool
		_r(self, L, top + 2, 1, 2, Color("#ee8e2e"))
		_r(self, L - 1, top + 3, 1, 1, Color("#da4e38"))
		_r(self, R - 1, top + 3, 1, 2, Color("#ee8e2e"))
		_r(self, R, top + 4, 1, 1, Color("#da4e38"))
		if fmod(t, 0.9) < 0.45:
			_r(self, -2, top - 1, 1, 1, Color("#ee8e2e"))
	if "wax_coat" in _wear:
		# a knitted red scarf (and its tail)
		var y2 := mini(top + 3, base - 4)
		_r(self, L - 1, y2 - 1, R - L + 2, 4, INK)
		_r(self, L, y2, R - L, 2, Color("#da4e38"))
		_r(self, L, y2, 2, 1, Color("#ee8e2e"))
		var x := L + 1
		while x < R:
			_r(self, x, y2 + 1, 1, 1, Color("#8f4029"))
			x += 2
		_r(self, R - 2, y2 + 2, 3, 4, INK)
		_r(self, R - 1, y2 + 2, 1, 3, Color("#da4e38"))
		_r(self, R - 1, y2 + 4, 1, 1, Color("#8f4029"))
	if "lace_fan" in _wear:
		# a lace collar where the candle meets the dish
		var y3 := base - 2
		_r(self, L - 1, y3 - 1, R - L + 2, 3, INK)
		_r(self, L, y3, R - L, 1, Color("#fdf7ed"))
		var x2 := L
		while x2 < R:
			_r(self, x2, y3 + 1, 1, 1, Color("#fdf7ed") if (x2 - L) % 2 == 0 else Color("#d3bfa9"))
			x2 += 1
	if "household" in p.rites and h >= 8:
		_put(self, "apron", Vector2(-3, base - 7))
	if "jet_brooch" in _wear and h >= 7:
		var lit: bool = RelicFx._cur != null and is_instance_valid(RelicFx._cur) and RelicFx._cur.brooch > 0
		_put(self, "brooch", Vector2(-2, mini(fy + 5, base - 5)), 2 if lit else 0, 4.0)
	if "love_letter" in _wear:
		_put(self, "bow", Vector2(L - 3, top + 1))
	if "stopped_clock" in _wear and h >= 5:
		_put(self, "key", Vector2(L - 5, top + maxi(2, h / 2) - 2), 2, 2.0)
	if "nightshade" in _wear:
		_put(self, "berries", Vector2(-9, -9))
	if "phoenix_feather" in _wear and p.revives > 0:
		_put(self, "feather", Vector2(4, -15))
	if "both_ends" in _wear:
		_put(self, "flame_small", Vector2(-10, -11), 2, 8.0)
	if "old_pipe" in _wear:
		_put(self, "pipe", Vector2(0, fy + 1))
		var ph := fmod(t, 1.6)
		if ph < 1.0:
			_put(self, "puff", Vector2(6, fy - 2 - roundf(ph * 6.0)), 3, 3.0)
	if "seance" in p.rites:
		for k in 2:
			var a := t * 2.2 + k * PI
			var at := Vector2(cos(a) * 9.0, top - 6 + sin(a) * 3.0).round()
			_r(self, at.x, at.y, 1, 1, Color("#cae6f5"))
			_r(self, at.x - 1, at.y + 1, 1, 1, Color("#72d6ce"))


# ---------------------------------------------------------------- over the flame

func _draw_front() -> void:
	if not "glass_chimney" in _wear:
		return
	var fx := RelicFx._cur
	if fx == null or not is_instance_valid(fx) or not fx.chimney_ready:
		return
	var g := _geo()
	var top: int = g[0]
	_put(front, "chimney", Vector2(-7, top - 18))
