class_name TalkPortrait
extends Control
## A speaker's portrait in the talking scenes (v2.7, scripts/ui/talk.gd): a 56 x 56 brass-rimmed frame (the UI kit's
## colours), the speaker lit by a little banded pool of light inside it, drawn x2 so its pixels match the room's:
##   "me"      the candle being played, built from Tallow's own parts (Player.shape / paint_body / face sprites /
##             flame frames): an expression per line, a blink every few seconds, a 2-frame talk while the line types
##   "martha"  Martha Fenn as a memory (assets/art/talk/martha_*: sepia, a blink and a 2-frame talk)
##   <kind>    a guardian: the face part of its own frames (TalkLines.SPEAKERS "crop"), moving with its idle frames,
##             faster while it talks (the Choir and the Organist sing)
## The listener sits dimmed. Animation runs on real time, so it plays while the house is paused.

const SIZE := Vector2(56, 56)
const INNER := 48
const INK := Color("#21141b")
const BRASS := [Color("#facb3e"), Color("#ee8e2e"), Color("#c56025"), Color("#8f4029")]
## The light behind the speaker: [radius, colour], outermost first (warm), and Martha's sepia.
const POOL := [[34.0, Color("#140c11")], [24.0, Color("#23151d")], [17.0, Color("#38262d")], [11.0, Color("#483b3a")]]
const POOL_MEMORY := [[34.0, Color("#23151d")], [24.0, Color("#38262d")], [17.0, Color("#483b3a")], [11.0, Color("#775c55")]]
## Each expression: [mouth shut, mouth open, blink] (hero/face_* sprites), the flame and the arms.
const FACES := {
	"open": ["open", "open_talk", "blink", "idle", ["rest", "rest"]],
	"brave": ["brave", "shout", "blink", "flare", ["rest", "fwd"]],
	"worried": ["worried", "worried_talk", "blink_worried", "mid", ["low", "low"]],
	"teary": ["teary", "teary_talk", "blink_teary", "small", ["low", "low"]],
	"happy": ["happy", "happy_talk", "blink", "flare", ["cheer", "cheer"]],
	"tired": ["tired", "tired_talk", "blink_tired", "small", ["low", "low"]],
	"shout": ["shout", "brave", "blink", "flare", ["flail", "flail"]],
}

var who := "me"
var candle := "tallow"
var face := "open"
var talking := false
var lit := true
var unlit_flame := false   # the opening: a candle not lit yet
var _blink_left := 0.0
var _blink_in := 2.4
var _mouth := false
var _mouth_t := 0.0
var _anim_t := 0.0
var _flame_t := 0.0
var _bob := 0.0
var _art: Control


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = Control.new()
	_art.position = Vector2(4, 4)
	_art.size = Vector2(INNER, INNER)
	_art.clip_contents = true
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	add_child(_art)
	_blink_in = randf_range(1.6, 3.4)


## Who sits in the frame now (a fade-free swap: the talk box swaps the right-hand speaker for Martha's memory).
func show_speaker(w: String, f := "open") -> void:
	who = w
	face = f if f != "" else "open"
	_anim_t = 0.0
	queue_redraw()
	_art.queue_redraw()


## Called by the talk box with real seconds (it runs while the house is paused).
func step(dt: float) -> void:
	_flame_t += dt
	_anim_t += dt * (2.0 if talking else 1.0)
	if _blink_left > 0.0:
		_blink_left -= dt
	else:
		_blink_in -= dt
		if _blink_in <= 0.0:
			_blink_left = 0.13
			_blink_in = randf_range(2.0, 4.2)
	if talking:
		_mouth_t -= dt
		if _mouth_t <= 0.0:
			_mouth = not _mouth
			_mouth_t = 0.11 if _mouth else 0.09
	else:
		_mouth = false
	_bob = 1.0 if talking and _mouth else 0.0
	_art.modulate = Color.WHITE if lit else Color(0.5, 0.46, 0.5)
	_art.queue_redraw()


func _draw() -> void:
	# the rim: ink, a 2 px brass band lit from the top left, ink again, then the dark well
	draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
	draw_rect(Rect2(1, 1, 54, 54), BRASS[3])
	draw_rect(Rect2(1, 1, 54, 1), BRASS[0])
	draw_rect(Rect2(1, 1, 1, 54), BRASS[0])
	draw_rect(Rect2(2, 2, 52, 1), BRASS[1])
	draw_rect(Rect2(2, 2, 1, 52), BRASS[1])
	draw_rect(Rect2(54, 2, 1, 53), BRASS[2])
	draw_rect(Rect2(2, 54, 53, 1), BRASS[2])
	draw_rect(Rect2(3, 3, 50, 50), INK)
	# brass rivets in the corners
	for p in [Vector2(1, 1), Vector2(53, 1), Vector2(1, 53), Vector2(53, 53)]:
		draw_rect(Rect2(p, Vector2(2, 2)), BRASS[0])
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), BRASS[2])


func _draw_art() -> void:
	var ci := _art
	var pool: Array = POOL_MEMORY if who == "martha" else POOL
	ci.draw_rect(Rect2(0, 0, INNER, INNER), (pool[0][1] as Color))
	# a banded pool of light behind the speaker (whole pixels, no gradient), centred a little low
	var c := Vector2(24, 30)
	for band in pool.slice(1):
		var r: float = band[0]
		for y in INNER:
			var dy := absf(y + 0.5 - c.y)
			if dy > r:
				continue
			var hw := floorf(sqrt(r * r - dy * dy))
			ci.draw_rect(Rect2(c.x - hw, y, hw * 2.0, 1), band[1])
	if who == "me":
		_draw_candle(ci)
	elif who == "martha":
		var k := "f1" if _mouth else ("blink" if _blink_left > 0.0 else ("smile" if face == "smile" else "f0"))
		var tex := Art.tex("talk/martha_" + k)
		if tex:
			ci.draw_texture_rect(tex, Rect2(0, 0, INNER, INNER), false)
	else:
		_draw_guardian(ci)


## The candle, x2: Tallow's own body code with this line's face, flame and arms (bobbing a pixel as it talks).
func _draw_candle(ci: CanvasItem) -> void:
	var d: Dictionary = Candles.def_of(candle)
	var cs: Array = d["colours"]
	var c := {"ol": Player.OUTLINE, "hi": Color(cs[0]), "wax": Color(cs[1]), "sh": Color(cs[2]), "deep": Color(cs[3]),
		"cheek": Color(d.get("cheek", "#f78697")), "foil": Color("#b6cbcf"), "foil_sh": Color("#7b8994")}
	var fx: Array = FACES.get(face, FACES["open"])
	var two := int(d.get("shots", 1)) > 1
	var g := Player.shape(Player.rows_for(float(d["wax"])), 0, int(d["body_w"]) / 2, 0, 0,
		d.get("straight", false), d.get("foil", false), two)
	# 24 x 24 at x2, a bust: the cheeks on row 18 (the face, the arms and the flame above it show; the dish does not)
	var o := Vector2(12, 15 - int(g["fy"]) + _bob)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	Player.paint_body(ci, o, g, c, d.get("stripes", false))
	Player.paint_cheeks(ci, o, g, c["cheek"])
	var fname: String = fx[2] if _blink_left > 0.0 else (fx[1] if _mouth else fx[0])
	var ftex := Player.face_tex(fname, Color(d.get("ink", "#21141b")))
	if ftex:
		ci.draw_texture(ftex, o + Vector2(int(g["cx"]) - 5, int(g["fy"])))
	Player.paint_arms(ci, o, g, c, fx[4])
	Player.paint_wick(ci, o, g, Player.OUTLINE)
	if not unlit_flame:
		var sf := Player.flame_frames(false)
		var kind: String = fx[3]
		var n := sf.get_frame_count(kind)
		var fr := int(_flame_t * float(Player.FLAME_KINDS.get(kind, 8.0))) % maxi(1, n)
		for k in (2 if two else 1):
			var ft: Texture2D = sf.get_frame_texture(kind if k == 0 else "mid", (fr + k) % maxi(1, sf.get_frame_count(kind if k == 0 else "mid")))
			var t2: Vector2i = g["tip"] if k == 0 else g["tip2"]
			ci.draw_texture(ft, o + Vector2(t2) + Player.FLAME_OFS)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A guardian: the face part of its frame, x2 (it breathes with its idle frames; it talks with them faster, or sings).
func _draw_guardian(ci: CanvasItem) -> void:
	var d: Dictionary = Enemy.DEFS.get(who, {})
	var sp: Dictionary = TalkLines.SPEAKERS.get(who, {})
	var sf := Enemy.frames_for(str(d.get("sprite", who)))
	if sf == null:
		return
	var anim := "idle" if sf.has_animation("idle") else "default"
	var talk_anim := str(sp.get("talk", ""))
	if talking and talk_anim != "" and sf.has_animation(talk_anim):
		anim = talk_anim
	var n := sf.get_frame_count(anim)
	if n <= 0:
		return
	var fps := sf.get_animation_speed(anim)
	var tex := sf.get_frame_texture(anim, int(_anim_t * fps) % n)
	var crop: Array = sp.get("crop", [0, 0])
	var src := Rect2(float(crop[0]), float(crop[1]), 24, 24)
	ci.draw_texture_rect_region(tex, Rect2(0, 0, INNER, INNER), src, d.get("tint", Color.WHITE))
