class_name BossAI
extends RefCounted
## The newer floor guardians: the Wax Mother, the Sexton, the Melted Choir and the Great Pendulum.
## Each has three phases (by health: 66% / 33%), a roar between phases, and only telegraphed attacks:
## a flash plus an open-mouthed / raised-spade frame before every volley, rings where it will erupt.
## Bullet colours: rose wax (Mother), bone (Sexton), purple + sound rings (Choir), purple (Pendulum).

const RED := Color("#da4e38")
const PALE := Color("#cae6f5")


static func _phase_check(e: Enemy) -> bool:
	var np := e._boss_phase()
	if np != e.phase:
		e.phase = np
		e.on_new_phase()
		return true
	return false


static func _roar(e: Enemy) -> bool:
	if e.state == "roar":
		if e.t <= 0:
			e.state = "idle"
			e.cd = 0.6
		return true
	return false


static func _fan(e: Enemy, at: Vector2, base: float, n: int, spread: float, spd: float, kind: String) -> void:
	for i in n:
		e.world.enemy_shot(at, Vector2.from_angle(base + (i - (n - 1) / 2.0) * spread) * spd, kind)


static func _squash(e: Enemy, k := 1.0) -> void:
	e.scale = Vector2(1.0 + 0.12 * k, 1.0 - 0.12 * k)
	e.create_tween().tween_property(e, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ================================================================= THE WAX MOTHER (floor 1)
func boss_mother(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	if e.state == "idle" and _phase_check(e):
		return
	if _roar(e):
		return
	var mouth := e.global_position + Vector2(0, -14)
	match e.state:
		"idle":
			e._walk(ddt, to_p, e.speed * (1.0 + 0.35 * (e.phase - 1)))
			if e.cd <= 0:
				e._pattern += 1
				var opts := ["weep", "weep", "shed"]
				if e.phase >= 2:
					opts = ["weep", "spray", "shed", "spray"]
				if e.phase >= 3:
					opts = ["pour", "spray", "weep", "shed"]
				e.state = opts[e._pattern % opts.size()]
				e.t = {"weep": 0.65, "shed": 0.6, "spray": 0.5, "pour": 0.6}[e.state]
				e.play_anim("atk", e.t + 0.2)
				e._telegraph(Color(1, 0.55, 0.7))
				Audio.play("splash", -6.0, 0.05, 0.7)
				if e.state == "weep":
					e.tele().ring(e.global_position, 26.0, e.t, Color("#f78697"))
		"weep":
			if e.t <= 0:
				e._spin += 0.3
				e.world.burst(mouth, 12 + 2 * e.phase, 56.0, "bolt_wax", e._spin)
				_squash(e)
				e.world.shake(2.0)
				Audio.play("splash", 0.0, 0.05, 0.6)
				e.state = "idle"
				e.cd = 2.0 - 0.3 * e.phase
		"shed":
			if e.t <= 0:
				# her brood: one drop at first, two later, never a flood (and they do not split again)
				var brood: int = e.world.count_enemies() - 1
				var n := (1 if e.phase == 1 else 2) - maxi(0, brood - 1)
				for i in maxi(0, n):
					var sx := -1 if (e._pattern + i) % 2 == 0 else 1
					var m: Enemy = e.world.spawn_enemy("wax_blob", e.global_position + Vector2(18 * sx, 4))
					if m:
						m.set_meta("no_split", true)
						m.kvel = Vector2(90 * sx, 20)
				_squash(e, 1.5)
				Audio.play("splash", 2.0, 0.05, 0.5)
				e.state = "idle"
				e.cd = 1.6
		"spray":
			if e.t <= 0:
				for k in 3:
					e.later(0.28 * k, func():
						var a: float = (e.world.player.global_position - e.global_position).angle()
						_fan(e, mouth, a, 5, 0.2, 78.0, "bolt_wax")
						Audio.play("enemy_shoot", -2.0, 0.05, 0.8))
				e.state = "rest"
				e.t = 0.9
		"pour":
			if e.t <= 0:
				e.state = "pouring"
				e.t = 2.2
				e._wob = 0.0
				e._spin = randf() * TAU
		"pouring":
			e._wob -= ddt
			if e._wob <= 0:
				e._wob = 0.14
				e._spin += 0.45
				for k in 3:
					e.world.enemy_shot(mouth, Vector2.from_angle(e._spin + k * TAU / 3.0) * 60.0, "bolt_wax")
			if e.t <= 0:
				e.state = "idle"
				e.cd = 1.4
		"rest":
			if e.t <= 0:
				e.state = "idle"
				e.cd = 1.0


# ================================================================= THE SEXTON (floor 2)
func boss_sexton(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	if e.state == "idle" and _phase_check(e):
		return
	if _roar(e):
		return
	var p: Player = e.world.player
	match e.state:
		"idle":
			var want := to_p if dist > 60 else to_p.orthogonal() * (1.0 if sin(e._wob) > 0 else -1.0)
			e._wob += ddt * 0.8
			e._walk(ddt, want, e.speed * (1.0 + 0.15 * e.phase))
			if e.cd <= 0:
				e._pattern += 1
				var opts := ["toss", "dig"]
				if e.phase >= 2:
					opts = ["toss", "dig", "raise", "toss", "dig"]
				if e.phase >= 3:
					opts = ["dig", "toss", "dig", "raise"]
				e.state = opts[e._pattern % opts.size()]
				match e.state:
					"toss":
						e.t = 0.55
						e.play_anim("atk", 0.0)
						e.spr.pause()
						e.spr.frame = 0
						e._telegraph(Color(1, 1, 0.8))
						Audio.play("charge", -6.0, 0.05, 1.1)
					"dig":
						e.t = 0.45
						e.play_anim("atk", 0.0)
						e.spr.pause()
						e.spr.frame = 1
						Audio.play("crate_break", -4.0, 0.05, 0.6)
					"raise":
						e.t = 0.7
						e._telegraph(Color(0.6, 1.0, 0.6))
						Audio.play("teleport", -2.0, 0.05, 0.6)
		"toss":
			if e.t <= 0:
				e.spr.frame = 1
				var n := 3 if e.phase < 3 else 5
				_fan(e, e.global_position + Vector2(6, -16), to_p.angle(), n, 0.24, 88.0, "bolt_bone")
				Audio.play("enemy_shoot", 0.0, 0.05, 0.9)
				if e.phase >= 2:
					e.later(0.35, func():
						var a: float = (e.world.player.global_position - e.global_position).angle()
						_fan(e, e.global_position + Vector2(6, -16), a, 2, 0.5, 80.0, "bolt_bone"))
				e.state = "rest"
				e.t = 0.5
		"dig":
			if e.t <= 0:
				e.buried = true
				e.active = false
				e.spr.play("mound")
				e._anim_lock = 0.0
				e.world.fx_debris(e.global_position, "R")
				e.state = "under"
				e.t = 1.5 - 0.2 * e.phase
		"under":
			e.active = false
			var spd := 70.0 + 10.0 * e.phase
			var r: Rect2 = e.world.room.inner_rect().grow(-14)
			e.global_position = (e.global_position + to_p.normalized() * minf(spd * ddt, dist)).clamp(r.position, r.end)
			if e.t <= 0 or dist < 6.0:
				e.state = "tell"
				e.t = 0.8
				e.tele().ring(e.global_position, 22.0, 0.8, RED)
				Audio.play("charge", -4.0, 0.05, 0.6)
		"tell":
			e.spr.position.x = sin(e.t * 60.0) * 1.5
			if e.t <= 0:
				e.spr.position.x = 0
				e.buried = false
				e.active = true
				e.play_anim("atk", 0.6)
				e.spr.pause()
				e.spr.frame = 1
				e.world.burst(e.global_position + Vector2(0, -8), 10 + 2 * e.phase, 70.0, "bolt_bone", randf() * TAU)
				e.world.shake(4.0)
				Audio.play("explosion", -4.0, 0.05, 0.7)
				for k in 4:
					e.world.fx_debris(e.global_position + Vector2(randf_range(-10, 10), 0), "R")
				if dist < e.radius + 12.0 and not p.dead:
					p.hurt(8.0 * e.world.enemy_dmg_mult(), to_p)
				e.state = "rest"
				e.t = 0.9
		"raise":
			if e.t <= 0:
				var hands := 0
				for m in e.world.enemies:
					if is_instance_valid(m) and m.alive and m.kind == "grave_hand":
						hands += 1
				for i in mini(2, 3 - hands):
					e.world.spawn_enemy("grave_hand", e.free_spot(p.global_position, 40.0, 110.0))
				Audio.play("urn_break", -2.0, 0.05, 0.5)
				e.state = "rest"
				e.t = 0.4
		"rest":
			if e.t <= 0:
				if e.spr.animation != "idle":
					e.spr.play("idle")
				e.state = "idle"
				e.cd = 0.9 - 0.1 * e.phase


# ================================================================= THE MELTED CHOIR (floor 3)
## Where each voice sings from (left, middle, right), relative to the choir's feet.
const VOICE := [Vector2(-15, -26), Vector2(0, -30), Vector2(15, -26)]


func boss_choir(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	if e.state == "idle" and _phase_check(e):
		e.spr.play("idle")
		return
	if _roar(e):
		return
	var p: Player = e.world.player
	match e.state:
		"idle":
			# drift along the upper half of the chapel, keeping across from Tallow
			var room: Room = e.world.room
			var goal := Vector2(clampf(p.global_position.x, room.position.x + 84, room.position.x + 188), room.position.y + 80)
			var d := goal - e.global_position
			if d.length() > 4.0:
				e._move(d.normalized() * e.speed * ddt)
			if e.cd <= 0:
				e._pattern += 1
				var v := e._pattern % 3
				var voices: Array = [v]
				if e.phase >= 2:
					voices.append((v + 1) % 3)
				if e.phase >= 3:
					voices = [0, 1, 2]
				e.mem["voices"] = voices
				e.spr.play("sing")
				e.spr.pause()
				e.spr.frame = v if voices.size() == 1 else 3
				e._telegraph(Color(1, 0.9, 0.7))
				for vv in voices:
					e.tele().ring(e.global_position + VOICE[vv], 7.0, 0.6, Color("#f78697"))
					Audio.play("tick", -2.0, 0.0, 0.7 + 0.3 * vv)
				e.state = "inhale"
				e.t = 0.6 if e.phase < 3 else 0.5
		"inhale":
			if e.t <= 0:
				for vv in e.mem["voices"]:
					_voice(e, vv)
				e.state = "sing"
				e.t = 0.5
				if e.phase >= 2 and e._pattern % 3 == 0:
					var books := 0
					for m in e.world.enemies:
						if is_instance_valid(m) and m.alive and m.kind == "psalter":
							books += 1
					if books < 2:
						e.world.spawn_enemy("psalter", e.global_position + Vector2(randf_range(-30, 30), -4))
		"sing":
			if e.t <= 0:
				e.spr.play("idle")
				e.state = "idle"
				e.cd = 1.5 - 0.2 * e.phase


static func _voice(e: Enemy, v: int) -> void:
	var at: Vector2 = e.global_position + VOICE[v]
	var p: Player = e.world.player
	match v:
		0:
			# the alto: an aimed fan
			_fan(e, at, (p.global_position + Vector2(0, -8) - at).angle(), 5, 0.22, 78.0, "bullet_purple")
			Audio.play("enemy_shoot", 0.0, 0.05, 0.9)
		1:
			# the treble: a ring of sound
			e.world.burst(at, 14, 54.0, "bolt_ring", randf() * TAU)
			Audio.play("bell_toll", -8.0, 0.05, 1.9)
		2:
			# the bass: three hard notes straight at you
			for k in 3:
				e.later(0.16 * k, func():
					var a: Vector2 = e.global_position + VOICE[2]
					var dirv: Vector2 = (e.world.player.global_position + Vector2(0, -8) - a).normalized()
					e.world.enemy_shot(a, dirv * 96.0, "bullet_purple")
					Audio.play("enemy_shoot", -2.0, 0.05, 0.6))


# ================================================================= THE GREAT PENDULUM (floor 4)
const PEND_ANCHOR := Vector2(136, 22)
const PEND_LEN := 96.0
const PEND_RING := 33.0


static func _pend_place(e: Enemy, theta: float) -> void:
	var anchor: Vector2 = e.world.room.position + PEND_ANCHOR
	var ring := anchor + Vector2(sin(theta), cos(theta)) * PEND_LEN
	e.global_position = ring + Vector2(0, PEND_RING)
	var tl := e.tele()
	tl.rod = true
	tl.rod_anchor = anchor
	tl.rod_end = Vector2(0, -PEND_RING + 1)
	tl.queue_redraw()


func init_boss_pendulum(e: Enemy) -> void:
	e.mem["amp"] = 0.0
	e.mem["theta"] = 0.0
	e.state = "wind"
	_pend_place(e, 0.0)


func boss_pendulum(e: Enemy, ddt: float, _to_p: Vector2, _dist: float) -> void:
	var np := e._boss_phase()
	if np != e.phase and e.state == "swing":
		e.phase = np
		e.on_new_phase()
		e.state = "halt"
		e.t = 1.4
	var want_amp: float = [0.0, 0.95, 1.1, 1.25][e.phase]
	var speed: float = [0.0, 1.85, 2.2, 2.55][e.phase]
	match e.state:
		"wind":
			# winds up from rest: show the sweep so you learn where not to stand
			if not e.mem.has("shown"):
				e.mem["shown"] = true
				var pts := PackedVector2Array()
				var anchor: Vector2 = e.world.room.position + PEND_ANCHOR
				for i in 25:
					var th := lerpf(-want_amp, want_amp, i / 24.0)
					pts.append(anchor + Vector2(sin(th), cos(th)) * PEND_LEN + Vector2(0, PEND_RING - 16))
				e.tele().path(pts, 1.8, Color("#da4e38"))
			e.mem["amp"] = move_toward(e.mem["amp"], want_amp, ddt * 0.6)
			e._spin += ddt * speed
			if e.mem["amp"] >= want_amp - 0.001:
				e.state = "swing"
		"halt":
			e.mem["amp"] = move_toward(e.mem["amp"], 0.0, ddt * 1.4)
			e._spin += ddt * speed * 0.5
			if e.t <= 0.5 and not e.mem.get("tolled", false):
				e.mem["tolled"] = true
				Audio.play("bell_toll", -2.0, 0.0, 0.8)
				e.world.burst(e.global_position + Vector2(0, -16), 16, 58.0, "bullet_purple", randf() * TAU)
			if e.t <= 0:
				e.mem["tolled"] = false
				e.mem.erase("shown")
				e.state = "wind"
		"roar":
			e.state = "halt"
			e.t = 1.4
		_:
			e.mem["amp"] = move_toward(e.mem["amp"], want_amp, ddt * 0.5)
			e._spin += ddt * speed
	var s := sin(e._spin)
	var theta: float = e.mem["amp"] * s
	_pend_place(e, theta)
	e.spr.flip_h = false
	var centre := e.global_position + Vector2(0, -16)
	# contact: the whole bob is dangerous
	var p: Player = e.world.player
	if not p.dead and e.world.freeze_t <= 0.0 and (p.global_position + Vector2(0, -6)).distance_to(centre) < 18.0:
		p.hurt(8.0 * e.world.enemy_dmg_mult(), p.global_position - centre)
	if e.state != "swing":
		return
	# warn just before each turn, strike at the turn ("tock"), and fire low at the bottom
	if absf(s) > 0.86 and not e.mem.get("warned", false):
		e.mem["warned"] = true
		e.play_anim("atk", 0.45)
		e._telegraph(Color(1, 0.4, 0.3))
		Audio.play("tick", 0.0, 0.0, 1.2)
	if absf(s) > 0.985 and not e.mem.get("tock", false):
		e.mem["tock"] = true
		e._pattern += 1
		e.world.burst(centre, 8 + 2 * e.phase, 58.0 + 6.0 * e.phase, "bullet_purple", e._pattern * 0.21)
		e.world.shake(2.0)
		Audio.play("tick", 2.0, 0.0, 0.55)
		if e.phase >= 2 and e._pattern % 2 == 0:
			var beetles := 0
			for m in e.world.enemies:
				if is_instance_valid(m) and m.alive and m.kind == "deathwatch":
					beetles += 1
			if beetles < 3:
				e.world.spawn_enemy("deathwatch", e.world.free_spot_near(centre + Vector2(0, 10), 5.0))
	if absf(s) < 0.5:
		e.mem["warned"] = false
		e.mem["tock"] = false
	if e.phase >= 2 and absf(s) < 0.06 and not e.mem.get("low", false):
		e.mem["low"] = true
		var a := (p.global_position + Vector2(0, -8) - centre).angle()
		_fan(e, centre, a, 3, 0.18, 92.0, "bullet_purple")
	if absf(s) > 0.3:
		e.mem["low"] = false
