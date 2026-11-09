class_name GuardiansV21
extends RefCounted
## v2.1: one more guardian on every floor, so each floor has three (picked by the run seed, Enemy.pick_boss):
##   THE COAL FURNACE (Cellar)  fire jets down marked lanes, coal that smoulders on the floor, a vent-stall
##                              where it stands open and takes half again as much damage
##   THE OSSUARY (Crypt)        skull arcs, bone fans; falls apart into rolling skulls and pulls itself
##                              back together somewhere else
##   THE ORGANIST (Chapel)      pipes that play their lanes in order, sound rings with a marked safe gap, chords
##   THE WEATHERCOCK (Belfry)   wind gusts (streaks and arrows show the way first), spinning dart volleys, hops
## Same contract as BossAI: three phases (66% / 33%) with a roar and a banner line (Enemy.on_new_phase), only
## telegraphed attacks, the existing enemy shot kinds. Phase gate: Enemy._damage clamps every hit to
## mem.hp_floor, so a burst never skips a phase or its banner, and a phase lasts at least MIN_PHASE seconds.
## Hooks: enemy.gd sends ai "g21_*" here (one line); autotest.gd --boss=<kind> calls trial() / tour().

const RED := Color("#da4e38")
const PALE := Color("#cae6f5")
const MIN_PHASE := 3.0

static var _host: GuardiansV21


static func ai() -> GuardiansV21:
	if _host == null:
		_host = GuardiansV21.new()
	return _host


# ================================================================= shared
## The phase gate and the phase change. `busy`: never change phase now (the Ossuary in pieces). Returns
## true when a new phase began this frame (the roar takes over).
static func _phases(e: Enemy, ddt: float, busy := false) -> bool:
	e.mem["phase_t"] = float(e.mem.get("phase_t", 0.0)) + ddt
	e.mem["held_t"] = float(e.mem.get("held_t", 0.0)) - ddt
	var np := mini(e._boss_phase(), e.phase + 1)
	if np > e.phase and not busy and e.state != "roar" and float(e.mem["phase_t"]) >= MIN_PHASE:
		e.phase = np
		e.mem["phase_t"] = 0.0
		e.mem["seq"] = int(e.mem.get("seq", 0)) + 1   # queued notes / volleys of the old phase are dropped
		e.spr.speed_scale = 1.0
		e.spr.play("idle")
		e.spr.position = Vector2.ZERO
		e.on_new_phase()
		_set_floor(e)
		return true
	_set_floor(e)
	if e.mem.get("held", false):
		# a held hit (the gate) rings like iron so the player knows the damage is waiting
		e.mem["held"] = false
		if float(e.mem["held_t"]) <= 0.0:
			e.mem["held_t"] = 0.35
			Audio.play("hit_wall", -6.0, 0.1, 1.6)
	return false


static func _set_floor(e: Enemy) -> void:
	if e.phase < 3:
		e.mem["hp_floor"] = [0.0, 0.66, 0.33][e.phase] * e.max_hp - 0.5
	else:
		e.mem.erase("hp_floor")


static func _roar(e: Enemy) -> bool:
	if e.state == "roar":
		if e.t <= 0:
			e.state = "idle"
			e.cd = 0.7
		return true
	return false


static func _fan(e: Enemy, at: Vector2, base: float, n: int, spread: float, spd: float, kind: String) -> void:
	for i in n:
		e.world.enemy_shot(at, Vector2.from_angle(base + (i - (n - 1) / 2.0) * spread) * spd, kind)


## A guardian's hazard (jet, coal, rolling skull, landing) burns Tallow: blamed on the guardian (death note).
static func _hit(e: Enemy, dmg: float, from: Vector2) -> void:
	var p: Player = e.world.player
	if p.dead or e.world.freeze_t > 0.0:
		return
	Records.blame(e)
	p.hurt(dmg * e.world.enemy_dmg_mult(), p.global_position - from)


## How far from `from` along angle `a` before the room's walls.
static func _reach(e: Enemy, from: Vector2, a: float) -> float:
	var r: Rect2 = e.world.room.inner_rect()
	var d := Vector2.from_angle(a)
	var t := 400.0
	if d.x > 0.001:
		t = minf(t, (r.end.x - from.x) / d.x)
	elif d.x < -0.001:
		t = minf(t, (r.position.x - from.x) / d.x)
	if d.y > 0.001:
		t = minf(t, (r.end.y - from.y) / d.y)
	elif d.y < -0.001:
		t = minf(t, (r.position.y - from.y) / d.y)
	return maxf(t, 8.0)


## Enemy time for a hazard node: 0 while the boss card is up or time is frozen, slowed by slow auras.
static func _k(e: Enemy) -> float:
	if not is_instance_valid(e) or e.world == null or Juice.holding(e.world):
		return 0.0
	return e.world.time_scale_enemies()


static func _alive(e: Enemy) -> bool:
	return is_instance_valid(e) and e.alive and e.world != null and not e.world.finished


# ================================================================= THE COAL FURNACE (Cellar)
## Where the fire door (its mouth) and the stovepipe are, from its feet (40x40 art, tools/art_monsters_bosses.py).
const F_MOUTH := Vector2(0, -12)
const F_PIPE := Vector2(7, -38)


func init_g21_furnace(e: Enemy) -> void:
	_set_floor(e)
	e.cd = 1.4


func g21_furnace(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	if _phases(e, ddt):
		return
	if _roar(e):
		return
	var mouth := e.global_position + F_MOUTH
	match e.state:
		"idle":
			e._walk(ddt, to_p, e.speed * (1.0 + 0.25 * (e.phase - 1)))
			if e.cd <= 0:
				e._pattern += 1
				var opts: Array = [["jet", "coal", "jet", "vent"], ["jet", "coal", "jet", "coal", "vent"],
					["jet", "coal", "jet", "vent"]][e.phase - 1]
				match opts[(e._pattern - 1) % opts.size()]:
					"jet":
						_furnace_jet_tell(e, mouth)
					"coal":
						_furnace_coal_tell(e)
					_:
						_furnace_vent(e)
		"jet_tell":
			if e.t <= 0:
				e.state = "jet"
				e.t = [0.0, 0.6, 0.7, 0.8][e.phase]
				for a in e.mem["lanes"]:
					FireJet.fire(e, mouth, a, e.t)
				Audio.play("burn_whoosh", 0.0, 0.05, 0.8)
				e.world.shake(2.0)
		"jet":
			if e.t <= 0:
				e.state = "rest"
				e.t = 0.5
		"coal_tell":
			if e.t <= 0:
				var from := e.global_position + F_PIPE
				for tgt in e.mem["coal"]:
					CoalLob.throw(e, from, tgt, 0.9, [0.0, 4.0, 4.5, 4.5][e.phase])
				Audio.play("explosion", -10.0, 0.05, 1.4)
				e.world.fx_smoke(from + Vector2(0, -4))
				e.state = "rest"
				e.t = 0.7
		"vent":
			_furnace_venting(e, ddt)
		"rest":
			if e.t <= 0:
				e.state = "idle"
				e.cd = [0.0, 1.0, 0.9, 0.8][e.phase]


## Fire jets: the door swings open, the lanes blink red, then the fire comes (one lane, two, then three).
static func _furnace_jet_tell(e: Enemy, mouth: Vector2) -> void:
	var p: Player = e.world.player
	var a := (p.global_position + Vector2(0, -6) - mouth).angle()
	var lanes: Array = [a]
	if e.phase == 2:
		lanes.append(a + (0.7 if randf() < 0.5 else -0.7))
	elif e.phase >= 3:
		lanes = [a - 0.6, a, a + 0.6]
	e.mem["lanes"] = lanes
	e.state = "jet_tell"
	e.t = [0.0, 0.9, 0.8, 0.75][e.phase]
	e.play_anim("atk", e.t + 0.8)
	e._telegraph(Color(1, 0.6, 0.3))
	for l in lanes:
		e.tele().line(mouth, mouth + Vector2.from_angle(l) * _reach(e, mouth, l), e.t, RED)
	Audio.play("fire_crackle", 0.0, 0.05, 0.8)


## Coal: the stovepipe coughs lumps that land where the red rings are and smoulder for a while.
static func _furnace_coal_tell(e: Enemy) -> void:
	var p: Player = e.world.player
	var n: int = [0, 3, 4, 5][e.phase]
	var pts: Array = [p.global_position]
	for i in n - 1:
		pts.append(e.free_spot(p.global_position, 26.0, 70.0))
	e.mem["coal"] = pts
	for q in pts:
		e.tele().ring(q, 9.0, 1.4, RED)
	e.state = "coal_tell"
	e.t = 0.5
	e._telegraph(Color(1, 0.7, 0.4))
	e.world.fx_smoke(e.global_position + F_PIPE + Vector2(0, -4))
	Audio.play("fire_crackle", 2.0, 0.05, 0.6)


## The vent-stall: it runs out of draw, the door hangs open and it stands still, venting steam. Every hit
## lands half again as hard ("venting!"). In phase 3 it ends with a ring of cinders (a red ring first).
static func _furnace_vent(e: Enemy) -> void:
	e.state = "vent"
	e.t = [0.0, 2.4, 2.2, 2.0][e.phase] + (0.6 if e.phase >= 3 else 0.0)
	e.spr.play("mound")
	e._anim_lock = e.t
	e.mem["vent_hp"] = e.hp
	e.mem["vent_tell"] = false
	e.mem["puff"] = 0.0
	e.world.fx_text(e.global_position + Vector2(0, -46), "venting!", UI.GOLD)
	Audio.play("sizzle", 2.0, 0.05, 0.7)


static func _furnace_venting(e: Enemy, ddt: float) -> void:
	var lost: float = float(e.mem["vent_hp"]) - e.hp
	if lost > 0.0:
		e._damage(lost * 0.5, false)
		if not e.alive:
			return
	e.mem["vent_hp"] = e.hp
	e.mem["puff"] = float(e.mem["puff"]) - ddt
	if float(e.mem["puff"]) <= 0.0:
		e.mem["puff"] = 0.3
		e.world.fx_smoke(e.global_position + F_PIPE + Vector2(0, -3))
		e.world.fx_smoke(e.global_position + F_MOUTH + Vector2(randf_range(-6, 6), -2))
	if e.phase >= 3 and e.t <= 0.6 and not e.mem["vent_tell"]:
		e.mem["vent_tell"] = true
		e.tele().ring(e.global_position + Vector2(0, -14), 30.0, 0.6, RED)
		e._telegraph(Color(1, 0.5, 0.3))
		Audio.play("charge", -4.0, 0.05, 0.8)
	if e.t <= 0:
		if e.phase >= 3:
			e.world.burst(e.global_position + Vector2(0, -14), 12, 60.0, "bullet_purple", randf() * TAU)
			e.world.shake(3.0)
			Audio.play("explosion", -6.0, 0.05, 0.9)
		e.spr.play("idle")
		e._anim_lock = 0.0
		e.state = "idle"
		e.cd = 0.8


## A jet of fire from the furnace door: grows along its lane to the wall, burns, then dies back.
class FireJet extends Node2D:
	const GROW := 520.0
	const COLS := [Color("#21141b"), Color("#da4e38"), Color("#ee8e2e"), Color("#facb3e")]
	var e: Enemy
	var from := Vector2.ZERO
	var dir := Vector2.RIGHT
	var reach := 100.0
	var life := 0.6
	var age := 0.0
	var cur := 0.0
	var tail := 0.0

	static func fire(owner_e: Enemy, at: Vector2, a: float, dur: float) -> void:
		var j := FireJet.new()
		j.e = owner_e
		j.from = at
		j.dir = Vector2.from_angle(a)
		j.reach = GuardiansV21._reach(owner_e, at, a)
		j.life = dur
		owner_e.world.fx_layer.add_child(j)

	func _ready() -> void:
		material = Art.unshaded
		z_index = -2

	func _half(d: float) -> float:
		return 2.0 + minf(3.0, d / 40.0)   # it widens as it goes

	func _physics_process(dt: float) -> void:
		if not GuardiansV21._alive(e):
			queue_free()
			return
		dt *= GuardiansV21._k(e)
		age += dt
		if age < life:
			cur = minf(reach, cur + GROW * dt)
		else:
			tail += GROW * 1.6 * dt     # it dies back from the door
			if tail >= cur:
				queue_free()
				return
		queue_redraw()
		var p: Player = e.world.player
		var c := p.global_position + Vector2(0, -6)
		var q := Geometry2D.get_closest_point_to_segment(c, from + dir * tail, from + dir * cur)
		if c.distance_to(q) < _half(q.distance_to(from)) + 3.0:
			GuardiansV21._hit(e, 8.0, q)

	func _draw() -> void:
		var flick := int(age * 24.0)
		for layer in 4:
			var d := maxf(4.0, tail)
			var i := 0
			while d < cur:
				var hw := _half(d) + (1.0 if (flick + i) % 3 == 0 else 0.0)
				var s := hw * 2.0 + 2.0 - layer * 2.0
				if s > 0.5:
					var p := from + dir * d
					draw_rect(Rect2((p - Vector2(s, s) * 0.5).round(), Vector2(s, s).round()), COLS[layer])
				d += 3.0
				i += 1


## A lump of coal coughed out of the stovepipe: it arcs to its ring and lands as a CoalBed.
class CoalLob extends Node2D:
	var e: Enemy
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var dur := 0.9
	var life := 4.0
	var age := 0.0

	static func throw(owner_e: Enemy, from: Vector2, to: Vector2, d: float, bed_life: float) -> void:
		var c := CoalLob.new()
		c.e = owner_e
		c.a = from
		c.b = to
		c.dur = d
		c.life = bed_life
		c.position = from
		owner_e.world.fx_layer.add_child(c)

	func _ready() -> void:
		material = Art.unshaded

	func _physics_process(dt: float) -> void:
		if not GuardiansV21._alive(e):
			queue_free()
			return
		age += dt * GuardiansV21._k(e)
		var f := clampf(age / dur, 0.0, 1.0)
		position = (a.lerp(b, f) + Vector2(0, -sin(f * PI) * 46.0)).round()
		queue_redraw()
		if f >= 1.0:
			CoalBed.drop(e, b, life)
			Audio.play("thud_heavy", -8.0, 0.1, 1.3)
			queue_free()

	func _draw() -> void:
		var tumble := int(age * 10.0) % 2
		draw_rect(Rect2(-3, -2, 6, 5), Color("#21141b"))
		draw_rect(Rect2(-2, -1, 4, 3), Color("#2a2a3a"))
		draw_rect(Rect2(-1 + tumble, -1, 1, 1), Color("#facb3e"))
		draw_rect(Rect2(1 - tumble, 0, 1, 1), Color("#e46e33"))


## A coal smouldering on the floor (the room's floor layer): standing on it burns. It dims and blinks
## before it goes out, and goes out at once when the furnace falls.
class CoalBed extends Node2D:
	var e: Enemy
	var life := 4.0
	var age := 0.0
	var _f := -1

	static func drop(owner_e: Enemy, at: Vector2, l: float) -> void:
		var room: Room = owner_e.world.room
		if room == null or not is_instance_valid(room.floor_layer):
			return
		var c := CoalBed.new()
		c.e = owner_e
		c.life = l
		c.position = (at - room.position).round()
		room.floor_layer.add_child(c)
		owner_e.world.fx_debris(at, "R")

	func _ready() -> void:
		material = Art.unshaded

	func _physics_process(dt: float) -> void:
		if not GuardiansV21._alive(e):
			queue_free()
			return
		age += dt * GuardiansV21._k(e)
		if age >= life:
			queue_free()
			return
		var f := int(age * 6.0)
		if f != _f:
			_f = f
			queue_redraw()
		if age < life - 0.25:
			var d: Vector2 = e.world.player.global_position - global_position
			if absf(d.x) < 7.0 and absf(d.y) < 5.0:
				GuardiansV21._hit(e, 6.0, global_position)

	func _draw() -> void:
		var cooling := age > life - 0.9
		if cooling and _f % 2 == 1:
			return
		var hot := Color("#facb3e") if not cooling else Color("#8f4029")
		var warm := Color("#e46e33") if not cooling else Color("#62232f")
		# a faint heat ring so the burning patch reads on any floor
		if not cooling:
			for i in 14:
				if (i + _f) % 2 == 0:
					var ang := TAU * i / 14.0
					draw_rect(Rect2(Vector2(cos(ang) * 8.0, sin(ang) * 4.8).round(), Vector2.ONE), Color("#da4e38"))
		draw_rect(Rect2(-4, -2, 8, 4), Color("#21141b"))
		draw_rect(Rect2(-3, -3, 5, 1), Color("#21141b"))
		draw_rect(Rect2(-3, -2, 6, 3), Color("#2a2a3a"))
		draw_rect(Rect2(-2, -1, 2, 1), warm)
		draw_rect(Rect2(1, -1, 1, 1), hot if _f % 3 != 0 else warm)
		draw_rect(Rect2(-1, 0, 1, 1), hot)


# ================================================================= THE OSSUARY (Crypt)
## The great skull (where bone fans come from) and the raised hand's skull (atk frame 0), from its feet.
const O_SKULL := Vector2(-1, -27)
const O_HAND := Vector2(16, -33)


func init_g21_ossuary(e: Enemy) -> void:
	_set_floor(e)
	e.cd = 1.2


func g21_ossuary(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	if _phases(e, ddt, e.state in ["split", "out", "back_tell", "back", "reform"]):
		return
	if _roar(e):
		return
	var p: Player = e.world.player
	match e.state:
		"idle":
			var want := to_p if dist > 76 else (-to_p if dist < 40 else to_p.orthogonal() * (1.0 if sin(e._wob) > 0 else -1.0))
			e._wob += ddt * 0.7
			e._walk(ddt, want, e.speed * (1.0 + 0.15 * e.phase))
			if e.cd <= 0:
				e._pattern += 1
				var opts: Array = [["skulls", "fan", "skulls", "fan"], ["skulls", "fan", "split", "fan"],
					["split", "skulls", "fan", "skulls", "fan"]][e.phase - 1]
				match opts[(e._pattern - 1) % opts.size()]:
					"skulls":
						e.state = "skulls_tell"
						e.t = 0.6
						e.play_anim("atk", 0.0)
						e.spr.pause()
						e.spr.frame = 0
						e._telegraph(Color(0.7, 1.0, 0.95))
						Audio.play("charge", -6.0, 0.05, 1.2)
					"fan":
						e.state = "fan_tell"
						e.t = 0.5
						e._telegraph(Color(1, 1, 0.85))
						Audio.play("urn_break", -10.0, 0.05, 1.6)
					_:
						e.state = "split_tell"
						e.t = 0.7
						e._telegraph(Color(0.7, 1.0, 0.95))
						Audio.play("urn_break", -2.0, 0.05, 0.7)
		"skulls_tell":
			if e.t <= 0:
				e.spr.frame = 1
				var n: int = [0, 3, 3, 4][e.phase]
				var seq: int = e.mem.get("seq", 0)
				for i in n:
					e.later(0.2 * i, func():
						if int(e.mem.get("seq", 0)) != seq:
							return
						var tgt: Vector2 = e.world.player.global_position
						if i > 0:
							tgt = e.free_spot(tgt, 18.0, 46.0)
						SkullLob.throw(e, e.global_position + O_HAND, tgt, 0.85, [0, 5, 6, 6][e.phase])
						Audio.play("enemy_shoot", -2.0, 0.05, 0.7))
				e.state = "rest"
				e.t = 0.4 + 0.2 * n
		"fan_tell":
			if e.t <= 0:
				var at := e.global_position + O_SKULL
				var n: int = [0, 5, 6, 7][e.phase]
				_fan(e, at, (p.global_position + Vector2(0, -6) - at).angle(), n, 0.24, 80.0 + 4.0 * e.phase, "bolt_bone")
				Audio.play("enemy_shoot", 0.0, 0.05, 0.9)
				e.state = "rest"
				e.t = 0.5
		"split_tell":
			e.spr.position.x = sin(e.t * 70.0) * 1.5
			if e.t <= 0:
				e.spr.position.x = 0
				_ossuary_split(e)
		"split":
			if e.t <= 0:
				# the skulls roll out down their lanes
				for s in e.mem["skulls"]:
					var sk: RollSkull = s
					if is_instance_valid(sk):
						sk.go(sk.get_meta("goal"), 120.0)
				Audio.play("crate_break", -4.0, 0.05, 0.8)
				e.state = "out"
				e.t = 1.6
		"out":
			if e.t <= 0 or _skulls_still(e):
				# where it pulls itself together: well away from Tallow
				var b := e.free_spot(p.global_position, 70.0, 150.0)
				e.mem["reform"] = b
				e.tele().ring(b, 22.0, 0.8, RED)
				for s in e.mem["skulls"]:
					if is_instance_valid(s):
						e.tele().line((s as Node2D).global_position, b, 0.8, RED)
				e.state = "back_tell"
				e.t = 0.8
				Audio.play("summon", -6.0, 0.05, 0.8)
		"back_tell":
			if e.t <= 0:
				for s in e.mem["skulls"]:
					if is_instance_valid(s):
						(s as RollSkull).go(e.mem["reform"], 130.0)
				e.state = "back"
				e.t = 1.6
		"back":
			if e.t <= 0 or _skulls_still(e):
				for s in e.mem["skulls"]:
					if is_instance_valid(s):
						(s as Node).queue_free()
				e.mem["skulls"] = []
				e.global_position = e.mem["reform"]
				e.spr.play("rise")
				e._anim_lock = 0.7
				e.state = "reform"
				e.t = 0.6
				Audio.play("summon", 0.0, 0.05, 0.6)
		"reform":
			if e.t <= 0:
				e.buried = false
				e.active = true
				e.world.burst(e.global_position + Vector2(0, -16), [0, 8, 8, 12][e.phase], 62.0, "bolt_bone", randf() * TAU)
				e.world.shake(4.0)
				Audio.play("explosion", -6.0, 0.05, 0.8)
				e.state = "rest"
				e.t = 0.6
		"rest":
			if e.t <= 0:
				if e.spr.animation != "idle":
					e.spr.play("idle")
				e.state = "idle"
				e.cd = [0.0, 1.0, 0.9, 0.7][e.phase]


## Falls apart: the heap drops into a spill of bones (untouchable), and its skulls get ready to roll down
## red lanes fanned round Tallow.
static func _ossuary_split(e: Enemy) -> void:
	e.buried = true
	e.active = false
	e.spr.play("mound")
	e._anim_lock = 0.0
	e.world.fx_debris(e.global_position, "R")
	e.world.fx_debris(e.global_position + Vector2(8, 0), "R")
	e.world.shake(3.0)
	Audio.play("urn_break", 2.0, 0.05, 0.6)
	var p: Player = e.world.player
	var base := (p.global_position - e.global_position).angle()
	var n: int = [0, 4, 4, 6][e.phase]
	var spread := 0.5 if n <= 4 else 0.42
	var skulls: Array = []
	var room: Room = e.world.room
	for i in n:
		var a := base + (i - (n - 1) / 2.0) * spread
		var from := e.global_position + Vector2.from_angle(a) * 8.0
		var to := from + Vector2.from_angle(a) * (_reach(e, from, a) - 6.0)
		e.tele().line(from, to, 0.75, RED)
		var sk := RollSkull.new()
		sk.e = e
		sk.set_meta("goal", to)
		room.objects.add_child(sk)
		sk.global_position = from
		skulls.append(sk)
	e.mem["skulls"] = skulls
	e.state = "split"
	e.t = 0.75


static func _skulls_still(e: Enemy) -> bool:
	for s in e.mem.get("skulls", []):
		if is_instance_valid(s) and (s as RollSkull).moving:
			return false
	return true


## One of the Ossuary's skulls, rolling down its lane (y-sorted with everyone in the room).
class RollSkull extends Node2D:
	var e: Enemy
	var goal := Vector2.ZERO
	var speed := 120.0
	var moving := false
	var roll := 0.0
	var spr: Sprite2D
	var frames: Array = []

	func _ready() -> void:
		frames = Art.seq("monsters/ossuary_roll")
		spr = Sprite2D.new()
		spr.texture = frames[0] if not frames.is_empty() else null
		spr.offset = Vector2(0, -5)
		spr.material = Art.unshaded
		add_child(spr)

	func go(to: Vector2, spd: float) -> void:
		goal = to
		speed = spd
		moving = true
		spr.flip_h = to.x < global_position.x

	func _physics_process(dt: float) -> void:
		if not GuardiansV21._alive(e):
			queue_free()
			return
		dt *= GuardiansV21._k(e)
		if moving:
			var to := goal - global_position
			var step := speed * dt
			if to.length() <= step:
				global_position = goal
				moving = false
			else:
				global_position += to.normalized() * step
			roll += step / 4.0
			if not frames.is_empty():
				spr.texture = frames[int(roll) % frames.size()]
		var p: Player = e.world.player
		if (p.global_position + Vector2(0, -5)).distance_to(global_position + Vector2(0, -5)) < 8.0:
			GuardiansV21._hit(e, 6.0, global_position)

	func _draw() -> void:
		draw_rect(Rect2(-3, -1, 7, 2), Color(0.13, 0.08, 0.1, 0.45))


## A skull thrown in an arc: it lands on its red ring and bursts into bone shards.
class SkullLob extends Node2D:
	var e: Enemy
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var dur := 0.85
	var n := 5
	var age := 0.0
	var spr: Sprite2D
	var frames: Array = []

	static func throw(owner_e: Enemy, from: Vector2, to: Vector2, d: float, shards: int) -> void:
		var s := SkullLob.new()
		s.e = owner_e
		s.a = from
		s.b = to
		s.dur = d
		s.n = shards
		s.position = from
		owner_e.world.fx_layer.add_child(s)
		owner_e.tele().ring(to, 12.0, d, GuardiansV21.RED)

	func _ready() -> void:
		frames = Art.seq("monsters/ossuary_roll")
		spr = Sprite2D.new()
		spr.texture = frames[0] if not frames.is_empty() else null
		spr.material = Art.unshaded
		add_child(spr)

	func _physics_process(dt: float) -> void:
		if not GuardiansV21._alive(e):
			queue_free()
			return
		age += dt * GuardiansV21._k(e)
		var f := clampf(age / dur, 0.0, 1.0)
		position = (a.lerp(b, f) + Vector2(0, -sin(f * PI) * 40.0)).round()
		if not frames.is_empty():
			spr.texture = frames[int(age * 12.0) % frames.size()]
		if f >= 1.0:
			e.world.burst(b + Vector2(0, -4), n, 64.0, "bolt_bone", randf() * TAU)
			e.world.fx_debris(b, "R")
			Audio.play("crate_break", -6.0, 0.1, 1.2)
			queue_free()


# ================================================================= THE ORGANIST (Chapel)
## Its seven pipe mouths (x from its feet; art: ORGAN_PIPES in tools/art_monsters_bosses.py, 48x50 sprite).
const PIPES_X := [-13, -9, -5, -1, 3, 7, 11]
const PIPE_Y := -31
## Where its sound rings start (the carved face).
const ORGAN_FACE := Vector2(0, -22)


## Each pipe always plays down the same lane, fanning across the chapel from left to right.
static func _pipe_angle(i: int) -> float:
	return deg_to_rad(lerpf(150.0, 30.0, i / 6.0))


static func _pipe_at(e: Enemy, i: int) -> Vector2:
	return e.global_position + Vector2(PIPES_X[i], PIPE_Y)


func init_g21_organist(e: Enemy) -> void:
	_set_floor(e)
	e.mem["lit"] = {}
	e.mem["up"] = true
	e.cd = 1.3
	var o := PipeLights.new()
	o.e = e
	e.add_child(o)


func g21_organist(e: Enemy, ddt: float, _to_p: Vector2, _dist: float) -> void:
	if _phases(e, ddt):
		e.mem["lit"] = {}
		return
	if _roar(e):
		return
	var p: Player = e.world.player
	if e.state in ["idle", "rest"]:
		# it keeps to the top of the chapel, sliding across to stay over Tallow
		var room: Room = e.world.room
		var goal := Vector2(clampf(p.global_position.x, room.position.x + 84, room.position.x + 188), room.position.y + 80)
		var d := goal - e.global_position
		if d.length() > 3.0:
			e._move(d.normalized() * e.speed * ddt)
	match e.state:
		"idle":
			if e.cd <= 0:
				e._pattern += 1
				var opts: Array = [["scale", "ring", "scale", "ring"], ["chord", "ring", "scale", "chord", "ring"],
					["toccata", "ring", "chord", "ring"]][e.phase - 1]
				match opts[(e._pattern - 1) % opts.size()]:
					"scale":
						var order: Array = range(7) if e.mem["up"] else range(6, -1, -1)
						e.mem["up"] = not e.mem["up"]
						_organ_play(e, order, 0.24, 0.6)
					"toccata":
						var order2: Array = range(7)
						order2.append_array(range(5, -1, -1))
						_organ_play(e, order2, 0.18, 0.55)
					"chord":
						_organ_chords(e)
					_:
						_organ_ring(e)
		"playing":
			if e.t <= 0:
				e.spr.play("idle")
				e.state = "rest"
				e.t = 0.5
		"ring_tell":
			if e.t <= 0:
				_organ_ring_fire(e)
				if e.phase >= 3 and not e.mem.get("second", false):
					# phase 3: a second ring follows, its gap on the other side
					e.mem["second"] = true
					e.mem["gap"] = float(e.mem["gap"]) - float(e.mem["gap_off"]) * 2.0
					_organ_ring_mark(e, 0.9)
				else:
					e.mem["second"] = false
					e.spr.play("idle")
					e.state = "rest"
					e.t = 0.7
		"rest":
			if e.t <= 0:
				e.state = "idle"
				e.cd = [0.0, 1.2, 1.0, 0.9][e.phase]


## A run of notes: each pipe lights and its lane blinks for `lead` seconds, then it plays three notes
## down the lane. Lanes come one after another, so there is always a clear stretch between them.
static func _organ_play(e: Enemy, order: Array, step: float, lead: float) -> void:
	var seq: int = e.mem.get("seq", 0)
	e.play_anim("atk", 0.0)
	e.spr.pause()
	e.spr.frame = 0
	e._telegraph(Color(1, 0.9, 0.7))
	for k in order.size():
		var i: int = order[k]
		e.later(step * k, func():
			if int(e.mem.get("seq", 0)) == seq:
				_pipe_tell(e, i, lead))
		e.later(step * k + lead, func():
			if int(e.mem.get("seq", 0)) == seq:
				e.spr.frame = 1
				_pipe_fire(e, i, 3))
	e.state = "playing"
	e.t = step * order.size() + lead + 0.4


static func _pipe_tell(e: Enemy, i: int, lead: float) -> void:
	var at := _pipe_at(e, i)
	var a := _pipe_angle(i)
	e.tele().line(at + Vector2.from_angle(a) * 4.0, at + Vector2.from_angle(a) * _reach(e, at, a), lead, RED)
	(e.mem["lit"] as Dictionary)[i] = lead + 0.2
	Audio.play("bell_small", -10.0, 0.0, 0.7 + 0.12 * i)


static func _pipe_fire(e: Enemy, i: int, n: int) -> void:
	var at := _pipe_at(e, i)
	var v := Vector2.from_angle(_pipe_angle(i)) * 94.0
	for j in n:
		e.later(0.07 * j, func(): e.world.enemy_shot(at, v, "bullet_water"))
	Audio.play("enemy_shoot", -4.0, 0.05, 0.6 + 0.1 * i)


## Chords: three (or four) pipes sound at once, their lanes marked together; then another chord.
static func _organ_chords(e: Enemy) -> void:
	var seq: int = e.mem.get("seq", 0)
	var chords: Array = [[0, 3, 6], [1, 4], [2, 5]] if e._pattern % 2 == 0 else [[1, 3, 5], [0, 2, 4, 6]]
	if e.phase < 3:
		chords = chords.slice(0, 2)
	e.spr.play("sing")
	e.spr.pause()
	e.spr.frame = 0
	e._telegraph(Color(1, 0.9, 0.7))
	var lead := 0.75
	for c in chords.size():
		var chord: Array = chords[c]
		e.later(1.1 * c, func():
			if int(e.mem.get("seq", 0)) == seq:
				for i in chord:
					_pipe_tell(e, i, lead))
		e.later(1.1 * c + lead, func():
			if int(e.mem.get("seq", 0)) == seq:
				e.spr.frame = 1
				for i in chord:
					_pipe_fire(e, i, 4)
				e.world.shake(2.0))
	e.state = "playing"
	e.t = 1.1 * chords.size() + 0.4


## A ring of sound with a safe gap: the gap is marked first (two pale lines either side of it on a dotted
## ring). Phase 1: the gap is where Tallow stands; later it is off to one side, so you have to move into it.
static func _organ_ring(e: Enemy) -> void:
	var p: Player = e.world.player
	var at := e.global_position + ORGAN_FACE
	var off := 0.0 if e.phase == 1 else (0.85 if randf() < 0.5 else -0.85)
	e.mem["gap_off"] = off
	e.mem["gap"] = (p.global_position + Vector2(0, -6) - at).angle() + off
	e.mem["second"] = false
	e.spr.play("sing")
	e.spr.pause()
	e.spr.frame = 0
	e._telegraph(Color(0.85, 0.95, 1.0))
	_organ_ring_mark(e, 1.0)


static func _organ_ring_mark(e: Enemy, dur: float) -> void:
	var at := e.global_position + ORGAN_FACE
	var gap: float = e.mem["gap"]
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		if absf(angle_difference(a, gap)) > 0.55:
			pts.append(at + Vector2(cos(a), sin(a)) * 28.0)
	e.tele().path(pts, dur, Color("#f78697"))
	for s in [-1.0, 1.0]:
		var a2: float = gap + float(s) * 0.55
		e.tele().line(at + Vector2.from_angle(a2) * 28.0, at + Vector2.from_angle(a2) * 70.0, dur, PALE)
	e.state = "ring_tell"
	e.t = dur
	Audio.play("bell_toll", -10.0, 0.05, 1.6)


static func _organ_ring_fire(e: Enemy) -> void:
	var at := e.global_position + ORGAN_FACE
	var gap: float = e.mem["gap"]
	var n := 22
	for i in n:
		var a := TAU * i / n + gap
		if absf(angle_difference(a, gap)) > 0.5:
			e.world.enemy_shot(at, Vector2.from_angle(a) * 46.0, "bolt_ring")
	e.spr.frame = 1
	Audio.play("bell_toll", -4.0, 0.05, 1.2)


## The pipe that is about to play lights up (drawn over the organ, unlit, so it reads in the dark).
class PipeLights extends Node2D:
	var e: Enemy

	func _ready() -> void:
		material = Art.unshaded
		z_index = 1

	func _physics_process(dt: float) -> void:
		if not is_instance_valid(e) or not e.alive:
			return
		var lit: Dictionary = e.mem.get("lit", {})
		if lit.is_empty():
			if visible:
				visible = false
			return
		visible = true
		for k in lit.keys():
			lit[k] = float(lit[k]) - dt * GuardiansV21._k(e)
			if float(lit[k]) <= 0.0:
				lit.erase(k)
		queue_redraw()

	func _draw() -> void:
		for k in e.mem.get("lit", {}).keys():
			var x: int = GuardiansV21.PIPES_X[k]
			var y := GuardiansV21.PIPE_Y
			draw_rect(Rect2(x - 2, y - 2, 5, 4), Color("#21141b"))
			draw_rect(Rect2(x - 1, y - 1, 3, 2), Color("#facb3e"))
			draw_rect(Rect2(x, y - 1, 1, 2), Color("#fdf7ed"))


# ================================================================= THE WEATHERCOCK (Belfry)
## Where its darts leave (the arrow it stands on) and its body, from its feet (44x52 art).
const W_ARROW := Vector2(0, -23)
const W_BODY := Vector2(-1, -36)


func init_g21_weathercock(e: Enemy) -> void:
	_set_floor(e)
	e.cd = 1.4


func g21_weathercock(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	if _phases(e, ddt, e.state == "hop"):
		return
	if _roar(e):
		return
	var p: Player = e.world.player
	match e.state:
		"idle":
			var want := to_p if dist > 92 else (-to_p if dist < 50 else to_p.orthogonal() * (1.0 if sin(e._wob) > 0 else -1.0))
			e._wob += ddt * 0.6
			e._walk(ddt, want, e.speed * (1.0 + 0.1 * e.phase))
			e.spr.flip_h = to_p.x < 0
			if e.cd <= 0:
				e._pattern += 1
				var opts: Array = [["gust", "spin", "hop", "spin"], ["gust", "spin", "hop", "gust", "spin"],
					["storm", "spin", "hop", "spin"]][e.phase - 1]
				match opts[(e._pattern - 1) % opts.size()]:
					"gust", "storm":
						_cock_gust(e)
					"spin":
						e.state = "spin_tell"
						e.t = 0.7
						e.spr.play("grab")
						e.spr.speed_scale = 1.6
						e._anim_lock = 9.0
						e._telegraph(Color(1, 0.95, 0.75))
						Audio.play("charge_up", -4.0, 0.05, 1.2)
					_:
						_cock_hop_tell(e)
		"gust_tell":
			if e.t <= 0:
				e.spr.speed_scale = 1.0
				e.play_anim("atk", 1.0)
				e.spr.flip_h = (e.mem["wind"] as Vector2).x < 0
				e.state = "gusting"
				e.t = float(e.mem["blow"])
				e.mem["volley"] = 0.6
				e.mem["spin_a"] = randf() * TAU
				Audio.play("burn_whoosh", 2.0, 0.05, 0.6)
		"gusting":
			if e.phase == 2:
				# aimed volleys of three darts while the wind blows (each flashes first)
				e.mem["volley"] = float(e.mem["volley"]) - ddt
				if float(e.mem["volley"]) <= 0.35 and not e.mem.get("flashed", false):
					e.mem["flashed"] = true
					e._telegraph(Color(1, 0.95, 0.75))
				if float(e.mem["volley"]) <= 0.0:
					e.mem["volley"] = 0.95
					e.mem["flashed"] = false
					var at := e.global_position + W_ARROW
					_fan(e, at, (p.global_position + Vector2(0, -6) - at).angle(), 3, 0.2, 80.0, "bolt_bone")
					Audio.play("enemy_shoot", -2.0, 0.05, 1.1)
			elif e.phase >= 3:
				_cock_spray(e, ddt, 2, 1.6, 70.0)   # the storm: a slow two-armed spiral in the gale
			if e.t <= 0:
				e.state = "rest"
				e.t = 0.6
		"spin_tell":
			if e.t <= 0:
				e.state = "spinning"
				e.t = [0.0, 2.0, 2.2, 2.4][e.phase]
				e.spr.speed_scale = 2.4
				e.mem["spin_a"] = randf() * TAU
				e.mem["volley"] = 0.0
				Audio.play("burn_whoosh", -2.0, 0.05, 1.3)
		"spinning":
			_cock_spray(e, ddt, [0, 2, 3, 4][e.phase], 2.3, 78.0)
			if e.t <= 0:
				e.spr.speed_scale = 1.0
				e._anim_lock = 0.0
				e.spr.play("idle")
				e.state = "rest"
				e.t = 0.6
		"hop_tell":
			if e.t <= 0:
				e.state = "hop"
				e.t = 0.55
				e.mem["hop_a"] = e.global_position
				e.play_anim("run", 0.6)
				Audio.play("moth_flutter", 0.0, 0.05, 0.6)
		"hop":
			var f := clampf(1.0 - e.t / 0.55, 0.0, 1.0)
			e.global_position = (e.mem["hop_a"] as Vector2).lerp(e.mem["hop_b"], f)
			e._jump_h = sin(f * PI) * 30.0
			if e.t <= 0:
				e._jump_h = 0.0
				var at2: Vector2 = e.mem["hop_b"]
				e.world.burst(at2 + Vector2(0, -6), [0, 10, 12, 14][e.phase], 66.0, "bullet_purple", randf() * TAU)
				e.world.shake(5.0)
				e.world.fx_debris(at2, "R")
				Audio.play("thud_heavy", 0.0, 0.05, 0.8)
				if (p.global_position).distance_to(at2) < 18.0:
					_hit(e, 8.0, at2)
				e.state = "rest"
				e.t = 0.7
		"rest":
			if e.t <= 0:
				if e.spr.animation != "idle":
					e.spr.play("idle")
				e.state = "idle"
				e.cd = [0.0, 0.9, 0.8, 0.7][e.phase]


## Darts from the turning vane: `arms` streams that turn at `turn` rad/s.
static func _cock_spray(e: Enemy, ddt: float, arms: int, turn: float, spd: float) -> void:
	e.mem["spin_a"] = float(e.mem["spin_a"]) + turn * ddt
	e.mem["volley"] = float(e.mem["volley"]) - ddt
	if float(e.mem["volley"]) <= 0.0:
		e.mem["volley"] = 0.14
		var at := e.global_position + W_ARROW
		for k in arms:
			e.world.enemy_shot(at, Vector2.from_angle(float(e.mem["spin_a"]) + TAU * k / arms) * spd, "bolt_bone")


## The wind: the vane spins round and settles to point the way it will blow; streaks start drifting that
## way across the whole belfry and big pale arrows blink over the room. Then the gale pushes Tallow
## (slower than he walks, so he can always fight it).
static func _cock_gust(e: Enemy) -> void:
	var p: Player = e.world.player
	var room: Room = e.world.room
	# blow him toward the middle of the room, never pin him in a corner
	var want := room.center() - p.global_position
	var dirs: Array = [Vector2.LEFT, Vector2.RIGHT]
	if e.phase >= 2:
		dirs = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized(),
			Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	var best: Vector2 = dirs[randi() % dirs.size()]
	if want.length() > 30.0:
		var bd := -9.0
		for d in dirs:
			var s: float = (d as Vector2).dot(want.normalized()) + randf() * 0.4
			if s > bd:
				bd = s
				best = d
	e.mem["wind"] = best
	e.mem["blow"] = [0.0, 2.2, 2.6, 3.0][e.phase]
	var warn: float = [0.0, 1.2, 1.0, 1.0][e.phase]
	Gust.start(e, best, warn, float(e.mem["blow"]), [0.0, 44.0, 48.0, 52.0][e.phase])
	e.state = "gust_tell"
	e.t = warn
	e.spr.play("grab")
	e.spr.speed_scale = 2.0
	e._anim_lock = warn
	e._telegraph(Color(0.85, 0.95, 1.0))
	Audio.play("dodge", 0.0, 0.05, 0.6)


static func _cock_hop_tell(e: Enemy) -> void:
	var b: Vector2 = e.world.player.global_position
	e.mem["hop_b"] = b
	e.tele().ring(b, 20.0, 0.75, RED)
	e.state = "hop_tell"
	e.t = 0.75
	e.scale = Vector2(1.1, 0.9)
	e.create_tween().tween_property(e, "scale", Vector2.ONE, 0.5)
	e._telegraph(Color(1, 0.5, 0.4))
	Audio.play("charge", -4.0, 0.05, 1.0)


## The gale: pale streaks drift the way the wind will blow and big arrows blink over the room (the
## warning), then the streaks race and Tallow is pushed (Player._move, so walls and cobwebs still count).
class Gust extends Node2D:
	var e: Enemy
	var dir := Vector2.RIGHT
	var warn := 1.0
	var blow := 2.2
	var push := 44.0
	var age := 0.0
	var streaks: Array = []

	static func start(owner_e: Enemy, d: Vector2, w: float, b: float, strength: float) -> void:
		var g := Gust.new()
		g.e = owner_e
		g.dir = d
		g.warn = w
		g.blow = b
		g.push = strength
		owner_e.world.fx_layer.add_child(g)

	func _ready() -> void:
		material = Art.unshaded
		z_index = -1
		var r: Rect2 = e.world.room.inner_rect()
		for i in 26:
			streaks.append([Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y)), randi_range(4, 9)])

	func _physics_process(dt: float) -> void:
		if not GuardiansV21._alive(e) or e.state == "roar":
			queue_free()
			return
		dt *= GuardiansV21._k(e)
		age += dt
		if age >= warn + blow + 0.3:
			queue_free()
			return
		var r: Rect2 = e.world.room.inner_rect()
		var spd := 22.0 if age < warn else 170.0
		for s in streaks:
			var q: Vector2 = s[0] + dir * spd * dt
			if not r.has_point(q):
				# wrap round to the upwind side
				q = Vector2(fposmod(q.x - r.position.x, r.size.x) + r.position.x, fposmod(q.y - r.position.y, r.size.y) + r.position.y)
			s[0] = q
		queue_redraw()
		if age >= warn and age < warn + blow:
			var p: Player = e.world.player
			if not p.dead and not p.frozen and dt > 0.0:
				p._move(dir * push * dt)

	func _draw() -> void:
		var blowing := age >= warn
		var col := Color("#cae6f5")
		col.a = 0.85 if blowing else 0.5
		for s in streaks:
			var a: Vector2 = s[0]
			for k in int(s[1]):
				if blowing or k % 2 == 0:
					draw_rect(Rect2((a - dir * k).round(), Vector2.ONE), col)
		if blowing or fmod(age, 0.32) > 0.2:
			return
		# the warning arrows: three double chevrons across the room, pointing downwind
		var c: Vector2 = e.world.room.center()
		var side := dir.orthogonal()
		for j in [-1, 0, 1]:
			for h in 2:
				var tip: Vector2 = c + side * 46.0 * j + dir * (6.0 * h - 3.0)
				for k in 6:
					for sgn in [-1.0, 1.0]:
						var q2: Vector2 = tip - dir * k + side * sgn * k
						draw_rect(Rect2(q2.round(), Vector2(2, 2)), Color("#21141b"))
						draw_rect(Rect2(q2.round(), Vector2.ONE), Color("#fdf7ed"))


# ================================================================= tests and tours
## --autotest --playtest --boss=<kind> [--runs=N]: each run goes straight into that guardian's room on its
## floor with the same kit for every guardian of that floor (TRIAL_KIT, plus the wax and the "your flame
## grows" of a run that got there), and the bot fights. One line per fight: time to kill and hits taken, or
## how far the guardian was when Tallow fell. Works for every guardian (balance against floor-mates).
const TRIAL_KIT := {1: ["bellows"], 2: ["bellows", "beeswax", "lamp_oil"],
	3: ["bellows", "beeswax", "lamp_oil", "sharp_wick", "thimble"],
	4: ["bellows", "beeswax", "lamp_oil", "sharp_wick", "thimble", "split_wick", "wax_coat"]}
const TRIAL_WAX := {1: 100.0, 2: 88.0, 3: 78.0, 4: 72.0}


static func floor_of(kind: String) -> int:
	var floors: Dictionary = load("res://scripts/game/world.gd").FLOORS
	for n in floors:
		if kind in floors[n]["bosses"]:
			return n
	return 1


static func trial(w: Node, kind: String) -> void:
	if w == null or w.get("player") == null or not Enemy.DEFS.has(kind) or not Enemy.DEFS[kind].get("boss", false):
		print("[boss] no such guardian: ", kind)
		return
	var n := floor_of(kind)
	for id in TRIAL_KIT.get(mini(n, 4), []):
		if Items.RELICS.has(id) and not id in w.player.relics:
			Items.apply(id, w.player, w)
	w.player.damage += 0.15 * (n - 1)
	w._start_floor(n)
	w.omen = ""
	w.boss_kind = kind
	w.player.wax = minf(w.player.wax_max, TRIAL_WAX.get(mini(n, 4), 80.0))
	var watch := Trial.new()
	watch.w = w
	watch.kind = kind
	watch.floor_n = n
	w.add_child(watch)
	w.get_tree().create_timer(1.0).timeout.connect(func():
		if not is_instance_valid(w) or w.finished:
			return
		var c: Vector2i = w.layout["boss"]
		w.cur_cell = c
		w.room.dispose()
		w.room = w._build_room(c)
		w.player.position = w.room.center() + Vector2(0, 56)
		w.cam.position = w._cam_target(w.room)
		w._on_enter_room())


## Watches one trial fight and prints how it went, then ends the run (so the next one starts).
class Trial extends Node:
	var w: Node
	var kind := ""
	var floor_n := 1
	var t := 0.0
	var hits0 := 0
	var started := false
	var done := false
	var phase_at: Array = []
	var last_phase := 1

	func _physics_process(dt: float) -> void:
		if done or not is_instance_valid(w):
			return
		var b: Variant = w.boss
		if not started:
			if b != null and is_instance_valid(b) and (b as Enemy).kind == kind and (b as Enemy).active:
				started = true
				hits0 = int(w.hits_total)
			return
		if Juice.holding(w):
			return
		t += dt
		var p: Player = w.player
		if b != null and is_instance_valid(b) and (b as Enemy).phase != last_phase:
			last_phase = (b as Enemy).phase
			phase_at.append("%.0f" % t)
		var phases := "/".join(phase_at) if not phase_at.is_empty() else "-"
		if p.dead:
			done = true
			var e: Enemy = b if b != null and is_instance_valid(b) else null
			print("[boss] %s floor %d: FELL after %.1f s, guardian at %d%% (phase %d), hits %d, phases at %s s" % [
				kind, floor_n, t, int(100.0 * e.hp / e.max_hp) if e else -1, e.phase if e else 0, int(w.hits_total) - hits0, phases])
			return
		if b == null or not is_instance_valid(b) or not (b as Enemy).alive:
			done = true
			print("[boss] %s floor %d: SNUFFED in %.1f s, hits %d, wax left %.0f, phases at %s s" % [
				kind, floor_n, t, int(w.hits_total) - hits0, p.wax, phases])
			w.get_tree().create_timer(0.6).timeout.connect(func():
				if is_instance_valid(w) and not w.finished:
					w.finished = true
					w._end_run(true))


## --autotest --tour --boss=<kind> --shots=DIR: the guardian's versus card, then two shots in each phase
## (the bot fights, unkillable; health is set to 60% and 30% to move the phases on).
static func tour(bot: Node, kind: String) -> void:
	bot.args["god"] = true
	bot.args["drive"] = true
	var n := floor_of(kind)
	bot.main.goto("game", {"seed": 11 + n})
	await bot._wait(1.2)
	var w: Node = bot.main.current
	w._start_floor(n)
	w.boss_kind = kind
	await bot._wait(0.3)
	bot._jump(w, w.layout["boss"])
	await bot._wait(0.55)
	await bot._shot("g21_%s_card" % kind)
	for ph in [1, 2, 3]:
		if ph > 1 and w.boss and is_instance_valid(w.boss):
			w.boss.mem.erase("hp_floor")
			w.boss.hp = w.boss.max_hp * (0.6 if ph == 2 else 0.3)
			w.boss._damage(0.01, false)
		await bot._wait(3.4 if ph > 1 else 3.0)
		await bot._shot("g21_%s_p%d_a" % [kind, ph])
		await bot._wait(1.7)
		await bot._shot("g21_%s_p%d_b" % [kind, ph])
	bot.get_tree().quit()
