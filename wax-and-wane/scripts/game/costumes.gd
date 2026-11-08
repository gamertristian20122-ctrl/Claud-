class_name Costumes
extends Node2D
## Relics you can see on Tallow: a glass chimney round the flame, a tin reflector behind it, a pipe,
## a knitted scarf, a feather in the dish, a wind-up key... A child of the Player, placed in the
## same coordinates as Player._draw (feet at 0,0); every piece anchors to Player.geo() (the wax rows,
## the lip, the eyes, the wick tip), so it follows the melting, hopping candle.
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
	use_parent_material = true   # self-lit with Tallow (Player._process)
	back = Node2D.new()
	back.z_index = 0
	back.use_parent_material = true
	add_child(back)
	front = Node2D.new()
	front.z_index = 2
	front.use_parent_material = true
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
			p.set("c_hi", Color("#cae6f5"))
			p.set("c_wax", Color("#b6cbcf"))
			p.set("c_sh", Color("#7b8994"))
			p.set("c_deep", Color("#417089"))
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


## The body's geometry this frame, straight from Player.shape() (so every piece follows the melting,
## hopping, squashing candle): t = top wax row, top = the outline over it, base = the bottom wax row
## (it stands in the dish, whose bowl row is base + 1), lip = the overhang, fy = the eyes' top row,
## cheek = the blush row (fy + 3), cx = the face's x, w = half-width at the eyes, belly = half-width
## of the gumdrop belly, tip = the wick tip, d = the dish's offset (it hops with him).
func _geo() -> Dictionary:
	var g: Dictionary = p.geo()
	var at: Dictionary = g["at"]
	var w: int = g["w"]
	var bl := Player.span_at(g, int(g["base"])).y
	return {"t": g["top"], "top": int(g["top"]) - 1, "base": g["base"], "lip": at["lip"], "fy": g["fy"],
		"cheek": at["cheek"], "pool": at["pool"], "cx": g["cx"], "w": w, "belly": maxi(bl, w), "h": g["h"],
		"tip": g["tip"], "d": Vector2(0, -int(g["lift"])), "stage": g["stage"]}


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
	var tip: Vector2i = g["tip"]
	if "tin_sconce" in _wear:
		# a tin reflector standing behind the flame, its foot on the top of the wax
		_put(back, "sconce", Vector2(tip.x - 6, int(g["top"]) - 15))


# ---------------------------------------------------------------- on the body

func _draw_mid() -> void:
	var g := _geo()
	var t0: int = g["t"]
	var top: int = g["top"]
	var base: int = g["base"]
	var lip: int = g["lip"]
	var fy: int = g["fy"]
	var cheek: int = g["cheek"]
	var cx: int = g["cx"]
	var w: int = g["w"]
	var bw: int = g["belly"]
	var h: int = g["h"]
	var d: Vector2 = g["d"]
	var t := Time.get_ticks_msec() / 1000.0
	if "bell_wire" in _wear:
		# copper wire wound round the body: under the overhang and round the belly
		var ys: Array = [lip + 1]
		if cheek + 1 <= base:
			ys.append(cheek + 1)
		for y in ys:
			var hw: int = Player.span_at(p.geo(), y).y
			_r(self, -hw, y, 2 * hw + 1, 1, Color("#c56025"))
			_r(self, -hw + 1, y, 2, 1, Color("#ee8e2e"))
			_r(self, hw - 1, y, 1, 1, Color("#8f4029"))
			_r(self, hw + 1, y, 1, 2, INK)
			_r(self, -hw - 1, y - 1, 1, 2, INK)
	if "scalding_wax" in _wear and h >= 5:
		# red-hot tears over the lip and a bubble that pops in the pool round the wick
		_r(self, -w - 1, lip, 1, 3, Color("#facb3e"))
		_r(self, -w - 1, lip + 3, 1, 1, Color("#ee8e2e"))
		_r(self, -w - 1, lip + 4, 1, 1, Color("#da4e38"))
		_r(self, w + 1, lip, 1, 2, Color("#ee8e2e"))
		_r(self, w + 1, lip + 2, 1, 1, Color("#da4e38"))
		var pool: int = g["pool"]
		var pw: int = Player.span_at(p.geo(), pool).y
		_r(self, -pw + 2, pool, 2 * pw - 3, 1, Color("#ee8e2e"))
		var bub := fmod(t, 0.9)
		if bub < 0.5:
			_r(self, -3 + int(t / 0.9) % 3, pool - 1 - roundf(bub * 4.0), 1, 1, Color("#facb3e"))
	if "wax_coat" in _wear:
		# a knitted red scarf round the belly, just under the blush (at low wax it drapes over the dish)
		var y2 := cheek + 2
		_r(self, -bw - 2, y2 - 1, 2 * bw + 5, 4, INK)
		_r(self, -bw - 1, y2, 2 * bw + 3, 2, Color("#da4e38"))
		_r(self, -bw - 1, y2, 2, 1, Color("#ee8e2e"))
		var x := -bw
		while x <= bw + 1:
			_r(self, x, y2 + 1, 1, 1, Color("#8f4029"))
			x += 2
		_r(self, bw - 2, y2 + 2, 3, 4, INK)
		_r(self, bw - 1, y2 + 2, 1, 3, Color("#da4e38"))
		_r(self, bw - 1, y2 + 4, 1, 1, Color("#8f4029"))
	if "lace_fan" in _wear:
		# a lace collar where the candle meets the dish (it hangs over the bowl's rim)
		var y3 := base
		_r(self, -bw - 2, y3 - 1, 2 * bw + 5, 3, INK)
		_r(self, -bw - 1, y3, 2 * bw + 3, 1, Color("#fdf7ed"))
		var x2 := -bw - 1
		while x2 <= bw + 1:
			_r(self, x2, y3 + 1, 1, 1, Color("#fdf7ed") if (x2 + bw + 1) % 2 == 0 else Color("#d3bfa9"))
			x2 += 1
	if "household" in p.rites and h >= 7:
		# an apron tied under the blush, its hem over the dish
		_put(self, "apron", Vector2(-4, cheek + 1))
	if "jet_brooch" in _wear and h >= 7:
		var lit: bool = RelicFx._cur != null and is_instance_valid(RelicFx._cur) and RelicFx._cur.brooch > 0
		var bf := (int(Time.get_ticks_msec() / 250) % 2) if lit else 0
		var bt := _tex("brooch", bf)
		if bt:
			# pinned on his top-left shoulder, clear of the eyes
			draw_texture(bt, Vector2(-w - 4, t0 - 2))
	if "love_letter" in _wear:
		_put(self, "bow", Vector2(w - 3, t0 - 2))
	if "stopped_clock" in _wear and h >= 5:
		# the wind-up key in his back, sticking out on the left above the arm
		_put(self, "key", Vector2(-w - 9, lip + 1), 2, 2.0)
	if "nightshade" in _wear:
		_put(self, "berries", Vector2(-16, -9) + d)   # a sprig by the dish
	if "phoenix_feather" in _wear and p.revives > 0:
		_put(self, "feather", Vector2(9, -16) + d)
	if "both_ends" in _wear:
		_put(self, "flame_small", Vector2(-15, -8) + d, 2, 8.0)   # burning at the other end too
	if "old_pipe" in _wear and h >= 5:
		var my := fy + 3   # the bottom of the mouth
		_put(self, "pipe", Vector2(cx + 1, my - 4))
		var ph := fmod(t, 1.6)
		if ph < 1.0:
			_put(self, "puff", Vector2(cx + 7, my - 6 - roundf(ph * 6.0)), 3, 3.0)
	if "seance" in p.rites:
		for k in 2:
			var a := t * 2.2 + k * PI
			var at := Vector2(cos(a) * 11.0, top - 6 + sin(a) * 3.0).round()
			_r(self, at.x, at.y, 1, 1, Color("#cae6f5"))
			_r(self, at.x - 1, at.y + 1, 1, 1, Color("#72d6ce"))


# ---------------------------------------------------------------- over the flame

func _draw_front() -> void:
	if not "glass_chimney" in _wear:
		return
	var fx := RelicFx._cur
	var ready: bool = fx != null and is_instance_valid(fx) and fx.chimney_ready
	if not ready and not p.has_meta("show_all"):
		return
	var g := _geo()
	var tip: Vector2i = g["tip"]
	# a glass chimney round the flame, standing on the top of the wax
	_put(front, "chimney", Vector2(tip.x - 8, int(g["top"]) - 18))
