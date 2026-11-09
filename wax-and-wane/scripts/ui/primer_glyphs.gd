class_name PrimerGlyphs
extends RefCounted
## v2.7 (docs/streams/v27_onboarding.md): the controls as little animations, drawn for the primer (primer.gd) and its
## replay (primer_reel.gd): a thumb on the touch stick, keycaps that press, a gamepad stick that tilts, the mouse, a
## button tapped. Pictures from tools/art_primer.py (assets/art/primer/) and the HUD's own stick; every position is a
## whole pixel. `t` is the step's clock in seconds; `calm` is Settings > Reduce motion: nothing glides (the thumb and
## the stick step between two places) and the beat is slower.

const INK := Color("#21141b")
const SHINE := Color("#fdf7ed")
const GOLD := Color("#facb3e")
const EMBER := Color("#ee8e2e")
const DIM := Color("#775c55")
const KEY_H := 14.0
const STICK_REACH := 11.0      # px the touch knob travels in the drawing (the real stick reaches 22)
const PAD_REACH := 2.0       # px a stick's cap tilts in its well (the pad picture)
## The move demo walks the four ways in turn: right, up, left, down.
const WAYS := [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]
const BEAT := 1.0              # s per push (calm: 1.4)

static var _key_sb: StyleBoxTexture
static var _key_dn: StyleBoxTexture


static func _box(path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Art.tex(path)
	sb.texture_margin_left = 5
	sb.texture_margin_right = 5
	sb.texture_margin_top = 5
	sb.texture_margin_bottom = 6
	return sb


## The push of a demo at time `t`: 0..1 out from the middle and back (glide out 0.25 s, hold, back in 0.2 s; calm:
## jump out, hold, jump back).
static func push(t: float, calm: bool) -> float:
	var beat := BEAT * (1.4 if calm else 1.0)
	var u := fmod(t, beat) / beat
	if calm:
		return 1.0 if u < 0.7 else 0.0
	if u < 0.25:
		return ease(u / 0.25, 0.4)
	if u < 0.75:
		return 1.0
	if u < 0.95:
		return 1.0 - (u - 0.75) / 0.2
	return 0.0


## Which of WAYS the move demo pushes at time `t`.
static func way(t: float, calm: bool) -> Vector2:
	var beat := BEAT * (1.4 if calm else 1.0)
	return WAYS[int(t / beat) % WAYS.size()]


## A key press beat for a single key (bomb, special): down 0.35 s of every 1.0 s (calm: 0.7 of 1.4).
static func tap_down(t: float, calm: bool) -> bool:
	var beat := BEAT * (1.4 if calm else 1.0)
	return fmod(t, beat) < (0.7 if calm else 0.35)


## A keycap with its word (W, SHIFT, RB...): ivory, or lit gold and 1 px lower while pressed. `at` is the top-left;
## returns its width.
static func key(ci: CanvasItem, at: Vector2, text: String, down: bool, min_w := 13.0) -> float:
	if _key_sb == null:
		_key_sb = _box("primer/key")
		_key_dn = _box("primer/key_down")
	var f: Font = Art.font_small
	var w := maxf(min_w, key_w(text))
	at = at.floor()
	ci.draw_style_box(_key_dn if down else _key_sb, Rect2(at, Vector2(w, KEY_H)))
	var y := at.y + (11.0 if down else 10.0)
	# engraved: ink letters with a bright edge under them (the kit's brass plates)
	ci.draw_string(f, Vector2(at.x, y + 1), text, HORIZONTAL_ALIGNMENT_CENTER, w, 8, Color("#ffcc68") if down else SHINE)
	ci.draw_string(f, Vector2(at.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, 8, INK)
	return w


## W A S D (or the arrow keys) as a cluster centred on `c`; `press` is the way being pushed (zero: none).
static func key_cross(ci: CanvasItem, c: Vector2, labels: Array, press: Vector2) -> void:
	# labels: [up, left, down, right]
	var k := 13.0
	var gap := 1.0
	var x0 := c.x - (k * 3.0 + gap * 2.0) / 2.0
	var y0 := c.y - (KEY_H * 2.0 + gap) / 2.0
	key(ci, Vector2(x0 + k + gap, y0), labels[0], press == Vector2.UP)
	key(ci, Vector2(x0, y0 + KEY_H + gap), labels[1], press == Vector2.LEFT)
	key(ci, Vector2(x0 + k + gap, y0 + KEY_H + gap), labels[2], press == Vector2.DOWN)
	key(ci, Vector2(x0 + (k + gap) * 2.0, y0 + KEY_H + gap), labels[3], press == Vector2.RIGHT)


## The arrow keys' words (the pixel font has no arrows): a small arrow is drawn in code instead, see arrow_cross.
static func arrow_cross(ci: CanvasItem, c: Vector2, press: Vector2) -> void:
	key_cross(ci, c, ["", "", "", ""], press)
	var k := 13.0
	var gap := 1.0
	var x0 := c.x - (k * 3.0 + gap * 2.0) / 2.0
	var y0 := c.y - (KEY_H * 2.0 + gap) / 2.0
	var spots := [[Vector2(x0 + k + gap, y0), Vector2.UP], [Vector2(x0, y0 + KEY_H + gap), Vector2.LEFT],
		[Vector2(x0 + k + gap, y0 + KEY_H + gap), Vector2.DOWN], [Vector2(x0 + (k + gap) * 2.0, y0 + KEY_H + gap), Vector2.RIGHT]]
	for s in spots:
		var down: bool = press == s[1]
		var mid: Vector2 = (s[0] as Vector2).floor() + Vector2(6, 6 + (1 if down else 0))
		_arrow(ci, mid, s[1], INK)


## A 5 px pixel arrow pointing `d` (one of the four ways), its tip at mid + d * 2.
static func _arrow(ci: CanvasItem, mid: Vector2, d: Vector2, col: Color) -> void:
	var side := Vector2(-d.y, d.x)
	for i in 5:   # the shaft
		var p: Vector2 = mid + d * float(i - 2)
		ci.draw_rect(Rect2(p, Vector2.ONE), col)
	for i in [1, 2]:   # the head
		var tip: Vector2 = mid + d * 2.0
		ci.draw_rect(Rect2(tip - d * float(i) + side * float(i), Vector2.ONE), col)
		ci.draw_rect(Rect2(tip - d * float(i) - side * float(i), Vector2.ONE), col)


## The touch stick as the HUD draws it, its knob pushed `knob` px, and the player's thumb on the knob.
static func touch_stick(ci: CanvasItem, c: Vector2, knob: Vector2, alpha := 1.0) -> void:
	c = c.floor()
	var base := Art.tex("ui/stick_base")
	var nub := Art.tex("ui/stick_knob")
	ci.draw_texture(base, (c - base.get_size() / 2.0).floor(), Color(1, 1, 1, 0.8 * alpha))
	var kp := (c + knob).round()
	ci.draw_texture(nub, (kp - nub.get_size() / 2.0).floor(), Color(1, 1, 1, alpha))
	thumb(ci, kp, alpha)


## The thumb, its nail over `at` (the spot it presses), the hand coming up from below.
static func thumb(ci: CanvasItem, at: Vector2, alpha := 1.0) -> void:
	var th := Art.tex("primer/thumb")
	ci.draw_texture(th, (at - Vector2(th.get_width() / 2.0, 4.0)).floor(), Color(1, 1, 1, alpha))


## The wells' middles on primer/pad.png (tools/art_primer.py PAD_STICKS) and the parts that can light up.
const PAD_STICKS := [Vector2(15, 18), Vector2(32, 18)]
const PAD_PARTS := {"LB": "lb", "RB": "rb", "LT": "lt", "RT": "rt"}
const PAD_SIZE := Vector2(48, 30)


## A gamepad centred on `c`: stick `stick` (0 left, 1 right, -1 none) lit gold and tilted `tilt` (length 0..1), and
## the bumper / trigger named `part` ("RB", "LT"...) lit when `lit`.
static func pad(ci: CanvasItem, c: Vector2, stick: int, tilt: Vector2, part := "", lit := false) -> void:
	var o := (c - PAD_SIZE / 2.0).floor()
	ci.draw_texture(Art.tex("primer/pad"), o)
	if lit and PAD_PARTS.has(part):
		ci.draw_texture(Art.tex("primer/pad_" + str(PAD_PARTS[part])), o)
	for i in 2:
		var on := i == stick
		var cp: Vector2 = o + PAD_STICKS[i] + ((tilt * PAD_REACH).round() if on else Vector2.ZERO)
		ci.draw_texture(Art.tex("primer/pad_cap_on" if on else "primer/pad_cap"), cp - Vector2(3, 3))


## The mouse with its left button held (lit) or not; `at` is its top-left.
static func mouse(ci: CanvasItem, at: Vector2, down: bool) -> void:
	ci.draw_texture(Art.tex("primer/mouse"), at.floor())
	if down:
		ci.draw_texture(Art.tex("primer/mouse_left"), at.floor())


## A ring of whole pixels round `c` (radius r), stepped like the move button's ring: gold, marching while `t` runs.
static func ring(ci: CanvasItem, c: Vector2, r: int, t: float, calm: bool, col := GOLD) -> void:
	var pts := Moves.ring_pixels(r)
	var step := 0 if calm else int(t * 10.0)
	c = c.floor()
	for i in pts.size():
		var p: Vector2 = c + pts[i]
		ci.draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), INK)
	for i in pts.size():
		var p: Vector2 = c + pts[i]
		ci.draw_rect(Rect2(p, Vector2.ONE), col if (i + step) % 4 != 0 else EMBER)


## A thumb tapping the button whose middle is `c`: it comes down on the lower half (the icon stays in sight), lifts
## 5 px, and a ring pulses at each press.
static func tap(ci: CanvasItem, c: Vector2, r: int, t: float, calm: bool) -> void:
	var down := tap_down(t, calm)
	ring(ci, c, r + (1 if down and not calm else 0), t, calm)
	thumb(ci, c + Vector2(3, 8 if down else 13))


## A button on `dev` that is not on the screen as a HUD button (the bomb on keys or a pad, the move on a pad):
## the key pressing, or the pad with that bumper / trigger lit. `c` is the middle. Returns the drawing's half width.
static func press(ci: CanvasItem, dev: String, c: Vector2, glyph: String, t: float, calm: bool) -> float:
	var down := tap_down(t, calm)
	if dev == Controls.PAD and PAD_PARTS.has(glyph):
		pad(ci, c, -1, Vector2.ZERO, glyph, down)
		var kw := key_w(glyph)
		key(ci, Vector2(c.x - kw / 2.0, c.y + PAD_SIZE.y / 2.0 + 2.0), glyph, down)
		return PAD_SIZE.x / 2.0
	var w := key_w(glyph)
	key(ci, Vector2(c.x - w / 2.0, c.y - KEY_H / 2.0), glyph, down)
	return w / 2.0


## A keycap's width for its word (as key() draws it).
static func key_w(text: String) -> float:
	var tw := Art.font_small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := maxf(13.0, ceilf(tw) + 7.0)
	if int(w) % 2 == 0 and int(ceilf(tw)) % 2 == 1:
		w += 1.0
	return w


## A frame round a rectangle (the HUD's clock + wax gauge), 2 px outside it, gold with ink, marching.
static func frame(ci: CanvasItem, r: Rect2, t: float, calm: bool) -> void:
	r = Rect2(r.position.floor() - Vector2(3, 3), r.size.ceil() + Vector2(6, 6))
	var step := 0 if calm else int(t * 12.0)
	var per := int(2.0 * (r.size.x + r.size.y))
	for i in per:
		var p := _perimeter(r, i)
		ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2.ONE), INK)
	for i in per:
		var p := _perimeter(r, i)
		ci.draw_rect(Rect2(p, Vector2.ONE), GOLD if (i + step) % 6 < 4 else EMBER)


static func _perimeter(r: Rect2, i: int) -> Vector2:
	var w := int(r.size.x)
	var h := int(r.size.y)
	if i < w:
		return r.position + Vector2(i, 0)
	i -= w
	if i < h:
		return r.position + Vector2(w - 1, i)
	i -= h
	if i < w:
		return r.position + Vector2(w - 1 - i, h - 1)
	i -= w
	return r.position + Vector2(0, h - 1 - mini(i, h - 1))


## The glyph for moving on `dev` at `c`, animated by `t`.
static func move(ci: CanvasItem, dev: String, c: Vector2, t: float, calm: bool) -> void:
	var d := way(t, calm)
	var k := push(t, calm)
	match dev:
		Controls.TOUCH:
			touch_stick(ci, c, d * STICK_REACH * k)
		Controls.PAD:
			pad(ci, c, 0, d * k)
		_:
			key_cross(ci, c, ["W", "A", "S", "D"], d if k > 0.5 else Vector2.ZERO)


## The glyph for aiming and firing on `dev` at `c`, toward `dir` (a unit vector: where the target is).
static func aim(ci: CanvasItem, dev: String, c: Vector2, dir: Vector2, t: float, calm: bool) -> void:
	var k := push(t, calm)
	var four := Vector2.RIGHT if absf(dir.x) >= absf(dir.y) and dir.x >= 0.0 else (Vector2.LEFT if absf(dir.x) >= absf(dir.y) else (Vector2.DOWN if dir.y > 0.0 else Vector2.UP))
	match dev:
		Controls.TOUCH:
			touch_stick(ci, c, dir * STICK_REACH * k)
		Controls.PAD:
			pad(ci, c, 1, dir * k)
		Controls.MOUSE:
			mouse(ci, c - Vector2(5, 8), k > 0.5)
		_:
			arrow_cross(ci, c, four if k > 0.5 else Vector2.ZERO)
