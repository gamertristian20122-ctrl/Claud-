class_name Keeper
extends RefCounted
## THE KEEPER OF HOURS, the true final boss of the Clock Tower, and the tower's two lodgers.
## Enemy DEFS whose "ai" starts with "tower_" run from here (one line in enemy.gd).
##
## The Keeper stands on the brass dial inlaid in its floor; its two great hands sweep that dial.
##   Phase 1: the hour hand (short, slow) and the minute hand (long, quick) take turns sweeping an arc.
##            Before a hand moves, its ghost shows where it starts, a dotted arc shows how far it goes and
##            a dotted line marks where it stops: run the way it goes, past that line, or out past its tip. Cog fans
##            and rings in between.
##   Phase 2 (66%): STOPPED TIME. The room greys and everything freezes. Cog bolts appear in the air, each
##            with a short mark showing which way it will fly; three ticks (three pips over the Keeper),
##            then everything moves again at once. Your own sparks hang in the air and fly on with them.
##   Phase 3 (33%): the hour hand turns for good, the minute hand sweeps faster, and every few seconds the
##            Keeper chimes: a ring of sound and, now and then, a Cog Sentry.
## Readable on a phone: hands are bright brass with a dark outline, drawn unshaded; every warning shows
## for 0.75 s or more.

const PIVOT := Vector2(136, 104)     # room-local centre of the floor dial
const HOUR_LEN := 74.0
const MIN_LEN := 104.0
const HAND_HIT := 6.0
const STOP_TIME := 2.9
const MAX_SENTRIES := 2
## Shortest time in phase 1 / 2 before the next phase (strong runs still see every pattern).
const MIN_PHASE := [0.0, 6.0, 8.0, 0.0]
const FACE := Vector2(0, -41)        # the dial on the sprite, from the Keeper's feet
const WARN := Color("#da4e38")
const PALE := Color("#cae6f5")
const GREY_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.30, 0.55, 0.15));
	vec3 cold = vec3(g * 0.86, g * 0.95, g * 1.18);
	COLOR = vec4(mix(c, cold, amount), 1.0);
}
"""

static var _host: Keeper
static var _grey_shader: Shader


static func ai() -> Keeper:
	if _host == null:
		_host = Keeper.new()
	return _host


## How far a hand pointing at angle `a` can reach from the dial centre before it meets a wall.
static func reach(a: float) -> float:
	var d := Vector2.from_angle(a)
	var t := 999.0
	if absf(d.x) > 0.001:
		t = minf(t, ((256.0 if d.x > 0 else 16.0) - PIVOT.x) / d.x)
	if absf(d.y) > 0.001:
		t = minf(t, ((176.0 if d.y > 0 else 32.0) - PIVOT.y) / d.y)
	return t


# ================================================================= THE KEEPER OF HOURS
func init_tower_keeper(e: Enemy) -> void:
	e.global_position = e.world.room.position + PIVOT + Vector2(0, 6)
	e.mem["hands"] = [
		{"len": HOUR_LEN, "w": 5.0, "a": -PI / 2, "st": "off"},
		{"len": MIN_LEN, "w": 3.0, "a": -PI / 2 + 0.6, "st": "off"},
	]
	e.mem["hand_t"] = 1.2
	e.mem["next_hand"] = 0
	e.mem["chime_t"] = 3.0
	e.mem["stop_n"] = 0
	e.mem["stop_due"] = 4.0
	e.state = "idle"
	e.cd = 1.6
	var h := Hands.new()
	h.e = e
	e.world.room.add_child(h)
	e.mem["node"] = h
	var f := Face.new()
	f.e = e
	f.position = FACE
	e.add_child(f)
	# its dial catches the moonlight: the Keeper is always easy to find in the dark
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(0.72, 0.8, 1.0)
	l.energy = 0.7
	l.texture_scale = 0.45
	l.position = FACE
	e.add_child(l)


## Tours and tests: start a pattern now.
func force(e: Enemy, what: String) -> void:
	if what == "stop":
		_stop_hands(e)
		_start_stop(e)


func tower_keeper(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	var w: Node = e.world
	var hands: Array = e.mem["hands"]
	if w.main and w.main.autotest:   # the play-test log: how the fight went
		e.mem["fight_t"] = e.mem.get("fight_t", 0.0) + e.get_physics_process_delta_time()
		if w.player.dead and not e.mem.get("logged", false):
			e.mem["logged"] = true
			print("[keeper] Tallow fell after %.0f s in phase %d, the Keeper at %d%% (hand hits %d)" % [e.mem["fight_t"], e.phase, int(100.0 * e.hp / e.max_hp), e.mem.get("hand_hits", 0)])
	# every phase is seen, however strong the run: damage past the next threshold is held (the dial
	# flashes pale and rings like metal) until the Keeper has changed phase, and a phase lasts at least
	# MIN_PHASE seconds (long enough for its hands, and in phase 2 for one stopped time)
	e.mem["phase_t"] = e.mem.get("phase_t", 0.0) + e.get_physics_process_delta_time()
	e.mem["held_t"] = e.mem.get("held_t", 0.0) - e.get_physics_process_delta_time()
	if e.phase < 3:
		var gate: float = [0.0, 0.66, 0.33][e.phase] * e.max_hp - 0.5
		if e.hp < gate:
			e.hp = gate
			w.on_boss_hp(e)
			if e.mem["held_t"] <= 0.0 and float(e.mem["phase_t"]) < MIN_PHASE[e.phase]:
				e.mem["held_t"] = 0.3
				e._telegraph(PALE)
				Audio.play("hit_wall", -6.0, 0.1, 1.6)
	if e.state == "stop":
		_stop_tick(e)
		return
	# a new phase (one at a time) breaks off whatever the hands were doing
	var np := mini(e._boss_phase(), e.phase + 1)
	if np > e.phase and e.state != "roar" and float(e.mem["phase_t"]) >= MIN_PHASE[e.phase]:
		_stop_hands(e)
		e.phase = np
		e.mem["phase_t"] = 0.0
		e.mem["stop_due"] = 1.6   # stopped time comes early in phase 2
		e.on_new_phase()
		if w.main and w.main.autotest:
			print("[keeper] phase %d after %.0f s, Tallow at %s" % [np, e.mem.get("fight_t", 0.0), Game.clock_text(w.clock_minutes())])
		if np >= 3:
			hands[0]["st"] = "spin"
			hands[0]["a"] = (to_p.angle() + PI)    # starts pointing away from you
		return
	if e.state == "roar":
		if e.t <= 0:
			e.state = "idle"
			e.cd = 0.8
		_hands_tick(e, ddt)
		return
	_hands_tick(e, ddt)
	# the hands take turns
	e.mem["hand_t"] -= ddt
	if e.mem["hand_t"] <= 0.0 and e.state == "idle":
		var which: int = e.mem["next_hand"] if e.phase < 3 else 1
		if hands[which]["st"] == "off":
			_start_sweep(e, which, to_p)
			e.mem["next_hand"] = 1 - which
			e.mem["hand_t"] = [0.0, 4.6, 5.4, 4.6][e.phase] + (1.2 if which == 0 else 0.0)
	# phase 2: stopped time every so often (never while a hand is moving)
	if e.phase == 2 and e.state == "idle":
		e.mem["stop_due"] -= ddt
		if e.mem["stop_due"] <= 0.0 and not _hands_busy(e):
			_start_stop(e)
			return
	# phase 3: the chimes
	if e.phase >= 3:
		e.mem["chime_t"] -= ddt
		if e.mem["chime_t"] <= 0.0:
			e.mem["chime_t"] = 4.2
			_chime(e, to_p)
	var face: Vector2 = e.global_position + FACE
	match e.state:
		"idle":
			if e.cd <= 0:
				e._pattern += 1
				var opts := ["fan", "ring", "fan"] if e.phase < 3 else ["fan"]   # in phase 3 the chimes are the rings
				e.state = opts[e._pattern % opts.size()]
				e.t = 0.5 if e.state == "fan" else 0.6
				e.play_anim("atk", e.t + 0.15)
				e._telegraph(Color(1, 0.75, 0.35))
				Audio.play("tick", -2.0, 0.0, 0.8)
				e.dir = to_p.normalized()
		"fan":
			if e.t <= 0:
				var n := mini(3 + e.phase, 5)
				var base: float = (w.player.global_position + Vector2(0, -6) - face).angle()
				for i in n:
					w.enemy_shot(face, Vector2.from_angle(base + (i - (n - 1) / 2.0) * 0.21) * (74.0 + 6.0 * e.phase), "bolt_cog")
				Audio.play("enemy_shoot", 2.0, 0.05, 0.75)
				e.state = "idle"
				e.cd = [0.0, 1.6, 1.5, 1.8][e.phase]
		"ring":
			if e.t <= 0:
				w.burst(face, 8 + 2 * e.phase, 58.0, "bolt_cog", randf() * TAU)
				Audio.play("tick", 2.0, 0.0, 0.55)
				w.shake(1.5)
				e.state = "idle"
				e.cd = [0.0, 1.6, 1.5, 1.7][e.phase]


func _hands_busy(e: Enemy) -> bool:
	for h in e.mem["hands"]:
		if h["st"] in ["ghost", "on", "fade"]:
			return true
	return false


func _stop_hands(e: Enemy) -> void:
	for h in e.mem["hands"]:
		if h["st"] != "spin":
			h["st"] = "off"
	e.tele().clear()


## A sweep: the hand's ghost appears behind you, then it sweeps through where you stand.
func _start_sweep(e: Enemy, which: int, _to_p: Vector2) -> void:
	var h: Dictionary = e.mem["hands"][which]
	var pa: float = (e.world.player.global_position - (e.world.room.position + PIVOT)).angle()
	var span := PI if which == 0 else deg_to_rad(120.0)
	var lead := span * 0.58
	var cw: bool = int(e.mem.get("sweeps", 0)) % 2 == 0
	e.mem["sweeps"] = e.mem.get("sweeps", 0) + 1
	var a0: float = pa - lead if cw else pa + lead
	var a1: float = a0 + span if cw else a0 - span
	var fast := e.phase >= 3
	h["a0"] = a0
	h["a1"] = a1
	h["a"] = a0
	h["tele"] = (1.0 if which == 0 else 0.9) - (0.15 if fast else 0.0)
	h["dur"] = (span / 0.8) if which == 0 else (1.6 if not fast else 1.25)
	h["t"] = 0.0
	h["st"] = "ghost"
	# the arc it will cover and the line where it stops
	var c: Vector2 = e.world.room.position + PIVOT
	var pts := PackedVector2Array()
	var r: float = h["len"] - 5.0
	var steps := int(absf(a1 - a0) * r / 7.0)
	for i in steps + 1:
		var a := lerpf(a0, a1, i / float(maxi(1, steps)))
		if reach(a) > r + 2.0:   # only the part of the arc inside the room
			pts.append(c + Vector2.from_angle(a) * r)
	var dur: float = h["tele"] + h["dur"]
	e.tele().path(pts, dur, WARN)
	e.tele().line(c + Vector2.from_angle(a1) * 18.0, c + Vector2.from_angle(a1) * minf(h["len"], reach(a1) - 2.0), dur, WARN)
	Audio.play("charge_up" if which == 0 else "tick", -4.0, 0.0, 1.0 if which == 0 else 1.5)
	if Game.tip("keeper_hands", 1):
		e.world.hud.show_hint("A hand is coming: run the way the arc goes, past the dotted line, or out past its tip.", 3.5)


func _hands_tick(e: Enemy, ddt: float) -> void:
	for h in e.mem["hands"]:
		match h["st"]:
			"ghost":
				h["tele"] -= ddt
				if h["tele"] <= 0.0:
					h["st"] = "on"
					Audio.play("burn_whoosh", -5.0, 0.05, 0.6 if h["w"] > 4.0 else 0.9)
			"on":
				h["t"] += ddt
				var k: float = clampf(h["t"] / h["dur"], 0.0, 1.0)
				h["a"] = lerpf(h["a0"], h["a1"], k)
				if k >= 1.0:
					h["st"] = "fade"
					h["t"] = 0.25
			"fade":
				h["t"] -= ddt
				if h["t"] <= 0.0:
					h["st"] = "off"
			"spin":
				h["a"] += ddt * (0.45 + (0.1 if e.hp / e.max_hp < 0.15 else 0.0))
		if h["st"] in ["on", "spin"]:
			_hand_hits(e, h)
	if e.mem.has("node") and is_instance_valid(e.mem["node"]):
		(e.mem["node"] as Node2D).queue_redraw()


func _hand_hits(e: Enemy, h: Dictionary) -> void:
	var w: Node = e.world
	var p: Player = w.player
	if p.dead or w.freeze_t > 0.0:
		return
	var c: Vector2 = w.room.position + PIVOT
	var d := Vector2.from_angle(h["a"])
	var pp := p.global_position + Vector2(0, -5)
	var rel := pp - c
	var along := rel.dot(d)
	if along < 14.0 or along > h["len"] + 2.0:
		return
	var off := absf(rel.dot(d.orthogonal()))
	if off < h["w"] * 0.5 + 4.0:
		if p.invuln <= 0.0:
			e.mem["hand_hits"] = e.mem.get("hand_hits", 0) + 1
		p.hurt(HAND_HIT * w.enemy_dmg_mult(), d.orthogonal() * signf(rel.dot(d.orthogonal()) + 0.001))


func _chime(e: Enemy, to_p: Vector2) -> void:
	var w: Node = e.world
	var face: Vector2 = e.global_position + FACE
	Audio.play("bell_toll", -1.0, 0.0, 1.2)
	e._telegraph(Color(1, 1, 1))
	w.shake(2.5)
	w.fx_ring(face, PALE)
	# a ring of sound with a gap where you stand: keep still and it passes you by
	var n := 12
	var gap := to_p.angle() + PI
	for i in n:
		var a := gap + TAU * (i + 0.5) / n
		if absf(angle_difference(a, to_p.angle())) < 0.25:
			continue
		w.enemy_shot(face, Vector2.from_angle(a) * 56.0, "bolt_ring")
	var sentries := 0
	for m in w.enemies:
		if is_instance_valid(m) and m.alive and m.kind == "cog_sentry":
			sentries += 1
	e.mem["chimes"] = e.mem.get("chimes", 0) + 1
	if sentries < MAX_SENTRIES and e.mem["chimes"] % 3 == 1:
		var spot: Vector2 = w.random_free_spot(w.player.global_position, 70.0)
		var s: Enemy = w.spawn_enemy("cog_sentry", spot)
		if s:
			w.fx_ring(spot + Vector2(0, -6), Color("#facb3e"))
			Audio.play("summon", -6.0)


# ---------------------------------------------------------------- stopped time
func _start_stop(e: Enemy) -> void:
	var w: Node = e.world
	e.state = "stop"
	e.mem["stop_t"] = 0.0
	e.mem["stop_spawned"] = 0
	e.mem["pips"] = 3
	e.mem["stop_kind"] = e.mem["stop_n"] % 2
	e.mem["stop_n"] += 1
	e.mem["stop_due"] = 8.5
	e.mem["stop_at"] = w.player.global_position
	e.play_anim("atk", STOP_TIME)
	e._telegraph(PALE)
	w.freeze_t = maxf(w.freeze_t, STOP_TIME + 0.1)
	Audio.play("charge_up", 0.0, 0.0, 0.7)
	Audio.duck(-8.0, STOP_TIME)
	w.player.z_index = 18      # Tallow keeps her colour: the only thing still burning
	var gr := _grey(w)
	gr.position = w.cam.position - Vector2(320, 180)
	gr.size = Vector2(640, 360)
	gr.visible = true
	var mat: ShaderMaterial = _grey(w).material
	var tw := _grey(w).create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("amount", v), 0.0, 1.0, 0.3)
	# every bolt already in the air freezes too: mark which way each one will go
	var marks: Array = []
	for s in w.enemy_shots:
		if is_instance_valid(s) and s.vel.length() > 1.0:
			marks.append([s, s.vel.normalized()])
	e.mem["marks"] = marks
	if not e.mem.has("marks_node") or not is_instance_valid(e.mem["marks_node"]):
		var mk := Marks.new()
		mk.e = e
		w.fx_layer.add_child(mk)
		e.mem["marks_node"] = mk
	if Game.tip("stopped_time", 1):
		w.hud.show_hint("Time stands still. Read the marks and find a gap before it ticks on.", 3.5)


func _stop_tick(e: Enemy) -> void:
	var w: Node = e.world
	var rdt := e.get_physics_process_delta_time()
	var st: float = e.mem["stop_t"] + rdt
	e.mem["stop_t"] = st
	w.freeze_t = maxf(w.freeze_t, STOP_TIME - st + 0.05)
	_hold_sparks(w, st)
	# the bolts appear one by one in the frozen air
	var total := 16 if e.mem["stop_kind"] == 0 else 12
	var want := clampi(int((st - 0.15) / 1.1 * total) + 1, 0, total) if st >= 0.15 else 0
	while e.mem["stop_spawned"] < want:
		_stop_bolt(e, e.mem["stop_spawned"], total)
		e.mem["stop_spawned"] += 1
	for i in 3:
		var at := 1.45 + 0.5 * i
		if st >= at and e.mem["pips"] == 3 - i:
			e.mem["pips"] = 2 - i
			Audio.play("clock_tick_fast", 0.0, 0.0, 1.0 - 0.1 * i)
	if st >= STOP_TIME:
		_end_stop(e)


func _stop_bolt(e: Enemy, i: int, total: int) -> void:
	var w: Node = e.world
	var room: Room = w.room
	var pos: Vector2
	var vel: Vector2
	if e.mem["stop_kind"] == 0:
		# a ring round where you stood, closing in (they cross in the middle and fly on out)
		var c: Vector2 = e.mem["stop_at"] + Vector2(0, -6)
		var a := TAU * i / float(total)
		pos = c + Vector2.from_angle(a) * 48.0
		vel = -Vector2.from_angle(a) * 64.0
	else:
		# twelve bolts on the dial's rim, each aimed at you as it appears
		var c2: Vector2 = room.position + PIVOT
		var a2 := -PI / 2 + TAU * i / float(total)
		pos = c2 + Vector2.from_angle(a2) * 64.0
		vel = (w.player.global_position + Vector2(0, -6) - pos).normalized() * 80.0
	var lp := pos - room.position
	if lp.x < 18 or lp.x > 254 or lp.y < 34 or lp.y > 174 or room.blocked(pos + Vector2(0, 6), 2.0, true):
		return
	w.enemy_shot(pos, vel, "bolt_cog")
	if not w.enemy_shots.is_empty():
		(e.mem["marks"] as Array).append([w.enemy_shots.back(), vel.normalized()])
	w.fx_poof(pos, false, 0.6)
	if i % 3 == 0:
		Audio.play("tick", -8.0, 0.1, 1.8)


func _end_stop(e: Enemy) -> void:
	var w: Node = e.world
	w.freeze_t = 0.0
	_release_sparks(w)
	e.state = "idle"
	e.cd = 1.0
	e.mem["pips"] = -1
	e.mem["marks"] = []
	e._anim_lock = minf(e._anim_lock, 0.3)   # its arms come down as time moves again
	w.player.z_index = 0
	Audio.play("bell_toll", -2.0, 0.0, 1.35)
	Audio.play("thud_heavy", -4.0)
	w.shake(3.0)
	var g := _grey(w)
	var mat: ShaderMaterial = g.material
	var tw := g.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("amount", v), 1.0, 0.0, 0.25)
	tw.tween_callback(func(): g.visible = false)


## Tallow's own sparks fly a moment, then hang in the stopped air until time moves again.
static func _hold_sparks(w: Node, st: float) -> void:
	for s in w.fx_layer.get_children():
		if not (s is Shot) or not s.friendly or s._dead:
			continue
		if not s.has_meta("kt"):
			s.set_meta("kt", st)
		elif not s.has_meta("kv") and st - float(s.get_meta("kt")) > 0.1:
			s.set_meta("kv", s.vel)
			s.vel = Vector2.ZERO
			s.life += STOP_TIME - st + 0.3


static func _release_sparks(w: Node) -> void:
	for s in w.fx_layer.get_children():
		if s is Shot and s.friendly:
			if s.has_meta("kv"):
				s.vel = s.get_meta("kv")
				s.remove_meta("kv")
			if s.has_meta("kt"):
				s.remove_meta("kt")


static func _grey(w: Node) -> ColorRect:
	var g = w.get_meta("keeper_grey") if w.has_meta("keeper_grey") else null
	if g != null and is_instance_valid(g):
		return g
	if _grey_shader == null:
		_grey_shader = Shader.new()
		_grey_shader.code = GREY_SHADER
	var r := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = _grey_shader
	m.set_shader_parameter("amount", 0.0)
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 17
	r.visible = false
	w.add_child(r)
	w.set_meta("keeper_grey", r)
	return r


## Clean up whatever stopped time left behind (the Keeper died mid-stop, the run ended).
static func cleanup(w: Node) -> void:
	if not is_instance_valid(w):
		return
	if w.has_meta("keeper_grey") and is_instance_valid(w.get_meta("keeper_grey")):
		(w.get_meta("keeper_grey") as ColorRect).visible = false
	if w.player:
		w.player.z_index = 0
	_release_sparks(w)


## The bot: keep out of a hand's way (behind it, or past its tip).
static func bot_push(w: Node, pos: Vector2) -> Vector2:
	var b: Variant = w.boss
	if b == null or not is_instance_valid(b) or not b.alive or b.kind != "keeper" or w.room == null:
		return Vector2.ZERO
	var c: Vector2 = w.room.position + PIVOT
	var rel := pos + Vector2(0, -5) - c
	var dist := rel.length()
	var pa := rel.angle()
	var push := Vector2.ZERO
	for h in b.mem.get("hands", []):
		if not h["st"] in ["ghost", "on", "spin"] or dist > h["len"] + 12.0:
			continue
		var a: float = h["a"]
		if h["st"] == "spin":
			var dd := angle_difference(a, pa)
			if absf(dd) < 0.5:
				push += Vector2.from_angle(pa + signf(dd) * PI / 2) * 1.6 + rel.normalized() * 0.8
			continue
		var a1: float = h["a1"]
		var dirn := signf(a1 - a)
		var ahead := angle_difference(a, pa) * dirn
		var left := absf(angle_difference(a, a1))
		if ahead > -0.15 and ahead < left + 0.2:
			# in the arc it is about to sweep: run the way it goes, past the dotted line where it stops
			# (and out toward its tip)
			var side := Vector2.from_angle(pa + dirn * PI / 2)
			push += (side * 1.4 + rel.normalized() * (1.6 if h["len"] < 90.0 else 0.6)) * 1.6
	return push


# ---- the hands, the floor dial's pips and stopped time's tidy-up
class Hands extends Node2D:
	var e: Enemy
	const OUT := Color("#21141b")
	const BRASS := Color("#facb3e")
	const BRASS_SH := Color("#c56025")
	const BRASS_HI := Color("#ffcc68")
	const GHOST := Color("#cae6f5")

	func _ready() -> void:
		z_index = -13
		material = Art.unshaded

	func _process(_dt: float) -> void:
		if e == null or not is_instance_valid(e) or not e.alive or e.world.finished:
			if e != null and is_instance_valid(e) and is_instance_valid(e.world):
				Keeper.cleanup(e.world)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for h in e.mem.get("hands", []):
			var st: String = h["st"]
			if st == "off":
				continue
			var d := Vector2.from_angle(h["a"])
			var tip: Vector2 = Keeper.PIVOT + d * minf(float(h["len"]), Keeper.reach(h["a"]) - 3.0)
			var tail: Vector2 = Keeper.PIVOT - d * 14.0
			var w: float = h["w"]
			if st == "ghost":
				if fmod(t, 0.24) < 0.14:
					var n := int((minf(float(h["len"]), Keeper.reach(h["a"]) - 3.0) - 14.0) / 3.0)
					for i in n:
						var p: Vector2 = Keeper.PIVOT + d * (14.0 + i * 3.0)
						draw_rect(Rect2(p.round(), Vector2.ONE * (2.0 if w > 4.0 else 1.0)), GHOST)
				continue
			if st == "fade" and fmod(t, 0.1) < 0.05:
				continue
			draw_line(tail, tip, OUT, w + 2.0)
			draw_line(tail, tip, BRASS_SH, w)
			var hi := d.orthogonal() * -0.5 * (w - 1.0)
			draw_line(tail + hi, tip + hi, BRASS, maxf(1.0, w - 2.0))
			if w > 4.0:
				draw_line(Keeper.PIVOT + d * 20.0 + hi, tip - d * 8.0 + hi, BRASS_HI, 1.0)
			# a spade point on the hour hand, an arrow on the minute hand
			var s := 4.0 if w > 4.0 else 3.0
			var pts := PackedVector2Array([tip + d * s, tip + d.orthogonal() * s, tip - d * s * 0.6, tip - d.orthogonal() * s])
			draw_colored_polygon(pts, OUT)
			var pts2 := PackedVector2Array([tip + d * (s - 1.5), tip + d.orthogonal() * (s - 1.5), tip - d * (s * 0.6 - 1.0), tip - d.orthogonal() * (s - 1.5)])
			draw_colored_polygon(pts2, BRASS)


# ---- stopped time's marks: which way each frozen bolt will fly, and three pips over the Keeper that go
# out one per tick. Drawn above the grey (in the effects layer), so they keep their colour.
class Marks extends Node2D:
	var e: Enemy

	func _ready() -> void:
		material = Art.unshaded

	func _process(_dt: float) -> void:
		if e == null or not is_instance_valid(e) or not e.alive:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if e.state != "stop":
			return
		var st: float = e.mem.get("stop_t", 0.0)
		var late := st > Keeper.STOP_TIME - 0.6
		var t := Time.get_ticks_msec() / 1000.0
		if not late or fmod(t, 0.16) < 0.1:
			for m in e.mem.get("marks", []):
				var s: Variant = m[0]
				if not is_instance_valid(s):
					continue
				var p: Vector2 = (s as Node2D).global_position - global_position
				var d: Vector2 = m[1]
				for k in 3:
					draw_rect(Rect2((p + d * (6.0 + 2.5 * k)).round(), Vector2.ONE), Keeper.PALE if k < 2 else Color("#72d6ce"))
		var pips: int = e.mem.get("pips", -1)
		var base: Vector2 = e.global_position - global_position + Vector2(-11, -68)
		for i in 3:
			var on := i < pips
			var p2 := base + Vector2(i * 9, 0)
			draw_rect(Rect2(p2 - Vector2(1, 1), Vector2(6, 6)), Color("#21141b"))
			draw_rect(Rect2(p2, Vector2(4, 4)), Color("#facb3e") if on else Color("#483b3a"))
			if on:
				draw_rect(Rect2(p2, Vector2(2, 1)), Color("#ffcc68"))


# ---- the hands on the Keeper's own face: they show the house clock (and run backwards in stopped time)
class Face extends Node2D:
	var e: Enemy
	var _back := 0.0

	func _process(dt: float) -> void:
		if e == null or not is_instance_valid(e):
			return
		if e.state == "stop":
			_back -= dt * 9.0
		queue_redraw()

	func _draw() -> void:
		if e == null or not is_instance_valid(e) or e.world == null:
			return
		var m: float = e.world.clock_minutes() if e.world.has_method("clock_minutes") else 0.0
		var am := fmod(m, 60.0) / 60.0 * TAU + _back
		var ah := fmod(m / 60.0, 12.0) / 12.0 * TAU + _back / 12.0
		var col := Color("#222222")
		_hand(am, 7.0, col)
		_hand(ah, 5.0, col)
		draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), Color("#c56025"))

	func _hand(a: float, ln: float, col: Color) -> void:
		var d := Vector2(sin(a), -cos(a))
		var n := int(ln)
		for i in n:
			var p := (d * i).round()
			draw_rect(Rect2(p, Vector2.ONE), col)


# ================================================================= COG SENTRY
func init_tower_cog(e: Enemy) -> void:
	e.mem["cross"] = randi() % 2
	e.mem["side"] = 1.0 if randf() < 0.5 else -1.0


## Keeps its distance, stops, shows four lanes (a + or an x) and fires a cog down each.
func tower_cog(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	var at := e.global_position + Vector2(0, -8)
	match e.state:
		"aim":
			if e.t <= 0:
				var base := 0.0 if e.mem["cross"] == 0 else PI / 4
				for k in 4:
					e.world.enemy_shot(at, Vector2.from_angle(base + k * PI / 2) * 72.0, "bolt_cog")
				Audio.play("enemy_shoot", -1.0, 0.08, 1.3)
				e.mem["cross"] = 1 - e.mem["cross"]
				e.state = "idle"
				e.cd = float(e.def.get("cd", 2.2)) * randf_range(0.85, 1.2)
		_:
			var want := Vector2.ZERO
			if dist > 80.0:
				want = to_p
			elif dist < 46.0:
				want = -to_p
			else:
				want = to_p.orthogonal() * e.mem["side"]
			e._walk(ddt, want, e.speed)
			if e.cd <= 0:
				e.state = "aim"
				e.t = 0.6
				e.play_anim("atk", 0.8)
				e._telegraph(Color(1, 0.45, 0.3))
				Audio.play("tick", -4.0, 0.05, 1.5)
				var base2 := 0.0 if e.mem["cross"] == 0 else PI / 4
				for k in 4:
					var d := Vector2.from_angle(base2 + k * PI / 2)
					e.tele().line(at + d * 6.0, at + d * 40.0, 0.6, WARN)


# ================================================================= MINUTE-HAND WRAITH
func init_tower_wraith(e: Enemy) -> void:
	e.mem["orbit"] = randf() * TAU
	e.cd = randf_range(1.2, 2.2)


## Drifts round you, aims its hand (a pale lane), lunges along it, fades and comes back elsewhere.
func tower_wraith(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	var p: Player = e.world.player
	match e.state:
		"aim":
			if e.t <= 0:
				e.state = "lunge"
				e.t = 0.7
				Audio.play("dodge", -2.0, 0.08, 0.8)
		"lunge":
			if not e._move(e.dir * 180.0 * ddt) or e.t <= 0:
				e.state = "fade"
				e.t = 0.35
				e.buried = true
				e.create_tween().tween_property(e.spr, "modulate:a", 0.15, 0.3)
		"fade":
			if e.t <= 0:
				e.global_position = e.free_spot(p.global_position, 60.0, 130.0)
				e.state = "appear"
				e.t = 0.4
				e.create_tween().tween_property(e.spr, "modulate:a", 1.0, 0.35)
		"appear":
			if e.t <= 0:
				e.buried = false
				e.state = "idle"
				e.cd = float(e.def.get("cd", 2.4)) * randf_range(0.8, 1.2)
		_:
			e.mem["orbit"] += ddt * 0.8
			var goal := p.global_position + Vector2.from_angle(e.mem["orbit"]) * 70.0
			var to_g := goal - e.global_position
			if to_g.length() > 3.0:
				e._move(to_g.normalized() * e.speed * ddt)
			if e.cd <= 0 and dist < 140.0:
				e.state = "aim"
				e.t = 0.65
				e.dir = to_p.normalized()
				e.play_anim("atk", 0.8)
				e._telegraph(PALE)
				var from := e.global_position + Vector2(0, -8)
				e.tele().line(from, from + e.dir * 126.0, 0.65, PALE)
