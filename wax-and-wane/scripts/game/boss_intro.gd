class_name BossIntro
extends Node2D
## Guardian entrances (v2.4, docs/streams/v24_boss_intros.md). Where a guardian fight starts (world._start_boss,
## right after the guardian is spawned: `BossIntro.play(world, boss)`), each of the 16 guardians makes a short
## entrance (1.4-2.0 s) that suits it, built from its own frames (idle / run / atk and its specials: mound, rise,
## sing, grab) and the juice (shake, dust, sparks, smoke, stains, small lights). While it plays:
##  - the guardian is harmless and cannot be hit: `Enemy.intro` holds its AI, its touch and every hit, and it
##    stays `active = false` (shots fly through it, aim assist and the moves leave it alone);
##  - Tallow can move; any tap, key, click or pad button, or his first shot, skips the rest at once;
##  - randomness is visual only (randf), every shake goes through world.shake (the Screen shake setting), and
##    nothing is drawn above the HUD (the effects live in the room, under the HUD's layer).
## When it ends (or is skipped) the guardian stands exactly where and how its fight expects it (its sprite,
## colour and lights, the Pendulum at rest, the Organist's pipes dark) and its AI starts.

## How long each guardian's entrance runs (s).
const LEN := {
	"big_zombie": 1.5, "wax_mother": 1.6, "furnace": 1.6,
	"ogre": 1.4, "sexton": 1.6, "ossuary": 1.8,
	"necro_boss": 1.8, "choir": 1.7, "organist": 1.9,
	"pendulum": 1.9, "big_demon": 1.4, "weathercock": 1.6,
	"stockpot": 1.7, "librarian": 1.6, "dress_form": 1.6, "keeper": 2.0,
}
const DEFAULT_LEN := 1.4
## A press this early is still the versus card's skip arriving: it does not skip the entrance too.
const SKIP_AFTER := 0.12

const CREAM := Color("#fdf7ed")
const GOLD := Color("#facb3e")
const ORANGE := Color("#ee8e2e")
const RED := Color("#da4e38")
const PALE := Color("#cae6f5")
const BLUE := Color("#5698cc")
const VIOLET := Color("#5956bd")
const BONE_C := [Color("#fdf7ed"), Color("#d3bfa9"), Color("#483b3a")]
const WAX_C := [Color("#f78697"), Color("#dc4a7b"), Color("#9f294e"), Color("#62232f")]
## The Melted Choir's three voices in its 48 px frames: [first column, width].
const VOICES := [[0, 16], [16, 16], [32, 16]]
## The Keeper's clock face: its centre from the Keeper's feet, and its radius.
const FACE_C := Vector2(0, -30)
const FACE_R := 24.0

## The entrance playing now (tours and tests read it).
static var live: BossIntro = null

var w: Node
var e: Enemy
var kind := ""
var t := 0.0
var dur := DEFAULT_LEN
var home := Vector2.ZERO          # where its fight starts (room-local, its feet)
var side := 1.0                   # +1: Tallow stands to its right
var glow: CreatureGlow
var _done := false
var _skipped := false
var _fired := {}
var _over: Node2D                 # what is drawn in front of the guardian
var _light: PointLight2D          # a short-lived light some entrances carry
var _bits: Array = []             # drawn bits: bones, skulls, wind, bubbles
var _voices: Array = []           # the Melted Choir's voices (temporary sprites)
var _start := Vector2.ZERO        # where a walking / rolling entrance begins (room-local)
var _spin := 0.0
var _last_dir := 0.0


## Hook (world._start_boss): give the guardian just spawned its entrance.
static func play(world: Node, en: Enemy) -> BossIntro:
	if world == null or en == null or not is_instance_valid(en) or not en.boss or not en.alive or en.get_parent() == null:
		return null
	var b := BossIntro.new()
	b.w = world
	b.e = en
	b.kind = en.kind
	b.dur = float(LEN.get(en.kind, DEFAULT_LEN))
	en.get_parent().add_child(b)
	return b


func _ready() -> void:
	live = self
	name = "BossIntro"
	home = e.position
	position = home.round()
	z_index = -1   # under the guardian (rings, puddles and glows on the floor and behind it)
	_over = Node2D.new()
	_over.z_index = 5
	_over.draw.connect(_draw_over)
	add_child(_over)
	if e.spawn_tw and e.spawn_tw.is_valid():
		e.spawn_tw.kill()   # the plain fade-in; this entrance takes its place
	e.intro = true
	e.active = false
	e.spr.modulate.a = 1.0
	glow = e.get_node_or_null("CreatureGlow") as CreatureGlow
	var p: Node2D = w.get("player")
	side = 1.0 if p == null or p.global_position.x >= e.global_position.x else -1.0
	if not e.def.get("no_flip", false):
		e.spr.flip_h = side < 0.0
	_begin()
	_step(0.0)


func _input(ev: InputEvent) -> void:
	if _done or t < SKIP_AFTER:
		return
	if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) \
			or (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventJoypadButton and ev.pressed):
		skip()


## Ends the entrance now: the guardian stands ready (a white flash) and its fight starts.
func skip() -> void:
	_skipped = true
	_finish()


func _process(dt: float) -> void:
	if _done:
		return
	if e == null or not is_instance_valid(e) or not e.alive or w == null or not is_instance_valid(w):
		_done = true
		if live == self:
			live = null
		queue_free()
		return
	var p: Node = w.get("player")
	if t >= SKIP_AFTER and p != null and (p.aim_input as Vector2).length() > 0.3:
		skip()   # his first shot
		return
	t += dt
	e.active = false   # nothing wakes it early (a bomb sets `active` on whatever it hits)
	if t >= dur:
		_finish()
		return
	_step(dt)
	queue_redraw()
	_over.queue_redraw()
	if glow:
		glow.queue_redraw()   # the rim follows the sprite's scale and turn too


func _finish() -> void:
	if _done:
		return
	_done = true
	if live == self:
		live = null
	if w.get("main") and w.main.autotest:
		print("[intro] %s %s at %.2f s of %.1f" % [kind, "skipped" if _skipped else "played", t, dur])
	if is_instance_valid(e) and e.alive:
		_rest()
		if not Talk.meet(w, e, _skipped):   # v2.7: a first meeting's words first (the scene starts the fight when it ends)
			e.intro = false
			e.active = true
			if _skipped:
				e._telegraph(Color(1, 1, 1))
	queue_free()


## Everything the entrance touched, back to the guardian's own.
func _rest() -> void:
	var s := e.spr
	e.position = home
	e.modulate = Color.WHITE
	s.visible = true
	s.position = Vector2.ZERO
	s.scale = Vector2.ONE
	s.rotation = 0.0
	s.modulate.a = 1.0
	s.speed_scale = 1.0
	if s.sprite_frames.has_animation("idle"):
		s.play("idle")
	e._anim_lock = 0.0
	e._flash = 0.0
	e.mat.set_shader_parameter("tint", Color(1, 1, 1))
	e.mat.set_shader_parameter("flash", 0.0)
	if e.shadow:
		e.shadow.position = Vector2(0, -1)
		e.shadow.scale = Vector2.ONE
		e.shadow.visible = true
	_glow_k(1.0)
	_rim(true)
	_pool(1.0)
	for v in _voices:
		if is_instance_valid(v):
			v.queue_free()
	_voices.clear()
	if kind == "pendulum":
		_pend(0.0, BossAI.PEND_LEN)
	elif kind == "organist":
		e.mem["lit"] = {}
	if glow:
		glow.queue_redraw()


# ---------------------------------------------------------------- helpers

func _k(a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _inout(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Overshoot, then settle at 1.
static func _back(x: float) -> float:
	var c := 1.7
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


## True once: the first frame the entrance passes `at` seconds.
func _at(id: String, at: float) -> bool:
	if t < at or _fired.has(id):
		return false
	_fired[id] = true
	return true


## A point on the guardian's body (offset from its feet as the art is drawn, mirrored with the sprite), in the world.
func _g(off: Vector2) -> Vector2:
	return e.global_position + e.spr.position + Vector2(off.x * (-1.0 if e.spr.flip_h else 1.0), off.y)


## A point near its starting spot, in the world.
func _hg(off := Vector2.ZERO) -> Vector2:
	return global_position + off


func _j() -> Juice:
	return Juice.of(w)


func _tint(rgb: float, a := 1.0) -> void:
	e.modulate = Color(rgb, rgb, rgb, a)


## How brightly its own lights shine (eyes, coals, the lantern): 1 = as in the fight.
func _glow_k(v: float) -> void:
	if glow and glow.material:
		(glow.material as ShaderMaterial).set_shader_parameter("glow", v)


func _rim(on: bool) -> void:
	if glow and glow.material:
		(glow.material as ShaderMaterial).set_shader_parameter("rim_col", CreatureGlow.RIM_BOSS if on else Color(0, 0, 0, 0))


## Its pale light pool, 0..1 of the fight's.
func _pool(v: float) -> void:
	if glow and glow.pool:
		glow.pool.energy = CreatureGlow.POOL_ENERGY * v


## Holds the hit-flash shader at `v` towards colour `c` (a hot or pale silhouette).
func _hold_flash(c: Color, v: float) -> void:
	e._flash = v
	e.mat.set_shader_parameter("tint", c)
	e.mat.set_shader_parameter("flash", v)


func _shake(a: float) -> void:
	w.shake(a)


func _show(anim: String, frame: int) -> void:
	var s := e.spr
	if not s.sprite_frames.has_animation(anim):
		return
	if s.animation != anim:
		s.animation = anim
	if s.is_playing():
		s.pause()
	s.frame = clampi(frame, 0, s.sprite_frames.get_frame_count(anim) - 1)


func _loop(anim: String, speed := 1.0) -> void:
	var s := e.spr
	if not s.sprite_frames.has_animation(anim):
		return
	if s.animation != anim or not s.is_playing():
		s.play(anim)
	s.speed_scale = speed


## A short-lived light at `off` from its starting spot.
func _lamp(off: Vector2, col: Color, sc: float) -> PointLight2D:
	if _light == null:
		_light = PointLight2D.new()
		_light.texture = Art.light_tex
		add_child(_light)
	_light.position = off
	_light.color = col
	_light.texture_scale = sc
	_light.energy = 0.0
	return _light


## A spot `back` px behind its own (up the screen), or nearer if something stands there.
func _behind(back: float) -> Vector2:
	for d in [back, back * 0.6, 0.0]:
		if not w.room.blocked(e.global_position + Vector2(0, -d), e.radius):
			return home + Vector2(0, -d)
	return home


# ---------------------------------------------------------------- per guardian

func _begin() -> void:
	match kind:
		"wax_mother", "ossuary":           # a puddle, bones: lit like the floor they lie on
			material = Lighting.lit_material()
		"big_demon", "keeper":             # hellfire, a clock face of light: they glow
			material = Art.unshaded
			_over.material = Art.unshaded
		"weathercock":
			_over.material = Art.unshaded
		"stockpot":
			_over.material = Lighting.lit_material()
	match kind:
		"big_zombie":
			_start = _behind(16.0)
			_tint(0.0, 0.0)
			_pool(0.0)
			_rim(false)
		"ogre":
			_start = _behind(12.0)
			_tint(0.15, 0.0)
			_pool(0.0)
		"librarian":
			_start = _behind(14.0)
			_tint(0.0, 0.0)
			_rim(false)
			_glow_k(0.0)
			_pool(0.0)
		"necro_boss":
			_tint(0.0, 1.0)
			_rim(false)
			_glow_k(0.0)
			_pool(0.0)
			_lamp(Vector2(-10.0 if e.spr.flip_h else 10.0, -10), Color(0.45, 0.85, 0.82), 0.4)
		"furnace":
			_tint(0.32, 0.0)
			_glow_k(0.0)
		"ossuary":
			_glow_k(0.0)
			for i in 8:
				var a := randf() * TAU
				_bits.append({"p": Vector2(cos(a) * randf_range(20, 36), sin(a) * randf_range(10, 18) - 2.0),
					"t0": randf_range(0.1, 0.3), "t1": randf_range(0.6, 0.85), "up": i % 2 == 0})
			for sgn in [-1.0, 1.0]:
				_bits.append({"skull": true, "x": sgn * 46.0, "t0": 0.25 if sgn < 0 else 0.35, "t1": 0.85})
		"weathercock":
			for i in 12:
				_bits.append({"p": Vector2(-side * randf_range(30, 170), randf_range(-66, -2)), "n": randi_range(4, 9),
					"v": randf_range(160, 240)})
		"choir":
			e.spr.visible = false
			for i in 3:
				var v := Sprite2D.new()
				v.centered = false
				v.region_enabled = true
				v.material = e.mat
				v.visible = false
				e.add_child(v)
				_voices.append(v)
		"keeper":
			_lamp(FACE_C, Color(0.72, 0.8, 1.0), 0.75)
			_tint(1.0, 0.0)
		"big_demon":
			_lamp(Vector2(0, -8), Color(1.0, 0.55, 0.3), 0.65)
			_tint(1.0, 0.0)
			for i in 16:
				_bits.append({"a": TAU * i / 16.0 + randf_range(-0.1, 0.1), "ph": randf() * TAU})
		"stockpot":
			for i in 6:
				_bits.append({"x": randf_range(-12, 12), "ph": randf(), "sp": randf_range(2.2, 3.4)})
		"dress_form":
			var r: Rect2 = w.room.inner_rect()
			var lo: float = r.position.x - w.room.position.x + 16.0
			var hi: float = r.end.x - w.room.position.x - 16.0
			_start = Vector2(clampf(home.x - side * 58.0, lo, hi), home.y)
			_tint(1.0, 0.0)
		"wax_mother", "sexton", "organist", "pendulum":
			_tint(1.0, 0.0)


func _step(dt: float) -> void:
	match kind:
		"big_zombie": _x_rot()
		"wax_mother": _x_mother()
		"furnace": _x_furnace()
		"ogre": _x_gaoler()
		"sexton": _x_sexton()
		"ossuary": _x_ossuary()
		"necro_boss": _x_warden()
		"choir": _x_choir()
		"organist": _x_organist()
		"pendulum": _x_pendulum()
		"big_demon": _x_fiend()
		"weathercock": _x_cock(dt)
		"stockpot": _x_stockpot()
		"librarian": _x_librarian()
		"dress_form": _x_form()
		"keeper": _x_keeper()
		_: _tint(1.0, _k(0.0, 0.4))


# ---- OLD ROT: a dark shape at the back of the room lurches forward into the light, two heavy steps, a groan
func _x_rot() -> void:
	var lit := _inout(_k(0.45, 1.2))
	_tint(lit, _out(_k(0.0, 0.35)))
	_pool(lit)
	_rim(t > 0.8)
	var s1 := _out(_k(0.35, 0.62))
	var s2 := _out(_k(0.8, 1.07))
	e.position = _start.lerp(home, 0.5 * s1 + 0.5 * s2)
	e.spr.rotation = sin(PI * _k(0.35, 0.62)) * 0.12 - sin(PI * _k(0.8, 1.07)) * 0.12
	var sq := sin(PI * _k(1.12, 1.4)) * 0.08
	e.spr.scale = Vector2(1.0 + sq, 1.0 - sq)
	if t < 1.1:
		_loop("run", 0.7)
	else:
		_loop("idle")
	if _at("wisps", 0.0):
		_j().lit.burst(e.global_position + Vector2(0, -10), 8, 4.0, 14.0, Vector2.UP, 0.9, 1.0, FxParts.SMOKE, -12.0, 1.0, 2)
	for st in [["s1", 0.62], ["s2", 1.07]]:
		if _at(st[0], st[1]):
			Audio.play("thud_heavy", -6.0, 0.05, 0.8)
			_j().lit.burst(e.global_position + Vector2(0, -1), 6, 12.0, 35.0, Vector2.ZERO, PI, 0.45, FxParts.DUST, -10.0, 3.0, 1)
			_shake(1.5)
	if _at("groan", 1.12):
		Audio.play("boss_roar", -8.0, 0.0, 0.75)
		_shake(2.0)


# ---- THE WAX MOTHER: a puddle of wax spreads, bubbles, and she oozes up out of it
func _x_mother() -> void:
	_tint(1.0, _k(0.0, 0.15))
	var sx: float
	var sy: float
	if t < 1.05:
		var up := _out(_k(0.3, 1.05))
		sx = lerpf(1.5, 0.88, up)
		sy = lerpf(0.06, 1.18, up)
	else:
		var q := t - 1.05
		var wob := exp(-6.0 * q) * cos(q * 18.0)
		sx = 1.0 - 0.12 * wob
		sy = 1.0 + 0.18 * wob
	e.spr.scale = Vector2(sx, sy)
	e.shadow.scale = Vector2(minf(1.0, sx * _k(0.2, 0.5)), 1.0)
	for b in [["b0", 0.05, 0.8], ["b1", 0.3, 1.0], ["b2", 0.55, 1.2]]:
		if _at(b[0], b[1]):
			Audio.play("wax_bubble", -2.0, 0.05, b[2])
	for d in [["d0", 0.55], ["d1", 0.8], ["d2", 1.0]]:
		if _at(d[0], d[1]):
			for k in 2:
				w.fx_drop(_g(Vector2(randf_range(-12, 12), -26.0 * sy)), Vector2(randf_range(-45, 45), randf_range(-30, -10)))
	if _at("up", 1.05):
		Audio.play("splat", -2.0, 0.05, 0.7)
		w.fx_stain(e.global_position, Stains.material_of(kind), true)   # what is left of the puddle stays on the floor
		_shake(1.5)


# ---- THE COAL FURNACE: a cold stove rumbles and smokes, the coals wake, then its door bursts open in sparks
func _x_furnace() -> void:
	var warm := lerpf(0.3, 0.55, _k(0.35, 0.9)) if t < 0.95 else lerpf(0.55, 1.0, _k(0.95, 1.15))
	_tint(warm, _k(0.0, 0.25))
	_glow_k(lerpf(0.0, 0.35, _k(0.45, 0.9)) if t < 0.95 else 1.0)   # the coals wake, then blaze
	if t < 0.95:
		_show("idle", 0)
		e.spr.position.x = (1.0 if int(t * 28.0) % 2 == 0 else -1.0) if t > 0.4 else 0.0
	elif t < 1.4:
		e.spr.position.x = 0.0
		_show("atk", 0 if t < 1.05 else 1)
	else:
		_loop("idle")
	if _at("crackle", 0.3):
		Audio.play("fire_crackle", -6.0)
	for s in [["m0", 0.35], ["m1", 0.6], ["m2", 0.82]]:
		if _at(s[0], s[1]):
			w.fx_smoke(_g(GuardiansV21.F_PIPE))
			Audio.play("thud_heavy", -14.0, 0.05, 0.6)
	var mouth := _g(GuardiansV21.F_MOUTH)
	if _at("burst", 0.95):
		var to: Vector2 = w.player.global_position - mouth
		var d := (to.normalized() + Vector2(0, 1)).normalized()
		_j().hot.burst(mouth, 24, 50.0, 140.0, d, 0.6, 0.45, FxParts.SPARK, 70.0, 1.0, 1, true)
		_j().hot.burst(mouth, 10, 20.0, 50.0, Vector2.UP, 0.8, 0.9, FxParts.EMBER, -30.0, 0.5, 1)
		w.fx_smoke(_g(GuardiansV21.F_PIPE))
		Audio.play("door_burst", 0.0, 0.05, 0.9)
		Audio.play("burn_whoosh", -2.0, 0.05, 0.8)
		_shake(4.0)
		_lamp(mouth - global_position, Color(1.0, 0.62, 0.32), 0.8).energy = 1.4
	if t > 0.95 and t < 1.4 and randf() < 0.5:
		_j().hot.emit(mouth + Vector2(randf_range(-4, 4), 0), Vector2(randf_range(-25, 25), randf_range(-45, -15)), 0.4, FxParts.EMBER, 30.0, 0.0, 1)
	if _light:
		_light.energy = maxf(0.0, _light.energy - 0.05)


# ---- THE GAOLER: it tramps out of the dark, rears up and stamps; dust flies and its keys rattle
func _x_gaoler() -> void:
	var lit := _inout(_k(0.0, 0.75))
	_tint(lerpf(0.15, 1.0, lit), _k(0.0, 0.25))
	_pool(lit)
	e.position = _start.lerp(home, 0.8 * _k(0.0, 0.55) + 0.2 * _k(0.55, 0.85))
	if t < 0.55:
		_loop("run", 0.8)
		e.spr.scale = Vector2.ONE
	elif t < 0.85:
		_show("idle", 0)
		var up := _out(_k(0.55, 0.78)) * (1.0 - _k(0.78, 0.85))
		e.spr.position.y = round(-7.0 * up)
		e.spr.scale = Vector2(1.0 - 0.1 * up, 1.0 + 0.12 * up)
	else:
		var sq := 1.0 - _out(_k(0.85, 1.1))
		e.spr.position.y = 0.0
		e.spr.scale = Vector2(1.0 + 0.25 * sq, 1.0 - 0.2 * sq)
		_loop("idle")
	for s in [["f0", 0.22], ["f1", 0.48]]:
		if _at(s[0], s[1]):
			Audio.play("thud_heavy", -10.0, 0.05, 1.0)
			_j().lit.burst(e.global_position, 3, 8.0, 20.0, Vector2.ZERO, PI, 0.35, FxParts.DUST, -8.0, 3.0, 1)
	if _at("stomp", 0.85):
		Audio.play("thud_heavy", 0.0, 0.05, 0.7)
		Audio.play("explosion", -10.0, 0.05, 0.6)
		Audio.play("bell_small", -12.0, 0.1, 2.2)   # the keys on its belt
		for i in 18:   # dust kicked out along the floor all round its feet
			var a := TAU * i / 18.0 + randf_range(-0.1, 0.1)
			var d := Vector2(cos(a), sin(a) * 0.45)
			_j().lit.emit(e.global_position + d * 6.0 + Vector2(0, -1), d * randf_range(45.0, 75.0), randf_range(0.35, 0.55), FxParts.DUST, -6.0, 4.0, 2)
		_j().lit.burst(e.global_position + Vector2(0, -2), 8, 10.0, 30.0, Vector2.UP, 1.0, 0.6, FxParts.DUST, -15.0, 2.0, 2)
		_shake(4.0)


# ---- THE SEXTON: the floor heaves (a mound, his spade in it), dirt flies, and he bursts up out of the grave
func _x_sexton() -> void:
	_tint(1.0, _k(0.0, 0.2))
	if t < 0.95:
		_loop("mound")
		e.spr.position.x = (1.0 if int(t * 22.0) % 2 == 0 else -1.0) if t > 0.3 else 0.0
		for i in 4:
			if _at("d%d" % i, 0.3 + 0.16 * i):
				w.fx_debris(e.global_position + Vector2(randf_range(-6, 6), -2), "R")
				Audio.play("thud_heavy", -12.0, 0.1, 1.3)
	elif t < 1.3:
		_show("atk", 1)
		var hop := sin(PI * _k(0.95, 1.3)) * 10.0
		e.spr.position = Vector2(0, round(-hop))
		e.shadow.scale = Vector2.ONE * (1.0 - hop / 25.0)
	else:
		e.spr.position = Vector2.ZERO
		e.shadow.scale = Vector2.ONE
		var sq := sin(PI * _k(1.3, 1.5)) * 0.15
		e.spr.scale = Vector2(1.0 + sq, 1.0 - sq)
		_loop("idle")
	if _at("up", 0.95):
		for k in 4:
			w.fx_debris(e.global_position + Vector2(randf_range(-10, 10), 0), "R")
		_j().lit.burst(e.global_position, 12, 20.0, 60.0, Vector2.UP, 1.2, 0.5, FxParts.DUST, 60.0, 1.0, 2)
		Audio.play("explosion", -8.0, 0.05, 0.7)
		_shake(3.0)
	if _at("land", 1.3):
		Audio.play("thud_heavy", -4.0, 0.05, 0.9)


# ---- THE OSSUARY: scattered bones and two skulls roll and hop into a heap, it rattles, rises, and its eyes light
func _x_ossuary() -> void:
	_tint(1.0, _k(0.0, 0.2))
	if t < 0.85:
		_show("mound", 0)
	elif t < 0.95:
		_show("mound", 1)
	elif t < 1.35:
		_show("rise", int((t - 0.95) / 0.12))
	else:
		_loop("idle")
	var eyes := 0.0
	if t >= 1.35:
		eyes = 1.0 if t > 1.5 or int(t * 30.0) % 3 != 0 else 0.3
	_glow_k(eyes)
	for i in 7:
		if _at("r%d" % i, 0.15 + 0.11 * i):
			Audio.play("hit_wall", -12.0, 0.2, 2.2)
	if _at("heap", 0.85):
		Audio.play("hit_wall", -6.0, 0.1, 1.6)
		_shake(1.5)
	if _at("rise", 0.95):
		Audio.play("summon", -8.0, 0.05, 0.8)
	if _at("stand", 1.3):
		Audio.play("thud_heavy", -6.0, 0.05, 0.9)
		_j().lit.burst(e.global_position, 8, 12.0, 35.0, Vector2.ZERO, PI, 0.45, FxParts.DUST, -10.0, 3.0, 1)
	if _at("eyes", 1.38):
		_j().hot.burst(_g(GuardiansV21.O_SKULL), 6, 10.0, 28.0, Vector2.ZERO, PI, 0.4, FxParts.BLUE, 0.0, 2.0, 1)


# ---- THE HOLLOW WARDEN: in the dark its lantern catches and its eyes open; then the rest of it is there
func _x_warden() -> void:
	var g := 0.0
	if t >= 0.12:
		g = 1.0
		if (t > 0.16 and t < 0.24) or (t > 0.31 and t < 0.35):
			g = 0.3   # the flame catches
	_glow_k(g)
	var body := _inout(_k(0.7, 1.35))
	_tint(body, 1.0)
	_pool(body)
	_rim(t > 1.0)
	if _light:
		_light.energy = 0.8 * g * (1.0 - _k(1.3, 1.75)) * (0.9 + 0.1 * sin(t * 37.0))
	if _at("match", 0.1):
		Audio.play("match_strike", -2.0, 0.05, 0.9)
	if _at("flame", 0.3):
		Audio.play("fire_crackle", -12.0)
		_j().hot.burst(_g(Vector2(10, -10)), 4, 6.0, 16.0, Vector2.UP, 0.6, 0.35, FxParts.BLUE, -10.0, 1.0, 1)
	if _at("body", 0.7):
		Audio.play("summon", -8.0, 0.05, 1.0)


# ---- THE MELTED CHOIR: three voices rise out of their wax one after another (a rising third), then sing as one
func _x_choir() -> void:
	var sf := e.spr.sprite_frames
	var tex := sf.get_frame_texture("idle", int(t * 7.0) % sf.get_frame_count("idle"))
	var risen := 0.0
	for i in 3:
		var v: Sprite2D = _voices[i]
		var st := 0.1 + 0.3 * i
		var k := _k(st, st + 0.42)
		v.visible = k > 0.0 and t < 1.15
		v.texture = tex
		v.region_rect = Rect2(VOICES[i][0], 0, VOICES[i][1], tex.get_height())
		v.offset = Vector2(-tex.get_width() / 2.0 + VOICES[i][0], -tex.get_height())
		v.scale = Vector2(lerpf(1.3, 1.0, _out(k)), _back(k))
		risen += _out(k) / 3.0
		if _at("v%d" % i, st):
			Audio.play("bell_small", -9.0, 0.0, [0.84, 1.0, 1.26][i])
			Audio.play("wax_bubble", -8.0, 0.1)
			_j().lit.burst(_g(Vector2(VOICES[i][0] + 8 - 24, -2)), 4, 10.0, 30.0, Vector2.UP, 1.0, 0.4, FxParts.WAX, 120.0, 0.0, 1)
	e.shadow.scale = Vector2(maxf(0.05, risen), 1.0)
	if t >= 1.15:
		e.spr.visible = true
		if t < 1.6:
			_show("sing", int((t - 1.15) / 0.11))
		else:
			_loop("idle")
	if _at("chord", 1.15):
		for p in [0.84, 1.0, 1.26]:
			Audio.play("bell_small", -10.0, 0.0, p)
		Lighting.shockwave(w, _g(Vector2(0, -20)), 36.0, 1.5)
		_shake(2.0)


# ---- THE ORGANIST: a dark organ; its pipes light one by one on a rising scale, then it plays a chord
func _x_organist() -> void:
	_tint(lerpf(0.3, 1.0, _k(0.3, 1.15)), _k(0.0, 0.3))
	var lit: Dictionary = e.mem.get("lit", {})
	for i in 7:
		if _at("p%d" % i, 0.3 + 0.12 * i):
			lit[i] = maxf(0.2, 1.75 - t)
			e.mem["lit"] = lit
			Audio.play("bell_small", -10.0, 0.0, 0.7 + 0.12 * i)
			_j().hot.burst(_g(Vector2(GuardiansV21.PIPES_X[i], GuardiansV21.PIPE_Y - 3)), 3, 8.0, 22.0, Vector2.UP, 0.5, 0.35, FxParts.GOLD, -10.0, 1.0, 1)
	if t >= 1.2:
		if t < 1.65:
			_show("sing", 0 if t < 1.32 else 1)
		else:
			_loop("idle")
	if _at("chord", 1.2):
		for p in [0.7, 0.88, 1.05]:
			Audio.play("bell_small", -9.0, 0.0, p)
		Audio.play("bell_toll", -10.0, 0.05, 1.2)
		Lighting.shockwave(w, _g(Vector2(0, -26)), 44.0, 1.5)
		_shake(2.5)
		for i in 7:
			_j().hot.burst(_g(Vector2(GuardiansV21.PIPES_X[i], GuardiansV21.PIPE_Y - 3)), 2, 15.0, 35.0, Vector2.UP, 0.4, 0.5, FxParts.GOLD, -20.0, 1.0, 1)


# ---- THE GREAT PENDULUM: it drops out of the dark on a short rod that runs out to full length, swings, settles
func _x_pendulum() -> void:
	_tint(1.0, _k(0.0, 0.25))
	var damp := 1.0 - _inout(_k(1.55, 1.9))
	var th := -side * 1.3 * cos(PI * t / 0.7) * exp(-1.6 * t) * damp
	_pend(th, lerpf(50.0, BossAI.PEND_LEN, _out(_k(0.0, 0.55))))
	if t < 0.35 or t > 0.6:
		_loop("idle")
	else:
		_show("atk", 0 if t < 0.48 else 1)
	if _at("drop", 0.08):
		Audio.play("burn_whoosh", -10.0, 0.05, 0.6)
	if _at("toll", 0.35):
		Audio.play("bell_toll", -4.0, 0.0, 0.8)
		_shake(3.0)
	if _at("tock", 0.7):
		Audio.play("tick", 0.0, 0.0, 0.55)
	if _at("tick", 1.4):
		Audio.play("tick", 0.0, 0.0, 1.2)


func _pend(theta: float, l: float) -> void:
	var anchor: Vector2 = w.room.position + BossAI.PEND_ANCHOR
	var ring := anchor + Vector2(sin(theta), cos(theta)) * l
	e.global_position = ring + Vector2(0, BossAI.PEND_RING)
	var tl := e.tele()
	tl.rod = true
	tl.rod_anchor = anchor
	tl.rod_end = Vector2(0, -BossAI.PEND_RING + 1)
	tl.queue_redraw()


# ---- THE HOUR FIEND: a ring of hellfire, a burst, and it stands in the flames, glowing hot, then cools
func _x_fiend() -> void:
	_tint(1.0, _k(0.35, 0.47))
	if t >= 0.35 and t < 1.0:
		_hold_flash(GOLD.lerp(RED, _k(0.35, 0.7)), 1.0 - _k(0.5, 1.0))
	if _light:
		_light.energy = (1.1 * _k(0.0, 0.35) if t < 0.35 else 1.6 * (1.0 - _k(0.35, 1.35)))
	if t > 0.05 and t < 0.9:
		var rx := 4.0 + 18.0 * _out(_k(0.0, 0.35))
		for k in 2:
			var a := randf() * TAU
			_j().hot.emit(_hg(Vector2(cos(a) * rx, sin(a) * rx * 0.45 - 1)), Vector2(randf_range(-6, 6), randf_range(-40, -20)), 0.5, FxParts.EMBER, -20.0, 0.0, 1)
	if _at("whoosh", 0.0):
		Audio.play("burn_whoosh", -4.0, 0.05, 0.7)
	if _at("crackle", 0.05):
		Audio.play("fire_crackle", -2.0)
	if _at("burst", 0.35):
		_j().hot.burst(_hg(Vector2(0, -10)), 28, 60.0, 160.0, Vector2.UP, 0.45, 0.5, FxParts.SPARK, 90.0, 1.0, 1, true)
		w.fx_scorch(_hg())
		Audio.play("explosion", -6.0, 0.05, 0.8)
		_shake(5.0)
	if _at("roar", 0.55):
		Audio.play("boss_roar", -6.0, 0.0, 0.9)


# ---- THE WEATHERCOCK: blown in on a gust, spinning on its spindle; it lands, spreads its wings and crows
func _x_cock(dt: float) -> void:
	_tint(1.0, _k(0.0, 0.2))
	var k := _k(0.0, 1.05)
	var ek := _out(k)
	if t < 1.05:
		e.spr.position = Vector2(-side * 72.0 * (1.0 - ek), -30.0 * (1.0 - ek) - 8.0 * sin(PI * ek)).round()
		_spin += dt * lerpf(16.0, 5.0, k)
		_show("grab", int(_spin) % 4)
	else:
		e.spr.position = Vector2.ZERO
		if t < 1.45:
			_show("atk", 0 if t < 1.2 else 1)
		else:
			_loop("idle")
	e.shadow.position = Vector2(e.spr.position.x, -1)
	e.shadow.scale = Vector2.ONE * lerpf(0.5, 1.0, ek)
	for b in _bits:
		b["p"] = b["p"] + Vector2(side * float(b["v"]) * dt, 0)
	if _at("gust", 0.0):
		Audio.play("burn_whoosh", -6.0, 0.05, 1.5)
	for f in [["w0", 0.3], ["w1", 0.6], ["w2", 0.85]]:
		if _at(f[0], f[1]):
			Audio.play("moth_flutter", -4.0, 0.1, 0.8)
	if _at("land", 1.05):
		Audio.play("thud_heavy", -6.0, 0.05, 1.1)
		_j().lit.burst(e.global_position, 10, 15.0, 45.0, Vector2.ZERO, PI, 0.45, FxParts.DUST, -10.0, 3.0, 1)
		_shake(2.5)
	if _at("crow", 1.1):
		Audio.play("boss_roar", -10.0, 0.0, 1.45)


# ---- THE STOCKPOT: it simmers, steams and rattles harder and harder, then boils over
func _x_stockpot() -> void:
	_tint(1.0, _k(0.0, 0.2))
	var heat := _k(0.2, 1.0)
	if t < 1.0:
		_loop("idle")
		e.spr.position.x = (1.0 if int(t * (10.0 + 26.0 * heat)) % 2 == 0 else -1.0) if heat > 0.25 else 0.0
		if randf() < 0.08 + 0.25 * heat:
			w.fx_wisp(_g(Vector2(randf_range(-12, 12), -32)))
	else:
		e.spr.position.x = 0.0
		if t < 1.5:
			_loop("atk")
		else:
			_loop("idle")
	for b in [["b0", 0.25, 0.7], ["b1", 0.48, 0.85], ["b2", 0.66, 1.0], ["b3", 0.8, 1.15], ["b4", 0.92, 1.3]]:
		if _at(b[0], b[1]):
			Audio.play("wax_bubble", -4.0, 0.05, b[2])
	if _at("sizzle", 0.6):
		Audio.play("sizzle", -8.0)
	var rim := _g(Vector2(0, -30))
	if _at("over", 1.0):
		Audio.play("splash", 0.0, 0.05, 0.8)
		Audio.play("sizzle", -4.0)
		_j().hot.burst(rim, 18, 40.0, 110.0, Vector2.UP, 1.1, 0.55, FxParts.EMBER, 260.0, 0.0, 2)
		_j().lit.burst(rim, 10, 10.0, 30.0, Vector2.UP, 0.9, 0.9, FxParts.SMOKE, -20.0, 1.0, 2)
		_shake(3.0)
	if _at("land", 1.3):
		var mat := Stains.material_of(kind)
		for i in 5:
			_j().splat(_hg(Vector2.from_angle(TAU * i / 5.0 + randf_range(-0.3, 0.3)) * randf_range(16.0, 24.0) * Vector2(1.0, 0.6)), mat, false)


# ---- THE HEAD LIBRARIAN: two lenses glint in the dark between the shelves, then she steps out, pages rustling
func _x_librarian() -> void:
	var lit := _inout(_k(0.5, 1.15))
	_tint(lit, _k(0.0, 0.35))
	_glow_k(1.0 if t >= 0.3 else 0.0)
	_pool(lit)
	_rim(t > 0.9)
	e.position = _start.lerp(home, _inout(_k(0.4, 1.05)))
	if t >= 0.4 and t < 1.05:
		_loop("run", 0.6)
	else:
		_loop("idle")
	if t > 0.1 and t < 0.9 and randf() < 0.18:
		_j().lit.emit(_hg(Vector2(randf_range(-22, 22), -58)), Vector2(randf_range(-3, 3), 10), 1.0, FxParts.DUST, 25.0, 0.0, 1)
	if _at("glint", 0.3):
		_j().hot.burst(_g(Vector2(-0.5, -43)), 4, 8.0, 20.0, Vector2.ZERO, PI, 0.3, FxParts.BLUE, 0.0, 2.0, 1)
		Audio.play("page_flip", -4.0)
	if _at("pg1", 0.65):
		Audio.play("page_flip", -6.0, 0.05, 0.8)
	if _at("pg2", 0.95):
		Audio.play("page_flip", -8.0, 0.05, 1.1)


# ---- THE DRESSMAKER'S FORM: it rolls in on its castors from across the room, tips, wobbles and stands
func _x_form() -> void:
	_tint(1.0, _k(0.0, 0.25))
	var k := _k(0.0, 1.0)
	e.position = _start.lerp(home, 1.0 - pow(1.0 - k, 3.0))
	var dir := signf(home.x - _start.x)
	if t < 1.0:
		e.spr.rotation = dir * 0.14 * sin(PI * k) * k
		_loop("run", lerpf(1.6, 0.4, k))
		if randf() < 0.35:
			_j().lit.emit(e.global_position + Vector2(-dir * 6.0, -1), Vector2(-dir * 12.0, -6.0), 0.4, FxParts.DUST, -5.0, 0.0, 1)
	else:
		var q := t - 1.0
		e.spr.rotation = dir * 0.12 * exp(-5.0 * q) * cos(q * 16.0)
		_loop("idle")
	for i in 5:
		if _at("c%d" % i, 0.08 + 0.18 * i):
			Audio.play("tick", -6.0, 0.1, 1.9)
	if _at("stop", 1.0):
		Audio.play("hit_wall", -8.0, 0.05, 1.6)
		Audio.play("thud_heavy", -10.0, 0.05, 1.4)
		_shake(1.5)
	if _at("pins", 1.05):
		w.fx_glint(_g(Vector2(0, -30)))


# ---- THE KEEPER OF HOURS: a clock face of light draws itself, it steps out of the glow, and the hour strikes
func _x_keeper() -> void:
	_tint(1.0, _k(0.45, 0.9))
	if t >= 0.45 and t < 1.45:
		_hold_flash(PALE, 0.8 if t < 0.95 else 0.8 * (1.0 - _k(0.95, 1.4)))
	var st := _out(_k(0.45, 1.2))
	e.spr.position = Vector2(0, round(-5.0 * (1.0 - st)))
	e.spr.scale = Vector2.ONE * lerpf(0.88, 1.0, st)
	if t >= 0.45 and t < 1.2:
		_loop("run", 0.8)
	else:
		_loop("idle")
	if _light:
		_light.energy = 1.1 * _k(0.0, 0.5) * (1.0 - _k(1.45, 1.95))
	for i in 6:
		if _at("t%d" % i, 0.05 + 0.1 * i):
			Audio.play("clock_tick_fast", -8.0)
	if _at("step", 0.45):
		Audio.play("teleport", -8.0, 0.05, 0.8)
	if _at("strike", 1.45):
		Audio.play("bell_toll", -2.0, 0.0, 1.0)
		Lighting.shockwave(w, _hg(FACE_C), 48.0, 2.0)
		_shake(3.0)


# ---------------------------------------------------------------- drawing (pixel by pixel, palette colours)

func _draw() -> void:
	match kind:
		"wax_mother": _draw_puddle()
		"ossuary": _draw_bones()
		"big_demon": _draw_fire(false)
		"keeper": _draw_face()


func _draw_over() -> void:
	match kind:
		"weathercock": _draw_wind()
		"big_demon": _draw_fire(true)
		"stockpot": _draw_bubbles()


static func _dot(ci: CanvasItem, p: Vector2, c: Color, sz := Vector2.ONE) -> void:
	ci.draw_rect(Rect2(p.round(), sz), c)


## A filled ellipse made of whole-pixel rows.
static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var h := int(ry)
	for y in range(-h, h + 1):
		var hw := rx * sqrt(maxf(0.0, 1.0 - float(y * y) / maxf(1.0, ry * ry)))
		var x0 := roundf(c.x - hw)
		var x1 := roundf(c.x + hw)
		if x1 > x0:
			ci.draw_rect(Rect2(x0, roundf(c.y) + y, x1 - x0, 1), col)


## A 1 px ellipse outline (no doubled pixels).
static func _ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, from := 0.0, to := TAU) -> void:
	var n := maxi(16, int((rx + ry) * 3.0))
	var seen := {}
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		var p := (c + Vector2(cos(a) * rx, sin(a) * ry)).round()
		if not seen.has(p):
			seen[p] = true
			ci.draw_rect(Rect2(p, Vector2.ONE), col)


## A 1 px line, pixel by pixel.
static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in n + 1:
		ci.draw_rect(Rect2(a.lerp(b, float(i) / n).round(), Vector2.ONE), col)


func _draw_puddle() -> void:
	var rx := (3.0 + 15.0 * _out(_k(0.0, 0.4))) * (1.0 - 0.45 * _inout(_k(0.6, 1.3)))
	if t > 1.5 or rx < 1.5:
		return
	var ry := maxf(1.0, rx * 0.38)
	var c := Vector2(0, -1)
	_oval(self, c + Vector2(0, 1), rx, ry, WAX_C[3])
	_oval(self, c, rx, ry, WAX_C[2])
	_oval(self, c + Vector2(-rx * 0.2, -ry * 0.3), rx * 0.5, ry * 0.45, WAX_C[1])
	for i in 3:   # bubbles: a dot swells into a ring and pops
		var ph := fposmod(t * 2.6 + i * 0.37, 1.0)
		var p := c + Vector2((i - 1) * rx * 0.5, (i % 2) * 1.0 - 1.0)
		if ph < 0.5:
			_dot(self, p, WAX_C[0])
		elif ph < 0.8:
			_ring(self, p, 1.5, 1.0, WAX_C[0])


func _draw_bones() -> void:
	for b in _bits:
		var k := _k(float(b["t0"]), float(b["t1"]))
		if k >= 1.0:
			continue
		if b.has("skull"):
			if k <= 0.0:
				continue
			var tex: Texture2D = Art.tex("monsters/ossuary_roll_f%d" % (int(t * 14.0) % 4))
			var x := float(b["x"]) * (1.0 - _out(k))
			draw_texture(tex, Vector2(round(x - tex.get_width() / 2.0), -tex.get_height()))
			continue
		var q := k * k
		var p: Vector2 = (b["p"] as Vector2) * (1.0 - q) + Vector2(0, -sin(PI * k) * 5.0)
		p = p.round()
		if b["up"]:   # a bone standing on end (3 x 5)
			draw_rect(Rect2(p + Vector2(-1, -4), Vector2(1, 1)), BONE_C[0])
			draw_rect(Rect2(p + Vector2(1, -4), Vector2(1, 1)), BONE_C[0])
			draw_rect(Rect2(p + Vector2(0, -4), Vector2(1, 5)), BONE_C[1])
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), BONE_C[1])
			draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), BONE_C[1])
			draw_rect(Rect2(p + Vector2(-1, 1), Vector2(3, 1)), BONE_C[2])
		else:         # a bone lying down (5 x 3)
			draw_rect(Rect2(p + Vector2(-2, -2), Vector2(1, 3)), BONE_C[0])
			draw_rect(Rect2(p + Vector2(2, -2), Vector2(1, 3)), BONE_C[1])
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 1)), BONE_C[1])
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), BONE_C[2])


## The Hour Fiend's ring of flames: the back half behind it, the front half in front of its feet.
func _draw_fire(front: bool) -> void:
	var ci: CanvasItem = _over if front else self
	var rx := 4.0 + 18.0 * _out(_k(0.0, 0.35))
	var life := 1.0 - _k(0.7, 1.4)
	if life <= 0.0:
		return
	for b in _bits:
		var a: float = b["a"]
		if (sin(a) >= 0.0) != front:
			continue
		var base := Vector2(cos(a) * rx, sin(a) * rx * 0.45 - 1.0).round()
		var h := int(round((2.0 + 3.0 * absf(sin(t * 17.0 + float(b["ph"])))) * life))
		if h <= 0:
			continue
		ci.draw_rect(Rect2(base + Vector2(-1, 0), Vector2(3, 1)), RED)
		for y in range(1, h + 1):
			var col: Color = ORANGE if y < h - 1 else (GOLD if y < h else CREAM)
			ci.draw_rect(Rect2(base + Vector2(0, -y), Vector2(1, 1)), col)


func _draw_wind() -> void:
	if t > 1.3:
		return
	var col := PALE
	col.a = 0.85
	for b in _bits:
		var a: Vector2 = b["p"]
		if absf(a.x) > 150.0:
			continue
		for k in int(b["n"]):
			_over.draw_rect(Rect2((a - Vector2(side * k, 0)).round(), Vector2.ONE), col)


func _draw_bubbles() -> void:
	if t > 1.05:
		return
	var heat := _k(0.2, 1.0)
	var sx := -1.0 if e.spr.flip_h else 1.0
	for b in _bits:
		var ph := fposmod(t * float(b["sp"]) * (0.6 + heat) + float(b["ph"]), 1.0)
		if ph > 0.3 + 0.6 * heat:
			continue
		var p := Vector2(float(b["x"]) * sx + e.spr.position.x, -31.0 - 5.0 * ph)
		if ph < 0.25:
			_dot(_over, p, GOLD)
		else:
			_ring(_over, p, 1.0, 1.0, ORANGE)


## The Keeper's clock face of light: a hand sweeps the rim round, the hours appear, and it flares out on the strike.
func _draw_face() -> void:
	if t > 1.95:
		return
	var sweep := TAU * _out(_k(0.0, 0.6))
	var grow := _out(_k(1.45, 1.95))
	var r := FACE_R + 18.0 * grow
	var fade := mini(2, int(grow * 3.0))
	var rim: Color = [PALE, BLUE, VIOLET][fade]
	var inner: Color = [BLUE, VIOLET, VIOLET][fade]
	var c := FACE_C
	_ring(self, c, r, r, rim, -PI / 2.0, -PI / 2.0 + sweep)
	if fade < 2:
		_ring(self, c, r - 2.0, r - 2.0, inner, -PI / 2.0, -PI / 2.0 + sweep)
	for h in 12:
		var a := -PI / 2.0 + TAU * h / 12.0
		if a > -PI / 2.0 + sweep + 0.01:
			continue
		var len := 3.0 if h % 3 == 0 else 1.0
		_line(self, c + Vector2.from_angle(a) * (r - 4.0 - len + 1.0), c + Vector2.from_angle(a) * (r - 4.0), CREAM if fade == 0 else rim)
	if grow <= 0.0:   # the hands: one draws the rim, then both spin until the strike
		var ha := -PI / 2.0 + (sweep if t < 0.6 else sweep + (t - 0.6) * 14.0)
		_line(self, c, c + Vector2.from_angle(ha) * (r - 5.0), CREAM)
		_line(self, c, c + Vector2.from_angle(-PI / 2.0 + t * 3.0) * (r - 11.0), CREAM)


# ---------------------------------------------------------------- tour: --autotest --tour --intros --shots=DIR

## Every guardian in house order: [kind, its floor, an area id, or 0 for the Clock Tower].
const TOUR := [["big_zombie", 1], ["wax_mother", 1], ["furnace", 1], ["ogre", 2], ["sexton", 2], ["ossuary", 2],
	["necro_boss", 3], ["choir", 3], ["organist", 3], ["pendulum", 4], ["big_demon", 4], ["weathercock", 4],
	["stockpot", "kitchen"], ["librarian", "library"], ["dress_form", "attic"], ["keeper", 0]]
## When the two shots of each entrance are taken (s): its signature moments.
const TOUR_AT := {
	"big_zombie": [0.5, 1.2], "wax_mother": [0.35, 0.75], "furnace": [0.6, 1.05],
	"ogre": [0.7, 0.92], "sexton": [0.6, 1.12], "ossuary": [0.45, 1.1],
	"necro_boss": [0.4, 1.0], "choir": [0.6, 1.25], "organist": [0.75, 1.3],
	"pendulum": [0.25, 0.8], "big_demon": [0.3, 0.5], "weathercock": [0.5, 1.2],
	"stockpot": [0.8, 1.15], "librarian": [0.35, 0.8], "dress_form": [0.3, 1.1], "keeper": [0.4, 0.8],
}


## Shoots every guardian's entrance twice mid-animation (no versus card: it has its own tours), checks each ends
## with the guardian ready (active, in place, plain sprite), then skips one with a key press and shows one with
## the card and the camera punch-in. `--intros=<kind>` keeps to one guardian. Log lines start with "[intros]".
static func tour(bot: Node) -> void:
	bot.args["nocard"] = true
	var only := str(bot.args["intros"]) if bot.args.get("intros") is String else ""
	Game.no_save = true
	Game.records["unlocked"] = Candles.ORDER.duplicate()   # no "new candle" news over the shots
	bot.main.goto("game", {"seed": 31})
	await bot._wait(1.6)
	var w: Node = bot.main.current
	var problems := 0
	for item in TOUR:
		if only != "" and item[0] != only:
			continue
		var b: BossIntro = await _tour_enter(bot, w, item)
		if b == null:
			problems += 1
			continue
		var e := b.e
		var kind := b.kind
		var length := b.dur
		for when in TOUR_AT.get(kind, [length * 0.45, length * 0.8]):
			while is_instance_valid(b) and not b._done and b.t < float(when):
				await bot._wait(0.01)
			w.hud.show_hint("", 0.0)   # no first-run tips over the shot
			var at: Vector2 = w.get_viewport().get_canvas_transform() * (e.global_position + e.spr.position + Vector2(0, -20))
			var shot := "intro_%s_%02d" % [kind, int(float(when) * 10.0)]
			await bot._shot(shot)
			print("[intros] shot %s screen %d %d" % [shot, int(at.x), int(at.y)])
		var waited := 0.0
		while is_instance_valid(b) and waited < 3.0:
			await bot._wait(0.02)
			waited += 0.02
		var ok := _tour_ready(e)
		print("[intros] %s: %.1f s, ends ready: %s" % [kind, length, ok])
		problems += 0 if ok else 1
	if only == "":
		# a key press skips the rest: the guardian stands ready at once
		var b2: BossIntro = await _tour_enter(bot, w, TOUR[0])
		if b2:
			var e2 := b2.e
			while is_instance_valid(b2) and b2.t < 0.4:
				await bot._wait(0.01)
			var ev := InputEventKey.new()
			ev.keycode = KEY_X
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventKey.new()
			up.keycode = KEY_X
			Input.parse_input_event(up)
			await bot._wait(0.05)
			var ok2 := not is_instance_valid(b2) and _tour_ready(e2)
			print("[intros] skip: a key at 0.4 s, guardian ready at once: %s" % ok2)
			problems += 0 if ok2 else 1
		# with the versus card and the camera punch-in, as in a run
		bot.args.erase("nocard")
		var b3: BossIntro = await _tour_enter(bot, w, TOUR[2], 5.0)
		if b3:
			while is_instance_valid(b3) and b3.t < 0.3:
				await bot._wait(0.01)
			await bot._shot("intro_furnace_card_punch")
		await bot._wait(2.0)
	print("[intros] done, %d problem(s)" % problems)
	_tour_clear(w)


## Starts the guardian's floor, walks into its room and waits for its entrance to begin.
static func _tour_enter(bot: Node, w: Node, item: Array, limit := 3.0) -> BossIntro:
	_tour_clear(w)
	var where = item[1]
	if where is String:
		w.floor_areas = {Areas.TEST_DEPTH: where}
		w._start_floor(Areas.TEST_DEPTH)
	else:
		w.floor_areas = {}
		w._start_floor(Tower.floor_of(w) if int(where) == 0 else int(where))
	w.boss_kind = item[0]
	w.player.wax = 100.0
	await bot._wait(2.9)   # the floor banner clears
	Juice.of(w).stain_store.clear()   # the test areas share a floor number: no puddles carried between them
	live = null
	bot._jump(w, w.layout["boss"])
	var waited := 0.0
	while live == null and waited < limit:
		await bot._wait(0.02)
		waited += 0.02
	if live == null or live.kind != item[0]:
		print("[intros] %s: NO ENTRANCE" % item[0])
		return null
	return live


static func _tour_ready(e: Enemy) -> bool:
	return is_instance_valid(e) and e.alive and e.active and not e.intro and e.spr.visible \
		and e.spr.scale == Vector2.ONE and e.spr.position == Vector2.ZERO and e.spr.rotation == 0.0 \
		and e.modulate == Color.WHITE


static func _tour_clear(w: Node) -> void:
	for en in w.enemies:
		if is_instance_valid(en):
			en.queue_free()
	w.enemies.clear()
	w.boss = null
	w.hud.set_boss("", false)
	w._clear_shots()
	Keeper.cleanup(w)
